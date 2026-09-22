# FEB_common false paths
# M. Mueller, September 2020

# CDC between nios clock and 156 clock
# - Max10 ADC
set_false_path -from e_fe_block|e_max10_interface|o_adc_reg* -to e_fe_block|e_reg_mapping|*
# - ArriaV temperature
set_false_path -from e_fe_block|arriaV_temperature* -to e_fe_block|e_reg_mapping|arriaV_temperature*
# - registers
set_false_path -from e_fe_block|e_max10_interface|max10_status* -to e_fe_block|e_max10_interface|o_max10_status*
set_false_path -from e_fe_block|e_max10_interface|max10_version* -to e_fe_block|e_max10_interface|o_max10_version*
set_false_path -from e_fe_block|e_max10_interface|* -to e_fe_block|e_max10_interface|o_programming_status*
# - single bits (prog.req. and fifo aclr)
set_false_path -from e_fe_block|e_reg_mapping|o_programming_ctrl* -to e_fe_block|e_max10_interface|*
# - addr and single bit (addr enable)
set_false_path -from e_fe_block|e_reg_mapping|o_programming_addr* -to e_fe_block|e_max10_interface|*

# single bit
set_false_path -from e_fe_block|firefly|e_lvds_controller|o_ready -to e_fe_block|e_reset_system|*

foreach e [ get_entity_instances -nowarn "firefly" ] {
    set to_regs [ get_registers -nocase "$e|*firefly_reg_mapping*|*" ]
    set from_regs [ get_registers -nocase "$e|*" ]
    set from_regs [ remove_from_collection $from_regs $to_regs ]
    set_false_path -from $from_regs -to $to_regs

    # [MM] this one is tricky, it's not really a false path
    # but i think we also cannot sync to recovered clock (we can, but might screw up reset alignment)
    set_false_path -from $e|e_lvds_controller|o_dpa_lock_reset -to $e|e_lvds_rx|*
}
