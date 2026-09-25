----------------------------------------------------------------------------
-- Dual port FIFO
-- M. Mueller
-- Feb 2022
-- TODO: make this behave more "fifo-like" using dual port RAM with output width > max(RDATA1_WIDTH, RDATA2_WIDTH). Buffer RAM output once, shift readpointer on ram output and buffer by RDATA1_WIDTH, RDATA2_WIDTH
-- UNTIL THAT IS DONE : START READING ONLY WHEN FULL, START WRITING ONLY WHEN EMPTY, NO READ & WRITE AT THE SAME TIME !!!
-- update Dec 2022: we are not going to do that, no memory for it at the other idea is much nicer for row conversion
-- now as a circular shift reg --> config is still there after read by spi or new protocol
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.mupix_registers.all;
use work.mupix.all;
use work.mudaq.all;

-- DPF stands for dual-port-fifo
-- note that dual-port-fifo is misnomer here
entity tdac_dp_fifo is
generic (
    g_BITS          : positive := 2047;
    g_WDATA_WIDTH   : positive := 32;
    g_RDATA1_WIDTH  : positive := 32;
    g_RDATA2_WIDTH  : positive := 32;
    g_IS_TDAC_DPF   : boolean  := false;
    g_IS_MUPIX10    : boolean  := false;
    g_TYPE          : string   := "undefined"--;
);
port (
    o_full          : out std_logic;
    o_empty         : out std_logic;

    i_we            : in  std_logic;
    i_wdata         : in  std_logic_vector(g_WDATA_WIDTH-1 downto 0);

    i_re1           : in  std_logic;
    o_rdata1        : out std_logic_vector(g_RDATA1_WIDTH-1 downto 0);

    i_re2           : in  std_logic;
    o_rdata2        : out std_logic_vector(g_RDATA2_WIDTH-1 downto 0);

    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic--;
);
end entity;

architecture RTL of tdac_dp_fifo is

    constant c_BITS_BLIND       : integer := work.util.max(g_RDATA2_WIDTH*integer(ceil(real(g_BITS)/real(g_RDATA2_WIDTH))), g_WDATA_WIDTH*integer(ceil(real(g_BITS)/real(g_WDATA_WIDTH)))) - g_BITS;
    constant c_BITS_ACTUAL      : integer := g_BITS + c_BITS_BLIND;
    constant c_R2_OFFSET        : integer := g_RDATA2_WIDTH*integer(ceil(real(g_BITS)/real(g_RDATA2_WIDTH))) - g_BITS;
    constant c_W_OFFSET         : integer := g_WDATA_WIDTH*integer(ceil(real(g_BITS)/real(g_WDATA_WIDTH))) - g_BITS;

    signal shift_reg            : std_logic_vector(c_BITS_ACTUAL-1 downto 0);
    signal bits_used            : integer range 0 to g_BITS + g_WDATA_WIDTH;

begin

    assert ( false ) report "instantiate " & g_TYPE & " dpf with width of " & integer'image(shift_reg'length) & " bits, "& integer'image(c_BITS_BLIND) & " of them blind" severity note;

    o_rdata1 <= shift_reg(g_RDATA1_WIDTH-1 downto 0);
    o_rdata2 <= shift_reg(g_RDATA2_WIDTH-c_R2_OFFSET-1 downto 0) & shift_reg(shift_reg'length-1 downto shift_reg'length-c_R2_OFFSET) when c_R2_OFFSET > 0 else shift_reg(g_RDATA2_WIDTH-1 downto 0);

    o_full  <= '1' when (bits_used = g_BITS or (i_we='1' and bits_used + g_WDATA_WIDTH >= g_BITS)) else '0';
    o_empty <= '1' when (bits_used = 0 or (i_re1 = '1' and bits_used - g_RDATA1_WIDTH <= 0) or (i_re2 = '1' and bits_used - g_RDATA2_WIDTH <=0)) else '0';

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        shift_reg <= (others => '0');
        bits_used <= 0;
        --
    elsif rising_edge(i_clk) then
        if ( i_re1 = '1' ) then
            shift_reg(c_BITS_ACTUAL-1-g_RDATA1_WIDTH downto 0) <= shift_reg(c_BITS_ACTUAL-1 downto g_RDATA1_WIDTH);
            shift_reg(c_BITS_ACTUAL-1 downto c_BITS_ACTUAL-g_RDATA1_WIDTH) <= shift_reg(g_RDATA1_WIDTH-1 downto 0);--(others => '0');
            bits_used <= bits_used - g_RDATA1_WIDTH;
        elsif ( i_re2 = '1') then
            shift_reg(c_BITS_ACTUAL-1-g_RDATA2_WIDTH downto 0) <= shift_reg(c_BITS_ACTUAL-1 downto g_RDATA2_WIDTH);
            shift_reg(c_BITS_ACTUAL-1 downto c_BITS_ACTUAL-g_RDATA2_WIDTH) <= shift_reg(g_RDATA2_WIDTH-1 downto 0);--(others => '0');
            if(bits_used > g_RDATA2_WIDTH) then
                bits_used <= bits_used - g_RDATA2_WIDTH;
            else
                bits_used <= 0;
            end if;
        elsif ( i_we = '1' ) then
            if(g_IS_TDAC_DPF = false) then
                shift_reg(c_BITS_ACTUAL-1-g_WDATA_WIDTH downto 0)               <= shift_reg(c_BITS_ACTUAL-1 downto g_WDATA_WIDTH);
                shift_reg(c_BITS_ACTUAL-1 downto c_BITS_ACTUAL-g_WDATA_WIDTH)   <= shift_reg(g_WDATA_WIDTH-1 downto 0);
                shift_reg(g_BITS+c_W_OFFSET-1 downto g_BITS+c_W_OFFSET-g_WDATA_WIDTH) <= i_wdata;
            else
                -- this is the by far easiest point to do tdac row conversion to digital addresses (not necessarily the easiest to understand but in terms of resources this needs nothing)
                for I in 508 to 511 loop
                    shift_reg(work.mupix.tdac_conversion_index_mp11(I)) <= i_wdata(I-508);
                end loop;
                for I in 0 to 507 loop
                    shift_reg(work.mupix.tdac_conversion_index_mp11(I)) <= shift_reg(work.mupix.tdac_conversion_index_mp11(I+4));
                end loop;
                -- tdac row conversion done ...

                -- Mupix10 version of that, overwrite above lines in case of (g_IS_MUPIX10 = true)
                if(g_IS_MUPIX10 = true)then
                    for I in 508 to 511 loop
                        shift_reg(work.mupix.tdac_conversion_index(I)) <= i_wdata(I-508);
                    end loop;
                    for I in 0 to 507 loop
                        shift_reg(work.mupix.tdac_conversion_index(I)) <= shift_reg(work.mupix.tdac_conversion_index(I+4));
                    end loop;
                end if;
            end if;

            if(bits_used + g_WDATA_WIDTH < g_BITS) then
                bits_used <= bits_used + g_WDATA_WIDTH;
            else
                bits_used <= g_BITS;
            end if;
        end if;
    end if;
    end process;

end architecture;
