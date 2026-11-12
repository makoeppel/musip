#

source {device.tcl}

source {util/nios_base.tcl}
set_instance_parameter_value ram {memorySize} {0x00010000}
set_instance_parameter_value spi numberOfSlaves 16

source {../fe/nios_avm.tcl}
source {../fe/nios_spi_si.tcl}
source {../fe/nios_tmp.tcl}
#source {../fe/nios_uart485.tcl}

