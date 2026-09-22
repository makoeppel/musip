#include "system.h"
#include "uart.h"
#include "uart_commands.h"
#include <cstdio>
#include <altera_avalon_spi.h>
#include <altera_avalon_spi_regs.h>

void uart485_print_status(int base) {
    printf("IORD_FIFOED_AVALON_UART_STATUS %x\n", IORD_FIFOED_AVALON_UART_STATUS(base));
    printf("IORD_FIFOED_AVALON_UART_CONTROL %x\n", IORD_FIFOED_AVALON_UART_CONTROL(base));
    printf("IORD_FIFOED_AVALON_UART_DIVISOR %x\n", IORD_FIFOED_AVALON_UART_DIVISOR(base));
    printf("IORD_FIFOED_AVALON_UART_EOP %x\n", IORD_FIFOED_AVALON_UART_EOP(base));
    printf("IORD_FIFOED_AVALON_UART_RX_FIFO_USED %x\n", IORD_FIFOED_AVALON_UART_RX_FIFO_USED(base));
    printf("IORD_FIFOED_AVALON_UART_TX_FIFO_USED %x\n", IORD_FIFOED_AVALON_UART_TX_FIFO_USED(base));
    printf("IORD_FIFOED_AVALON_UART_GAP %x\n", IORD_FIFOED_AVALON_UART_GAP(base));
    printf("IORD_FIFOED_AVALON_UART_TIMESTAMP %x\n", IORD_FIFOED_AVALON_UART_TIMESTAMP(base));
    printf("IORD_FIFOED_AVALON_UART_RXDATA %x\n", IORD_FIFOED_AVALON_UART_RXDATA(base));
    printf("IORD_FIFOED_AVALON_UART_TXDATA %x\n", IORD_FIFOED_AVALON_UART_TXDATA(base));
}

void uart485_init(int base) {
    IOWR_FIFOED_AVALON_UART_CONTROL(base, 0);
    IORD_FIFOED_AVALON_UART_RXDATA(base);
    IOWR_FIFOED_AVALON_UART_STATUS(base, 0);
}

void uart485_select(int base, int spi_base, int sel){
      //for 4-port DAB
      IOWR_ALTERA_AVALON_SPI_CONTROL(spi_base, 0);
      IOWR_ALTERA_AVALON_SPI_SLAVE_SEL(spi_base, ~uint8_t(sel));
      IOWR_ALTERA_AVALON_SPI_CONTROL(spi_base, ALTERA_AVALON_SPI_CONTROL_SSO_MSK);

      //for 2-port DAB
      auto reg=IORD_FIFOED_AVALON_UART_CONTROL(base) & ~FIFOED_AVALON_UART_CONTROL_RTS_MSK;
	  if( sel == 0)
		reg |= FIFOED_AVALON_UART_CONTROL_RTS_MSK;
	  IOWR_FIFOED_AVALON_UART_CONTROL(base,reg);
	}


int uart485_write(int base, const char* ptr, size_t len, bool flags) {
    //int             no_block;
    //alt_u32         next;
    //int count                = 0;
    int timeout = len * 100;
    const char* last = ptr + len;
    /*
     * Construct a flag to indicate whether the device is being accessed in
     * blocking or non-blocking mode.
     */

    //no_block = (flags & O_NONBLOCK);

    /*
     * Loop transferring data from the input buffer to the transmit circular
     * buffer. The loop is terminated once all the data has been transferred,
     * or, (if in non-blocking mode) the buffer becomes full.
     */

    while(timeout > 0) {
        if(IORD_FIFOED_AVALON_UART_STATUS(base) & FIFOED_AVALON_UART_STATUS_TRDY_MSK) {
            IOWR_FIFOED_AVALON_UART_TXDATA(base, *ptr);
            ++ptr;
            if(ptr == last) break;
        }
        timeout--;
    }
    //printf("Len=%d, Time=%d\n",len,len*100 - timeout);
    if(len > 0 && timeout == 0) return -1;
    return len;
}

void uart485_rxclear(int base) {
    char dummy = IORD_FIFOED_AVALON_UART_RXDATA(base);
    (void)dummy;
}

int uart485_read(int base, char* ptr, int len, bool non_block) {
    //int             no_block;
    //alt_u32         next;
    int pos = 0;
    int timeout = len * 1000;
    alt_u32 status;
    while(timeout > 0) {
        status = IORD_FIFOED_AVALON_UART_STATUS(base);
        IOWR_FIFOED_AVALON_UART_STATUS(base, 0);

        if(status & FIFOED_AVALON_UART_STATUS_RRDY_MSK) {
            ptr[pos] = IORD_FIFOED_AVALON_UART_RXDATA(base);
            pos++; // get the next char if needed
            if(pos == len) //maximum length reached
                break;
        }
        else // no chars are ready, stop here if nonblocking
            if(non_block) timeout--;
    }
    if(len > 0 && timeout == 0) return -1;
    return pos;
}

int uart485_write_packet(int base, const mcu_packet& packet, bool flags = 0) {
    char header[3];
    //flush buffer
    uart485_read(base, header, 3, true);
    header[0] = packet.cmd;
    header[1] = (packet.len & 0xff00) >> 8;
    header[2] = (packet.len & 0xff);
    //printf("WP:Cmd=%x Len=%d\n",packet.cmd,packet.len);
    //printf("Header: %x.%x.%x\n",header[0]&0xff,header[1]&0xff,header[2]&0xff);

    if(uart485_write(base, header, 3, flags) < 1) return -1;
    if(uart485_write(base, packet.data, packet.len, flags) < 0) return -1;
    return 0;
}

int uart485_rcv_packet(int base, mcu_packet& packet, int max_len, bool flags = false) {
    char header[3];
    if(uart485_read(base, header, 3, flags) < 3) return -1;
    packet.cmd = header[0];
    packet.len = header[2];
    packet.len |= (header[1] << 8);
    packet.len &= 0x1ff; //limit maximum readable length to avoid locking up

    if(max_len >= packet.len) max_len = packet.len;
    else {
        uart485_read(base, packet.data, max_len, true); //consume what we can
        uart485_read(base, NULL, packet.len - max_len, true); //consume and dump payload, we can not hold it
        return -2;
    }
    if(packet.len == 0) return 0;
    if(uart485_read(base, packet.data, packet.len, true) < 0) return -1;

    //printf("Packet RX / Header: %x.%x.%x, max_len=%d\n",header[0]&0xff,header[1]&0xff,header[2]&0xff,max_len);
    //printf("Packet RX / Packet:Cmd=%x Len=%d\n",packet.cmd,packet.len);
    //packet.print();
    return 0;
}
