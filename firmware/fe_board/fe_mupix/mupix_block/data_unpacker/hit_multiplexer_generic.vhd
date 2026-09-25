-----------------------------------
--
-- Generic version of hit_multiplexer
--
-- M.Mueller, May 2023
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity hit_multiplexer_generic is
generic (
    N : integer := 3--;
);
port (
    i_ts        : in    work.mupix.ts_array_t(N-1 downto 0);
    i_chip_id   : in    work.mupix.ch_id_array_t(N-1 downto 0);
    i_row       : in    work.mupix.row_array_t(N-1 downto 0);
    i_col       : in    work.mupix.col_array_t(N-1 downto 0);
    i_tot       : in    work.mupix.tot_array_t(N-1 downto 0);
    i_hit_ena   : in    std_logic_vector(N-1 downto 0);

    o_ts        : out   work.mupix.ts_array_t(0 downto 0);
    o_chip_id   : out   work.mupix.ch_id_array_t(0 downto 0);
    o_row       : out   work.mupix.row_array_t(0 downto 0);
    o_col       : out   work.mupix.col_array_t(0 downto 0);
    o_tot       : out   work.mupix.tot_array_t(0 downto 0);
    o_hit_ena   : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture RTL of hit_multiplexer_generic is

    signal hit_out          : std_logic_vector(38 downto 0);
    type hit_in_t is array ( natural range <> ) of std_logic_vector(38 downto 0);
    signal hit_in           : hit_in_t(N-1 downto 0);
    signal hit_in_buffer    : hit_in_t(N-1 downto 0);
    signal hit_ena_buffer   : std_logic_vector(N-1 downto 0);
    signal hit_taken        : std_logic_vector(N-1 downto 0);

begin

    genhitin : for i in 0 to N-1 generate
        hit_in(i) <= i_ts(i) & i_chip_id(i) & i_row(i) & i_col(i) & i_tot(i);
    end generate;

    o_tot(0)    <= hit_out(5 downto 0);
    o_col(0)    <= hit_out(13 downto 6);
    o_row(0)    <= hit_out(21 downto 14);
    o_chip_id(0)<= hit_out(27 downto 22);
    o_ts(0)     <= hit_out(38 downto 28);

    process(i_clk, i_reset_n) is
        variable position : integer range 0 to N;
    begin
    if ( i_reset_n = '0' ) then
        hit_ena_buffer <= (others => '0');
        hit_taken      <= (others => '0');
        o_hit_ena      <= '0';
    elsif rising_edge(i_clk) then
        hit_taken      <= (others => '0');
        o_hit_ena      <= '0';
        hit_ena_buffer <= i_hit_ena or (hit_ena_buffer and (not hit_taken));

        for i in 0 to N-1 loop
            if(i_hit_ena(i)='1') then
                hit_in_buffer(i)  <= hit_in(i);
            end if;
        end loop;

        position := work.util.count_leading_zeroes((hit_ena_buffer and (not hit_taken)));
        if ( position /= N ) then
            hit_out   <= hit_in_buffer(position);
            o_hit_ena <= '1';
            hit_taken <= (position => '1', others => '0');
        end if;
    end if;
    end process;

end architecture;
