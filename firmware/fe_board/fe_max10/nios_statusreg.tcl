# add pio
nios_base.add_pio status 32 Input 0x700F2000
nios_base.add_pio programming_status 32 Input 0x700F2040
nios_base.add_pio crclocation 32 Input 0x700F2080
nios_base.add_pio programming_control 32 Output 0x700F20C0
nios_base.add_pio shutdown 32 Output 0x700F2100
nios_base.add_pio temperature 32 Input 0x700F2140
