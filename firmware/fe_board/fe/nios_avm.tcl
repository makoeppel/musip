#

nios_base.add_clock_source clk_156 156250000 -clock_export clk_156_clock -reset_export clk_156_reset
nios_base.add_clock_source clk_125 125000000 -clock_export clk_125_clock -reset_export clk_125_reset

nios_base.add_irq_bridge irq_bridge 4 -clk clk_156

nios_base.export_avm avm_mscb 4 0x70030000 -readLatency 1 -clk clk_156
nios_base.export_avm avm_sc 16 0x70080000 -readLatency 1 -clk clk_156

nios_base.export_avm avm_qsfp 14 0x70010000 -clk clk_156
nios_base.export_avm avm_pod 14 0x70020000 -clk clk_125
