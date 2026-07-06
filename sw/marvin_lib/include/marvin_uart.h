/************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          *
 *                                                                                              *
 * marvin_uart.h                                                                                *
 * UART Driver definitions                                                                      *
 ************************************************************************************************/
#ifndef MARVIN_UART_H
#define MARVIN_UART_H

#include "marvin.h"

#define UART1_BASE 0xC0001000
#define UART1_TX  (REG32(UART1_BASE + 0x0))
#define UART1_RX  (REG32(UART1_BASE + 0x4))
#define UART1_STAT  (REG32(UART1_BASE + 0x8))

int uart1_ready_tx(void);
int uart1_available(void);

// Reads (getc/read/readline) do not block on uart1_available(); caller must
// check it first if new data isn't guaranteed to be there yet.
unsigned char uart1_getc(void);
void uart1_read(unsigned char *buf, int size);
int uart1_readline(char *str, int max_size);

// Blocking counterparts: wait on uart1_available() before reading.
unsigned char uart1_getc_blocking(void);
int uart1_readline_blocking(char *str, int max_size);

void uart1_putc(unsigned char byte);
void uart1_write(const unsigned char *str, int size);
void uart1_writeline(const char *str);

#endif // MARVIN_UART_H