# TODO — MaRVin SoC

Lista viva de tarefas. Marcar com `[x]` quando concluído e mover o item relevante
para o [[CHANGELOG]].

## Curto prazo

- [ ] Rodar a simulação no **Digital** (`sim/00_soc.dig`) — até agora só foi validado
      via Icarus Verilog (testbenches descartáveis, fora do repo); confirmar que o
      `.dig` também roda os `.hex` de teste corretamente.
- [ ] Revisar dimensionamento do mapeamento de endereço da RAM em `marvin_mem.v`
      (índice fixo de 12 bits vs. `WORDS` parametrizável) — ver mirroring de 4KB
      documentado em [[ARCHITECTURE]].
- [ ] Definir fluxo de build/assemble do software de teste (toolchain RISC-V usada
      para gerar `.hex` de programas maiores — os 3 atuais foram montados à mão).
- [ ] Criar algum mecanismo para trocar qual `.hex` é carregado sem editar o RTL
      (hoje o nome do arquivo está hardcoded no `initial $readmemh` de
      `marvin_mem.v`).

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
