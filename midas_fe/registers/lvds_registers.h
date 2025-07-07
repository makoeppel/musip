/************************************************
 * Register map header file
 * Automatically generated from
 * /Users/mariuskoppel/mu3e/online/common/libmudaq/../../common/firmware/registers/lvds_registers.vhd
 * On 2025-07-07T10:27:21.071619
 ************************************************/

#ifndef LVDS_REGISTERS__H
#define LVDS_REGISTERS__H

#define LVDS_STATUS_REGISTER_R 0x4101
#define LVDS_STATUS_START_REGISTER_W 0x1100
#define LVDS_STATUS_PLL_LOCKED_BIT 31
#define GET_LVDS_STATUS_PLL_LOCKED_BIT(REG) ((REG >> 31) & 0x1)
#define SET_LVDS_STATUS_PLL_LOCKED_BIT(REG) ((1 << 31) | REG)
#define UNSET_LVDS_STATUS_PLL_LOCKED_BIT(REG) ((~(1 << 31)) & REG)
#define LVDS_STATUS_READY_BIT 30
#define GET_LVDS_STATUS_READY_BIT(REG) ((REG >> 30) & 0x1)
#define SET_LVDS_STATUS_READY_BIT(REG) ((1 << 30) | REG)
#define UNSET_LVDS_STATUS_READY_BIT(REG) ((~(1 << 30)) & REG)
#define LVDS_STATUS_DPA_LOCKED_BIT 29
#define GET_LVDS_STATUS_DPA_LOCKED_BIT(REG) ((REG >> 29) & 0x1)
#define SET_LVDS_STATUS_DPA_LOCKED_BIT(REG) ((1 << 29) | REG)
#define UNSET_LVDS_STATUS_DPA_LOCKED_BIT(REG) ((~(1 << 29)) & REG)
#define LVDS_STATUS_ALIGN_CNT_RANGE_HI 27
#define LVDS_STATUS_ALIGN_CNT_RANGE_LOW 22
#define GET_LVDS_STATUS_ALIGN_CNT_RANGE(REG) ((REG >> 22) & 0x3f)
#define SET_LVDS_STATUS_ALIGN_CNT_RANGE(REG, VAL) ((REG & (~(0x3f << 22))) | ((VAL & 0x3f) << 22))
#define LVDS_STATUS_ARRIVAL_PHASE_RANGE_HI 21
#define LVDS_STATUS_ARRIVAL_PHASE_RANGE_LOW 20
#define GET_LVDS_STATUS_ARRIVAL_PHASE_RANGE(REG) ((REG >> 20) & 0x3)
#define SET_LVDS_STATUS_ARRIVAL_PHASE_RANGE(REG, VAL) ((REG & (~(0x3 << 20))) | ((VAL & 0x3) << 20))
#define LVDS_STATUS_OUTOF_PHASE_RANGE_HI 15
#define LVDS_STATUS_OUTOF_PHASE_RANGE_LOW 0
#define GET_LVDS_STATUS_OUTOF_PHASE_RANGE(REG) ((REG >> 0) & 0xffff)
#define SET_LVDS_STATUS_OUTOF_PHASE_RANGE(REG, VAL) \
    ((REG & (~(0xffff << 0))) | ((VAL & 0xffff) << 0))

#endif  // #ifndef LVDS_REGISTERS__H
