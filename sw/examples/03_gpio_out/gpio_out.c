/************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          *
 * gpio_out                                                                                     *
 * Teste do GPIO (output)                                                                       *
 *                                                                                              *
 * Não há timer ainda e portanto o delay foi implementado com loop for                          *
 * Pode ser executado com a CPU com clock máximo                                                *
 ************************************************************************************************/
#include "marvin_gpio.h"

#define DELAY_COUNT 1 //500000

void delay_for(int value);

int main() {
    gpio_dir(0, OUTPUT);
    gpio_dir(1, OUTPUT);
   
    while(1) {
        gpio_write(0, LOW);
        gpio_write(1, HIGH);
        delay_for(DELAY_COUNT);
        
	    gpio_write(1, LOW);
        gpio_write(0, HIGH);
        delay_for(DELAY_COUNT);
    }
}	

void delay_for(int value) {
    for (int x = 0; x < value; x++) {
        asm("nop");
    }
}