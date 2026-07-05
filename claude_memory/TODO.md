# TODO — MaRVin SoC

Lista viva de tarefas. Marcar com `[x]` quando concluído e mover o item relevante
para o [[CHANGELOG]].

## Curto prazo

Itens abaixo também aparecem (em forma resumida) no TODO do `README.md` — o
usuário mantém uma lista curta lá; esta aqui é a versão detalhada.

- [ ] Revisar dimensionamento do mapeamento de endereço da RAM em `marvin_mem.v`
      (índice fixo de 12 bits vs. `WORDS` parametrizável) — ver mirroring de 4KB
      documentado em [[ARCHITECTURE]].
- [ ] Criar algum mecanismo para trocar qual `.hex` é carregado sem editar o RTL
      (hoje o nome do arquivo está hardcoded no `initial $readmemh` de
      `marvin_mem.v`, atualmente `sw/examples/04_gpio_in/gpio_in.hex`).
- [ ] Antes de sintetizar pra FPGA de verdade: reverter o workaround de
      `gpio_out`/`gpio_in` em `rtl/marvin.v` pra `inout [31:0] gpio` (interface já
      deixada comentada no topo do arquivo) e garantir pull-up/down (interno da
      FPGA ou resistor externo) em qualquer pino de entrada lido pelo firmware —
      ver [[ARCHITECTURE]] (seção "Workaround do inout no Digital") e
      [[CHANGELOG]] (2026-07-05) para o porquê.

## Médio prazo

- [x] **GPIO (saída)** — periférico `rtl/marvin_gpio.v` + driver
      `sw/marvin_lib/` + exemplo `sw/examples/03_gpio_out/`. Ver [[CHANGELOG]]
      (2026-07-05) para os bugs de CPU descobertos e corrigidos no processo.
- [x] GPIO de entrada — registradores `GPIO_READ`/`GPIO_DIR_*`/`GPIO_SET`/`GPIO_CLR`/
      `GPIO_TOG` implementados e testados com pino externo real (`04_gpio_in`,
      Digital + Icarus). Ver [[CHANGELOG]] (2026-07-05).
- [ ] UART para debug/output — próximo periférico, mesma estrutura do GPIO
      (driver em `marvin_lib`, módulo RTL, decodificador em `marvin.v`).
- [ ] Separar ROM e RAM em módulos distintos (hoje é uma memória única com mapeamento
      de endereço) — avaliar se vale a pena ou se o modelo atual é suficiente.
- [ ] Planejar substituição do `marvin_cpu.v` (placeholder FemtoRV32) pela CPU
      didática própria quando ela atingir RV32I completo no outro repositório.

## Backlog / ideias

- [ ] Testbench automatizado versionado no repo (hoje as verificações com iverilog
      são feitas em testbenches descartáveis fora do repositório) para regressão
      contínua — ficaria mais fácil pegar regressões como as duas encontradas em
      2026-07-05 (FSM da CPU) mais cedo.
- [ ] Documentar toolchain e passo a passo de simulação no README.

## Concluído recentemente (ver [[CHANGELOG]] para detalhes)

- [x] GPIO de entrada: registradores atômicos (`GPIO_READ`/`SET`/`CLR`/`TOG`/
      `DIR_*`), exemplo `04_gpio_in`, bug de travamento por pino flutuante
      diagnosticado e corrigido (workaround `gpio_out`/`gpio_in` no Digital,
      validado no simulador). (2026-07-05)
- [x] GPIO de saída completo: RTL, driver C, exemplo, decodificador de endereço
      no topo, e dois bugs de CPU corrigidos (reset e FSM de shift). (2026-07-05)
- [x] Toolchain RISC-V instalado e validado (`riscv-none-elf-gcc`,
      `sw/toolchain/`) — usado com sucesso pra compilar `02_loop_c` e
      `03_gpio_out` ponta a ponta.
- [x] Loop em assembly montado via toolchain (`sw/examples/01_loop_asm/loop_asm.s`).
- [x] Programa pra converter binário em `.hex` (`sw/tools/bin2hex.py` e/ou
      `sw/toolchain/bin/image_gen.exe`).
- [x] Loop em C compilado e rodando no SoC (`sw/examples/02_loop_c/loop_c.c`).
- [x] Corrigir `rtl/marvin_mem.v`: `$readmemh` referenciava `rom` em vez de `memory`.
- [x] Criar programas de teste `.hex` (ALU, loop, memória) e validar via simulação.
