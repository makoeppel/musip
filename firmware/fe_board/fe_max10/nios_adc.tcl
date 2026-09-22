#

add_instance adc altera_modular_adc
set_instance_parameter_value adc {use_tsd} {1}
# Conversion Sequence Length
set_instance_parameter_value adc {seq_order_length} {10}
# Conversion Sequence Channels
set_instance_parameter_value adc {seq_order_slot_1} {0}
set_instance_parameter_value adc {seq_order_slot_2} {1}
set_instance_parameter_value adc {seq_order_slot_3} {2}
set_instance_parameter_value adc {seq_order_slot_4} {3}
set_instance_parameter_value adc {seq_order_slot_5} {4}
set_instance_parameter_value adc {seq_order_slot_6} {5}
set_instance_parameter_value adc {seq_order_slot_7} {6}
set_instance_parameter_value adc {seq_order_slot_8} {7}
set_instance_parameter_value adc {seq_order_slot_9} {8}
set_instance_parameter_value adc {seq_order_slot_10} {17}
# set channels
set_instance_parameter_value adc {use_ch0} {1}
set_instance_parameter_value adc {use_ch1} {1}
set_instance_parameter_value adc {use_ch2} {1}
set_instance_parameter_value adc {use_ch3} {1}
set_instance_parameter_value adc {use_ch4} {1}
set_instance_parameter_value adc {use_ch5} {1}
set_instance_parameter_value adc {use_ch6} {1}
set_instance_parameter_value adc {use_ch7} {1}
set_instance_parameter_value adc {use_ch8} {1}
set_instance_parameter_value adc {use_tsd} {1}


set_interface_property adc_pll_clock EXPORT_OF adc.adc_pll_clock
set_interface_property adc_pll_locked EXPORT_OF adc.adc_pll_locked



nios_base.connect adc clock reset_sink sequencer_csr 0x700F0380
nios_base.connect adc ""    ""         sample_store_csr 0x700F0400

nios_base.connect_irq adc.sample_store_irq 3

nios_base.add_pio adc_d0 32 Output 0x700F0880
nios_base.add_pio adc_d1 32 Output 0x700F0920
nios_base.add_pio adc_d2 32 Output 0x700F0960
nios_base.add_pio adc_d3 32 Output 0x700F0A00
nios_base.add_pio adc_d4 32 Output 0x700F0A40
