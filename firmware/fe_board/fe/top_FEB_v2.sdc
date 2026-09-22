#

# global clock constrains for feb_v2
# M. Mueller, September 2020



# create clocks
# NOTE : add small fractions to clock frequencies
#        to make timing analyzer warn on domain transitions
create_clock -period  "50.001 MHz" [ get_ports spare_clk_osc ]
create_clock -period  "50.002 MHz" [ get_ports systemclock_bottom ]
create_clock -period  "50.003 MHz" [ get_ports systemclock ]
create_clock -period "125.001 MHz" [ get_ports clk_125_top ]
create_clock -period "125.002 MHz" [ get_ports clk_125_bottom ]
create_clock -period "125.003 MHz" [ get_ports LVDS_clk_si1_fpga_A ]
create_clock -period "125.004 MHz" [ get_ports LVDS_clk_si1_fpga_B ]
create_clock -period "125.005 MHz" [ get_ports lvds_firefly_clk ]
create_clock -period "156.251 MHz" [ get_ports transceiver_pll_clock[0] ]
create_clock -period "156.252 MHz" [ get_ports transceiver_pll_clock[1] ]
create_clock -period "156.253 MHz" [ get_ports transceiver_pll_clock[2] ]

# derive pll clocks from base clocks
derive_pll_clocks -create_base_clocks
derive_clock_uncertainty



# SPI Input/Output delays max10 spi

set_input_delay -clock { spare_clk_osc } -min 2.0 [get_ports {max10_spi_mosi}]
set_input_delay -clock { spare_clk_osc } -min 2.0 [get_ports {max10_spi_miso}]
set_input_delay -clock { spare_clk_osc } -min 2.0 [get_ports {max10_spi_D1}]
set_input_delay -clock { spare_clk_osc } -min 2.0 [get_ports {max10_spi_D2}]

set_input_delay -clock { spare_clk_osc } -max 3.0 [get_ports {max10_spi_mosi}]
set_input_delay -clock { spare_clk_osc } -max 3.0 [get_ports {max10_spi_miso}]
set_input_delay -clock { spare_clk_osc } -max 3.0 [get_ports {max10_spi_D1}]
set_input_delay -clock { spare_clk_osc } -max 3.0 [get_ports {max10_spi_D2}]

set_output_delay -clock { spare_clk_osc } -min 0.5 [get_ports {max10_spi_sclk}]
set_output_delay -clock { spare_clk_osc } -min 0.5 [get_ports {max10_spi_mosi}]
set_output_delay -clock { spare_clk_osc } -min 0.5 [get_ports {max10_spi_miso}]
set_output_delay -clock { spare_clk_osc } -min 0.5 [get_ports {max10_spi_D1}]
set_output_delay -clock { spare_clk_osc } -min 0.5 [get_ports {max10_spi_D2}]
set_output_delay -clock { spare_clk_osc } -min 0.5 [get_ports {max10_spi_D3}]
set_output_delay -clock { spare_clk_osc } -min 0.5 [get_ports {max10_spi_csn}]

set_output_delay -clock { spare_clk_osc } -max 0.0 [get_ports {max10_spi_sclk}]
set_output_delay -clock { spare_clk_osc } -max 0.0 [get_ports {max10_spi_mosi}]
set_output_delay -clock { spare_clk_osc } -max 0.0 [get_ports {max10_spi_miso}]
set_output_delay -clock { spare_clk_osc } -max 0.0 [get_ports {max10_spi_D1}]
set_output_delay -clock { spare_clk_osc } -max 0.0 [get_ports {max10_spi_D2}]
set_output_delay -clock { spare_clk_osc } -max 0.0 [get_ports {max10_spi_D3}]
set_output_delay -clock { spare_clk_osc } -max 0.0 [get_ports {max10_spi_csn}]
