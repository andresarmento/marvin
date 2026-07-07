# ARCHITECTURE — MaRVin SoC

Detalhes de mapa de memória e interfaces. Mantido separado do [[CLAUDE]] para não
inchar a memória principal conforme o SoC ganhar mais periféricos.

## Mapa de endereços (atual)

| Faixa                         | Região | Observação                              |
|--------------------------------|--------|------------------------------------------|
| `0x0000_0000` – `0x7FFF_FFFF`  | ROM    | Programa, carregado via `$readmemh`       |
| `0x8000_0000` – `0xBFFF_FFFF`  | RAM    | Selecionada por `RAM_ADDR_MASK=0xC000_0000` |
| `0xC000_0000` – `0xC000_00FF`  | GPIO   | Selecionada por `GPIO_ADDR_MASK=0xFFFF_FF00` |
| `0xC000_1000` – `0xC000_10FF`  | UART1  | Selecionada por `UART1_ADDR_MASK=0xFFFF_FF00` |

Decodificação feita em `rtl/marvin.v` (`rom_selected`/`ram_selected`/
`gpio_selected`/`uart1_selected`), não dentro dos periféricos — `marvin_mem.v`,
`marvin_gpio.v` e `marvin_uart.v` recebem `valid` já filtrado pelo endereço
correto (exceto pela sub-decodificação ROM-vs-RAM que `marvin_mem.v` ainda faz
internamente, ver abaixo).

### Registradores da UART1 (`rtl/marvin_uart.v`, base `0xC000_1000`)

8N1, sem FIFO, sem interrupção. Adicionada em 2026-07-06.

| Offset  | Registrador   | Descrição                                          |
|---------|----------------|------------------------------------------------------|
| `0x00`  | `UART1_TX`     | Escrita: enfileira um byte pra transmitir (só aceita se `ready_tx=1`) |
| `0x04`  | `UART1_RX`     | Leitura: último byte recebido (bits `[7:0]`)         |
| `0x08`  | `UART1_STAT`   | bit0 = `ready_tx` (1=livre pra transmitir), bit1 = `available_rx` (1=byte recebido esperando leitura) |

**Polaridade de `ready_tx` (não `busy_tx`):** decisão do usuário em 2026-07-06 —
um flag ativo-alto de "pronto" é mais comum em periféricos reais do que um
ativo-alto de "ocupado". O RTL foi renomeado de `busy_tx` pra `ready_tx` com a
polaridade invertida em todos os pontos que o usam (reset, estado IDLE, início
de transmissão, fim do STOP bit, condição do contador de ticks, permissão de
escrita no TX port, montagem do status). Ler `uart1_ready_tx()` no driver C
espera exatamente essa convenção (bit0=1 quando pronto).

**Contrato de bloqueio do driver C** (`sw/marvin_lib/marvin_uart.h/.c`):
`uart1_getc`/`uart1_read`/`uart1_readline` **não bloqueiam** em
`uart1_available()` — é responsabilidade de quem chama garantir que há dado
novo, ou usar as variantes `uart1_getc_blocking`/`uart1_readline_blocking`.
`uart1_putc`/`uart1_write`/`uart1_writeline` sempre bloqueiam em
`uart1_ready_tx()` internamente (busy-wait), já que TX sempre vai ficar pronto
eventualmente (garantia que precisa vir do RTL) e não há razão pra expor uma
variante não-bloqueante do lado de escrita.

**Tipos dos buffers**: `uart1_read`/`uart1_write` usam `unsigned char*` (podem
carregar dado binário arbitrário); `uart1_readline`/`uart1_writeline`/
`uart1_strlen` usam `char*` (orientados a texto, evita warning de assinatura de
ponteiro ao passar literais de string tipo `"Hello World!"`). O único ponto de
cruzamento (`uart1_writeline` chamando `uart1_write`) faz um cast explícito.

**Dois bugs de RTL encontrados e corrigidos durante a revisão desta sessão**
(ver [[CHANGELOG]] 2026-07-06):
1. RX travava pra sempre — `DATA_bit`/`STOP_bit` comparavam
   `tick_count_rx == BIT_PERIOD`, valor que o contador nunca atinge (reseta ao
   chegar em `BIT_PERIOD - 1`, igual ao padrão já usado no lado TX). Corrigido
   pra `== BIT_PERIOD - 1`.
2. Atribuições bloqueantes (`=`) misturadas com não-bloqueantes (`<=`) pros
   registradores `tx_state`/`rx_state` dentro de `always @(posedge clk)` — três
   ocorrências corrigidas pra `<=`.
Verificado com testbench Icarus Verilog descartável (fora do repo): byte TX
decodificado corretamente na linha serial, dois bytes RX recebidos em sequência
sem travar (confirma que o bug do contador foi realmente a causa do travamento).

### Registradores do GPIO (`rtl/marvin_gpio.v`, base `0xC000_0000`)

Redesenhado em 2026-07-05: os registradores antigos (`GPIO_DIR`/`GPIO_OUT` únicos,
com escrita de byte inteiro) foram substituídos por um conjunto de registradores
atômicos de set/clear/toggle por bit, eliminando a necessidade de read-modify-write
em software.

| Offset  | Registrador     | Descrição                                          |
|---------|------------------|------------------------------------------------------|
| `0x00`  | `GPIO_READ`      | Leitura do estado real do pino (via barramento tri-state `gpio`) |
| `0x04`  | `GPIO_SET`       | Seta bits de `gpio_out` (OR atômico com `data_in`)  |
| `0x08`  | `GPIO_CLR`       | Limpa bits de `gpio_out` (AND atômico com `~data_in`) |
| `0x0C`  | `GPIO_DIR_READ`  | Leitura do registrador de direção (`gpio_dir`)      |
| `0x10`  | `GPIO_DIR_SET`   | Seta bits de `gpio_dir` (OR atômico), 0=input, 1=output |
| `0x14`  | `GPIO_DIR_CLR`   | Limpa bits de `gpio_dir` (AND atômico)              |
| `0x18`  | `GPIO_TOG`       | Inverte bits de `gpio_out` (XOR atômico com `data_in`) |

**Why (GPIO_SET/CLR/TOG em vez de escrita direta):** o design antigo exigia que o
firmware fizesse leitura + modificação + escrita em software para mexer em um único
pino sem afetar os vizinhos do mesmo byte — não atômico, com risco de lost update
se uma interrupção mexesse no mesmo registrador no meio do caminho. Os novos
registradores fazem a operação bit a bit diretamente em hardware (`gpio_out |=
data_in`, `gpio_out &= ~data_in`, `gpio_out ^= data_in`), em uma única transação de
barramento. Precedente real: Microchip/Atmel SAM D21 (`PORT`: `OUTSET`/`OUTCLR`/
`OUTTGL`) e Renesas RX/RA (`PTOG`) usam exatamente esse padrão; STM32 (`BSRR`) tem
set/clear atômico mas não tem toggle em hardware — o SAM D21 é a referência mais
próxima do que foi implementado aqui.
**How to apply:** ao adicionar novos periféricos com registradores bit-a-bit,
preferir esse padrão (READ + SET + CLR [+ TOG]) em vez de um único registrador de
leitura/escrita direta, quando o uso esperado for controle individual de bits.

Todos os registradores acima leem/escrevem em 1 ciclo de latência (`data_out`
registrado, ver nota sobre `<=` não-bloqueante em [[CLAUDE]] se existir, ou lembrar
que leitura e escrita no mesmo ciclo sempre retornam o valor anterior à escrita).

Reset do módulo é síncrono (`always @(posedge clk)`, sem `negedge nrst` na
sensibilidade), igual ao resto do SoC (`marvin_mem.v`, `marvin_cpu.v`) — uma versão
anterior desse módulo usava reset assíncrono por engano, corrigido em 2026-07-05.

Barramento `gpio`: `[31:0]` dentro do módulo, mas o topo do SoC (`rtl/marvin.v`)
hoje **não** expõe um `inout` direto — ver seção "Workaround do `inout` no Digital"
abaixo para o porquê e como isso é estruturado atualmente.

### Workaround do `inout` no Digital (2026-07-05)

`rtl/marvin.v` hoje expõe, em vez de um único `inout [31:0] gpio`, três sinais
separados usados no exemplo `04_gpio_in`:

```verilog
// inout [31:0] gpio,           // Real FPGA interface (comentado, ver abaixo)
output [1:0] gpio_out,          // pinos 0,1: saída
input        gpio_in,           // pino 2: entrada dedicada (workaround)
```

com fiação interna:
```verilog
wire [2:0] gpio;                // barramento interno de 3 bits, alimenta o periférico
assign gpio_out = gpio[1:0];    // periférico -> pino físico (unidirecional)
assign gpio[2]  = gpio_in;      // pino externo -> periférico (unidirecional)
```

**Why:** o bloco `ExternalFile`/`IVERILOG` do simulador **Digital** (usado em
`sim/*.dig`) declara `gpio` só em `externalOutputs` na cosimulação — não suporta um
pino verdadeiramente bidirecional (`inout`) sendo dirigido de fora do bloco. Um
switch ligado a um `inout` real causa "conflito de dois drivers" no Digital, porque
o bridge sempre se considera dono do sinal. A solução foi expor um `input` dedicado
(`gpio_in`) só pra esse propósito de simulação/teste.

**Bug relacionado, já corrigido, que motivou a investigação:** antes dessa correção,
com o pino de entrada (pino 2) sem nenhum driver externo (nem switch, nem
`inout` real), o valor lido era `z`/indefinido. Isso se propagou por uma condição de
branch (`if (gpio_read(2) == 1)`) até `predicate` na FSM da CPU
(`rtl/marvin_cpu.v`), corrompendo o próprio `PC` pra `X` de forma permanente — a CPU
trava pra sempre, sem nenhum reset de verdade envolvido (`nrst` continua em `1` o
tempo todo). Reproduzido e confirmado via Icarus Verilog: `dbg_x1=0x110` e
`address` viravam `X` (o hex display do Digital provavelmente renderiza isso como
`0000`). Ver [[CHANGELOG]] (2026-07-05) para o histórico completo da investigação.

**How to apply:**
- Esse workaround (`gpio_out`/`gpio_in` separados) é **só para simular no Digital**.
  Pra síntese em FPGA de verdade, a interface correta é o `inout [31:0] gpio`
  comentado no topo do arquivo — o padrão `assign gpio[i] = dir[i] ? out[i] :
  1'bz;` já usado em `marvin_gpio.v` sintetiza normalmente como IOBUF bidirecional
  em qualquer toolchain (Xilinx/Intel).
- **Isso não elimina o problema de pino flutuante em hardware real** — só muda a
  natureza dele. Em FPGA, um pino de entrada sem conexão física (sem pull-up/down)
  não vira "X" deterministicamente como em simulação; ele se estabiliza numa tensão
  imprevisível por ruído/capacitância parasita, o que pode gerar leitura
  instável/ruidosa (e consumo extra de corrente) se usada numa decisão de programa.
  Antes de portar pra FPGA de verdade: qualquer pino de entrada lido pelo firmware
  precisa estar fisicamente conectado (botão/sensor) ou ter pull-up/down habilitado
  (interno da FPGA via constraint, ou resistor externo).
- Ao adicionar novos exemplos/periféricos com pinos de entrada testados no Digital,
  repetir esse padrão (sinal `input` dedicado) em vez de tentar usar `inout` direto
  no `ExternalFile`.

Endereço físico dentro do array de memória (`marvin_mem.v`):
- ROM: usa o endereço diretamente (`phy_address = address` quando `!ram_selected`).
- RAM: `phy_address = (address & 0x0FFF) | 0x1000` — ou seja, RAM ocupa uma janela
  fixa de 4K bytes (1K words) a partir do offset 0x1000 dentro do array `memory`.

Isso implica que, com `WORDS=2048` (8KB total), a ROM efetivamente tem até 0x1000
(4KB / 1024 words) de espaço utilizável antes de colidir com a janela da RAM.

**Mirroring da RAM**: o decodificador só checa os 2 bits mais altos do endereço
(`RAM_ADDR_MASK`) pra selecionar a região, e dentro da janela de RAM só usa os 12
bits baixos do endereço pra indexar a memória física. Ou seja, os 4KB físicos reais
de RAM aparecem repetidos (espelhados) em toda a janela lógica de 1GB
(`0x8000_0000`-`0xBFFF_FFFF`): `0x8000_0000`, `0x8000_1000`, `0x8000_2000`, ...
`0xBFFF_F000` endereçam todos a mesma word física. Não existe 1GB de RAM real —
é decodificação parcial de endereço. Comentado diretamente no código
(`marvin_mem.v`, acima da linha do `phy_address`).

## Interface de barramento (estilo picoRV32)

Sinais entre CPU e memória (ver `rtl/marvin.v` e `rtl/marvin_cpu.v`):

| Sinal        | Direção (CPU→MEM) | Descrição                                  |
|--------------|--------------------|----------------------------------------------|
| `mem_addr`   | CPU → MEM          | Endereço (byte address, 32 bits)              |
| `mem_wdata`  | CPU → MEM          | Dado a escrever                               |
| `mem_wmask`  | CPU → MEM          | Máscara de escrita por byte (4 bits)          |
| `mem_rdata`  | MEM → CPU          | Dado lido                                     |
| `mem_valid`  | CPU → MEM          | Endereço válido (leitura ou escrita)          |
| `mem_ready`  | MEM → CPU          | Operação concluída (1 ciclo de latência)      |

Reset do sistema: `nrst` (ativo baixo), propagado para CPU e memória.

## Sinais de debug (topo do SoC)

- `dbg_x1`, `dbg_x2`, `dbg_x15`: conteúdo dos registradores x1/x2/x15 do register file.
- `dbg_state` existe como porta de saída em `marvin_cpu.v` mas **não está conectado**
  no topo (`marvin.v`) atualmente — removido da lista de portas do topo em algum
  momento, sem substituto. Reconectar se precisar observar o estado da FSM de fora.
- `address`: eco do `cpu_addr` exposto no topo para observação em simulação.

## Módulos e parâmetros

- `maRVin_cpu #(RESET_ADDR=32'h0000_0000, ADDR_WIDTH=32)` — instanciado no top-level
  com esses valores. Reset síncrono, estado inicial `FETCH_INSTR` (ver [[CLAUDE]]
  para a pegadinha de FSM que exigiu isso).
- `maRVin_mem #(WORDS=2048)` — 2048 words de 32 bits = 8KB, compartilhados entre
  ROM e RAM (ver mapa acima).
- `maRVin_gpio #()` — sem parâmetros hoje; registradores atômicos set/clear/toggle
  (ver seção de registradores do GPIO acima).

## Simulação

- `sim/*.dig` — arquivos do simulador **Digital** (hneemann/Digital), via bloco
  `ExternalFile`/`IVERILOG` que roda o RTL de verdade (`rtl/*.v`) por baixo — não é
  um schematic gate-level nem testbench Verilog tradicional. Ver seção "Workaround
  do `inout` no Digital" acima para uma limitação importante desse bridge.
- `sim/04_gpio_in.dig` — validado funcionando em 2026-07-05, com o workaround de
  pino de entrada dedicado.
- Qualquer fluxo de simulação alternativo (iverilog/Verilator standalone, fora do
  Digital) ainda precisa ser formalizado como testbench versionado — ver [[TODO]].
