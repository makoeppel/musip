#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include "include/a5/fifoed_avalon_uart_regs.h"
#include "uart_commands.h"


void uart485_print_status(int base);
void uart485_init(int base);
void uart485_select(int base,int spi_base, int sel);
int uart485_write (int base, const char* ptr, size_t len, bool flags);
void uart485_rxclear(int base);
int uart485_read (int base, char* ptr, int len, bool non_block);
int uart485_write_packet(int base, const mcu_packet& packet, bool flags);
int uart485_rcv_packet(int base, mcu_packet& packet, int max_len, bool flags);
