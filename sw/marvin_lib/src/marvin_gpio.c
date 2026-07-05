/************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          *
 *                                                                                              *
 * marvin_gpio.c                                                                                *
 * GPIO driver                                                                                  *
 ************************************************************************************************/
#include "marvin_gpio.h" 

void gpio_write(int pin, int value) {
  if (pin < 0 || pin > 31) return;
  if (value) 
    GPIO_SET = (0x0001 << pin);
  else
    GPIO_CLR = (0x0001 << pin);
}

int gpio_read(int pin) {
  return (GPIO_READ >> pin) & 0x1;
}

void gpio_dir(int pin, int value) {
  if (pin < 0 || pin > 31) return;
  if (value)
    GPIO_DIR_SET = (0x0001 << pin);
  else
    GPIO_DIR_CLR = (0x0001 << pin);
}

void gpio_toggle(int pin) {
  if (pin < 0 || pin > 31) return;
  GPIO_TOG = (0x0001 << pin);
}