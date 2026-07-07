/************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          *
 * serial                                                                                       *
 * Teste da Interface Serial (UART RX)                                                             *
 *                                                                                              *
 *                                                                                              *
 ************************************************************************************************/
#include "marvin_uart.h"
#include "marvin_gpio.h"

#define DELAY_COUNT 100

int main() {
    char str[20];

    while(1) {
        uart1_writeline("Qual o seu nome?");
        uart1_readline_blocking(str, 100);
        uart1_write((const unsigned char *)"Bom dia: ", 9);
        uart1_writeline(str);
    }
}	