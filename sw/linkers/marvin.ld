/*************************************************************************************************
 * MaRVin - RISC-V SoC
 * Linker script
 *
 * Memory map (rtl/marvin_mem.v): single 8KB physical array, address-decoded into two regions.
 * ROM starts at 0x00000000 (matches CPU RESET_ADDR), RAM starts at 0x80000000.
 * Each region is 4K, the full physical capacity per side of the array.

 * Memory segments:
 * ├─────────────────────────┼──────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
 * │ .text                   │ código (instruções)                                      │ nada — já fica pronto na ROM                                                     │
 * ├─────────────────────────┼──────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
 * │ .rodata                 │ constantes de leitura (const, literais de string)        │ nada — fica na ROM, nunca muda, nunca precisa ir pra RAM                         │
 * ├─────────────────────────┼──────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
 * │ .data                   │ globais/estáticas inicializadas com valor ≠ 0 (ex:       │ copiar ROM→RAM (precisa existir na RAM porque é mutável, mas o valor inicial só  │
 * │                         │ counter = 1)                                             │ existe gravado na ROM)                                                           │
 * ├─────────────────────────┼──────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
 * │ .bss                    │ globais/estáticas com valor 0 ou sem inicializador       │ zerar na RAM (não guarda nada na ROM, seria desperdício gravar um monte de zeros)│
 * ├─────────────────────────┼──────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
 * │ pilha (stack)           │ variáveis locais, frames de função                       │ nada — só reserva o espaço (__stack_top), conteúdo é lixo até ser usado          │
 * ├─────────────────────────┼──────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
 * │ heap (se existisse      │ alocação dinâmica                                        │ nada — só reserva espaço, sem inicialização                                      │
 * │ malloc)                 │                                                          │                                                                                  │

 *************************************************************************************************/
ENTRY(_start)

MEMORY
{
    rom (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    ram (rwx) : ORIGIN = 0x80000000, LENGTH = 4K
}

SECTIONS
{
    /* .text.init (crt0's _start) is forced first: the CPU always fetches from
       RESET_ADDR on reset, regardless of the link order of the other objects. */
    .text : ALIGN(4)
    {
        KEEP(*(.text.init))
        *(.text .text.* .gnu.linkonce.t.*)
    } > rom

    .rodata : ALIGN(4)
    {
        *(.rodata .rodata.* .gnu.linkonce.r.*)
    } > rom

    /* Initial values are stored in rom (LMA) but the section is accessed at its ram address (VMA).
       No crt0 exists yet to copy these bytes from rom to ram at boot, so initialized globals
       will NOT have their initial value in ram until a startup routine does that copy. */
    .data : ALIGN(4)
    {
        _data_lma = LOADADDR(.data);
        _data_start = .;
        __global_pointer$ = .;
        *(.data .data.* .sdata .sdata.*)
        . = ALIGN(4);
        _data_end = .;
    } > ram AT > rom

    /* Zero-initialized data, not present in the rom image; a startup routine must zero it. */
    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start__ = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
    } > ram

    /* Stack grows down from the top of ram; nothing is placed above it. */
    PROVIDE(__stack_top = ORIGIN(ram) + LENGTH(ram));
}
