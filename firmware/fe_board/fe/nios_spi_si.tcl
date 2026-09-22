#

add_instance spi_si altera_avalon_spi
nios_base.connect spi_si clk reset spi_control_port 0x700F0260
set_instance_parameter_value spi_si numberOfSlaves 2

nios_base.connect_irq spi_si.irq 8

add_interface spi_si conduit end
set_interface_property spi_si EXPORT_OF spi_si.external
