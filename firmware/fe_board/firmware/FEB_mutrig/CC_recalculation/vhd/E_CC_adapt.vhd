---------------------------------------
--
-- Perform energy extraction from PRBS-decoded timestamps
-- E-T calculation ; rescaling and offset ; cutoff
-- Latency two clock cycles.
-- Konrad Briggl 12/23
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;
LIBRARY lpm;
USE lpm.all;

use work.mutrig_hit_types.all;


entity E_CC_adapt is
port (
    --config
    i_cfg_scale   : in  std_logic_vector( 3 downto 0) := X"0";
    i_cfg_offset  : in  std_logic_vector(14 downto 0) := "000" & X"000";

    --data stream
    i_data      : in    t_hit_presort;
    o_data      : out   t_hit_presort;

    --system
    i_rst       : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;




architecture impl of E_CC_adapt is

signal s_d0 : unsigned (14 downto 0);
signal s_d1 : unsigned (14 downto 0);
signal s_d2 : unsigned (14 downto 0);
signal s_d3 : unsigned (14 downto 0);
signal s_isneg : std_logic;
signal pipe : t_v_hit_presort (0 to 4);
begin
    p_pipeline : process(i_clk)
    begin
        if rising_edge(i_clk) then
            -- 0 : Build difference
            pipe(0) <= i_data;
            s_d0 <=  unsigned(i_data.E_CC) - unsigned(i_data.T_CC);

            if (i_data.E_CC < i_data.T_CC) then
                s_isneg <= '1';
            else
                s_isneg <= '0';
            end if;

            -- 1 : Lapse correction
            pipe(1) <= pipe(0);
            s_d1 <= s_d0;
            if s_isneg = '1' then
                s_d1 <= s_d0 - 1; --TODO check if this is correct, could be implemented to take one less clock cycle
            end if;

            -- 2 : Offset
            pipe(2) <= pipe(1);
            s_d2 <= s_d1 - to_integer(unsigned(i_cfg_offset));
            if (s_d1 < to_integer(unsigned(i_cfg_offset))) then
                s_d2 <= to_unsigned(0,s_d2'length);
            end if;
            
            -- 3 : Rescaling
            pipe(3) <= pipe(2);
            s_d3 <= shift_right(s_d2,to_integer(unsigned(i_cfg_scale)));

            -- 4 : Treat overflow
            pipe(4) <= pipe(3);
            pipe(4).E_CC <= std_logic_vector(s_d3);
            if ( s_d3 > x"1ff" ) then
                pipe(4).E_CC <= "000" & x"1ff";
            end if;
         end if;
    end process;

    o_data <= pipe(4);

end architecture;

