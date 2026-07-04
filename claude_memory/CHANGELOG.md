# CHANGELOG — MaRVin SoC

Formato: data (AAAA-MM-DD) + o que mudou e por quê. Entradas mais recentes no topo.

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
