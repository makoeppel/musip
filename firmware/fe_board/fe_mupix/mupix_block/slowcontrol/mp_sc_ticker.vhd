----------------------------------------------------------------------------
-- Mupix Slowcontrol ticker
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mupix.all;
use work.mudaq.all;
use work.mupix_registers.all;

entity mp_sc_ticker is
port (
    o_tick                  : out  std_logic := '0';

    i_enable                : in  std_logic := '0';
    i_reset_n               : in  std_logic := '0';
    i_clk                   : in  std_logic--; -- slow clock of the mu3e control
);
end entity;

architecture RTL of mp_sc_ticker is

    constant COUNTER_MAX       : positive := 67;
    signal counter             : integer range 0 to COUNTER_MAX;

begin

    process(i_clk, i_reset_n) is
    begin
    if ( i_reset_n = '0' ) then
        counter <= 0;
        o_tick  <= '0';

    elsif rising_edge(i_clk) then
        if(counter = COUNTER_MAX) then
            counter <= 0;
        else
            counter <= counter + 1;
        end if;
        o_tick  <= '0';

        if(counter = COUNTER_MAX) then
            if(i_enable = '1') then
                o_tick  <= '1';
            end if;
            counter <= 0;
        end if;
    end if;
    end process;

end architecture;
