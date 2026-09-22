# add pio
nios_base.add_pio flash_ps_ctrl 32 Output 0x700F1600
nios_base.add_pio flash_w_cnt 32 Input 0x700F1640
nios_base.add_pio flash_cmd_addr 32 Output 0x700F1680
nios_base.add_pio flash_ctrl 8 Output 0x700F1720
nios_base.add_pio flash_status 8 Input 0x700F1760
nios_base.add_pio flash_o_data 8 Input 0x700F1800
nios_base.add_pio flash_i_data 8 Output 0x700F1840
nios_base.add_pio flash_fifo_data 9 Output 0x700F1880
