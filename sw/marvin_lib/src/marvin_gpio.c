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
    GPIO_OUT |= (0x0001u << pin);
  else
    GPIO_OUT &= ~(0x0001u << pin);
}

int gpio_read(int pin) {
  if (pin < 0 || pin > 31) return 0;
  return (GPIO_OUT >> pin) & 0x1;
}

void gpio_dir(int pin, int value) {
  if (pin < 0 || pin > 31) return;
  if (value)
    GPIO_DIR |= (0x0001u << pin);
  else
    GPIO_DIR &= ~(0x0001u << pin);
}

void gpio_toggle(int pin) {
  if (pin < 0 || pin > 31) return;
  gpio_write(pin, !gpio_read(pin));
}
