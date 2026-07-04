# ARCHITECTURE — MaRVin SoC

Detalhes de mapa de memória e interfaces. Mantido separado do [[CLAUDE]] para não
inchar a memória principal conforme o SoC ganhar mais periféricos.

## Mapa de endereços (atual)

| Faixa                         | Região | Observação                              |
|--------------------------------|--------|------------------------------------------|
| `0x0000_0000` – `0x7FFF_FFFF`  | ROM    | Programa, carregado via `$readmemh`       |
| `0x8000_0000` – `0xBFFF_FFFF`  | RAM    | Selecionada por `RAM_ADDR_MASK=0xC000_0000` |

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

- `dbg_x1`, `dbg_x2`, `dbg_x3`: conteúdo dos registradores x1-x3 do register file.
- `dbg_state`: estado atual da FSM da CPU (4 bits).
- `address`: eco do `cpu_addr` exposto no topo para observação em simulação.

## Módulos e parâmetros

- `maRVin_cpu #(RESET_ADDR=32'h0000_0000, ADDR_WIDTH=32)` — instanciado no top-level
  com esses valores.
- `maRVin_mem #(WORDS=2048)` — 2048 words de 32 bits = 8KB, compartilhados entre
  ROM e RAM (ver mapa acima).

## Simulação

- `sim/00_soc.dig` — arquivo do simulador **Digital** (hneemann/Digital), não é
  testbench Verilog tradicional. Qualquer fluxo de simulação alternativo
  (iverilog/Verilator) ainda precisa ser definido — ver [[TODO]].
