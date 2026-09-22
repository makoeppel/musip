library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- for UNIFORM, TRUNC
use ieee.numeric_std.all; -- for TO_UNSIGNED
use ieee.std_logic_textio.all; -- for write std_logic_vector to line
library std;
use std.textio.all; -- FOR LOGFILE WRITING

use work.mutrig_hit_types.all;

entity testbench is
end entity;

architecture RTL of testbench is

    signal i_data    : t_hit_presort;
    signal o_data    : t_hit_presort;

    --system signals
    signal i_rst : std_logic:='0';
    signal i_clk_125, i_clk_625 : std_logic:='0';

    signal upper, lower, delay: std_logic_vector(14 downto 0);

    signal ts_hit_A, ts_hit_B : natural;
    signal ts_send_A, ts_send_B : natural;
    signal ts_hit_A_long, ts_hit_B_long : natural;


    signal i_data_d1, i_data_d2, i_data_d3, i_data_d4 : t_hit_presort;
    signal o_data_d1 : t_hit_presort;


    signal var_t_global: integer := 0;
    signal var_t_in, var_t_in_d1: integer := 0;

    signal latency_system: natural := 1000;
begin
    --dut
    dut : entity work.lapse_counter
    port map(
        i_clk   => i_clk_125,
        i_reset   => i_rst,

        i_enable => '1',
        i_lower_bnd => lower,
        i_upper_bnd => upper,
        i_delay => delay,

        i_data  => i_data,
        o_data  => o_data
    );

    -- basic stimulus for receiver
    i_clk_625 <= not i_clk_625 after  1 ns; -- 625 MHz clock
    i_clk_125 <= not i_clk_125 after  5 ns; -- 125 MHz system core clock
    i_rst <= '1' after 20 ns, '0' after 30 ns; -- Basic reset

    upper   <= std_logic_vector(to_unsigned(32767-10240-400,15));
    lower   <= std_logic_vector(to_unsigned(10240+400,15));
    delay   <= std_logic_vector(to_unsigned(900,15));

    p_time : process(i_clk_625, i_rst)
    begin
        if rising_edge(i_rst) then
            var_t_global <= 0-latency_system;
        elsif (rising_edge(i_clk_625)) then
            var_t_global <= var_t_global + 1;
        end if;
    end process;

    p_align : process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
        i_data_d1 <= i_data;
        i_data_d2 <= i_data_d1;
        i_data_d3 <= i_data_d2;
        i_data_d4 <= i_data_d3;

        o_data_d1 <= o_data;
    end if ;
    end process;

    p_stim : process
        variable seed1, seed2: positive;
        variable rand: real;
        variable j : integer:=0;

        variable latency_asic   : natural := 10240; -- 10240;

        variable var_t_diff: integer;
    begin
        seed1:=1483;
        seed2:=1234;
        i_data.T_CC     <=std_logic_vector(to_unsigned((0),15));
        i_data.valid    <= '0';
        var_t_in <= 0;
        var_t_in_d1 <= 0;

        wait until falling_edge ( i_rst );

        for i in 0 to  INTEGER'high loop

            if(var_t_global > 1+latency_system) then
                if((var_t_global-(var_t_global mod 5)) mod 12500 = 100) then
                    ts_hit_A <= (var_t_global mod 32767) + 1;
                    ts_hit_A_long <= var_t_global + 1;
                    UNIFORM(seed2, seed1, rand);
                    ts_send_A <= var_t_global + 1 + integer(rand * real(latency_asic));

                elsif((var_t_global-(var_t_global mod 5)) mod 12500 = 6350) then
                    ts_hit_B <= (var_t_global mod 32767) + 1;
                    ts_hit_B_long <= var_t_global + 1;
                    UNIFORM(seed2, seed1, rand);
                    ts_send_B <= var_t_global + 1 + integer(rand * real(latency_asic));
                end if;
                if(ts_send_B = ts_send_A) then
                    ts_send_B <= ts_send_B+30;
                end if;
            end if;


            --set outputs
            if(var_t_global > ts_send_A and var_t_global < ts_send_A+5) then
                i_data.T_CC     <=std_logic_vector(to_unsigned((ts_hit_A),15));
                i_data.valid    <= '1';
                var_t_in <= ((ts_hit_A_long -13)  mod 20480);
                var_t_in_d1 <= var_t_in;
            elsif(var_t_global > ts_send_B and var_t_global < ts_send_B+5) then
                i_data.T_CC     <=std_logic_vector(to_unsigned((ts_hit_B),15));
                i_data.valid    <= '1';
                var_t_in <= ((ts_hit_B_long -13)  mod 20480);
                var_t_in_d1 <= var_t_in;
            else
                i_data.valid    <= '0';
            end if;

            i_data.asic    <= (others => '0');
            i_data.channel <= (others => '0');
            i_data.E_CC    <= (others => '0');




           wait until rising_edge(i_clk_125);
        end loop;
        i_data.valid<='0';
        wait for 200 ns;
        assert false report "Simulation Finished." severity FAILURE;
    end process;

    ---------------------------------------------A side logger --------------------------------------------------------
    -- prepocess logger
    fifo_logging_A: process (i_clk_125, i_rst)
        file log_file_in  : TEXT open write_mode is "data_in.txt";
        file log_file_out : TEXT open write_mode is "data_out.txt";
        variable l : line;
        variable skip_first_n : integer :=2;
    begin
    if rising_edge(i_rst) then
        -- write header
        write(log_file_in, string'("----HEADER IN--------------" & LF));
        write(log_file_out, string'(" TIN  T20 T20d1 T32in Tout ToutD1-------------" & LF));
    elsif (rising_edge(i_clk_125)) then
        if(i_data.valid='1') then
            write(log_file_in,
                    natural'image(to_integer(unsigned(i_data.T_CC))) &
--                HT & natural'image(to_integer(unsigned(i_data.E_CC))) &
--                HT & natural'image(energy) &
                LF);
        end if;
        if(o_data.valid='1' and skip_first_n = 0) then
            write(log_file_out,
                     integer'image(var_t_global) &
                HT & integer'image(var_t_in) &
                HT & integer'image(var_t_in_d1) &
                HT & natural'image(to_integer(unsigned(i_data_d2.T_CC))) &
                HT & natural'image(to_integer(unsigned(o_data.T_CC))) &
                HT & integer'image(to_integer(unsigned(o_data_d1.T_CC))) &
                HT & integer'image((var_t_in -var_t_in_d1+40960) mod 20480) &
                HT & integer'image((to_integer(unsigned(o_data.T_CC))- to_integer(unsigned(o_data_d1.T_CC))+40960)mod 20480) &
                HT & integer'image((var_t_in+12301) mod 20480) &
            LF);
        elsif(o_data.valid='1') then
            skip_first_n := skip_first_n -1;
        end if;
    end if;
    end process;

end architecture;
