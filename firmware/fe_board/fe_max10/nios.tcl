#

source {device.tcl}

source "util/nios_base.tcl"
set_instance_parameter_value ram {memorySize} {0x00008000}
source "nios_ava_mm.tcl"

source "nios_ufm.tcl"

source "nios_spiflash.tcl"
source "nios_statusreg.tcl"
