#pragma once

#include "system.h"
#include "altera_avalon_pio_regs.h"

struct status_t {
    alt_alarm alarm;

    void init() {
    }

    void menu() {
        while (1) {
            printf("\n");
            printf("[status] -------- menu --------\n");
            ReadStatusRegister();
            printf("  [s] => status\n");
            printf("  [p] => program Arria\n");
            printf("  [d] => shutdown FEB\n");
            printf("  [q] => exit\n");

            printf("Select entry ...\n");
            char cmd = wait_key();
            switch(cmd) {
            case 's':
                ReadStatusRegister();
                break;
            case 'p':
                StartProgramming();
                break;
            case 'd':
                IOWR_ALTERA_AVALON_PIO_DATA(SHUTDOWN_BASE, 0x1);
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }
        }
    }


    static void ReadStatusRegister() {
    printf("Status: %x\n", (uint32_t)IORD_ALTERA_AVALON_PIO_DATA(STATUS_BASE));
    printf("Programming Status: %x\n", (uint32_t)IORD_ALTERA_AVALON_PIO_DATA(PROGRAMMING_STATUS_BASE));
    printf("CRC location: %x\n", (uint32_t)IORD_ALTERA_AVALON_PIO_DATA(CRCLOCATION_BASE));
    printf("Raw temperature: %i\n", (uint32_t)IORD_ALTERA_AVALON_PIO_DATA(TEMPERATURE_BASE));
    }

    static void StartProgramming() {
        IOWR_ALTERA_AVALON_PIO_DATA(PROGRAMMING_CONTROL_BASE, 0x1);
        IOWR_ALTERA_AVALON_PIO_DATA(PROGRAMMING_CONTROL_BASE, 0x0);
    }


};
