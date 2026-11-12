#pragma once

#include "system.h"
#include "spiflash_commands.h"
#include "altera_avalon_pio_regs.h"

#define CMDADDR(cmd, addr) ((cmd << 24) + addr)
#define CMDADDRBASE FLASH_CMD_ADDR_BASE
#define CTRLBASE FLASH_CTRL_BASE
#define DATAOUTBASE FLASH_O_DATA_BASE
#define DATAINBASE FLASH_I_DATA_BASE

#define STROBE_BIT 0x1
#define CONTINUE_BIT 0x2
#define FIFO_BIT 0x80
#define FIFO_CLEAR_BIT 0x40



struct flash_t {
    alt_alarm alarm;

    void init() {
        printf("[flash] init\n");

        // TODO: init flash

        int err = alt_alarm_start(&alarm, 0, callback, this);
        if(err) {
            printf("[flash] ERROR: alt_alarm_start => %d\n", err);
        }
    }

    alt_u32 hibit(alt_u32 n) {
        if(n == 0) return 0;
        alt_u32 r = 0;
        if(n & 0xFFFF0000) { r += 16; n >>= 16; };
        if(n & 0xFF00) { r += 8; n >>= 8; };
        if(n & 0xF0) { r += 4; n >>= 4; };
        if(n & 8) return r + 3;
        if(n & 4) return r + 2;
        if(n & 2) return r + 1;
        return 0;
    }

    volatile alt_u32* ctrl = (alt_u32*)(FLASH_CTRL_BASE);
    volatile alt_u8* data = (alt_u8*)(FLASH_DATA_BASE);

    alt_u32 hist_ts[16];

    alt_u32 callback() {
        alt_timestamp_start();
        int state = 0;

        alt_u32 size = ctrl[1];
        if(size == 0) return 10;
        alt_u32 addr = ctrl[0];
        for(int i = 0; i < FLASH_DATA_SPAN && i < size; i += 256) {
            if(((addr + i) % (64 * 1024)) == 0) flash_eraseBlock64(addr + i); // erase 64 KiB
//            flash_eraseSector(addr + i); // erase 256 bytes
            // write 256 bytes
            flash_writeSector(addr + i, data + i);
        }
        ctrl[2] = 0;
        for(int i = 0; i < FLASH_DATA_SPAN && i < size; i++) {
            if(flash_readByte(addr + i) != data[i]) {
                printf("%x: %x != %x\n", addr + i, flash_readByte(addr + i), data[i]);
                ctrl[2] += 1;
            }
        }

        alt_u32 ts_bin = hibit(alt_timestamp() / 125);
        if(ts_bin < 16) hist_ts[ts_bin]++;
        if(state == -EAGAIN) return 1;
        if(state == 0) {
            IOWR(ctrl, 0, 0);
            IOWR(ctrl, 1, 0);
        }

        return 10;
    }

    static
    alt_u32 callback(void* flash) {
        return ((flash_t*)flash)->callback();
    }

    void menu() {
        while (1) {
            printf("\n");
            printf("[flash] -------- menu --------\n");

            printf("\n");
            for(int i = 0; i <= 10; i++) {
                printf("%8u", 1 << i);
            } printf("\n");
            for(int i = 0; i <= 10; i++) {
                printf("%8u", hist_ts[i]);
            } printf("\n");

            printf("\n");
            printf("  [s] => status\n");
            printf("  [m] => manufacturer ID\n");
            printf("  [e] => erase test\n");
            printf("  [w] => write test\n");
            printf("  [r] => read test\n");
            printf("  [u] => unwritten blocks\n");
            printf("  [q] => exit\n");

            printf("Select entry ...\n");
            char cmd = wait_key();
            switch(cmd) {
            case 's':
                ReadStatusRegister();
                break;
            case 'm':
                ReadID();
                break;
            case 'e': {
                EraseTest();
                break;
            }
            case 'w': {
                WriteTest();
                break;
            }
            case 'r': {
                ReadTest();
                break;
            }
            case 'u': {
                UnwrittenBlocks();
                break;
            }

            case '?':
                wait_key();
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }
        }
    }

static void ReadStatusRegister(){
    printf("Status: %x\n", (uint32_t)IORD_ALTERA_AVALON_PIO_DATA(FLASH_STATUS_BASE));
}

static void ReadID(){
    printf("ID: %x\n", (uint32_t)flash_getManufacturerID());
}

static void UnwrittenBlocks(){
    int i;
    int start = -1;
for(i = 0; i < 0xc20cc0; i++){

    if(start == -1 && flash_readByte(i) == 0xFF)
        start = i;

    if(start != -1 && flash_readByte(i) != 0xFF){
        if(i - start > 128)
            printf("Block %x to %x\n", start, i-1);
        start = -1;
    }



}

}


static void ReadTest(void)
{
    int i;
    int offset = 0x0;

    for(i = 0; i < 256; i++)
        printf( "Normal read: Addr: %x: %x \n", i+offset, (int)flash_readByte(i+offset));


        printf( " Fast read: %x \n", (int)flash_readByteFast(i+offset));
        printf( " Dual read: %x \n", (int)flash_readByteDual(i+offset));
        printf( " Quad read: %x \n", (int)flash_readByteQuad(i+offset));
        printf( " DualIO read: %x \n", (int)flash_readByteDualIO(i+offset));
        printf( " QuadIO read: %x \n", (int)flash_readByteQuadIO(i+offset));
        printf( " QuadIOWord read: %x \n", (int)flash_readByteQuadIO(i+offset));

  /* Get the input string for exiting this test. */


  printf(".....Exiting FLASH Test.\n");
}


static void EraseTest(void)
{
    int i,j;
    int offset = 0x0;
    printf("Before\n");
    for(i = 0; i < 16; i++){
        for(j = 0; j < 16; j++){
            printf("%x ", flash_readByte(offset + i*16+j));
        }
        printf("\n");
    }
    flash_eraseChip();
    printf("After\n");
    for(i = 0; i < 16; i++){
        for(j = 0; j < 16; j++){
            printf("%x ", flash_readByte(offset + i*16+j));
        }
        printf("\n");
    }


  printf(".....Exiting FLASH Test.\n");

}

static void WriteTest(void)
{
    int i,j;
    int offset = 0x0;
    alt_u32 fifodata;
    int fwrite;

    printf("Before\n");
    for(i = 0; i < 16; i++){
        for(j = 0; j < 16; j++){
            printf("%x ", flash_readByte(offset + i*16+j));
        }
        printf("\n");
    }

    flash_eraseSector(offset);

    printf("After erase\n");
    for(i = 0; i < 16; i++){
        for(j = 0; j < 16; j++){
            printf("%x ", flash_readByte(offset + i*16+j));
        }
        printf("\n");
    }


    printf("Writing FIFO\n");
    bool togglebit = true;

    for(i =0; i < 256; i++){
        IOWR_ALTERA_AVALON_PIO_DATA(FLASH_FIFO_DATA_BASE, (togglebit << 8) | ((60+i)&0xFF));
        togglebit = ! togglebit;
    }
    printf("FIFO filled\n");

    printf("Writing FLASH\n");
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_WRITE_ENABLE,0));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE,CMDADDR(COMMAND_QUAD_PAGE_PROGRAM, offset));
    setstrobefifo();
    waitforbusy();
    waitforwip();
    printf("Done Writing FLASH\n");
    printf("After write\n");
    for(i = 0; i < 16; i++){
        for(j = 0; j < 16; j++){
            printf("%x ", flash_readByte(offset + i*16+j));
        }
        printf("\n");
    }


}

/* Set the strobe signal for initiating a flash SPI command*/
static void setstrobe(){
    IOWR_ALTERA_AVALON_PIO_DATA(CTRLBASE, STROBE_BIT);
}

static void setstrobecontinue(){
    IOWR_ALTERA_AVALON_PIO_DATA(CTRLBASE, STROBE_BIT|CONTINUE_BIT);
}

static void setstrobefifo(){
    IOWR_ALTERA_AVALON_PIO_DATA(CTRLBASE, STROBE_BIT|FIFO_BIT);
}



static void unsetstrobe(){
    IOWR_ALTERA_AVALON_PIO_DATA(CTRLBASE, 0x0);
}

static void strobe(){
    IOWR_ALTERA_AVALON_PIO_DATA(CTRLBASE, STROBE_BIT);
    IOWR_ALTERA_AVALON_PIO_DATA(CTRLBASE, 0x0);
}

static void waitforbusy(){
  alt_u8 flashstatus = 0x08;
  while(flashstatus & 0x88 ){
          flashstatus = IORD_ALTERA_AVALON_PIO_DATA(FLASH_STATUS_BASE);
  }
}

static void waitforwip(){
      unsetstrobe();
          IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_READ_STATUS_REGISTER1,0));
      setstrobecontinue();
          alt_u8 datafromflash = 0x1;
          while(datafromflash & 0x1){
                  datafromflash = IORD_ALTERA_AVALON_PIO_DATA(DATAOUTBASE);
          }
    unsetstrobe();
}

/* Get the manufacturer ID - should return 0x1F */
static alt_u8 flash_getManufacturerID(){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_JEDEC_ID,0));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    return IORD_ALTERA_AVALON_PIO_DATA(DATAOUTBASE);
}

/* Read a single byte from the flash memory */
static alt_u8 flash_readByte(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_READ_DATA,addr));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    return IORD_ALTERA_AVALON_PIO_DATA(DATAOUTBASE);
}

/* Read a single byte from the flash memory in fast mode*/
static alt_u8 flash_readByteFast(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_FAST_READ,addr));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    return IORD_ALTERA_AVALON_PIO_DATA(DATAOUTBASE);
}


/* Read a single byte from the flash memory using dual output mode*/
static alt_u8 flash_readByteDual(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_DUAL_OUTPUT_FAST_READ,addr));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    return IORD_ALTERA_AVALON_PIO_DATA(DATAOUTBASE);
}

/* Read a single byte from the flash memory using quad output mode*/
static alt_u8 flash_readByteQuad(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_QUAD_OUTPUT_FAST_READ,addr));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    return IORD_ALTERA_AVALON_PIO_DATA(DATAOUTBASE);
}


/* Read a single byte from the flash memory using dual io mode*/
static alt_u8 flash_readByteDualIO(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_DUAL_IO_FAST_READ,addr));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    return IORD_ALTERA_AVALON_PIO_DATA(DATAOUTBASE);
}

/* Read a single byte from the flash memory using quad io mode*/
static alt_u8 flash_readByteQuadIO(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_QUAD_IO_FAST_READ,addr));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    return IORD_ALTERA_AVALON_PIO_DATA(DATAOUTBASE);
}

/* Read a single byte from the flash memory using quad io word mode*/
static alt_u8 flash_readByteQuadIOWord(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_QUAD_IO_WORD_FAST_READ,addr));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    return IORD_ALTERA_AVALON_PIO_DATA(DATAOUTBASE);
}

/* Write a single byte to the flash memory */
static void flash_writeByte(alt_u32 addr, alt_u8 byte){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_WRITE_ENABLE,0));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_PAGE_PROGRAM,addr));
    IOWR_ALTERA_AVALON_PIO_DATA(DATAINBASE, byte);
    setstrobe();
    waitforbusy();
    waitforwip();
    unsetstrobe();
    return;
}

/* Erase a sector */
static void flash_eraseSector(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_WRITE_ENABLE,0));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_SECTOR_ERASE,addr));
    setstrobe();
    waitforbusy();
    waitforwip();
    unsetstrobe();
    return;
}

/* Erase a 32K block */
static void flash_eraseBlock32(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_WRITE_ENABLE,0));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_BLOCK_ERASE_32,addr));
    setstrobe();
    waitforbusy();
    waitforwip();
    unsetstrobe();
    return;
}

/* Erase a 64K block */
static void flash_eraseBlock64(alt_u32 addr){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_WRITE_ENABLE,0));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_BLOCK_ERASE_64,addr));
    setstrobe();
    waitforbusy();
    waitforwip();
    unsetstrobe();
    return;
}

/*Erase the complete SPI flash */
static void flash_eraseChip(){
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_WRITE_ENABLE,0));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_CHIP_ERASE,0));
    setstrobe();
    waitforbusy();
    waitforwip();
    unsetstrobe();
    return;
}

/* Write a sector */
static void flash_writeSector(alt_u32 addr, volatile alt_u8 * data){
    int i;
    IOWR_ALTERA_AVALON_PIO_DATA(CTRLBASE, FIFO_CLEAR_BIT);
    for(i =0; i < 257; i++){};
    IOWR_ALTERA_AVALON_PIO_DATA(CTRLBASE, 0);

    bool togglebit = true;

    for(i =0; i < 256; i++){
        IOWR_ALTERA_AVALON_PIO_DATA(FLASH_FIFO_DATA_BASE, (togglebit << 8) | data[i]);
        togglebit = ! togglebit;
    }


    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE, CMDADDR(COMMAND_WRITE_ENABLE,0));
    setstrobe();
    waitforbusy();
    unsetstrobe();
    IOWR_ALTERA_AVALON_PIO_DATA(CMDADDRBASE,CMDADDR(COMMAND_QUAD_PAGE_PROGRAM, addr));
    setstrobefifo();
    waitforbusy();
    waitforwip();
    return;
}

};
