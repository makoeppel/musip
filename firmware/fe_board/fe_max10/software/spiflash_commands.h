/*
 * spiflash_commands.h
 *
 *  Created on: Aug 25, 2020
 *      Author: nberger
 */

#pragma once

#define COMMAND_WRITE_ENABLE               0x06
#define COMMAND_WRITE_DISABLE              0x04
#define COMMAND_READ_STATUS_REGISTER1      0x05
#define COMMAND_READ_STATUS_REGISTER2      0x35
#define COMMAND_READ_STATUS_REGISTER3      0x15
#define COMMAND_WRITE_ENABLE_VSR           0x50
#define COMMAND_WRITE_STATUS_REGISTER1     0x01
#define COMMAND_WRITE_STATUS_REGISTER2     0x31
#define COMMAND_WRITE_STATUS_REGISTER3     0x11
#define COMMAND_READ_DATA                  0x03
#define COMMAND_FAST_READ                  0x0B
#define COMMAND_DUAL_OUTPUT_FAST_READ      0x3B
#define COMMAND_DUAL_IO_FAST_READ          0xBB
#define COMMAND_QUAD_OUTPUT_FAST_READ      0x6B
#define COMMAND_QUAD_IO_FAST_READ          0xEB
#define COMMAND_QUAD_IO_WORD_FAST_READ     0xE7
#define COMMAND_PAGE_PROGRAM               0x02
#define COMMAND_QUAD_PAGE_PROGRAM          0x32
#define COMMAND_FAST_PAGE_PROGRAM          0xF2
#define COMMAND_SECTOR_ERASE               0x20
#define COMMAND_BLOCK_ERASE_32             0x52
#define COMMAND_BLOCK_ERASE_64             0xD8
#define COMMAND_CHIP_ERASE                 0xC7
#define COMMAND_ENABLE_RESET               0x66
#define COMMAND_RESET                      0x99
#define COMMAND_JEDEC_ID                   0x9F
#define COMMAND_ERASE_SECURITY_REGISTERS   0x44
#define COMMAND_PROG_SECURITY_REGISTERS    0x42
#define COMMAND_READ_SECURITY_REGISTERS    0x42
