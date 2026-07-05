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
#define GPIO_READ (REG32(GPIO_BASE + 0x00))
#define GPIO_SET  (REG32(GPIO_BASE + 0x04))
#define GPIO_CLR  (REG32(GPIO_BASE + 0x08))
#define GPIO_DIR_READ (REG32(GPIO_BASE + 0x0C))
#define GPIO_DIR_SET  (REG32(GPIO_BASE + 0x10))
#define GPIO_DIR_CLR  (REG32(GPIO_BASE + 0x14))
#define GPIO_TOG      (REG32(GPIO_BASE + 0x18))

void gpio_write(int pin, int value);
int  gpio_read(int pin);
void gpio_dir(int pin, int value);
void gpio_toggle(int pin);

#endif //MARVIN_GPIO_H
