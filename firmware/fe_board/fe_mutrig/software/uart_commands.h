/*
 * uart_commands.h
 *
 * Created: 30.10.2023 14:45:46
 *  Author: konra
 */


#ifndef UART_COMMANDS_H_
#define UART_COMMANDS_H_

#define MCUCMD_ACK   0xaa
#define MCUCMD_NACK  0xff
#define MCUCMD_PING  0x01
#define MCUCMD_CFG   0x02
#define MCUCMD_TRD   0x03
#define MCUCMD_VRD   0x04
#define MCUCMD_STAT  0x05
#define MCUCMD_PCTRL 0x06

struct mcu_packet {
    alt_u8 cmd; //command
    alt_u16 len; //payload length in bytes
    char* data;
    mcu_packet(alt_u8 _cmd, alt_u16 _len = 0, char* _data = NULL)
        : cmd(_cmd)
        , len(_len)
        , data(_data) {};

    mcu_packet()
        : cmd(0)
        , len(0)
        , data(NULL) {};

    mcu_packet(char* _data)
        : cmd(0)
        , len(0)
        , data(_data) {};

    void print(int n = 20) {
        printf("Packet: cmd=0x%x, len=%u \t\"", cmd & 0xff, len);
        for(int i = 0; i < n; i++) {
            if(i >= len) break;
            printf("%2.2x.", 0xff & data[i]);
        }
        printf("\"\n");
    }
};

#endif /* UART_COMMANDS_H_ */
