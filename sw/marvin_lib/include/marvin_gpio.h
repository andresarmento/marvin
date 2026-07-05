/************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          *
 *                                                                                              *
 * marvin_gpio.h                                                                                *
 * GPIO Driver definitions                                                                      *
 ************************************************************************************************/
#ifndef MARVIN_GPIO_H
#define MARVIN_GPIO_H

#include "marvin.h" 

#define GPIO_BASE 0xC0000000
#define GPIO_DIR (REG32(GPIO_BASE + 0x0))
#define GPIO_OUT  (REG32(GPIO_BASE + 0x4))
#define GPIO_IN (REG32(GPIO_BASE + 0x8))

void gpio_write(int pin, int value);
int  gpio_read(int pin);
void gpio_dir(int pin, int value);
void gpio_toggle(int pin);

#endif //MARVIN_GPIO_H
