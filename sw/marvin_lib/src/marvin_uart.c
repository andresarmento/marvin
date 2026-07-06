/************************************************************************************************
 * MaRVin - RISC-V SoC                                                                          *
 *                                                                                              *
 * marvin_uart.c                                                                                *
 * UART driver                                                                                  *
 ************************************************************************************************/
#include "marvin_uart.h" 

size_t uart1_strlen(const char *str) {
    const char *ptr = str;
    while (*ptr != '\0') {
        ptr++;
    }
    return ptr - str;
}

int uart1_ready_tx(void) {
    int ret = UART1_STAT & 0x1;
    return ret;
}

int uart1_available(void) {
    int ret = (UART1_STAT >> 1) & 0x1;
    return ret; 
}

unsigned char uart1_getc(void) {
    return (UART1_RX & 0xFF);
}

void uart1_putc(unsigned char byte) {
    while (!uart1_ready_tx()) { /* Busy wait... */ }
    UART1_TX = byte; 
}

void uart1_read(unsigned char *buf, int size) {
    for (int x = 0; x < size; x++) {
        buf[x] = uart1_getc();
    }
}

void uart1_write(const unsigned char *str, int size) {
    for (int x = 0; x < size; x++) {
    	while (!uart1_ready_tx()) { /* Busy wait... */ }
        UART1_TX = str[x]; 
    }
}

int uart1_readline(char *str, int max_size) {
    int k = 0;
    if (max_size <= 0) return 0;
    while (k < max_size - 1) {
        char c = (char)uart1_getc();
        if (c == '\r' || c == '\n') {
            break;
        }
        str[k] = c;
        k++;
    }
    str[k] = '\0';
    return k;
}

unsigned char uart1_getc_blocking(void) {
    while (!uart1_available()) { /* Busy wait... */ }
    return uart1_getc();
}

int uart1_readline_blocking(char *str, int max_size) {
    int k = 0;
    if (max_size <= 0) return 0;
    while (k < max_size - 1) {
        char c = (char)uart1_getc_blocking();
        if (c == '\r' || c == '\n') {
            break;
        }
        str[k] = c;
        k++;
    }
    str[k] = '\0';
    return k;
}

void uart1_writeline(const char *str) {
    int len = (int)uart1_strlen(str);
    uart1_write((const unsigned char *)str, len);
    uart1_putc('\r');
    
    uart1_putc('\n');
}