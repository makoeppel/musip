#pragma once

#include "../../fe/generated/mupix_registers.h"
#include "../../fe/generated/sorter_registers.h"
#include "../../fe/generated/lvds_registers.h"

using namespace mu3e::daq::feb;

//declaration of interface to scifi module: hardware access, menu, slow control handler
struct mupix_t {
    sc_t* sc;
    mupix_t(sc_t* sc_) : sc(sc_) {}

    const uint32_t MUPIX8_LEN32 = 94;
    const uint32_t MUPIX_CONFIG_LEN_BYTES=MUPIX8_LEN32*4;
    const uint32_t MUPIX_CONFIG_LEN_BITS =MUPIX8_LEN32*4*8;
    const uint32_t MUPIXBOARD_LEN32 = 2;

    const uint8_t n_ASICS = 1;

    void mupix_write_all_off(bool useNew) {
        if(useNew) {
            sc->ram->data[MP_CTRL_SPI_ENABLE_REGISTER_W]=0x00000000;
        }
        else {
            sc->ram->data[MP_CTRL_SPI_ENABLE_REGISTER_W]=0x00000001;
        }
        sc->ram->data[MP_CTRL_SLOW_DOWN_REGISTER_W]=0x0000000F; // set spi slow down
        sc->ram->data[MP_CTRL_DIRECT_SPI_ENABLE_REGISTER_W]=0x00000000;
        sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000001;
        usleep(10);
        sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000000;

        for(int i = 0; i<12; i++){
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x2A000A03;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xFA3F002F;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1E041041;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x041E9A51;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x40280000;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1400C20A;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x0280001F;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x00020038;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x0000FC09;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xF0001C80;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x00148000;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x11802E00;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x52400000;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xa3f03cf;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1e514514;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x514e9a12;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x8028000a;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x14028c14;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x180001f;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x30138;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xfc00;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xf0001400;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1d9d4000;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1c002a40;
        }
    }

    void test_tdacs() {

        printf("test tdacs both");

        for(int i = 0; i<24; i++) {
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0xFFFFFFFF;
        }
        //for(int i = 30; i<40; i++) {
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0x0;
        //}
        for(int i = 35; i<128; i++) {
            sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W]=0xFFFFFFFF;
        }

    }

    void test_tdacs2() {

        printf("test tdacs mask\n");

        for (int c = 0; c < 2; ++c) {
            for(int i = 0; i<256*64; i++) {
                sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W+c]=0x0;
            }
        }

    }

    void test_tdacs3() {

        printf("test tdacs unmask\n");

        for (int c = 0; c < 2; ++c) {
            for(int i = 0; i<256*64; i++) {
                sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W+c]=0xFFFFFFFF;
            }
        }

    }

    void test_tdac_pattern() {
        printf("test tdac pattern");
        sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000001;
        sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000000;
        sc->ram->data[MP_CTRL_RUN_TEST_REGISTER_W]=0x1;
    }

    void test_write_all(bool useNew) {
        if(useNew){
            sc->ram->data[MP_CTRL_SPI_ENABLE_REGISTER_W]=0x00000000;
        }else{
            sc->ram->data[MP_CTRL_SPI_ENABLE_REGISTER_W]=0x00000001;
        }
        sc->ram->data[MP_CTRL_DIRECT_SPI_ENABLE_REGISTER_W]=0x00000000;
        sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000001;
        usleep(10); // time the mupix needs to reset
        sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000000;
        printf("test write all");
        for(int i = 0; i<12; i++){
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x2A000A03;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xFA3F0025;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1E041041;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x041E5951;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x40280000;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1400C20A;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x028A001F;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x00000038;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x0000FC09;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xF0001C80;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x00148000;
            //sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x11802E00;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x52400000;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xa3f03cf;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1e514514;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x514e9a12;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x8028000a;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x14028c14;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x18a001f;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x30138;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xfc00;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xf0001400;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1d9d4000;
            sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1c002a40;
        }

    }



    void test_write_one(int i) {
        printf("test write %i", i);
        sc->ram->data[MP_CTRL_SPI_ENABLE_REGISTER_W]=0x00000000;
        sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000001;

        /*sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x2A000A03;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xFA3F0025;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1E041041;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x041E5951;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x40280000;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1400C20A;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x028A001F;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x00000038;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x0000FC09;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xF0001C80;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x00148000;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x11802E00;*/

        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x16000A00;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xA53F014F;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x1E514A28;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x514B0CA1;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x00100005;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x14010A14;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x010A003F;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x00020038;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x0000FC04;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0xF00025C0;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x2E6D4000;
        sc->ram->data[MP_CTRL_COMBINED_START_REGISTER_W+i]=0x29C03180;


    }

    void menu_lvds() {
        alt_u32 value = 0x0;
        while (1) {
            char cmd;
            if(read(uart, &cmd, 1) > 0) switch(cmd) {
            case '?':
                wait_key();
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }

            printf("pll_lock should always be '1', rx_state 0: wait for dpa_lock 1: alignment 2:ok, disp_err is only counting in rx_state 2\n");
            printf("order is CON2 ModuleA chip1 ABC, chip2 ABC, .. ModuleB chip1 ABC .. CON3..\n");
            for(int i=0; i<37; i++){
                value = sc->ram->data[LVDS_STATUS_START_REGISTER_W+i*4];
                printf("chip%i, Link%i val: %x \n ",i/3,i,value);
                //printf("chip%i, Link%i ready: %01x pll_lock: %01x align_cnt: %01x disp_err: %01x\n ",i/3,i,value>>31,(value>>30) & 0x1,(value>>24) & 0x3F,value & 0x00FFFFFF);
            }
            printf("----------------------------\n");
            usleep(200000);
        }
    }

    //write slow control pattern over SPI, returns 0 if readback value matches written, otherwise -1. Does not include CSn line switching.
    alt_u16 set_chip_dacs(alt_u32 asic, volatile alt_u32* bitpattern) {
        return FEB_REPLY_SUCCESS;
    }

    alt_u16 set_board_dacs(alt_u32 asic, volatile alt_u32* bitpattern) {
        return FEB_REPLY_SUCCESS;
    }

    void powerup() {
        printf("[scifi] powerup: not implemented\n");
    }

    void powerdown() {
        printf("[scifi] powerdown: not implemented\n");
    }

    void read_counters() {
        printf("[mupix] trigger read counters\n");
    }

    void menu() {
        //auto& regs = sc->ram->regs.scifi;
        alt_u32 value = 0x0;
        alt_u32 value2 = 0x0;
        char str[2] = {0};
        int n_pages_remaining = 128;
        int pos = 0;
        int tdac_counter = 0;
        alt_u32 n_free_pages = 0x0;

        while(1) {
            printf("  [a] => write all OFF\n");
            printf("  [z] => write all OFF (new)\n");
            printf("  [t] => test tdacs\n");
            printf("  [0] => configure chip Number N\n");
            printf("  [1] => set mupix config mask\n");
            printf("  [2] => set spi clk slow down reg\n");
            printf("  [3] => print lvds status\n");
            printf("  [5] => set lvds mask\n");
            printf("  [6] => test write all\n");
            printf("  [9] => test write all new\n");
            printf("  [7] => write sorter delay\n");
            printf("  [8] => test TDAC write\n");
            if((sc->ram->data[MP_CTRL_SIN_INVERT_REGISTER_W]) & 1U){
                printf("  [i] => do not invert SIN\n");
            }
            else {
                printf("  [i] => invert SIN\n");
            }
            printf("  [k] => incr SIN shift\n");
            printf("  [m] => decr SIN shift\n");
            printf("  [n] => mask all pixels\n");
            printf("  [u] => unmask all pixels\n");
            printf("  [q] => exit\n");

            printf("Select entry ...\n");
            char cmd = wait_key();
            switch(cmd) {
            case 'r':
                sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000001;
                usleep(10);
                sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000000;
                break;
            case 'a':
                mupix_write_all_off(false);
                break;
            case 'z':
                mupix_write_all_off(true);
                break;
            case 'b':
                test_tdacs();
                break;
            case 'n':
                test_tdacs2();
                break;
            case 'u':
                test_tdacs3();
                break;
            case 'p':
                test_tdac_pattern();
                break;
            case 'i':
                sc->ram->data[MP_CTRL_SIN_INVERT_REGISTER_W] ^= 1UL;
                break;
            case 'k':
                sc->ram->data[MP_CTRL_SLOW_CLK_SHIFT_REGISTER_W]=sc->ram->data[MP_CTRL_SLOW_CLK_SHIFT_REGISTER_W]+1;
                value = sc->ram->data[MP_CTRL_SLOW_CLK_SHIFT_REGISTER_W];
                printf("shift is: 0x%08x\n", value);
                break;
            case 'm':
                sc->ram->data[MP_CTRL_SLOW_CLK_SHIFT_REGISTER_W]=sc->ram->data[MP_CTRL_SLOW_CLK_SHIFT_REGISTER_W]-1;
                value = sc->ram->data[MP_CTRL_SLOW_CLK_SHIFT_REGISTER_W];
                printf("shift is: 0x%08x\n", value);
                break;
            case '0':
                value = 0x0;
                printf("Enter Chip to configure in hex: ");

                str[0] = wait_key();
                value = strtol(str,NULL,16);
                printf("configuring chip: 0x%08x\n", value);
                if(value<12) {
                    test_write_one(value);
                }
                else {
                    printf("chip 0x%08x does not exist on any FEB\n", value);
                }

                break;
            case '1':
                value = 0x0;
                printf("Enter Chip Mask in hex: ");

                for(int i = 0; i < 8; i++) {
                    printf("mask: 0x%08x\n", value);
                    str[0] = wait_key();
                    value = value*16+strtol(str,NULL,16);
                }

                printf("setting mask to 0x%08x\n",value);
                //sc->ram->data[MP_CTRL_CHIP_MASK_REGISTER_W]=value;
                break;
            case '2':
                value = 0x0;
                printf("Enter value in hex:(clk period will be something like 12.8ns * this value)");

                for(int i = 0; i < 8; i++) {
                    printf("value: 0x%08x\n", value);
                    str[0] = wait_key();
                    value = value*16+strtol(str,NULL,16);
                }

                printf("setting spi slow down to 0x%08x\n",value);
                sc->ram->data[MP_CTRL_SLOW_DOWN_REGISTER_W]=value;
                break;
            case '3':
                menu_lvds();
                break;
            case '5':
                value = 0x0;
                value2 = 0x0;
                printf("Enter mask in hex: (36 bit number)\n");
                printf("mask: 0x%01x%08x\n",value2, value);
                str[0] = wait_key();
                value2 = value2*16+strtol(str,NULL,16);
                for(int i = 0; i < 8; i++) {
                    printf("mask: 0x%01x%08x\n",value2, value);
                    str[0] = wait_key();
                    value = value*16+strtol(str,NULL,16);
                }

                printf("setting lvds mask to 0x%01x%08x\n",value2, value);
                sc->ram->data[MP_LVDS_LINK_MASK_REGISTER_W]=value;
                sc->ram->data[MP_LVDS_LINK_MASK2_REGISTER_W]=value2;
                break;
            case '6':
                test_write_all(false);
                break;
            case '9':
                test_write_all(true);
                break;
            case '7':
                sc->ram->data[MP_SORTER_DELAY_REGISTER_W]=10;
                break;
            case '8':
                printf("testing tdac write ...\n");
                sc->ram->data[MP_CTRL_SPI_ENABLE_REGISTER_W] = 0x1;
                sc->ram->data[MP_CTRL_SLOW_DOWN_REGISTER_W] = 0xF;
                sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000001;
                usleep(10);
                sc->ram->data[MP_CTRL_RESET_REGISTER_W]=0x00000000;


                n_pages_remaining = 128;
                while(n_pages_remaining > 0) {
                    n_free_pages = sc->ram->data[MP_CTRL_N_FREE_PAGES_REGISTER_R];
                    printf("free %08x, remain %08x\n",n_free_pages,n_pages_remaining);
                    if(n_free_pages > 0) {
                        printf("write %08x\n",n_free_pages);
                        for(int i = 0; i< n_free_pages; i++) {
                            for(int j=0; j < 128; j++) {
                                sc->ram->data[MP_CTRL_TDAC_START_REGISTER_W + pos]= tdac_counter;
                            }
                            n_pages_remaining--;
                            pos = (pos+1)%12;
                        }
                    }else{
                        usleep(5000);
                    }
                }
                printf("done\n");
                break;
            //case '9':
            //    sc->ram->data[MP_SORTER_DELAY_REGISTER_W]=0x5FC;
            //    break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }
        }
    }

    alt_u16 callback(alt_u16 cmd, volatile alt_u32* data, alt_u16 n) {
//        auto& regs = ram->regs.scifi;
        alt_u16 status=FEB_REPLY_SUCCESS;
        switch(cmd){
        case 0x0101: //power up (not implemented in current FEB)
            break;
        case 0x0102: //power down (not implemented in current FEB)
            break;
        case 0x0105: //read counters
            read_counters();
            break;
        case 0xfffe:
            printf("-ping-\n");
            break;
        case 0xffff:
            break;
        case 0x0110:
            status=set_chip_dacs(data[0], &(data[1]));
            return status;
        case 0x0120:
            status=set_board_dacs(data[0], &(data[1]));

/*
            if(sc->ram->regs.scifi.ctrl.dummy&1){
                //when configured as dummy do the spi transaction,
                //but always return success to switching board
                if(status!=FEB_REPLY_SUCCESS) printf("[WARNING] Using configuration dummy\n");
                status=FEB_REPLY_SUCCESS;
            }*/
            return status;
        default:
            return FEB_REPLY_ERROR;
        }

        return 0;
    }

};
