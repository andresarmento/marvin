/*************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          
 * Example: loop_asm                                                                                     
 * Simple loop - four nops inside loop, count 5 address: 0000 to 0004               
 *************************************************************************************************/
.section .text      # Place following code in the .text section (executable code)
.balign 4           # Align next address to a 4-byte boundary (RISC-V instruction size)
.global _start      # Make _start symbol visible to the linker (entry point)

_start:
    nop         # nop is a pseudo-instruction, translate to: addi x0, x0, 0
    nop
    nop
    nop
    j _start    # j is a pseudo-instruction, translate to: jal x0, _start
