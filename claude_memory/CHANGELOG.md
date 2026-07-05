# CHANGELOG — MaRVin SoC

Formato: data (AAAA-MM-DD) + o que mudou e por quê. Entradas mais recentes no topo.

## 2026-07-05 — Primeiro periférico (GPIO) e dois bugs sérios na CPU

- Criada a biblioteca de drivers `sw/marvin_lib/` (`include/`, `src/`), começando
  pelo driver de GPIO (`marvin_gpio.h/.c`): `gpio_write`, `gpio_read`, `gpio_dir`,
  `gpio_toggle`. Convenção definida: `marvin_lib` é só pra APIs de periféricos —
  `crt0.S` continua em `sw/startup/`, o linker script em `sw/linkers/`, fora da lib.
- Revisão da lib encontrou e corrigiu: `gpio_read` sem bounds-check de `pin` (só
  `gpio_write`/`gpio_dir` validavam antes); shifts usando literal `int` assinado
  (`0x0001 << pin`) trocados para `0x0001u` (UB no bit 31 com tipo assinado);
  `gpio_toggle` (que estava comentado, "Problemas aqui", referenciando um
  `GPIO_IO` que nunca existiu) implementado via `gpio_write(pin, !gpio_read(pin))`
  e validado por simulação (pino alternando 0→1→0 corretamente em dois ciclos
  completos).
- Criado o periférico `rtl/marvin_gpio.v`: registradores `GPIO_DIR` (0x00) e
  `GPIO_OUT` (0x04) — leitura de `GPIO_OUT` reflete o pino físico via barramento
  tri-state, sem registrador `GPIO_IN` separado por enquanto (decisão do usuário;
  `GPIO_IN` já reservado em `marvin_gpio.h` pra uso futuro). Barramento externo
  `gpio` exposto como 4 bits no topo (`rtl/marvin.v`) contra 32 bits internos ao
  periférico — confirmado intencional (só 4 pinos físicos por enquanto; os 28
  bits não conectados leem como `X` num read-modify-write de 32 bits, harmless
  hoje mas revisar se um dia usarem mais bits/`GPIO_IN`). Corrigidos durante
  revisão: reset era assíncrono (`posedge clk or negedge nrst`), padronizado pra
  síncrono como o resto do SoC; `case` sem `default` deixava `data_out` com lixo
  em endereço não mapeado dentro do periférico.
- Adicionado decodificador de endereço em `rtl/marvin.v` (antes inexistente: CPU
  só enxergava a memória, ligação direta sem decisão de endereço nenhuma):
  `rom_selected`, `ram_selected`, `gpio_selected`, roteando `mem_valid`/
  `gpio_valid` e o mux de volta (`cpu_ready`/`cpu_rdata`). Mapa: ROM
  `0x0000_0000`-`0x7FFF_FFFF`, RAM `0x8000_0000`-`0xBFFF_FFFF`, GPIO
  `0xC000_0000`-`0xC000_00FF`. Cabeçalho do arquivo atualizado com o endereço do
  GPIO.
- **Dois bugs sérios encontrados e corrigidos em `rtl/marvin_cpu.v`, ambos
  expostos justamente pela adição do decodificador** (o SoC só funcionava antes
  porque não havia decodificação de endereço nenhuma — ver [[CLAUDE]] para os
  detalhes completos, ficaram documentados lá como convenção importante):
  1. Reset da CPU inicializava `state <= WAIT_ALU_OR_MEM` (com `FETCH_INSTR`
     comentado ao lado) — um truque de bootstrap herdado do FemtoRV32 original
     que dependia de `cpu_ready` ligado direto em `mem_ready`, sem decodificação.
     Nesse estado, `mem_addr` é `loadstore_addr` (não `PC`), calculado a partir
     de `rs1`/`instr` — registradores nunca resetados, logo lixo/`X` no boot. Com
     o decodificador, esse endereço de lixo nunca batia com nenhuma faixa válida,
     travando `cpu_ready` e a CPU inteira em `PC=0` pra sempre. Corrigido
     trocando o estado inicial pra `FETCH_INSTR` (usa `PC` real como endereço
     desde o primeiro ciclo).
  2. Mesmo depois da correção acima, qualquer instrução de shift (SLL/SRL/SRA —
     usada pela primeira vez por um programa real, via `gpio_write`/`gpio_dir`'s
     `<<`) travava a CPU pra sempre em `WAIT_ALU_OR_MEM`: a condição de saída
     (`!aluBusy & mem_ready`) assumia, como no FemtoRV32 original, que
     `mem_ready` fica ocioso em **alto** quando não há transação pendente; mas a
     interface foi adaptada pro estilo picoRV32 (`ready <= valid`), que fica
     ocioso em **baixo**. Num shift puro (sem load/store), `mem_valid` nunca é
     ativado, então `mem_ready` nunca sobe. Corrigido pra
     `!aluBusy & (mem_ready | !(isLoad|isStore))` — só exige `mem_ready` quando
     realmente é load/store.
  3. Ambos os bugs foram diagnosticados e confirmados por simulação com Icarus
     Verilog (testbenches descartáveis, fora do repo), inspecionando
     `state`/`aluBusy`/`aluShamt`/`mem_ready` ciclo a ciclo.
- Criado o exemplo `sw/examples/03_gpio_out/` (`gpio_out.c` — pisca os pinos 0/1
  em loop com delay via `asm("nop")`). Makefile recriado do zero seguindo o
  padrão do `02_loop_c` (o makefile antigo era herança de uma tentativa anterior,
  com caminhos que não existiam: `sw/crt0/crt0_noISR.s` e `image_gen.exe` sem
  caminho). A pedido do usuário, o `OBJS` final usa auto-discovery via
  `wildcard` (`CRT0_SRC`/`MARVIN_LIB_SRC`) em vez de regras explícitas por
  arquivo, igual ao padrão que o `02_loop_c` já usava — os `.o` de `crt0`/lib
  compartilhados ficam nas pastas de origem (`sw/startup/`, `sw/marvin_lib/src/`),
  não na pasta do exemplo.
- Build completo validado ponta a ponta com o toolchain `riscv-none-elf-gcc` (o
  usuário resolveu, por conta própria, um problema de instalação do toolchain:
  faltava `sw/toolchain/lib/gcc/riscv-none-elf/14.2.0/include/`, os headers
  freestanding do próprio GCC como `stddef.h`; nunca detectado antes porque
  nenhum exemplo anterior incluía `marvin.h`/`stdlib.h`).
- **Redesenho do registrador do GPIO** (`rtl/marvin_gpio.v`): `GPIO_DIR`/`GPIO_OUT`
  (escrita de byte inteiro) substituídos por um conjunto de registradores
  atômicos — `GPIO_READ` (0x00), `GPIO_SET` (0x04), `GPIO_CLR` (0x08),
  `GPIO_DIR_READ` (0x0C), `GPIO_DIR_SET` (0x10), `GPIO_DIR_CLR` (0x14) — todos via
  OR/AND-com-complemento sobre os registradores internos, eliminando a
  necessidade de read-modify-write em software para mexer em um pino sem afetar
  os vizinhos do mesmo byte. Detalhes e motivação completos em [[ARCHITECTURE]].
- Adicionado `GPIO_TOG` (0x18): inverte bits de `gpio_out` via XOR atômico,
  simétrico a `SET`/`CLR`. Motivação: implementar toggle em software
  (`gpio_read` + `gpio_write` condicional) reintroduziria o mesmo risco de
  read-modify-write não atômico que `SET`/`CLR` foram criados pra eliminar.
  Precedente real: Microchip SAM D21 (`PORT.OUTTGL`) e Renesas RX/RA (`PTOG`)
  implementam esse mesmo padrão em hardware; STM32 (`BSRR`) não tem toggle
  atômico nativo.
- `marvin_gpio.v` também corrigido nesta revisão: reset estava assíncrono
  (`posedge clk or negedge nrst`) numa versão intermediária, revertido para
  síncrono (padrão do resto do SoC); comentários todos em inglês.
- Criado o exemplo `sw/examples/04_gpio_in/` (`gpio_in.c` — configura pino 2 como
  entrada, 0/1 como saída, e espelha o valor lido no par de saídas) + `makefile`
  nos moldes do `03_gpio_out`. `gpio_toggle` do driver C também migrado para usar
  `GPIO_TOG` diretamente (era `gpio_write(pin, !gpio_read(pin))`).
- **Bug sério encontrado e corrigido: CPU travava permanentemente ao ler um pino
  de GPIO configurado como entrada sem nenhum driver externo conectado.** Não era
  reset (confirmado via Icarus: `nrst` continuava em `1` o tempo todo) — era
  corrupção do próprio `PC` para `X`. Mecanismo: pino flutuante (`z`) lido por
  `gpio_read(2)` → usado num `if (... == 1)` → `predicate` da FSM
  (`rtl/marvin_cpu.v`) fica `X` → `PC <= jumpToPCplusImm ? PCplusImm : PCplus4`
  também vira `X` → busca da próxima instrução em `memory[X]` retorna `X` →
  travamento auto-sustentado, sem reset envolvido. Reproduzido de forma
  determinística no Icarus (`dbg_x1=0x00000110` idêntico ao valor visto pelo
  usuário no Digital, `address` virando `X`, exibido lá provavelmente como
  `0000`). Ver [[ARCHITECTURE]] para o mecanismo completo.
- **Causa raiz de por que o pino ficava sem driver: o bloco `ExternalFile`/
  `IVERILOG` do simulador Digital não suporta um pino `inout` de verdade em
  cosimulação** — `gpio` estava listado só em `externalOutputs` no `.dig`, então
  nenhum switch conectado a ele conseguia realmente injetar um valor na simulação
  (só gerava erro de "conflito de drivers"). Corrigido expondo, em
  `rtl/marvin.v`, um `input` dedicado (`gpio_in`, pino 2) e um `output` puro
  (`gpio_out[1:0]`, pinos 0/1) em vez do `inout [31:0] gpio` original — a
  interface `inout` correta pra FPGA ficou comentada no topo do arquivo como
  referência. Validado funcionando no Digital pelo usuário
  (`sim/04_gpio_in.dig`) após reconectar o switch no novo pino dedicado.
- Confirmado com o usuário: **esse workaround é só para o Digital.** Pra FPGA de
  verdade, `inout [31:0] gpio` sintetiza normalmente (padrão IOBUF via
  `assign gpio[i] = dir[i] ? out[i] : 1'bz;`), mas o problema de pino flutuante
  não desaparece — só muda de "trava determinístico" (simulação) pra "leitura
  instável/ruidosa" (hardware real, sem pull-up/down). Qualquer pino de entrada
  lido pelo firmware precisa de conexão física ou pull-up/down antes de ir pra
  FPGA de verdade.

## 2026-07-04 (continuação)

- Usuário deu os dois primeiros commits do repositório:
  - `b7ae532` "first commit! CPU and Memory" — todo o estado inicial (rtl/, sw/,
    sim/, docs/, claude_memory/, README.md).
  - `012964a` "organizing examples in folder" — moveu os 3 `.hex` de
    `sw/*.hex` para `sw/examples/*.hex`, e atualizou `HEX_FILES_PATH` em
    `rtl/marvin_mem.v` para apontar pra `sw/examples/`.
- Usuário atualizou `README.md` com uma lista de TODO própria: toolchain RISC-V,
  montar loop em assembly (via toolchain, não à mão), programa pra converter
  binário em `.hex`, compilar loop em C. Refletido em [[TODO]].

## 2026-07-04

- Corrigido bug em `rtl/marvin_mem.v`: `$readmemh({...}, rom)` apontava para um
  sinal `rom` inexistente; corrigido para `memory` (nome real do array).
- Criados 3 programas de teste em `sw/`, escritos/codificados manualmente (sem
  toolchain, hex calculado à mão) e validados rodando o SoC completo com Icarus
  Verilog (testbenches descartáveis, não versionados):
  - `00_test_alu.hex` — ALU básica com x1/x2 (ADDI/ADD/SUB). Resultado esperado
    e confirmado: x1=2, x2=13.
  - `00_test_loop.hex` — 4 NOPs + `jal` de volta ao início (loop infinito).
    Confirmado PC ciclando 0x00→0x04→0x08→0x0c→0x10→0x00...
  - `00_test_mem.hex` — grava x2=5 na RAM (via x1 como ponteiro pra
    `0x8000_0000`), sobrescreve x2 com sentinela -1, recarrega da RAM (provando
    que o load funciona de verdade), decrementa em loop até 0, repete. Todas as
    versões originais usaram x10/x11; depois recodificadas para usar x1/x2 a
    pedido do usuário.
- Adicionado comentário no código (`marvin_mem.v`, acima da linha do
  `phy_address`) explicando o mirroring de 4KB de RAM física pela janela lógica
  de 1GB (`0x8000_0000`-`0xBFFF_FFFF`) — só os 12 bits baixos do endereço são
  decodificados.
- Confirmado com o usuário: reset da CPU (`marvin_cpu.v`) e da memória
  (`marvin_mem.v`) é **síncrono** (só `always @(posedge clk)`, sem
  `negedge nrst`), ao contrário da CPU didática própria do usuário (assíncrona);
  usuário decidiu migrar a CPU didática pra reset síncrono também, mas adiou
  ("depois vejo isso" — ver memória externa do Claude, `project_marvin.md`).

## 2026-07-03

- Projeto reiniciado de forma organizada: criada a pasta `claude_memory/` com
  `CLAUDE.md` (memória principal), `TODO.md` e `CHANGELOG.md` para acompanhar o
  desenvolvimento do SoC de forma estruturada.
- Estado do repositório neste momento: ainda sem nenhum commit (`git log` vazio),
  apenas arquivos untracked (`README.md`, `docs/`, `rtl/`, `sim/`).
- Código-fonte existente até aqui: `rtl/marvin.v` (top-level), `rtl/marvin_cpu.v`
  (CPU placeholder baseada em FemtoRV32 Quark), `rtl/marvin_mem.v` (memória
  ROM+RAM unificada). Ver [[CLAUDE]] para detalhes de arquitetura.

## 2026-07-01 (repositório separado, registrado por memória anterior)

- CPU didática própria (`marvin_cpu`) foi separada deste repositório e passou a
  viver em repositório independente, com seu próprio histórico (LUI, ADDI, FSM
  one-hot, caminho RISC47 → RV32I). Este repositório passou a conter apenas o SoC.
