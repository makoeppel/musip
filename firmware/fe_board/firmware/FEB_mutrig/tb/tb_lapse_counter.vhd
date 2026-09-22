library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity tb_lapse_counter is
end entity;

architecture arch of tb_lapse_counter is

    constant N_CC : integer := 15;
    signal clk, clk_fast, reset_n, reset, en : std_logic := '0';

    signal DONE : std_logic_vector(1 downto 0) := (others => '0');
    signal delay : std_logic_vector(N_CC-1 downto 0);

    signal i_CC : std_logic_vector(N_CC-1 downto 0);
    signal o_CC : std_logic_vector(N_CC-1 downto 0);
    signal COUNT : integer := 32767;

    signal CC_BND : std_logic_vector(N_CC-1 downto 0) := (others => '0');
    signal FPGA_BND : std_logic_vector(N_CC-1 downto 0) := (others => '0');
    signal offset : std_logic_vector(N_CC-1 downto 0) := (others => '0');

begin

    clk     <= not clk after 8 ns;          -- 125MHz
    clk_fast<= not clk_fast after 1.6 ns;   -- 625MHz
    reset_n <= '0', '1' after 1.0 us;
    en      <= '0', '1' after 3.0 us;
    reset   <= not reset_n;

    p_gen_cc: process(clk_fast, reset_n)
    begin
    if ( reset_n = '0' ) then
        i_CC <= (others => '0');
        delay<= (others => '0');
    elsif rising_edge(clk_fast) then
        if delay < x"FF" then
            delay <= delay + 1;
        else
            if ( i_CC = COUNT - 1 ) then
                i_CC <= (others => '0');
            else
                i_CC <= i_CC + 1;

            end if;
        end if;
    end if;
    end process;

    CC_BND      <= "111010100110000"; -- CC_BND 30000
    FPGA_BND    <= "000101011001111"; -- FPGA_BND 2767
    offset <= (others => '0');

    e_lapse_counter : entity work.lapse_counter
    generic map (N_CC => N_CC)
    port map (
        i_CC => i_CC,
        i_upper_bnd => CC_BND,
        i_lower_bnd => FPGA_BND,
        o_cnt => open,
        o_CC => o_CC,
        i_reset_n => reset_n,
        i_clk => clk--,
    );

end architecture;
