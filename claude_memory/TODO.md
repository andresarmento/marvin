# TODO — MaRVin SoC

Lista viva de tarefas. Marcar com `[x]` quando concluído e mover o item relevante
para o [[CHANGELOG]].

## Curto prazo

Itens abaixo também aparecem (em forma resumida) no TODO do `README.md` — o
usuário mantém uma lista curta lá; esta aqui é a versão detalhada.

- [ ] **Toolchain para compilar RISC-V** — definir/instalar toolchain (gcc/as
      RISC-V ou similar) em vez de calcular hex à mão como foi feito nos 3
      exemplos atuais.
- [ ] **Montar loop em Assembly** — usar a toolchain acima pra montar um `.s` real
      (hoje `00_test_loop.hex` foi codificado manualmente, sem assembler).
- [ ] **Programa para converter binário em `.hex`** — script/ferramenta pra ir de
      `.bin`/ELF gerado pela toolchain até o formato `$readmemh` usado por
      `marvin_mem.v`.
- [ ] **Compilar loop em C** — programa em C compilado e rodando no SoC.
- [ ] Rodar a simulação no **Digital** (`sim/00_soc.dig`) — até agora só foi validado
      via Icarus Verilog (testbenches descartáveis, fora do repo); confirmar que o
      `.dig` também roda os `.hex` de teste corretamente.
- [ ] Revisar dimensionamento do mapeamento de endereço da RAM em `marvin_mem.v`
      (índice fixo de 12 bits vs. `WORDS` parametrizável) — ver mirroring de 4KB
      documentado em [[ARCHITECTURE]].
- [ ] Criar algum mecanismo para trocar qual `.hex` é carregado sem editar o RTL
      (hoje o nome do arquivo está hardcoded no `initial $readmemh` de
      `marvin_mem.v`, atualmente `sw/examples/00_test_mem.hex`).

## Médio prazo

- [ ] Adicionar periféricos ao SoC (ex: UART para debug/output, GPIO).
- [ ] Separar ROM e RAM em módulos distintos (hoje é uma memória única com mapeamento
      de endereço) — avaliar se vale a pena ou se o modelo atual é suficiente.
- [ ] Planejar substituição do `marvin_cpu.v` (placeholder FemtoRV32) pela CPU
      didática própria quando ela atingir RV32I completo no outro repositório.

## Backlog / ideias

- [ ] Testbench automatizado versionado no repo (hoje as verificações com iverilog
      são feitas em testbenches descartáveis fora do repositório) para regressão
      contínua.
- [ ] Documentar toolchain e passo a passo de simulação no README.

## Concluído recentemente (ver [[CHANGELOG]] para detalhes)

- [x] Corrigir `rtl/marvin_mem.v`: `$readmemh` referenciava `rom` em vez de `memory`.
- [x] Criar programas de teste `.hex` (ALU, loop, memória) e validar via simulação.
