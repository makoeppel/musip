#

set_false_path -to   [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|o_reg_rdata[*]}]
set_false_path -from [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|o_sorter_delay[*]}]
set_false_path -from [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|o_diagwidth[*]}]
# [AK] FIXME: there is no point in using ff_sync if all internal regs outputs are false_path'd
set_false_path -from [get_keepers {tile_path:e_tile_path|mutrig_reg_mapping:e_reg_mapping|ff_sync:e_out_sc_mutrig|ff[*][*]}]

#sorter counters. To be dealt with properly
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|noutoftime[*][*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|noverflow[*][*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|nintime[*][*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|nout[*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|credit[*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|nprewindow[*][*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|npastwindow[*][*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|hitsorter:sorter|sorter_reg_mapping:e_sorter_reg_mapping|noutdiag[*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|tile_receiver_block:u_rxdeser|o_rx_status[*].dpa_locked}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|tile_receiver_block:u_rxdeser|o_rx_status[*].dpa_locked}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|tile_receiver_block:u_rxdeser|o_rx_status[*].err8b10b[*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|tile_receiver_block:u_rxdeser|o_rx_status[*].disperr[*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|tile_receiver_block:u_rxdeser|o_rx_status[*].aligncnt[*]}]
set_false_path -to [get_keepers {tile_path:e_tile_path|tile_datapath:e_mutrig_datapath|tile_receiver_block:u_rxdeser|o_rx_ready[*]}]
