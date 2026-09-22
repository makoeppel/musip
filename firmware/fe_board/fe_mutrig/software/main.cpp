
#include "include/base.h"

#include "include/a5/fifoed_avalon_uart_regs.h"
#include "uart.h"

int uart485_0 = -1;

void uart485_init() {
    uart = open(UART485_0_NAME, O_NONBLOCK);
    if(uart < 0) {
        printf("ERROR: can't open %s\n", UART485_0_NAME);
    }
}

#include "include/xcvr.h"

#include "../../fe/software/si5345.h"
#include "../../fe/software/si5345_regs1_mutrig.h"
#include "../../fe/software/si5345_regs2.h"
si5345_t si5345_1 { SPI_SI_BASE, 0, si5345_regs1_mutrig, sizeof(si5345_regs1_mutrig) / sizeof(si5345_regs1_mutrig[0]) };
si5345_t si5345_2 { SPI_SI_BASE, 1, si5345_regs2, sizeof(si5345_regs2) / sizeof(si5345_regs2[0]) };

#include "../../fe/software/sc.h"
sc_t sc;

#include "../../fe/software/mscb_user.h"
mscb_t mscb;
#include "../../fe/software/reset.h"


#include "uart_commands.h"

#include "tmb_module.h"
TB_t TB(sc);
#include "../../../registers/mutrig_registers.h"
#include "../../firmware/FEB_mutrig/software/mutrig_common.h"

#include "../../../../midas_fe/constants.h"

//definition of callback function for slow control packets
alt_u16 sc_t::callback(alt_u16 cmd, volatile alt_u32* data, alt_u16 n) {
    //printf("[sc callback] %x \n,cmd");
    switch(cmd & 0xFFF0) {
    case CMD_MUTRIG_CNT_RESET:
        mutrig_reset_counters();
        return FEB_REPLY_SUCCESS;
        break;
    default:
        return TB.sc_callback(cmd, data, n);
        break;
    }
    return FEB_REPLY_SUCCESS;
}

char wait_key_to(useconds_t us = 100000, int timeout_cnt = 100) {
    while(timeout_cnt--) {
        char cmd = 0;
        if(uart < 0) return cmd;
        if(read(uart, &cmd, 1) > 0) return cmd;
        usleep(us);
    }
    return 0;
}

void print_menu(int ID){
        printf("\n");
        printf("[fe_tile] -------- menu --------\n");
        printf("ID: 0x%08x\n",ID);

        printf("\n");
        printf("  [1] => Firefly channels\n");
        printf("  [2] => sub-detector menu\n");
        printf("  [c] => common mutrig\n");
        printf("  [3] => sc\n");
        printf("  [4] => si5345_1\n");
        printf("  [5] => si5345_2\n");
        printf("  [6] => mscb\n");
        printf("  [7] => reset system\n");

        printf("Select entry ...\n");
}


//#define QUICKBOOT
int main() {

    base_init();
#ifndef QUICKBOOT
    si5345_2.init();
    usleep(5000000);
    si5345_1.init();
    //mscb.init();
    sc.init();
#endif

    volatile sc_ram_t* ram = (sc_ram_t*)AVM_SC_BASE;
    ram->data[FPGA_ID_REGISTER_RW] = 0xaffeaffe;
    printf("%08X\n", ram->data[CMD_OFFSET_REGISTER_RW]);
    //issue a reset to the datapath
    sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 2;
    usleep(50000);
    sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0;

    ram->data[CMD_OFFSET_REGISTER_RW] = 0x0002;
    uart485_init(UART485_0_BASE);
    //char buffer[254];
    //mcu_packet packet(buffer);

    print_menu(ram->data[FPGA_ID_REGISTER_RW]);
    while(1) {
        char cmd = wait_key_to(1000,1000);
        switch(cmd) {
        case 0:
            //TB.periodic();
            continue;
        case '1':
            menu_xcvr((alt_u32*)((AVM_SC_BASE + 4 * 0xFF00) | ALT_CPU_DCACHE_BYPASS_MASK));
            break;
        case '2':
            TB.menu_TB_main();
            break;
        case 'c':
            menu_mutrig_common(13,1);
            break;
        case '3':
            sc.menu();
            break;
        case '4':
            si5345_1.menu();
            break;
        case '5':
            si5345_2.menu();
            break;
        case '6':
            mscb_main();
            break;
        case '7':
            menu_reset();
            break;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
        print_menu(ram->data[FPGA_ID_REGISTER_RW]);
    }

    return 0;
}
