/************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          *
 * gpio_in                                                                                     *
 * Teste do GPIO (Input)                                                                        *
 *                                                                                              *
 *                                                                                              *
 ************************************************************************************************/
#include "marvin_gpio.h"

int main() {
   // GPIO_DIR_SET = 0xFFFFFFFF;
    gpio_dir(0, OUTPUT);
    gpio_dir(1, OUTPUT);
    gpio_dir(2, INPUT);

    while(1) {
        if (gpio_read(2) == 1) {
            gpio_write(0, LOW);
            gpio_write(1, HIGH);
        } else {
            gpio_write(1, LOW);
            gpio_write(0, HIGH);
        }
    }
}	
