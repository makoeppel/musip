--

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
    signal i_data_d1 : t_hit_presort;
    signal i_data_d2 : t_hit_presort;
    signal i_data_d3 : t_hit_presort;
    signal i_data_d4 : t_hit_presort;
    signal i_data_d5 : t_hit_presort;
    signal energy    : integer;
    signal energy_d1 : integer;
    signal energy_d2 : integer;
    signal energy_d3 : integer;
    signal energy_d4 : integer;
    signal energy_d5 : integer;
   signal o_data    : t_hit_presort;

    --system signals
    signal i_rst : std_logic:='0';
    signal i_clk : std_logic:='0';

    constant CC_RANGE : integer := 32767;
begin

    -- basic stimulus for receiver
    i_clk <= not i_clk after  4 ns; -- 125 MHz system core clock
    i_rst <= '1' after 20 ns, '0' after 30 ns; -- Basic reset

    --dut
    dut : entity work.E_CC_adapt
    port map(
        i_clk   => i_clk,
        i_rst   => i_rst,
        i_data  => i_data,
        o_data  => o_data
    );

    p_align : process(i_clk)
    begin
    if rising_edge(i_clk) then
        i_data_d1 <= i_data;
        i_data_d2 <= i_data_d1;
        i_data_d3 <= i_data_d2;
        i_data_d4 <= i_data_d3;
        i_data_d5 <= i_data_d4;
        energy_d1 <= energy;
        energy_d2 <= energy_d1;
        energy_d3 <= energy_d2;
        energy_d4 <= energy_d3;
        energy_d5 <= energy_d4;
    end if ;
    end process;

    p_stim : process
        variable seed1, seed2: positive;
        variable rand: real;
        variable j : integer:=0;
        variable e : integer:=0;
        variable channel : integer:=0;
    begin
        seed1:=1483;
        seed2:=1234;
        wait until falling_edge ( i_rst );

        for i in 0 to 1000000 loop
           i_data.valid   <= '0';
           i_data.asic    <= (others => '0');
           i_data.channel <= (others => '0');
           i_data.T_fine  <= (others => '0');
           i_data.E_CC    <= (others => '0');

           --generate T & E data
           UNIFORM(seed2, seed1, rand);
           j := integer(rand * real(35000));
           e := integer(rand * real(520)); --minimal amount of overflows
           i_data.T_CC<=std_logic_vector(to_unsigned((j) mod CC_RANGE,15));
           i_data.E_CC<=std_logic_vector(to_unsigned((j+e) mod CC_RANGE,15));
           channel := to_integer(unsigned(i_data.channel));
           energy <= e;

           --generate valid flag
           UNIFORM(seed1, seed2, rand);
           if( rand*1.5 > 0.5) then
               i_data.valid <= '1';
           else
               i_data.valid <= '0';
           end if;


           wait until rising_edge(i_clk);
        end loop;
        i_data.valid<='0';
        wait for 200 ns;
        assert false report "Simulation Finished." severity FAILURE;
    end process;

    ---------------------------------------------A side logger --------------------------------------------------------
    -- prepocess logger
    fifo_logging_A: process (i_clk)
        file log_file_in  : TEXT open write_mode is "E_data_in.txt";
        file log_file_out : TEXT open write_mode is "E_data_out.txt";
        variable l : line;
    begin
    if rising_edge(i_rst) then
        -- write header
        write(log_file_in, string'("TCC ECC Energy------------------------------------" & LF));
        write(log_file_out, string'("TCC_i ECC_i Energy_i TCC_o ECC_o ----------------" & LF));
    elsif (rising_edge(i_clk)) then
        if(i_data.valid='1') then
            write(log_file_in,
                     natural'image(to_integer(unsigned(i_data.T_CC))) &
                HT & natural'image(to_integer(unsigned(i_data.E_CC))) &
                HT & natural'image(energy) &
                LF);
        end if;
        if(o_data.valid='1') then
            write(log_file_out,
                     natural'image(to_integer(unsigned(i_data_d5.T_CC))) &
                HT & natural'image(to_integer(unsigned(i_data_d5.E_CC))) &
                HT & natural'image(energy_d5) &
                HT & natural'image(to_integer(unsigned(o_data.T_CC))) &
                HT & natural'image(to_integer(unsigned(o_data.E_CC))) &
                LF);
        end if;
    end if;
    end process;

end architecture;
