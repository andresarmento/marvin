/*************************************************************************************************
 * MaRVin - RISC-V SoC
 * crt0 - minimal startup code
 *
 * Runs before main(): sets up sp/gp, copies .data from its ROM load address to RAM,
 * zeroes .bss, then calls main. Placed in .text.init so the linker script can force it
 * to the very first address in ROM.
 *************************************************************************************************/
.section .text.init          # Named section so the linker script can force it first in ROM
.global _start               # Export _start so the linker's ENTRY(_start) can find it
.type _start, @function      # Mark as a function for ELF symbol metadata

_start:
    /* Safely initialize the global pointer defined in the linker script */
    .option push                  # Save current assembler options
    .option norelax               # Disable relaxation so gp is loaded with its real address, not gp-relative
    la   gp, __global_pointer$    # Set up the global pointer
    .option pop                   # Restore previous assembler options

    la   sp, __stack_top          # Set up the stack pointer to the top of ram (stack grows downward)

    /* copy .data: initial values live in rom (LMA), accessed in ram (VMA) */
    la   a0, _data_lma       # a0 = source pointer, start of initial values in rom
    la   a1, _data_start     # a1 = destination pointer, start of .data in ram
    la   a2, _data_end       # a2 = destination end, marks when the copy is done
1:
    bge  a1, a2, 2f          # if destination pointer reached the end, exit the loop
    lw   t0, 0(a0)           # load one word from rom
    sw   t0, 0(a1)           # store it into ram
    addi a0, a0, 4           # advance source pointer by one word
    addi a1, a1, 4           # advance destination pointer by one word
    j    1b                  # repeat
2:

    /* zero .bss: zero-initialized globals have no stored value in rom, so they must be cleared here */
    la   a0, __bss_start__   # a0 = pointer, start of .bss in ram
    la   a1, __bss_end__     # a1 = end of .bss, marks when the zeroing is done
3:
    bge  a0, a1, 4f          # if pointer reached the end, exit the loop
    sw   zero, 0(a0)         # store 0 (x0 is hardwired to zero)
    addi a0, a0, 4           # advance pointer by one word
    j    3b                  # repeat
4:

    call main

hang:
    j    hang

.size _start, . - _start
