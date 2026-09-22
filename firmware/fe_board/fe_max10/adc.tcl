source {device.tcl}

# Instances and instance parameters
# (disabled instances are intentionally culled)
add_instance modular_adc_0 altera_modular_adc
set_instance_parameter_value modular_adc_0 {CORE_VAR} {2}
set_instance_parameter_value modular_adc_0 {clkdiv} {2}
set_instance_parameter_value modular_adc_0 {external_vref} {2.5}
set_instance_parameter_value modular_adc_0 {ip_is_for_which_adc} {1}
set_instance_parameter_value modular_adc_0 {prescaler_ch8} {1}
set_instance_parameter_value modular_adc_0 {refsel} {0}
set_instance_parameter_value modular_adc_0 {sample_rate} {0}
set_instance_parameter_value modular_adc_0 {seq_order_length} {10}
set_instance_parameter_value modular_adc_0 {seq_order_slot_1} {0}
set_instance_parameter_value modular_adc_0 {seq_order_slot_10} {17}
set_instance_parameter_value modular_adc_0 {seq_order_slot_2} {1}
set_instance_parameter_value modular_adc_0 {seq_order_slot_3} {2}
set_instance_parameter_value modular_adc_0 {seq_order_slot_4} {3}
set_instance_parameter_value modular_adc_0 {seq_order_slot_5} {4}
set_instance_parameter_value modular_adc_0 {seq_order_slot_6} {5}
set_instance_parameter_value modular_adc_0 {seq_order_slot_7} {6}
set_instance_parameter_value modular_adc_0 {seq_order_slot_8} {7}
set_instance_parameter_value modular_adc_0 {seq_order_slot_9} {8}
set_instance_parameter_value modular_adc_0 {tsclksel} {1}
set_instance_parameter_value modular_adc_0 {tsd_max} {125}
set_instance_parameter_value modular_adc_0 {tsd_min} {0}
set_instance_parameter_value modular_adc_0 {use_ch0} {1}
set_instance_parameter_value modular_adc_0 {use_ch1} {1}
set_instance_parameter_value modular_adc_0 {use_ch2} {1}
set_instance_parameter_value modular_adc_0 {use_ch3} {1}
set_instance_parameter_value modular_adc_0 {use_ch4} {1}
set_instance_parameter_value modular_adc_0 {use_ch5} {1}
set_instance_parameter_value modular_adc_0 {use_ch6} {1}
set_instance_parameter_value modular_adc_0 {use_ch7} {1}
set_instance_parameter_value modular_adc_0 {use_ch8} {1}
set_instance_parameter_value modular_adc_0 {use_tsd} {1}

# exported interfaces
set_instance_property modular_adc_0 AUTO_EXPORT {true}

# interconnect requirements
set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
set_interconnect_requirement {$system} {qsys_mm.enableEccProtection} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.insertDefaultSlave} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}

