-----------------------------------
--
-- On detector FPGA for layer 0/1
-- Hit multiplexer 3-1
-- Assume hits at maximum every third cycle
-- Niklaus Berger, Feb 2014
--
-- nberger@physi.uni-heidelberg.de
--
----------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity hit_multiplexer is
port (
    i_ts        : in    work.mupix.ts_array_t(2 downto 0);
    i_chip_id   : in    work.mupix.ch_id_array_t(2 downto 0);
    i_row       : in    work.mupix.row_array_t(2 downto 0);
    i_col       : in    work.mupix.col_array_t(2 downto 0);
    i_tot       : in    work.mupix.tot_array_t(2 downto 0);
    i_hit_ena   : in    std_logic_vector(2 downto 0);

    o_ts        : out   work.mupix.ts_array_t(0 downto 0);
    o_chip_id   : out   work.mupix.ch_id_array_t(0 downto 0);
    o_row       : out   work.mupix.row_array_t(0 downto 0);
    o_col       : out   work.mupix.col_array_t(0 downto 0);
    o_tot       : out   work.mupix.tot_array_t(0 downto 0);
    o_sel_chip  : out   std_logic_vector(1 downto 0);
    o_hit_ena   : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture RTL of hit_multiplexer is

    signal hit_in1          : std_logic_vector(38 downto 0);
    signal hit_ena1         : std_logic;
    signal hit_in2          : std_logic_vector(38 downto 0);
    signal hit_ena2         : std_logic;
    signal hit_in3          : std_logic_vector(38 downto 0);
    signal hit_ena3         : std_logic;
    signal hit_out          : std_logic_vector(38 downto 0);
    signal sel_chip_out     : std_logic_vector(1 downto 0);
    signal hit_ena          : std_logic;

    signal ena              : std_logic_vector(2 downto 0);
    signal ena_del1         : std_logic_vector(2 downto 0);
    signal ena_del2         : std_logic_vector(2 downto 0);

    signal ena_del1_nors    : std_logic_vector(2 downto 0);
    signal ena_del2_nors    : std_logic_vector(2 downto 0);

    signal hit1             : std_logic_vector(38 downto 0);
    signal hit2             : std_logic_vector(38 downto 0);
    signal hit3             : std_logic_vector(38 downto 0);

begin

    hit_in1     <= i_ts(0) & i_chip_id(0) & i_row(0) & i_col(0) & i_tot(0);
    hit_ena1    <= i_hit_ena(0);
    hit_in2     <= i_ts(1) & i_chip_id(1) & i_row(1) & i_col(1) & i_tot(1);
    hit_ena2    <= i_hit_ena(1);
    hit_in3     <= i_ts(2) & i_chip_id(2) & i_row(2) & i_col(2) & i_tot(2);
    hit_ena3    <= i_hit_ena(2);

    o_tot(0)    <= hit_out(5 downto 0);
    o_col(0)    <= hit_out(13 downto 6);
    o_row(0)    <= hit_out(21 downto 14);
    o_chip_id(0)<= hit_out(27 downto 22);
    o_ts(0)     <= hit_out(38 downto 28);
    o_sel_chip  <= sel_chip_out;
    o_hit_ena   <= hit_ena;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        hit_ena         <= '0';
        ena             <= (others => '0');
        ena_del1        <= (others => '0');
        ena_del2        <= (others => '0');
        ena_del1_nors   <= (others => '0');
        ena_del2_nors   <= (others => '0');
    elsif rising_edge(i_clk) then

        ena         <= ((hit_ena3 & hit_ena2 & hit_ena1) and (not ena)) and (not ena_del1_nors);
        ena_del1    <= ena;
        ena_del2    <= ena_del1;

        ena_del1_nors   <= ena;
        ena_del2_nors   <= ena_del1_nors;

        if(hit_ena1 = '1' and ena(0) = '0' and ena_del1_nors(0) = '0') then
            hit1    <= hit_in1;
        end if;

        if(hit_ena2 = '1' and ena(1) = '0' and ena_del1_nors(1) = '0') then
            hit2    <= hit_in2;
        end if;

        if(hit_ena3 = '1' and ena(2) = '0' and ena_del1_nors(2) = '0') then
            hit3    <= hit_in3;
        end if;

        if(ena_del2(0) = '1') then
            hit_out     <= hit1;
            sel_chip_out<= "00";
            hit_ena     <= '1';
        elsif (ena_del2(1) = '1') then
            hit_out     <= hit2;
            sel_chip_out<= "01";
            hit_ena     <= '1';
        elsif (ena_del2(2) = '1') then
            hit_out     <= hit3;
            sel_chip_out<= "10";
            hit_ena     <= '1';
        elsif(ena_del1(0) = '1') then
            hit_out     <= hit1;
            sel_chip_out<= "00";
            hit_ena     <= '1';
            ena_del2(0) <= '0';
        elsif (ena_del1(1) = '1') then
            hit_out     <= hit2;
            sel_chip_out<= "01";
            hit_ena     <= '1';
            ena_del2(1) <= '0';
        elsif (ena_del1(2) = '1') then
            hit_out     <= hit3;
            sel_chip_out<= "10";
            hit_ena     <= '1';
            ena_del2(2) <= '0';
        elsif(ena(0) = '1') then
            hit_out     <= hit1;
            sel_chip_out<= "00";
            hit_ena     <= '1';
            ena_del1(0) <= '0';
        elsif (ena(1) = '1') then
            hit_out     <= hit2;
            sel_chip_out<= "01";
            hit_ena     <= '1';
            ena_del1(1) <= '0';
        elsif (ena(2) = '1') then
            hit_out     <= hit3;
            sel_chip_out<= "10";
            hit_ena     <= '1';
            ena_del1(2) <= '0';
        else
            hit_ena     <= '0';
        end if;

    end if;
    end process;

end architecture;
