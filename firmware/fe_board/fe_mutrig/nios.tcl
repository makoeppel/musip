#
source {device.tcl}
source {../fe/util/nios_base.tcl}
set_instance_parameter_value ram {memorySize} {0x0001F000}
set_instance_parameter_value spi numberOfSlaves 16
set_instance_parameter_value spi targetClockRate 128000
set_instance_parameter_value spi clockPolarity 0
set_instance_parameter_value spi clockPhase 0

source {../fe/nios_avm.tcl}
source {../fe/nios_spi_si.tcl}
source {../fe/nios_tmp.tcl}
source {../fe/nios_uart485.tcl}
