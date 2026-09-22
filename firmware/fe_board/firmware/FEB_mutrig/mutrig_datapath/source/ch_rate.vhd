--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

-- counters for hits per channel
entity ch_rate is
generic (
    num_ch : integer range 1 to 128;
    g_CLK_MHZ : real := 125.0--;
);
port (
    i_hit       : in    work.mutrig_hit_types.t_hit_presort;

    o_ch_rate   : out   slv32_array_t(num_ch-1 downto 0);

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture rtl of ch_rate is

    signal index : integer range 0 to num_ch - 1;

    signal ch_counter   : slv32_array_t(num_ch-1 downto 0);
    signal time_counter : std_logic_vector(31 downto 0);
    signal hit          : work.mutrig_hit_types.t_hit_presort;
    signal en           : std_logic;

begin

    index <= to_integer(unsigned(hit.channel));

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_ch_rate       <= (others => (others => '0'));
        ch_counter      <= (others => (others => '0'));
        time_counter    <= (others => '0');
        hit             <= work.mutrig_hit_types.t_hit_presort_zero;
        en              <= '0';
        --
    elsif rising_edge(i_clk) then
        hit <= i_hit;
        en <= i_hit.valid;
        if ( time_counter = integer(g_CLK_MHZ*1000000.0) ) then
            for i in ch_counter'range loop
                o_ch_rate(i) <= ch_counter(i);
                ch_counter(i) <= (others => '0');
            end loop;
            time_counter <= (others => '0');
        else
            if ( en = '1' ) then
                ch_counter(index) <= ch_counter(index) + '1';
            end if;
            time_counter <= time_counter + '1';
        end if;
    end if;
    end process;

end architecture;
