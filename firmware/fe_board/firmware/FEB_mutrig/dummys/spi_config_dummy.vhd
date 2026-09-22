-- simulates stic spi register
-- Simon Corrodi, June 2017
-- corrodis@phys.ethz.ch

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity spi_config_dummy is
generic (
    N_BITS : integer:=2357; -- for MuTRiG1
    N_CLIENTS : integer:=1
);
port (
    i_MOSI          : in    std_logic;
    i_CSn           : in    std_logic_vector(N_CLIENTS-1 downto 0);
    i_SCLK          : in    std_logic;
    o_MISO          : out   std_logic;
    o_data_first    : out   std_logic_vector(31 downto 0);
    o_data_last     : out   std_logic_vector(31 downto 0)
);
end entity;

architecture arch of spi_config_dummy is

    signal shiftregister : std_logic_vector(N_BITS downto 0);

begin

    o_MISO <= shiftregister(0);
    o_data_first <= shiftregister(31 downto 0);
    o_data_last  <= shiftregister(N_BITS downto N_BITS-31);

    shift : process(i_SCLK)
    begin
    if rising_edge(i_SCLK) then
        if ( i_CSn /= (i_CSn'range => '1') ) then
            shiftregister <= i_MOSI & shiftregister(N_BITS downto 1);
        end if;
    end if;
    end process;

end architecture;
