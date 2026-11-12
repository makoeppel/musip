/**
 *  Created on: Apr 1, 2016
 *      Author: fwauters
 *
 *      Description: Get the MSCB interpreter for the Wavedream going on the NIOS processor
 */

#include "mscb.h"

#include "include/util.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/alt_timestamp.h>
#include <time.h>
#include <unistd.h>

/* GET_INFO attributes */
#define GET_INFO_GENERAL 0
#define GET_INFO_VARIABLE 1

/* Variable attributes */
#define SIZE_8BIT 1
#define SIZE_16BIT 2
#define SIZE_24BIT 3
#define SIZE_32BIT 4

/* Address modes */
#define ADDR_NONE 0
#define ADDR_NODE 1
#define ADDR_GROUP 2
#define ADDR_ALL 3

/* local variables */
int addressed = 0;
int addr_mode = 0;
int quit = 0;

int g_n_sub_addr;
int g_cur_sub_addr = 0;

SYS_INFO sys_info;
extern MSCB_INFO_VAR* variables;
int g_n_variables, g_var_size;

int DBG_INFO = 1;

/*------------------------------------------------------------------*/

/* number of status bytes */
#define N_STATUS_BYTES 2
/* number of setting bytes */
#define N_SETTING_BYTES 1

volatile alt_u32* sc_data = (alt_u32*)AVM_SC_BASE;
volatile alt_u32* mscb_base = (alt_u32*)AVM_MSCB_BASE;

const char* node_name = "FPGA_TEST";

/*---- Define variable parameters returned to CMD_GET_INFO command ----*/

typedef struct {
    uint8_t fpga_status[N_STATUS_BYTES];
    uint8_t fpga_status2[N_STATUS_BYTES];
    uint8_t fpga_setting[N_SETTING_BYTES];
} USER_DATA;

USER_DATA user_data;

MSCB_INFO_VAR vars[] = { { 0 } };

MSCB_INFO_VAR* variables = vars;

void read_fpga_status();
//void set_fpga();

void user_vars(int* n_sub_addr, int* var_size) {
    // declare number of sub-addresses and data size to framework
    *n_sub_addr = 1;
    *var_size = sizeof(USER_DATA);
}

/*---- User init function ------------------------------------------*/

extern SYS_INFO sys_info;

void user_init(int init) {
    /* initial nonzero EEPROM values */
    if(init) {
        memset(&user_data, 0, sizeof(user_data));
        //user_data.adc_gain = 1;
        //user_data.adc_offset = 0;
    }

    /* set default group address */
    if(sys_info.group_addr == 0xFFFF) sys_info.group_addr = 1600;

    sys_info.group_addr = 0xF000;
    sys_info.node_addr = 0xACA0;
    strcpy(sys_info.node_name, "StratixIVFrontend00");

    user_data.fpga_setting[0] = 0x00;
}

/*---- User read function ------------------------------------------*/

uint8_t user_read(int index) {
    return 0;
}

/*---- User get and set functions -----------------------------------------*/

// do we want to map some nios mem addr. to mscb variables ???

//void set_fpga() {
//    int value = user_data.fpga_setting[0];
//    IOWR_ALTERA_AVALON_PIO_DATA(PARALLEL_FPGA_SETTING_BASE, value);
//    usleep(1000);
//    return;
//}

//void read_fpga_status() {
//    user_data.fpga_status[0] = IORD_ALTERA_AVALON_PIO_DATA(PARALLEL_FPGA_STATUS_BASE);
//    user_data.fpga_status2[0] = IORD_ALTERA_AVALON_PIO_DATA(PARALLEL_FPGA_STATUS2_BASE);
//    return;
//}

/*---- User write function -----------------------------------------*/

void user_write(int index) {
    //set_fpga();
    return;
}

void print_byte(uint8_t byte) {
    printf("%0x\t", byte);
    for(int i = 7; i >= 0; i--) {
        printf("%d", (byte >> i) & 0x1);
    }
    printf("\n");
}

int get_times(void) {
    int counter = alt_nticks();
    return counter;
}

int time_diff(int t1, int t2) {
    //int diff_ = (t2 - t1);
    //int diff = (t2 - t1) / (int)TIME_FREQUENCY;
    return t2 - t1;
}

void mscb_init() {
    //printf("Starting MSCB test program\n");
    // start timer
    //if(alt_timestamp_start() < 0) printf("no timer available\n");
    // set default out values
    *mscb_base = 0x0FF; // fifo data
    printf("PARALLEL_MSCB_IN_BASE %x\n", *mscb_base);

    int flag = 0;

    // obtain number of sub addresses
    user_vars(&g_n_sub_addr, &g_var_size);

    // count variables
    for(g_n_variables = 0; variables[g_n_variables].width > 0; g_n_variables++) {
    }
    /*
    // obtain settings and variables from flash
    flag = mscb_flash_read();

    if (!flag) {
        // default addresses if flash info is invalid
        sys_info.group_addr = 0;
        sys_info.node_addr  = 0;
        strcpy(sys_info.node_name, "WD001");

        // default variables
        for(int i = 0; i < g_n_variables; i++) {
            if (!(variables[i].flags & MSCBF_DATALESS)) {
                // do it for each sub-address
                for(int adr = 0; adr < g_n_sub_addr; adr++) {
                    memset((uint8_t*)variables[i].ud + g_var_size*adr, 0, variables[i].width);
                }
            }
        }
    }

    // get GIT revision from src/git-revision.h and extract hash
    p = GIT_REVISION + strlen(GIT_REVISION)-4;
    sys_info.revision = strtol(p, NULL, 16);
    */
    user_init(!flag);

    if(DBG_INFO) printf("MSCB address   : 0x%04X\n", sys_info.node_addr);
}

/*------------------------------------------------------------------*/

int input_data_ready(void) {
    //2560 = 1010 0000 0000
    //printf("input parrallel port reading polling 0x%x\n", IORD_ALTERA_AVALON_PIO_DATA(PARALLEL_MSCB_IN_BASE));
    int input = *mscb_base;
    int empty_bit = 0x200;
    int empty = input & empty_bit;
    //usleep(10);
    //printf("empty bit = %0d\n",empty);
    if(empty != 0) {
        return 0;
    } //check empty flag of the fifo
    else {
        //printf("found data ready\n");
        return 1;
    }
}

int read_mscb_command(void) {
    //printf("input parrallel port reading before request 0x%x\n", IORD_ALTERA_AVALON_PIO_DATA(PARALLEL_MSCB_IN_BASE));
    //generate read request for the fifo
    *mscb_base = 0x400;

    //printf("input parrallel port reading 0x%x\n", IORD_ALTERA_AVALON_PIO_DATA(PARALLEL_MSCB_IN_BASE));

    return 0x1F & *mscb_base;
}

void send_data(uint8_t* buf, int n) {
    //printf("Data (%d bytes) ready to be send \n", n);
    for(int i = 0; i < n; i++) {
        //print_byte(buf[i]);
        *mscb_base = 0x1F & buf[i];
        //write request to FIFO
        *mscb_base = 0x200;
    }
}

/*------------------------------------------------------------------*/
int mscb_interprete(int submaster, uint8_t* buf, uint8_t* rb);
uint8_t in_buf[256], out_buf[256];
int i_in = 0;
int last_received = 0;

void mscb_uart_handler(void) {
    // drop partial buffer if no byte received for 100 ms
    int now = get_times();
    if(i_in > 0 && time_diff(last_received, now) > ALT_CPU_CPU_FREQ / 10000) {
        i_in = 0; //printf("reset buffer\n");
    }

    while(input_data_ready()) {
        //printf("int read byte loop, input_data_ready = %d\n", input_data_ready());
        int data = read_mscb_command();
        usleep(1); // wait inter-byte delay
        //printf("mscb byte = 0x%0x, i buffer = %d, tdiff = %d, last = %d, now = %d\n", data, i_in,time_diff(last_received, now), last_received, now);

        //print_byte(data);
        last_received = get_times();

        // a stream of 0's which we don`t interpret? FW
        // check for padding byte
        // is the this the start bit?
        if(data == 0 && i_in == 0) return;

        //read a byte FW
        in_buf[i_in++] = data;

        if(i_in == sizeof(in_buf)) {
            i_in = 0; // don't interpret command on buffer overflow
            return;
        }

        // initialize command length from first byte. 0x07 = 00000111. In the MSCb protocol, the last 3 bits of the first byte indicate the command length.
        int cmd_len = (in_buf[0] & 0x07) + 2; // + cmd + crc

        // if the first bit is xxxx x111, the command is variable in length
        if(i_in > 1 && cmd_len == 9) {
            // variable length command
            if(in_buf[1] & 0x80) cmd_len = (((in_buf[1] & 0x7F) << 8) | in_buf[2]) + 4;
            else
                cmd_len = in_buf[1] + 3; // + cmd + N + crc
        }

        // ignore ping acknowledge from other node
        if(i_in == 1 && in_buf[0] == 0x78) {
            i_in = 0;
            //printf("Ignoring ping acknowledge signal\n");
            return;
        }

        // hmmm, so what is happening here, return out of the function, so the data in reinterpreted?
        // I believe this is because the data gets transmitted byte by byte
        if(i_in < cmd_len) {
            //printf("Buffer not full yet, %d\n",cmd_len);
            return; // return if command not yet complete
        }

        int n = mscb_interprete(0, in_buf, out_buf);

        for(int i_printf = 0; i_printf < i_in; i_printf++) {
            //printf("0x%0x\t", in_buf[i_printf]);
        }
        //printf("\n");
        //printf("n is %d\n", n);
        if(n > 0) {
            send_data(out_buf, n);
            printf("sending mscb reply\n");
        }
        i_in = 0;
    }

    // drop partial buffer if no byte received for 100 ms
    //int now = get_times();
    //printf("time passed %f\n", time_diff(last_received, now));
    //if(i_in > 0 && time_diff(last_received,now) > 0.1) {
    //    i_in = 0;
    //    printf("reseting buffer\n");
    //}
}

/*------------------------------------------------------------------*/

void addr_node16(int mode, uint32_t adr, uint32_t node_addr) {
    //printf("entering addressing, current node address = %x, MSCB command address = %x, addressed status = %d, mode = %d\n",node_addr, adr, addressed, mode);
    if(node_addr == 0xFFFF) {
        if(adr == node_addr) {
            addressed = 1;
            g_cur_sub_addr = 0;
            addr_mode = mode;
        }
        else {
            addressed = 0;
            addr_mode = ADDR_NONE;
        }
    }
    else {
        if(mode == ADDR_NODE) {
            if(adr >= node_addr && adr < node_addr + g_n_sub_addr) {
                addressed = 1; // printf("addressed \n");
                g_cur_sub_addr = adr - node_addr;
                addr_mode = ADDR_NODE;
            }
            else {
                addressed = 0;
                addr_mode = ADDR_NONE;
            }
        }
        else if(mode == ADDR_GROUP) {
            if(adr == node_addr) {
                addressed = 1;
                g_cur_sub_addr = 0;
                addr_mode = ADDR_GROUP;
            }
            else {
                addressed = 0;
                addr_mode = ADDR_NONE;
            }
        }
    }
    //printf("addressed set to %d\n",addressed);
}

uint8_t mscb_loop(void) {
    quit = 0;

    // read UART only if we are in the crate -> slot_id != 0xFF
    //reg_bank_read(SYSTEM->wd2_reg_bank_ptr, REG_BANK_CTRL_REG, 4, &reg, 1);
    //if((reg & 0xFF) != 0xFF) mscb_uart_handler();

    mscb_uart_handler();
    static uint8_t ch = 'y';
    return ch;
}

int mscb_main() {
    //printf("starting mscb node ");
    //int ch = 'y';
    //mscb_init();

    //while(1) {
    //    ch = mscb_loop();
    //}

    printf("mscb node already running, using interrupts in this version\n");
    printf("Nothing to see here at the moment .., bye!\n");
    return 0;
}

int mscb_interprete(int submaster, uint8_t* buf, uint8_t* rb) {
    int n = 0;

    // determine length of MSCB command
    int buflen = (buf[0] & 0x07);
    if(buflen == 7) {
        if(buf[1] & 0x80) buflen = (((buf[1] & 0x7F) << 8) | buf[2]) + 4;
        else
            buflen = (buf[1] & 0x7F) + 3; // add command, length and CRC
    }
    else {
        buflen += 2; // add command and CRC
    }

    //if(DBG_INFO) {
    //    printf("MSCB interpreter: %d bytes\n", buflen);
    //    for(int j = 0; j < buflen; j++) {
    //        printf("%02X ", buf[j]);
    //        if ((j+1) % 16 == 0)
    //            printf("\n");
    //    }
    //    printf("\n");
    //}

    // check CRC
    if(util::crc8_dow(buf, buflen - 1) != buf[buflen - 1]) {
        //printf("MSCB interpreter: Invalid CRC %02X vs %02X\n", util::crc8_dow(buf, buflen-1), buf[buflen-1]);
        return 0;
    }
    //else printf("CRC ok\n");

    if(!addressed && buf[0] != MCMD_ADDR_NODE16 && buf[0] != MCMD_ADDR_GRP16 && buf[0] != MCMD_ADDR_BC &&
       buf[0] != MCMD_PING16) {
        //printf("not addressed\n");
        return 0;
    }

    switch(buf[0]) {
    case MCMD_ADDR_NODE16:
        addr_node16(ADDR_NODE, (buf[1] << 8) | buf[2], sys_info.node_addr);
        break;

    case MCMD_ADDR_GRP16:
        addr_node16(ADDR_GROUP, (buf[1] << 8) | buf[2], sys_info.group_addr);
        break;

    case MCMD_PING16:
        addr_node16(ADDR_NODE, (buf[1] << 8) | buf[2], sys_info.node_addr);
        if(addressed) {
            rb[0] = MCMD_ACK;
            n = 1;
        }
        else {
            if(submaster) {
                rb[0] = 0xFF;
                n = 1;
            }
        }
        break;

    case MCMD_INIT:
        quit = 1;
        mscb_main();
        break;

    case MCMD_GET_INFO:
        /* general info */
        n = 0;
        rb[n++] = MCMD_ACK + 7; // send acknowledge, variable data length
        rb[n++] = 32; // data length
        rb[n++] = PROTOCOL_VERSION; // send protocol version
        rb[n++] = 3; // n_variables // send number of variables
        rb[n++] = sys_info.node_addr >> 8; // send node address
        rb[n++] = sys_info.node_addr & 0xFF;
        rb[n++] = sys_info.group_addr >> 8; // send group address
        rb[n++] = sys_info.group_addr & 0xFF;
        rb[n++] = sys_info.revision >> 8; // send revision
        rb[n++] = sys_info.revision & 0xFF;

        for(int i = 0; i < 16; i++) // send node name
            rb[n++] = sys_info.node_name[i];

        for(int i = 0; i < 6; i++) // no RTC
            rb[n++] = 0;

        rb[n++] = 1024 >> 8; // max buffer size 1024 bytes
        rb[n++] = 1024 & 0xFF;

        rb[n] = util::crc8_dow(rb, n);
        n++;
        break;

    case MCMD_GET_INFO + 1:
        printf("variable info request\n");
        /* send variable info */
        if(buf[1] < g_n_variables) {
            MSCB_INFO_VAR* pvar;
            pvar = variables + buf[1];

            n = 0;
            rb[n++] = MCMD_ACK + 7; // send acknowledge, variable data length
            rb[n++] = 13; // data length
            rb[n++] = pvar->width;
            printf("width : %02X\n", pvar->width);
            rb[n++] = pvar->unit;
            rb[n++] = pvar->prefix;
            rb[n++] = pvar->status;
            rb[n++] = pvar->flags;

            for(int i = 0; i < 8; i++) { // send variable name
                rb[n++] = pvar->name[i];
            }

            rb[n] = util::crc8_dow(rb, n);
            n++;
        }
        else {
            /* just send dummy ack */
            rb[0] = MCMD_ACK;
            rb[1] = 0;
            n = 2;
        }
        break;

    case MCMD_SET_ADDR:
        printf("MCMD_SET_ADDR\n");
        if(buf[1] == ADDR_SET_NODE) /* complete node address */
            sys_info.node_addr = (buf[2] << 8) | buf[3];
        else if(buf[1] == ADDR_SET_HIGH)
            /* only high byte node address */
            *((uint8_t*)(&sys_info.node_addr)) = (buf[2] << 8) | buf[3];
        else if(buf[1] == ADDR_SET_GROUP)
            /* group address */
            sys_info.group_addr = (buf[2] << 8) | buf[3];

        /* copy address to flash */
        //mscb_flash_write();
        break;

    case MCMD_SET_NAME:
        printf("SET NAME\n");
        /* set node name in RAM */
        for(int i = 0; i < 16 && i < buf[1]; i++) {
            sys_info.node_name[i] = buf[2 + i];
        }
        sys_info.node_name[15] = 0;

        /* copy address to flash */
        //mscb_flash_write(); // Temp comment out, FW
        break;

    case MCMD_FLASH:
        printf("FLASH WRITE\n");
        //mscb_flash_write(); // Temp comment out, FW
        break;

    case MCMD_ECHO:
        printf("ECHO\n");
        rb[0] = MCMD_ACK + 1;
        rb[1] = buf[1];
        rb[2] = util::crc8_dow(rb, 2);
        n = 3;
        break;

    case MCMD_WRITE_MEM: {
        int size = buflen - 9; // minus cmd, len, subadr, adr and CRC
        // subadr = buf[3]; ignored
        int32_t adr = buf[4];
        adr = (adr << 8) | buf[5];
        adr = (adr << 8) | buf[6];
        adr = (adr << 8) | buf[7];
        printf("WRITE MEM:\t addr:%08X size %d\n", adr, size);
        sc_data[adr] = buf[8];
        //for(j=0;j<size;j++) { // TODO: block writing
        //    sc_data[adr] = (sc_data[adr] << 8) | buf[8+j];
        //}

        // avoid blocks for the moment:
        if(size >= 2) {
            sc_data[adr] = (sc_data[adr] << 8) | buf[9];
            if(size == 4) {
                sc_data[adr] = (sc_data[adr] << 8) | buf[10];
                sc_data[adr] = (sc_data[adr] << 8) | buf[11];
            }
        }

        for(int j = 0; j < size; j++) { // crc for mem write expects only crc of written data
            buf[j] = buf[j + 8];
        }

        rb[0] = MCMD_ACK;
        rb[1] = util::crc8_dow(buf, size);
        n = 2;
        buf[0] = 0; // do not re-interpreter command below

        break;
    }
    case MCMD_READ_MEM: {
        int size = (buf[2] << 8) | buf[3];
        // subadr = buf[3]; ignored
        uint32_t adr = buf[5];
        adr = (adr << 8) | buf[6];
        adr = (adr << 8) | buf[7];
        adr = (adr << 8) | buf[8];
        //printf("READ MEM:\t addr:%08X size %d\n", adr, size);

        //mscb only works with bytes
        //sc_data contains 32 bit per addr --> send 4 bytes per sc addr read:
        //buf[0]=(sc_data[adr]>>24);
        //buf[1]=(sc_data[adr]>>16);
        //buf[2]=(sc_data[adr]>>8);
        //buf[3]=sc_data[adr];

        //the same with a block of memory:
        for(int j = 0; j < (size / 4 + (size % 4 != 0)); j++) {
            for(int i = 0; i < 4; i++) {
                buf[j * 4 + i] = (sc_data[adr + j] >> (24 - 8 * i));
            }
        }

        rb[0] = MCMD_ACK + 7;
        rb[1] = 0x80 | ((size >> 8) & 0x7F);
        rb[2] = size & 0xFF;
        memcpy(rb + 3, buf, size);
        rb[3 + size] = util::crc8_dow(rb, size + 3);
        n = size + 4;
        buf[0] = 0; // do not re-interpreter command below
        break;
    }
    default:
        break;
    }

    if((buf[0] & 0xF8) == MCMD_READ) {
        printf("read request\n");
        if(buf[0] == MCMD_READ + 1) { // single variable
            if(buf[1] < g_n_variables) {
                n = variables[buf[1]].width; // number of bytes to return
                if(variables[buf[1]].flags & MSCBF_DATALESS) {
                    n = user_read(buf[1]); // for data less variables, user routine returns bytes
                    rb[0] = MCMD_ACK + 7; // and places data directly in out_buf
                    rb[1] = n;
                    n += 2;
                    rb[n] = util::crc8_dow(rb, n); // generate CRC code
                    n += 1;
                }
                else {
                    user_read(buf[1]);
                    if(n > 6) {
                        /* variable length buffer */
                        rb[0] = MCMD_ACK + 7; // send acknowledge, variable data length
                        rb[1] = n; // send data length
                        for(int i = 0; i < n; i++) { // copy user data
                            rb[2 + i] = ((uint8_t*)variables[buf[1]].ud)[i + g_var_size * g_cur_sub_addr];
                        }
                        n += 2;
                    }
                    else {
                        rb[0] = MCMD_ACK + n;
                        for(int i = 0; i < n; i++) { // copy user data
                            rb[1 + i] = ((uint8_t*)variables[buf[1]].ud)[i + g_var_size * g_cur_sub_addr];
                        }
                        n += 1;
                    }

                    rb[n] = util::crc8_dow(rb, n); // generate CRC code
                    n++;
                }
            }
            else {
                /* just send dummy ack to indicate error */
                rb[0] = MCMD_ACK;
                n = 1;
            }
        }
        else if(buf[0] == MCMD_READ + 2) { // variable range
            if(buf[1] < g_n_variables && buf[2] < g_n_variables && buf[1] <= buf[2]) {
                /* calculate number of bytes to return */
                int size = 0;
                for(int i = buf[1]; i <= buf[2]; i++) {
                    user_read(i);
                    size += variables[i].width;
                }
                n = 0;
                rb[n++] = MCMD_ACK + 7; // send acknowledge, variable data length
                if(size < 0x80) rb[n++] = size; // send data length one byte
                else {
                    rb[n++] = 0x80 | size / 0x100; // send data length two bytes
                    rb[n++] = size & 0xFF;
                }

                /* loop over all variables */
                for(int i = buf[1]; i <= buf[2]; i++) {
                    for(int j = 0; j < variables[i].width; j++) { // send user data
                        rb[n++] = ((uint8_t*)variables[i].ud)[j + g_var_size * g_cur_sub_addr];
                    }
                }

                rb[n] = util::crc8_dow(rb, n);
                n++;
            }
            else {
                /* just send dummy ack to indicate error */
                rb[0] = MCMD_ACK;
                n = 1;
            }
        }
    }

    if((buf[0] & 0xF8) == MCMD_WRITE_NA || (buf[0] & 0xF8) == MCMD_WRITE_ACK) {
        n = buf[0] & 0x07;
        int j, ch;
        if(n == 0x07) { // variable length
            j = 1;
            n = buf[1];
            ch = buf[2];
        }
        else {
            j = 0;
            ch = buf[1];
        }
        n--; // data size (minus channel)

        if(ch < g_n_variables) {

            /* don't exceed variable width */
            if(n > variables[ch].width) n = variables[ch].width;

            int a1, a2;
            if(addr_mode == ADDR_NODE) a1 = a2 = g_cur_sub_addr;
            else {
                a1 = 0;
                a2 = g_n_sub_addr - 1;
            }

            for(g_cur_sub_addr = a1; g_cur_sub_addr <= a2; g_cur_sub_addr++) {
                for(int i = 0; i < n; i++)
                    if(!(variables[ch].flags & MSCBF_DATALESS)) {
                        if(variables[ch].unit == UNIT_STRING) {
                            if(n > 4) /* copy bytes in normal order */
                                ((uint8_t*)variables[ch].ud)[i + g_var_size * g_cur_sub_addr] = buf[2 + j + i];
                            else
                                /* copy bytes in reverse order (got swapped on host) */
                                ((uint8_t*)variables[ch].ud)[i + g_var_size * g_cur_sub_addr] = buf[buflen - 2 - i];
                        }
                        else
                            /* copy LSB bytes, needed for BYTE if DWORD is sent */
                            ((uint8_t*)variables[ch].ud)[i + g_var_size * g_cur_sub_addr] =
                                buf[buflen - 1 - variables[ch].width + i + j];
                    }
                user_write(ch);
            }
            g_cur_sub_addr = a1; // restore previous value

            if((buf[0] & 0xF8) == MCMD_WRITE_ACK) {
                rb[0] = MCMD_ACK;
                rb[1] = buf[buflen - 1];
                n = 2;
            }
        }
    }
    return n;
}

struct mscb_t {
    alt_alarm alarm;

    void init() {
        printf("[mscb] init\n");
        mscb_init();

        while(input_data_ready()) {
            read_mscb_command();
        }

        if(int err = alt_ic_isr_register(0, 13, callback, this, nullptr)) {
            printf("[mscb] ERROR: alt_ic_isr_register => %d\n", err);
        }
    }

    void callback() {
        mscb_uart_handler();
        //printf("callback");

        // TEST OUTPUT
        //int data = read_mscb_command();
        //if(data != 0xff) { // why is this happening ?? TODO: fix this when doing addressing in hardware !
        //    printf("reading mscb command\n");
        //    print_byte(data);
        //}
        //while(input_data_ready()) {
        //    data = read_mscb_command();
        //    print_byte(data);
        //}
    }

    static void callback(void* context) {
        ((mscb_t*)context)->callback();
    }
};
