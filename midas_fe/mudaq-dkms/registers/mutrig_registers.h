/************************************************
 * Register map header file
 * Automatically generated from
 * /Users/mariuskoppel/mu3e/online/common/libmudaq/../../common/firmware/registers/mutrig_registers.vhd
 * On 2025-07-07T10:27:21.212795
 ************************************************/

#ifndef MUTRIG_REGISTERS__H
#define MUTRIG_REGISTERS__H

#define MUTRIG_CNT_ADDR_REGISTER_R 0x4100
#define MUTRIG_MON_STATUS_REGISTER_R 0x4500
#define MUTRIG_MON_TEMPERATURE_REGISTER_W 0x4501
#define MUTRIG_CNT_CTRL_REGISTER_W 0x4502
#define SECOND_SORTER_CNT_BIT 31
#define GET_SECOND_SORTER_CNT_BIT(REG) ((REG >> 31) & 0x1)
#define SET_SECOND_SORTER_CNT_BIT(REG) ((1 << 31) | REG)
#define UNSET_SECOND_SORTER_CNT_BIT(REG) ((~(1 << 31)) & REG)
#define MUTRIG_CTRL_DUMMY_REGISTER_W 0x4503
#define MUTRIG_CTRL_DP_REGISTER_W 0x4504
#define MUTRIG_CTRL_RESET_REGISTER_W 0x4505
#define MUTRIG_CTRL_RESETDELAY_REGISTER_W 0x4506
#define MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W 0x4507
#define MUTRIG_CTRL_LAPSE_DELAY_W 0x4508
#define MUTRIG_CTRL_ENERGY_REGISTER_W 0x4509

#endif  // #ifndef MUTRIG_REGISTERS__H
