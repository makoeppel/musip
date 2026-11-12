#

nios_base.add_clock_source clk_spi [ expr int($nios_clk_mhz * 1e6) ] -reset_export rst_spi

set_instance_parameter_value ram {dualPort} {1}

# avalon MM translator
add_instance ava_mm altera_merlin_master_translator
set_instance_parameter_value ava_mm {AV_ADDRESS_W} {14}
set_instance_parameter_value ava_mm {AV_DATA_W} {32}
set_instance_parameter_value ava_mm {AV_BURSTCOUNT_W} {4}
set_instance_parameter_value ava_mm {AV_BYTEENABLE_W} {4}
set_instance_parameter_value ava_mm {UAV_ADDRESS_W} {38}
set_instance_parameter_value ava_mm {UAV_BURSTCOUNT_W} {10}
set_instance_parameter_value ava_mm {AV_READLATENCY} {0}
set_instance_parameter_value ava_mm {USE_READDATA} {1}
set_instance_parameter_value ava_mm {USE_WRITEDATA} {1}
set_instance_parameter_value ava_mm {USE_READ} {1}
set_instance_parameter_value ava_mm {USE_WRITE} {1}
set_instance_parameter_value ava_mm {USE_ADDRESS} {1}
set_instance_parameter_value ava_mm {AV_SYMBOLS_PER_WORD} {4}
set_instance_parameter_value ava_mm {USE_BYTEENABLE} {0}
set_instance_parameter_value ava_mm {USE_BURSTCOUNT} {0}
set_instance_parameter_value ava_mm {USE_READDATAVALID} {0}
set_instance_parameter_value ava_mm {USE_WAITREQUEST} {0}
set_interface_property ava_mm EXPORT_OF ava_mm.avalon_anti_master_0

add_connection clk_spi.clk ram.clk2
add_connection clk_spi.clk ava_mm.clk

add_connection clk_spi.clk_reset ram.reset2
add_connection clk_spi.clk_reset ava_mm.reset

add_connection                 ava_mm.avalon_universal_master_0 ram.s2
set_connection_parameter_value ava_mm.avalon_universal_master_0/ram.s2     baseAddress {0x20000000}
