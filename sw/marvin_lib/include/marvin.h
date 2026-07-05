/************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          *
 *                                                                                              *
 * marvin.h                                                                                     *
 * Definitions                                                                                  *
 ************************************************************************************************/
#ifndef MARVIN_H
#define MARVIN_H

#include <stdint.h>  // for sizes, ex: uint32_t
#include <stdlib.h>
#include <stddef.h>

// Casts address x to a pointer to a volatile 32-bit register and dereferences it,
// so it can be read/written directly (e.g. REG32(GPIO_BASE) = 1;). volatile prevents
// the compiler from caching/reordering accesses to memory-mapped registers.
#define REG32(x) (*((volatile uint32_t *)(x)))

#define LOW    0
#define HIGH   1
#define INPUT  0
#define OUTPUT 1

#endif //MARVIN_H