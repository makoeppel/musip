#

# pin ~ALTERA_CLKUSR~ is reserved for calibration at location AV26
# and must be assigned a 100-125 MHz clock
create_clock -period  "100 MHz" [get_ports CLKUSR_100]

create_clock -period  "50.001 MHz" [get_ports CLK_50_B2J]
create_clock -period "125.002 MHz" [get_ports SMA_CLKIN]
create_clock -period "100.003 MHz" [get_ports PCIE_REFCLK_p]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty
