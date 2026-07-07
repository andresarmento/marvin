# MaRVin SoC — Memória Principal do Projeto

## O que é este projeto

SoC RISC-V (RV32I) chamado **MaRVin**, desenvolvido por André Sarmento (2025-2026).
Este repositório contém **apenas o SoC** (memória, integração, periféricos). A CPU
didática própria (`marvin_cpu` "de verdade") está sendo desenvolvida em **repositório
separado** e ainda não está pronta.

Enquanto a CPU didática não atinge RV32I completo, o SoC usa uma CPU placeholder
funcional: `rtl/marvin_cpu.v`, derivada do **FemtoRV32 Quark** (Bruno Levy / Matthias
Koch, 2020-2021). Objetivo futuro: substituir esse placeholder pela CPU didática
própria assim que ela estiver pronta.

Remote `origin`: https://github.com/andresarmento/marvin.git

## Estrutura do repositório

```
rtl/            Fontes Verilog do SoC
  marvin.v        Top-level do SoC (integra CPU + memória + periféricos, decodificador de endereço)
  marvin_cpu.v    CPU placeholder (baseada em FemtoRV32 Quark)
  marvin_mem.v    Memória unificada (ROM + RAM)
  marvin_gpio.v   Periférico GPIO (DIR/OUT, saída apenas por enquanto)
  marvin_uart.v   Periférico UART (8N1, sem FIFO, sem interrupção; TX+RX)
sim/            Simulação (atualmente 00_soc.dig — Digital simulator)
sw/             Software / firmware
  startup/        crt0.S (startup compartilhado, fora da lib de drivers)
  linkers/        marvin.ld (linker script compartilhado)
  toolchain/      riscv-none-elf-gcc (xpack) + w64devkit, instalado localmente
  tools/          bin2hex.py e outras ferramentas de build
  marvin_lib/     Biblioteca de drivers de periféricos (include/ + src/), ex: marvin_gpio
  examples/       Programas de teste/exemplo (ver seção abaixo)
docs/
  help/           Notas de ajuda (git, markdown)
  specs/          PDFs das especificações RISC-V (ISA priv/unpriv, ASM)
claude_memory/  Memória do projeto para o Claude (este diretório)
```

**Convenção de onde fica cada coisa em `sw/`**: `marvin_lib/` é só pra APIs de
periféricos (um `.h`/`.c` por periférico). `crt0.S` (startup/boot) e o linker
script (`marvin.ld`, memory layout) ficam fora da lib, em `sw/startup/` e
`sw/linkers/` respectivamente — são categorias diferentes (boot vs. layout de
memória vs. driver de periférico), decisão confirmada com o usuário em 2026-07-04.

## Arquitetura do SoC (estado atual)

**Top-level (`maRVin` em rtl/marvin.v):**
- Instancia `maRVin_cpu` + `maRVin_mem` + `maRVin_gpio`, ligados por um barramento
  simples estilo picoRV32: `mem_addr`, `mem_wdata`, `mem_wmask`, `mem_rdata`,
  `mem_valid`, `mem_ready`.
- **Decodificador de endereço** (adicionado em 2026-07-05, antes não existia —
  a CPU só enxergava a memória, ligação direta sem decisão de endereço nenhuma):
  `rom_selected`/`ram_selected`/`gpio_selected`/`uart1_selected` decodificados
  combinacionalmente a partir de `cpu_addr`, roteando `mem_valid`/`gpio_valid`/
  `uart1_valid` pro periférico certo e muxando `cpu_ready`/`cpu_rdata` de volta
  pra CPU. Mapa completo em [[ARCHITECTURE]].
- Sinais de debug expostos no topo: `dbg_x1`, `dbg_x2`, `dbg_x15` (`dbg_state` foi
  removido da lista de portas do topo, mas continua existindo como porta de saída
  não conectada em `marvin_cpu.v` — se precisar de volta, é só reconectar).
- Reset é **ativo baixo**: `nrst`.

**CPU (`maRVin_cpu` em rtl/marvin_cpu.v):**
- Baseada no FemtoRV32 Quark, com adaptações do usuário:
  - Interface de memória `mem_valid`/`mem_ready` (estilo picoRV32) em vez da interface
    original do FemtoRV32.
  - Estado inicial é `FETCH_INSTR`.
  - Reset renomeado para `nrst`.
  - Valores iniciais definidos no reset (não em bloco `initial`).
  - `RESET_ADDR` e `ADDR_WIDTH` como parâmetros (`RESET_ADDR=32'h0000_0000`,
    `ADDR_WIDTH=32` instanciado no top-level).
  - ECALL/EBREAK ignorados.
  - Contador de ciclos removido.

**Pegadinha importante da FSM da CPU (descoberta em 2026-07-05, ver [[CHANGELOG]]):**
O FemtoRV32 Quark original assume que `mem_ready` fica **ocioso em alto** (sempre
pronto quando não há transação pendente) — por isso o design original usa
`WAIT_ALU_OR_MEM` como estado inicial de reset (em vez de `FETCH_INSTR`) como
truque de bootstrap, e a condição de saída desse estado (`!aluBusy & mem_ready`)
não distingue entre "esperando a memória" e "esperando o ALU/shift terminar" — ela
conta com `mem_ready` estar sempre em 1 quando não há acesso à memória em voo.
Só que a interface deste projeto foi adaptada pro estilo **picoRV32**
(`ready <= valid`, registrado), que fica **ocioso em baixo**. Isso quebra duas
coisas se a CPU não for adaptada:
1. O estado inicial precisa ser `FETCH_INSTR` (não `WAIT_ALU_OR_MEM`), porque em
   `WAIT_ALU_OR_MEM` o `mem_addr` vem de `loadstore_addr` (não do `PC`), calculado
   a partir de registradores (`rs1`/`instr`) nunca resetados — endereço de
   lixo/`X` que trava o decodificador de endereço permanentemente.
2. A condição de saída do `WAIT_ALU_OR_MEM` precisa ser
   `!aluBusy & (mem_ready | !(isLoad|isStore))` — só exigir `mem_ready` quando a
   instrução realmente for load/store; senão qualquer shift (SLL/SRL/SRA) trava a
   CPU pra sempre esperando um `mem_ready` que nunca vai subir (já que nenhuma
   transação de memória foi solicitada).

Se algum dia mexer de novo nessa FSM (`marvin_cpu.v`), ou portar outro núcleo
FemtoRV32/similar pro mesmo barramento, verificar essa suposição de "ready ocioso"
primeiro — é a causa mais provável de qualquer travamento silencioso (sem erro,
sem timeout, só para de avançar).

**Memória (`maRVin_mem` em rtl/marvin_mem.v):**
- Memória única (array `memory`, parametrizável em `WORDS`, default instanciado com
  2048 words = 8KB) que serve tanto de ROM quanto de RAM via mapeamento de endereço.
- Mapa de endereços:
  - ROM: a partir de `0x0000_0000`
  - RAM: baseada em `0x8000_0000`, mascarada com `RAM_ADDR_MASK = 0xC000_0000`
    (faixa `0x8000_0000` a `0xBFFF_FFFF`)
  - Endereço físico dentro do array: RAM é remapeada para `0x1000` + offset (12 bits
    de índice — atenção, isso limita a RAM útil a 4K words dentro do array de 2048
    words do exemplo atual; ver **Known Issues** abaixo).
- Carrega o programa inicial via `$readmemh`, apontando atualmente para
  `sw/examples/03_gpio_out/gpio_out.hex` (o nome do arquivo em
  `initial $readmemh(...)` é trocado manualmente pelo usuário conforme qual
  teste ele quer rodar — ver `sw/examples/` abaixo). Path base é absoluto
  hardcoded via `` `define HEX_FILES_PATH ``
  (`C:/Users/andre/Downloads/PROJECTS/marvin/sw/examples/`).
- `ready` é registrado (1 ciclo de latência após `valid`).
- **RAM é espelhada (mirroring)**: só os 12 bits baixos do endereço são decodificados
  dentro da janela de RAM (1GB lógico), então só existem 4KB físicos reais de RAM
  (metade superior do array `memory`), repetidos por toda a faixa `0x8000_0000`-
  `0xBFFF_FFFF`. Comentário explicando isso já está no código, acima da linha do
  `phy_address` em `marvin_mem.v`.

**GPIO (`maRVin_gpio` em rtl/marvin_gpio.v)** — primeiro periférico do SoC,
adicionado em 2026-07-05:
- Endereço base `0xC000_0000`, registradores `GPIO_DIR` (offset `0x00`) e
  `GPIO_OUT` (offset `0x04`). Sem `GPIO_IN` separado por enquanto — ler
  `GPIO_OUT` já retorna o estado real do pino via barramento tri-state
  (`data_out <= gpio;`), não um registrador interno; decisão do usuário, só
  saída por enquanto.
- Barramento externo `gpio` é `[31:0]` dentro do módulo, mas só `[3:0]` chegam
  no topo do SoC (`rtl/marvin.v`) — confirmado intencional (só 4 pinos físicos
  por enquanto). Os bits `[31:4]` ficam sem conexão real; um read-modify-write
  de 32 bits (como a lib C faz) lê `X` nesses bits, o que é inofensivo hoje mas
  vale revisar se um dia usarem mais pinos ou um `GPIO_IN` de verdade.
- Cada pino usa lógica tri-state por bit: `gpio[i] = gpio_dir[i] ? gpio_out[i] : 1'bz`.
- Reset síncrono (igual ao resto do SoC), `case` com `default` explícito
  (zera `data_out` em qualquer offset não mapeado).
- Driver C em `sw/marvin_lib/` (`marvin_gpio.h/.c`): `gpio_write`, `gpio_read`
  (lê `GPIO_OUT`, refletindo o estado de saída do pino), `gpio_dir`,
  `gpio_toggle` (`gpio_write(pin, !gpio_read(pin))`).

**UART1 (`maRVin_uart` em rtl/marvin_uart.v)** — segundo periférico do SoC,
adicionado em 2026-07-06:
- Endereço base `0xC000_1000`, registradores `UART1_TX` (offset `0x00`, escrita),
  `UART1_RX` (offset `0x04`, leitura) e `UART1_STAT` (offset `0x08`: bit0 =
  `ready_tx`, bit1 = `available_rx`). 8N1, sem FIFO, sem interrupção — TX e RX
  cada um com sua própria máquina de estados (`IDLE`/`START`/`DATA`/`STOP`) e
  contador de ticks (`BIT_PERIOD = CLOCK_FREQ / BAUDRATE`, em ciclos de clock).
- **Convenção de polaridade**: o driver usa `ready_tx` (1 = livre pra transmitir),
  não `busy_tx` (1 = ocupado) — decisão do usuário por ser o padrão mais comum em
  periféricos reais (flag ativo-alto = estado "bom"/pronto, não "ruim"/ocupado).
  O RTL originalmente usava `busy_tx`; foi renomeado e a polaridade invertida em
  todos os pontos (reset, IDLE, início de transmissão, fim do STOP, contador de
  ticks, permissão de escrita no TX port, montagem do status) pra bater com
  `uart1_ready_tx()` no driver C.
- **Dois bugs sérios encontrados e corrigidos no RTL durante revisão** (ver
  [[CHANGELOG]] 2026-07-06 para o histórico completo):
  1. RX travava pra sempre: `DATA_bit`/`STOP_bit` comparavam
     `tick_count_rx == BIT_PERIOD`, mas o contador nunca atinge esse valor (reseta
     ao chegar em `BIT_PERIOD - 1`) — corrigido pra `== BIT_PERIOD - 1`, igual ao
     padrão já usado no lado TX.
  2. Mistura de atribuição bloqueante (`=`) com não-bloqueante (`<=`) pros
     registradores de estado (`tx_state`/`rx_state`) dentro de blocos sequenciais
     — trocado tudo pra `<=` por consistência/segurança.
  Ambos verificados com uma testbench Icarus Verilog descartável (fora do repo,
  como já é hábito neste projeto): TX decodificado corretamente na linha serial,
  RX recebendo dois bytes consecutivos sem travar.
- Driver C em `sw/marvin_lib/` (`marvin_uart.h/.c`): `uart1_ready_tx`,
  `uart1_available`, `uart1_getc`/`uart1_putc`, `uart1_read`/`uart1_write`
  (buffers `unsigned char*` — podem carregar binário), `uart1_readline`/
  `uart1_writeline` (buffers `char*` — texto; cast explícito pra
  `unsigned char*` só no ponto em que `uart1_writeline` chama `uart1_write`),
  `uart1_strlen` (reimplementado pra não depender de libc). `uart1_getc`/
  `uart1_read`/`uart1_readline` **não bloqueiam** em `uart1_available()` por
  padrão (documentado no header) — variantes bloqueantes existem à parte
  (`uart1_getc_blocking`, `uart1_readline_blocking`), seguindo o mesmo padrão de
  `getc`+`_blocking` visto em SDKs reais (Raspberry Pi Pico SDK, STM32 HAL).
- **Pendência conhecida**: a instância em `rtl/marvin.v` usa
  `CLOCK_FREQ(100)/BAUDRATE(10)` — valores de placeholder (iguais aos defaults
  do próprio módulo para simulação), não a frequência real do clock do SoC nem
  um baud rate padrão. Precisa ser ajustado antes de testar com hardware/terminal
  serial real. Ver [[TODO]].
- **Preferência do usuário para uma futura segunda UART**: em vez de generalizar
  o driver pra receber um handle/endereço base como parâmetro (padrão de HALs
  "profissionais" tipo STM32 HAL), a preferência é duplicar o padrão já usado
  (`uart2_*`/`UART2_BASE` num novo par de arquivos), mantendo a lib direta e sem
  abstração — consistente com [[feedback_marvin_lib_scope]]. Ainda não
  implementado, só uma decisão de design discutida e registrada.

## Programas de teste (`sw/examples/`)

Três programas `.hex` escritos manualmente (RV32I puro, sem toolchain/assembler —
os valores hex são calculados a mão), cada um com comentário por instrução:

- `sw/examples/00_test_alu.hex` — aritmética simples com x1/x2 (ADDI/ADD/SUB), termina em
  loop infinito (`jal x0,0`). Resultado esperado: x1=2, x2=13.
- `sw/examples/00_test_loop.hex` — 4 NOPs + `jal` de volta pro início (loop infinito puro).
- `sw/examples/00_test_mem.hex` — usa x1 como ponteiro pra RAM (`lui x1,0x80000`), escreve
  x2=5 na RAM, sobrescreve x2 com sentinela -1, recarrega da RAM (prova que o load
  funciona), depois faz um loop decrementando x2 de 5 até 0, e repete tudo pra
  sempre. Todos os três foram validados rodando o SoC completo com **Icarus
  Verilog** (iverilog, disponível em `C:/iverilog`), instanciando `maRVin` direto
  e observando `dbg_x1`/`dbg_x2`/`address`/`state` (e, no caso do teste de
  memória, acessando `dut._maRVin_cpu.registerFile[...]` e
  `dut._maRVin_mem.memory[...]` por referência hierárquica, já que só x1/x2/x15
  são expostos como debug no topo).

A partir daqui os exemplos passaram a usar o toolchain RISC-V de verdade
(`riscv-none-elf-gcc`, em `sw/toolchain/`) em vez de hex calculado à mão, cada um
com seu próprio `makefile` (padrão estabelecido em `02_loop_c`, ver [[TODO]] e
[[CHANGELOG]]):
- `sw/examples/01_loop_asm/` — loop em assembly montado pela toolchain.
- `sw/examples/02_loop_c/` — loop em C compilado e rodando no SoC.
- `sw/examples/03_gpio_out/` — usa `marvin_lib` (`marvin_gpio.h/.c`) pra piscar
  os pinos 0/1 do GPIO em loop com delay. Primeiro programa a exercitar o
  decodificador de endereço do topo e a pegadinha de FSM/shift documentada acima.
- `sw/examples/04_gpio_in/` — GPIO de entrada, ver [[CHANGELOG]] (2026-07-05).
- `sw/examples/05_uart_tx/` (`uart_tx.c`, renomeado de `05_uart`/`uart.c` em
  2026-07-06) — pisca GPIO 0/1 e manda `"Hello World!"` via `uart1_writeline`
  em loop. Primeiro programa a exercitar a UART.

## Known Issues / Pontos de atenção

- O mapeamento de endereço físico da RAM (`(address & 16'h0FFF) | 16'h1000`) usa
  índices de 16 bits mas o array tem `WORDS` parametrizável — revisar se o
  dimensionamento faz sentido para diferentes tamanhos de `WORDS`.
- Path do `.hex` está hardcoded para a máquina do usuário (`C:/Users/andre/...`) —
  não é portável, mas é aceitável para uso pessoal/local por enquanto.
- O nome do arquivo `.hex` carregado por `$readmemh` é hardcoded direto no
  `initial` de `marvin_mem.v` (hoje: `03_gpio_out/gpio_out.hex`) — trocar de
  teste exige editar o RTL. Nenhum mecanismo de seleção de programa foi criado
  ainda.
- GPIO só tem saída (`GPIO_DIR`/`GPIO_OUT`); `GPIO_IN` está reservado na lib C
  mas não implementado no RTL ainda.
- Barramento `gpio` é `[31:0]` dentro de `marvin_gpio.v` mas só `[3:0]` chegam
  no topo do SoC — bits `[31:4]` ficam sem conexão real (leem `X`).
- Instância da UART em `rtl/marvin.v` usa `CLOCK_FREQ(100)/BAUDRATE(10)` —
  placeholders de simulação, não a frequência real do clock do SoC nem um baud
  rate padrão. Precisa corrigir antes de testar em hardware/terminal real.

## Convenções observadas no código

- Nomes de módulos em CamelCase com prefixo `maRVin_` (ex: `maRVin_cpu`, `maRVin_mem`,
  `maRVin_gpio`).
- Reset sempre ativo baixo, nomeado `nrst`, e **síncrono** (`always @(posedge clk)`
  puro, sem `negedge nrst` na sensibilidade) em todos os módulos.
- Comentários de cabeçalho de arquivo com autor e ano.
- Sinais de barramento de memória/periférico seguem convenção picoRV32-like
  (`address/data_in/data_out/wmask/valid/ready`, ou `mem_*` na CPU) — `ready`
  fica **ocioso em baixo** (registrado, um ciclo depois de `valid`), diferente
  da suposição original do FemtoRV32 Quark (ver pegadinha de FSM acima).
- `sw/marvin_lib/` é só pra drivers de periféricos; `crt0.S`/linker script ficam
  fora da lib, em `sw/startup/`/`sw/linkers/`.

## Referências externas

- FemtoRV32 (Quark) — base original da CPU: Bruno Levy / Matthias Koch.
- Especificações RISC-V em `docs/specs/` (priv-isa, unpriv-isa, riscv-asm).

## Ver também

- [[TODO]] — lista de tarefas em aberto
- [[CHANGELOG]] — histórico de mudanças do projeto
- [[ARCHITECTURE]] — detalhes de mapa de memória e interfaces (quando crescer além do que cabe aqui)
