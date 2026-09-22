library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- for UNIFORM, TRUNC
use ieee.numeric_std.all; -- for TO_UNSIGNED
use ieee.std_logic_textio.all; -- for write std_logic_vector to line
library std;
use std.textio.all;             --FOR LOGFILE WRITING

use work.mutrig_hit_types.all;

entity testbench is
end entity;

architecture RTL of testbench is

    signal i_data : t_hit_presort;
    signal o_data : t_hit_presort;

    --system signals
    signal i_rst : std_logic:='0';
    signal i_clk : std_logic:='0';

begin

    -- basic stimulus for receiver
    i_clk <= not i_clk after  4 ns; -- 125 MHz system core clock
    i_rst <= '1' after 20 ns, '0' after 200 ns; -- Basic reset

    --dut
    dut : entity work.T_CC_adapt
    port map(
        i_clk   => i_clk,
        i_rst   => i_rst,
        i_data  => i_data,
        o_data  => o_data
    );

    p_stim : process
        variable seed1, seed2: positive;
        variable rand: real;
        variable j : integer:=0;
    begin
        seed1:=1483;
        seed2:=channel+1;
        wait until falling_edge ( i_rst );

        for i in 0 to 100 loop
           i_data.valid   <= '0';
           i_data.asic    <= (others => '0');
           i_data.channel <= (others => '0');
           i_data.T_fine  <= (others => '0');
           i_data.E_CC    <= (others => '0');

           --generate T & E data
           UNIFORM(seed2, seed1, rand);
           j := rand * 4095;
           i_A_data.T_CC<=std_logic_vector(to_unsigned(j,15));
           i_A_data.E_CC<=std_logic_vector(to_unsigned(j,15));


           --generate valid flag
           UNIFORM(seed1, seed2, rand);
           if( rand*1.5 > 0.5) then
               i_data(channel).valid <= '1';
           else
               i_data(channel).valid <= '0';
           end if;


           wait until rising_edge(i_clk);
        end loop;
        s_data.valid<='0';
        wait for 200 ns;
        assert false report "Simulation Finished." severity FAILURE;
    end process;

    ---------------------------------------------A side logger --------------------------------------------------------
    ---- prepocess logger
    --fifo_logging_A: process (i_clk)
    --file log_file : TEXT open write_mode is "preprocess_A_data.txt";
    --variable l : line;
    --begin
    --if rising_edge(i_rst) then
    --    -- write header
    --    write(l, string'("--------------------------------------------------"));
    --
    --elsif (rising_edge(i_clk) and i_data.valid='1') then
    --    flush(log_file);
    --end if;
    --end process;

end architecture;
