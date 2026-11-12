-- Convert gray code to a binary code
-- Sebastian Dittmeier
-- September 2017
-- dittmeier@physi.uni-heidelberg.de
-- based on code by Niklaus Berger
--
-- takes 3 clock cycles now to do the full thing


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity hit_ts_conversion is
port (
    i_invert_TS : in  std_logic;
    i_invert_TS2 : in  std_logic;
    i_gray_TS   : in  std_logic;
    i_gray_TS2  : in  std_logic;

    o_ts        : out std_logic_vector(10 downto 0);
    o_row       : out std_logic_vector(7 downto 0);
    o_col       : out std_logic_vector(7 downto 0);
    o_ts2       : out std_logic_vector(4 downto 0);
    o_hit_ena   : out std_logic;

    i_ts        : in  std_logic_vector(10 downto 0);
    i_row       : in  std_logic_vector(7 downto 0);
    i_col       : in  std_logic_vector(7 downto 0);
    i_ts2       : in  std_logic_vector(4 downto 0);
    i_hit_ena   : in  std_logic;

    i_reset_n   : in  std_logic;
    i_clk       : in  std_logic--;
);
end entity;

architecture rtl of hit_ts_conversion is

    constant MAX_SIZE : integer := 16;

    signal hit_in_TS        : std_logic_vector(MAX_SIZE-1 downto 0);
    signal hit_in_TS2       : std_logic_vector(MAX_SIZE-1 downto 0);
    signal hit_out_TS       : std_logic_vector(MAX_SIZE-1 downto 0);
    signal hit_out_TS2      : std_logic_vector(MAX_SIZE-1 downto 0);

    signal row_r1           : std_logic_vector(7 downto 0);
    signal row_r2           : std_logic_vector(7 downto 0);
    signal col_r1           : std_logic_vector(7 downto 0);
    signal col_r2           : std_logic_vector(7 downto 0);

    signal hit_ena_in_r1    : std_logic;
    signal hit_ena_in_r2    : std_logic;
    signal hit_in_TS_reg    : std_logic_vector(MAX_SIZE-1 downto 0);
    signal hit_in_TS2_reg   : std_logic_vector(MAX_SIZE-1 downto 0);

    signal ts_temp          : std_logic_vector(MAX_SIZE-1 downto 0);
    signal ts2_temp         : std_logic_vector(MAX_SIZE-1 downto 0);
    signal TS_SIZE          : integer range 0 to MAX_SIZE;
    signal TS2_SIZE         : integer range 0 to MAX_SIZE;

begin


    ------- Input selection ------------------
    input_chip: process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        TS_SIZE     <= 0;
        TS2_SIZE    <= 0;
        ts_temp     <= (others => '0');
        ts2_temp    <= (others => '0');

    elsif rising_edge(i_clk) then
        TS_SIZE     <= work.mupix.MUPIX_TIMESTAMPSIZE;
        TS2_SIZE    <= work.mupix.CHARGESIZE_MP10;
        ts_temp     <= (others => '0');
        ts2_temp    <= (others => '0');
        ts_temp(work.mupix.MUPIX_TIMESTAMPSIZE-1 downto 0)  <= i_ts;
        ts2_temp(work.mupix.CHARGESIZE_MP10-1 downto 0)    <= i_ts2;
    end if;
    end process;

    ------- Optional inversion before decoding ----------
    with i_invert_TS select hit_in_TS <=
        not ts_temp    when '1',
        ts_temp        when others;

    with i_invert_TS2 select hit_in_TS2 <=
        not ts2_temp    when '1',
        ts2_temp        when others;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        hit_out_TS <= (others => '0');
        hit_out_TS2 <= (others => '0');
    elsif rising_edge(i_clk) then
        hit_out_TS <= (others => '0');
        hit_out_TS2 <= (others => '0');
        hit_out_TS <= work.util.gray2bin(hit_in_TS);
        hit_out_TS2 <= work.util.gray2bin(hit_in_TS2);
    end if;
    end process;

    ------- Pipelining inputs --------
    -- this process happens concurrently with the input selection
    -- then decoding also takes 1 clock cyle
    -- so two pipelines
    pipelining: process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        hit_ena_in_r1   <= '0';
        hit_ena_in_r2   <= '0';
        col_r1          <= (others => '0');
        col_r2          <= (others => '0');
        row_r1          <= (others => '0');
        row_r2          <= (others => '0');

        hit_in_TS_reg   <= (others => '0');
        hit_in_TS2_reg  <= (others => '0');
    elsif rising_edge(i_clk) then
        hit_ena_in_r1   <= i_hit_ena;
        hit_ena_in_r2   <= hit_ena_in_r1;
        col_r1          <= i_col;
        col_r2          <= col_r1;
        row_r1          <= i_row;
        row_r2          <= row_r1;

        -- if gray decoding is not used, here we register the encoded, but optinally inverted timestamps
        hit_in_TS_reg   <= hit_in_TS;
        hit_in_TS2_reg  <= hit_in_TS2;
    end if;
    end process;

    ------- Output signals ----------------

    output_sel: process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_hit_ena       <= '0';
        o_col           <= (others => '0');
        o_row           <= (others => '0');
        o_ts            <= (others => '0');
        o_ts2           <= (others => '0');
    elsif rising_edge(i_clk) then
        o_hit_ena       <= hit_ena_in_r2;
        o_col           <= col_r2;
        o_row           <= row_r2;

        if ( i_gray_TS = '1' ) then
            o_ts        <= hit_out_TS(work.mupix.MUPIX_TIMESTAMPSIZE-1 downto 0);
        else
            o_ts        <= hit_in_TS_reg(work.mupix.MUPIX_TIMESTAMPSIZE-1 downto 0);
        end if;

        if ( i_gray_TS2 = '1' ) then
            o_ts2       <= hit_out_TS2(work.mupix.CHARGESIZE_MP10-1 downto 0);
        else
            o_ts2       <= hit_in_TS2_reg(work.mupix.CHARGESIZE_MP10-1 downto 0);
        end if;
    end if;
    end process;

end architecture;
