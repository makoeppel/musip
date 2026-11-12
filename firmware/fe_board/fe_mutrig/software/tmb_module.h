#ifndef TB_MODULE_H_
#define TB_MODULE_H_
//FEB
#include <sys/alt_alarm.h>

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>

//forward declarations
struct sc_t;

#include "uart_commands.h"
#include "uart.h"

struct TB_t {
    sc_t& sc;
    TB_t(sc_t& _sc);

    //=========================
    // higher level functions
    alt_u16     init_TB();
    bool        is_board_present(int asic);

    void        periodic(); //TODO - Needed?


    //automatic powering
    alt_u16     power_ASIC(int asic, bool enable=true);
    alt_u16     power_ASIC_AD(int asic, bool enable_vccd, bool enable_vcca, bool configure=false);
    void        power_ASIC_all(bool enable); //menu usage

    //control the pulse injection (pll_test) distribution tree of the TMB - output enable signal
    //- Switch corresponding register on the FEB
    alt_u16     setInject(int enable);
    bool        checkInject();

    //ASIC configuration
    //write slow control pattern over SPI, returns 0 if readback value matches written, otherwise -1. Does not include CSn line switching.
    int spi_write_pattern(alt_u32 spi_slave, const alt_u8* bitpattern);
    //write and verify pattern twice, toggle i2c lines via i2c
    alt_u16     configure_asic(alt_u32 asic, const alt_u8* bitpattern);

    //print out a given pattern for debugging
    void        print_config(const alt_u8* bitpattern);
    void        print_config_reverse(const alt_u8* bitpattern);

    static const uint8_t nBoards = 4;
    alt_u16 boards_present = 0;
    alt_u16 boardIDs[nBoards];
    alt_u16 software_Status = 0;
    alt_u16 asicStatus = 0;
    alt_u32 matrix_tmp_Status = 0;
    volatile alt_u32 matrix_tmp_data[53];
    volatile alt_u32 power_data[56];
    volatile alt_u32 tb_status_data[2+nBoards];


    //monitoring
    void        init_current_monitor(){}; //no current monitor
    void        init_matrix_t(){}; //TODO
    void        read_matrix_t(volatile alt_u32 * data);
    void        read_matrix_ids(volatile alt_u32 * data){}; //TODO
    void        read_tb_status(volatile alt_u32 * data);
    void        read_power(volatile alt_u32 * data);

    void        print_matrix_t(volatile alt_u32 * data, const bool two_columns=false);
    void        print_power(volatile alt_u32 * data);
    void        print_tb_status(volatile alt_u32 * data);

    bool        ping(int board, uint16_t& boardID);
    //=========================


    //=========================
    //Menu functions for command line use
    void menu_TB_monitors();
    void menu_TB_debug();
    void menu_TB_main();
    void menu_TB_pwr();
    void menu_ASIC_config();
    //Slow control callback
    alt_u16 sc_callback(alt_u16 cmd, volatile alt_u32* data, alt_u16 n);

};
#endif
