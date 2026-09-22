#

# Create clocks
set_time_format -unit ns -decimal_places 3

create_clock -name {altera_reserved_tck} -period 100.000 -waveform {0.000 50.000} { altera_reserved_tck }
create_clock -name {max10_si_clk} -period 20.000 -waveform {0.000 10.000} { max10_si_clk }
create_clock -name {max10_osc_clk} -period 20.000 -waveform {0.000 10.000} { max10_osc_clk }

derive_clock_uncertainty
derive_pll_clocks

set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}]

# SPI Input/Output delays flash spi
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {flash_io0}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {flash_io1}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {flash_io2}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {flash_io3}]

set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {flash_io0}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {flash_io1}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {flash_io2}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {flash_io3}]

set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {flash_sck}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {flash_csn}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {flash_io0}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {flash_io1}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {flash_io2}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {flash_io3}]

set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {flash_sck}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {flash_csn}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {flash_io0}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {flash_io1}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {flash_io2}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {flash_io3}]

# SPI Input/Output delays arria spi
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {fpga_spi_clk}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {fpga_spi_D1}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {fpga_spi_D2}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {fpga_spi_D3}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {fpga_spi_csn}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {fpga_spi_mosi}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 2 [get_ports {fpga_spi_miso}]

set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {fpga_spi_clk}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {fpga_spi_D1}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {fpga_spi_D2}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {fpga_spi_D3}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {fpga_spi_csn}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {fpga_spi_mosi}]
set_input_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 3 [get_ports {fpga_spi_miso}]



set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {fpga_spi_mosi}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {fpga_spi_miso}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {fpga_spi_D1}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {fpga_spi_D2}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -min 1 [get_ports {fpga_spi_D3}]

set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {fpga_spi_mosi}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {fpga_spi_miso}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {fpga_spi_D1}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {fpga_spi_D2}]
set_output_delay -clock { e_pll|altpll_component|auto_generated|pll1|clk[1] } -max 0 [get_ports {fpga_spi_D3}]


# Set False Path
set_false_path -from [get_clocks {max10_si_clk}] -to [get_clocks {max10_osc_clk}]
set_false_path -from [get_clocks {max10_osc_clk}] -to [get_clocks {max10_si_clk}]

# Set Net Delay
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|eoc}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|eoc}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|clk_dft}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|clk_dft}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[0]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[1]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[2]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[3]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[4]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[5]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[6]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[7]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[8]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[9]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[10]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[11]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[0]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[1]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[2]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[3]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[4]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[5]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[6]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[7]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[8]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[9]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[10]}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|adc_inst|adcblock_instance|primitive_instance|dout[11]}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|u_control_fsm|chsel[*]|q}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|u_control_fsm|chsel[*]|q}]
set_net_delay -max 5.000 -from [get_pins -compatibility_mode {*|u_control_fsm|soc|q}]
set_net_delay -min 0.000 -from [get_pins -compatibility_mode {*|u_control_fsm|soc|q}]
