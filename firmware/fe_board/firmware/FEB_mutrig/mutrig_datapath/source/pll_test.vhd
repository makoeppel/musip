--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity pll_test is
port (
    i_hit       : in    work.mutrig_hit_types.t_hit_presort_div;

    o_pll_test0 : out   std_logic_vector(63 downto 0);
    o_pll_test1 : out   std_logic_vector(63 downto 0);
    o_pll_test2 : out   std_logic_vector(63 downto 0);

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture rtl of pll_test is

begin

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_pll_test0 <= (others => '0');
        o_pll_test1 <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        if (i_hit.valid = '1' and (i_hit.asic = "0000" or i_hit.asic = "0010" or i_hit.asic = "0100" or i_hit.asic = "0110")) then
            o_pll_test0(31 downto 0) <= x"00" & "000" & i_hit.T_CC_div & i_hit.T_CC_rem & i_hit.T_Fine;
            o_pll_test0(63 downto 32) <= o_pll_test0(31 downto 0);
        end if;
        if (i_hit.valid = '1' and (i_hit.asic = "0001" or i_hit.asic = "0011" or i_hit.asic = "0101" or i_hit.asic = "0111")) then
            o_pll_test1(31 downto 0) <= x"00" & "000" & i_hit.T_CC_div & i_hit.T_CC_rem & i_hit.T_Fine;
            o_pll_test1(63 downto 32) <= o_pll_test1(31 downto 0);
        end if;
    end if;
    end process;

end architecture;
