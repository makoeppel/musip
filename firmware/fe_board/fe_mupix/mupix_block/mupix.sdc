# MuPix FEB false paths

# [AK] TODO: rename to `mupix_datapath.sdc`

# [AK] TODO: use `get_entity_instances -nowarn "mupix_datapath"`
set dp "e_mupix_block|e_mupix_datapath"

# CDC from lvds_firefly_clk to transceiver_pll_clock[0]
# - sample registers (monitoring)
set_false_path -to $dp|mp_pll_lock_reg_mapping|arrival_time_distr156*
set_false_path -to $dp|unpacker_counters_156_reg*
set_false_path -to $dp|hitsorter_in_ena_counters_reg*
set_false_path -to $dp|hitsorter_out_ena_cnt_reg*
set_false_path -to $dp|lvds_block|o_rx_status*
set_false_path -from $dp|last_sorter_hit* -to $dp|e_mupix_datapath_reg_mapping|o_reg_rdata*
set_false_path -from $dp|e_sorter|* -to $dp|e_sorter|e_sorter_reg_mapping|*
set_false_path -from $dp|coarsecounter_diff_chip* -to $dp|e_sorter|e_sorter_reg_mapping|*
#
# CDC from transceiver_pll_clock[0] to lvds_firefly_clk
# - control values (set once)
set_false_path -from $dp|e_mupix_datapath_reg_mapping|o_mp_datagen_control*
set_false_path -from $dp|e_mupix_datapath_reg_mapping|o_lvds_link_mask*
set_false_path -from $dp|e_mupix_datapath_reg_mapping|o_mp_readout_mode*
set_false_path -from $dp|e_mupix_datapath_reg_mapping|o_mp_use_arrival_time*
set_false_path -from $dp|e_sorter|e_sorter_reg_mapping|o_sorter_delay*
#
# CDC from transceiver_pll_clock[0] to lvds pll clock
# - control bits (set once)
set_false_path -from $dp|e_mupix_datapath_reg_mapping|o_lvds_invert*
# [AK] TODO: select one that exist
set_false_path -from $dp|e_mupix_datapath_reg_mapping|o_lvds_reset_n

set_false_path -to $dp|lvds_block|o_rx_ready*
set_false_path -to $dp|lvds_status[*].*

set_false_path -to $dp|e_sc_readback_mem|o_slowctrl_empty*

# ADC registers
set_false_path -to $dp|e_sc_readback_mem_adc|slowctrl_data64_ena_last[*]
