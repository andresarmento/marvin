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
  marvin.v        Top-level do SoC (integra CPU + memória)
  marvin_cpu.v    CPU placeholder (baseada em FemtoRV32 Quark)
  marvin_mem.v    Memória unificada (ROM + RAM)
sim/            Simulação (atualmente 00_soc.dig — Digital simulator)
sw/             Software / firmware (arquivos .hex carregados na memória)
docs/
  help/           Notas de ajuda (git, markdown)
  specs/          PDFs das especificações RISC-V (ISA priv/unpriv, ASM)
claude_memory/  Memória do projeto para o Claude (este diretório)
```

## Arquitetura do SoC (estado atual)

**Top-level (`maRVin` em rtl/marvin.v):**
- Instancia `maRVin_cpu` + `maRVin_mem`, ligados por um barramento simples estilo
  picoRV32: `mem_addr`, `mem_wdata`, `mem_wmask`, `mem_rdata`, `mem_valid`, `mem_ready`.
- Sinais de debug expostos no topo: `dbg_x1`, `dbg_x2`, `dbg_x3`, `dbg_state`.
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
  `sw/00_test_mem.hex` (o nome do arquivo em `initial $readmemh(...)` é trocado
  manualmente pelo usuário conforme qual teste ele quer rodar — ver `sw/` abaixo).
  Path base é absoluto hardcoded via `` `define HEX_FILES_PATH ``
  (`C:/Users/andre/Downloads/PROJECTS/marvin/sw/`).
- `ready` é registrado (1 ciclo de latência após `valid`).
- **RAM é espelhada (mirroring)**: só os 12 bits baixos do endereço são decodificados
  dentro da janela de RAM (1GB lógico), então só existem 4KB físicos reais de RAM
  (metade superior do array `memory`), repetidos por toda a faixa `0x8000_0000`-
  `0xBFFF_FFFF`. Comentário explicando isso já está no código, acima da linha do
  `phy_address` em `marvin_mem.v`.

## Programas de teste (`sw/`)

Três programas `.hex` escritos manualmente (RV32I puro, sem toolchain/assembler —
os valores hex são calculados a mão), cada um com comentário por instrução:

- `sw/00_test_alu.hex` — aritmética simples com x1/x2 (ADDI/ADD/SUB), termina em
  loop infinito (`jal x0,0`). Resultado esperado: x1=2, x2=13.
- `sw/00_test_loop.hex` — 4 NOPs + `jal` de volta pro início (loop infinito puro).
- `sw/00_test_mem.hex` — usa x1 como ponteiro pra RAM (`lui x1,0x80000`), escreve
  x2=5 na RAM, sobrescreve x2 com sentinela -1, recarrega da RAM (prova que o load
  funciona), depois faz um loop decrementando x2 de 5 até 0, e repete tudo pra
  sempre. Todos os três foram validados rodando o SoC completo com **Icarus
  Verilog** (iverilog, disponível em `C:/iverilog`), instanciando `maRVin` direto
  e observando `dbg_x1`/`dbg_x2`/`address`/`state` (e, no caso do teste de
  memória, acessando `dut._maRVin_cpu.registerFile[...]` e
  `dut._maRVin_mem.memory[...]` por referência hierárquica, já que só x1/x2/x3
  são expostos como debug no topo).

## Known Issues / Pontos de atenção

- O mapeamento de endereço físico da RAM (`(address & 16'h0FFF) | 16'h1000`) usa
  índices de 16 bits mas o array tem `WORDS` parametrizável — revisar se o
  dimensionamento faz sentido para diferentes tamanhos de `WORDS`.
- Path do `.hex` está hardcoded para a máquina do usuário (`C:/Users/andre/...`) —
  não é portável, mas é aceitável para uso pessoal/local por enquanto.
- O nome do arquivo `.hex` carregado por `$readmemh` é hardcoded direto no
  `initial` de `marvin_mem.v` (hoje: `00_test_mem.hex`) — trocar de teste exige
  editar o RTL. Nenhum mecanismo de seleção de programa foi criado ainda.

## Convenções observadas no código

- Nomes de módulos em CamelCase com prefixo `maRVin_` (ex: `maRVin_cpu`, `maRVin_mem`).
- Reset sempre ativo baixo, nomeado `nrst`.
- Comentários de cabeçalho de arquivo com autor e ano.
- Sinais de barramento de memória seguem convenção picoRV32-like
  (`mem_addr/mem_wdata/mem_wmask/mem_rdata/mem_valid/mem_ready`).

## Referências externas

- FemtoRV32 (Quark) — base original da CPU: Bruno Levy / Matthias Koch.
- Especificações RISC-V em `docs/specs/` (priv-isa, unpriv-isa, riscv-asm).

## Ver também

- [[TODO]] — lista de tarefas em aberto
- [[CHANGELOG]] — histórico de mudanças do projeto
- [[ARCHITECTURE]] — detalhes de mapa de memória e interfaces (quando crescer além do que cabe aqui)
