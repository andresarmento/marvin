/************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          *
 * Serial                                                                                       *
 * Teste da Interface Serial (UART TX por enquanto)                                             *
 *                                                                                              *
 *                                                                                              *
 ************************************************************************************************/
#include "marvin_uart.h"
#include "marvin_gpio.h"

#define DELAY_COUNT 100

void delay_for(int value);

int main() {
    gpio_dir(0, OUTPUT);
    gpio_dir(1, OUTPUT);

    while(1) {
        gpio_write(0, HIGH);
        gpio_write(1, LOW);
        uart1_writeline("Hello World!");
        
        gpio_write(0, LOW);
	    gpio_write(1, HIGH);
        delay_for(DELAY_COUNT);
    }
}	

void delay_for(int value) {
    for (int x=0; x<value; x++) {
        asm("nop");
    }
}