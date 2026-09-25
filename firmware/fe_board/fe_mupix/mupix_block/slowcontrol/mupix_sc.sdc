# MuPix slowcontrol false paths
# M. Mueller, December 2022

# CDC between (156 MHz) and (125 MHz divided by 8)

set mp_ctrl "e_mupix_block|e_mupix_ctrl"
set_false_path -from $mp_ctrl|clk_div_reset_n -to $mp_ctrl|clk_div_reset_125_n
set_false_path -from $mp_ctrl|e_mupix_ctrl_reg_mapping|o_mp_ctrl_spi_enable
set_false_path -from $mp_ctrl|e_mupix_ctrl_reg_mapping|o_mp_ctrl_direct_spi_enable

#create_generated_clock -name mp_ctrl_slow_clk -source [ get_pins $mp_ctrl|e_clkdiv|i_clk ] -divide_by 8 [ get_pins $mp_ctrl|e_clkdiv|o_clk ]

foreach mp_asm [ get_entity_instances -nowarn "mp_sc_command_assembler" ] {
    set_false_path -from $mp_asm|remove_dpf_empty_flag[*]   -to $mp_asm|dpf_empty_flag[*]
    set_false_path -from $mp_asm|read_dpf[*]                -to $mp_asm|read_dpf_prev[*]
    set_false_path -from $mp_asm|dpf_empty_flag[*]          -to $mp_asm|dpf_empty_flag_slow[*]
    set_false_path -from $mp_asm|i_data*                    -to $mp_asm|dpf_has_data_reg[*]
    set_false_path -from $mp_asm|i_data*                    -to $mp_asm|o_command[*]
}

# NB: Registers for ADC readback, need to do a clock transition which we hopefully handle safely
set_false_path -from {mupix_block:e_mupix_block|mupix_datapath:e_mupix_datapath|sc_readback_mem_adc:e_sc_readback_mem_adc|adcs[*][*][*]} -to {mupix_block:e_mupix_block|mupix_datapath:e_mupix_datapath|sc_readback_mem_adc:e_sc_readback_mem_adc|adcs156[*][*][*]}
