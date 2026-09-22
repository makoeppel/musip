library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- for UNIFORM, TRUNC
use ieee.numeric_std.all; -- for TO_UNSIGNED
use ieee.std_logic_textio.all; -- for write std_logic_vector to line
library std;
use std.textio.all;             --FOR LOGFILE WRITING

library modelsim_lib;
use modelsim_lib.util.all;

use work.mutrig_hit_types.all;

entity testbench is
end entity;

architecture RTL of testbench is
--dut definition

constant N : natural := 4;

    signal i_clk : std_logic :='0';
    signal i_rst : std_logic :='0';

    signal i_data : t_v_hit_presort(N-1 downto 0);
    signal o_data : t_hit_presort;

    signal tb_valid : std_logic_vector(N-1 downto 0);
    type v_real is array (integer range <>) of real;
    signal tb_rate : v_real(N-1 downto 0);

begin

    -- basic stimulus for receiver
    i_clk <= not i_clk after  4 ns;
    i_rst <= '1' after 24 ns, '0' after 240 ns;

    -- entity to test
    u_mux : entity work.channelmux
    generic map (NPORTS => N)
    port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_data => i_data,
        o_data => o_data
    );

    g_valid : for channel in i_data'range generate
        tb_valid(channel) <= i_data(channel).valid;
    end generate;

    g_stim : for channel in i_data'range generate
        p_stim : process
            variable seed1, seed2: positive;
            -- Random real-number value in range 0 to 1.0
            variable rand: real;
            variable rrate : real;
            -- Random integer value in range 0=> 4095
            variable j : integer:=0;
        begin
            seed1:=1483;
            seed2:=channel+1;
            wait until falling_edge ( i_rst );

            for rate in 1 to 100 loop
             tb_rate(channel) <= real(rate);
             for i in 0 to 100 loop
                i_data(channel).valid   <= '0';
                i_data(channel).asic    <= (others => '0');
                i_data(channel).channel <= (others => '0');
                i_data(channel).T_CC    <= std_logic_vector(to_unsigned(channel,o_data.T_CC'length));
                i_data(channel).E_CC    <= (others => '0');
                UNIFORM(seed1, seed2, rand);
                if( rand*real(rate) > 0.5) then
                    i_data(channel).valid <= '1';
                    i_data(channel).E_CC <= std_logic_vector(to_unsigned(j,o_data.E_CC'length));
                    j := j+1;
                else
                    i_data(channel).valid <= '0';
                end if;
                wait until rising_edge(i_clk);
                i_data(channel).valid <= '0';
                wait until rising_edge(i_clk);
                wait until rising_edge(i_clk);
                wait until rising_edge(i_clk);
             end loop;
            end loop;
        end process;
    end generate;

end architecture;
