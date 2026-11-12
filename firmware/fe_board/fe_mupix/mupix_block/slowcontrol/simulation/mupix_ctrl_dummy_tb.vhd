library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mupix_ctrl_dummy_tb is
end entity;

architecture rtl of mupix_ctrl_dummy_tb is

    constant CLK_MHZ        : positive := 125;
    signal clk, reset_n     : std_logic := '0';
    signal reset            : std_logic;

    signal counter          : std_logic_vector(31 downto 0);
    signal counter_int      : unsigned(31 downto 0);

    signal clock            : std_logic;
    signal mosi             : std_logic;
    signal csn              : std_logic;
begin

    clk <= not clk after (500 ns / CLK_MHZ);
    reset_n <= '1', '0' after 80 ns, '1' after 160 ns;
    reset <= not reset_n;
    counter <= std_logic_vector(counter_int);

    e_mupix_ctrl : entity work.mupix_ctrl_dummy
    port map (
        o_spi_clock                 => clock,
        o_spi_mosi                  => mosi,
        o_spi_csn                   => csn,

        i_start                     => reset,
        i_clk                       => clk--,
    );

    process
    begin
        counter     <= (others => '0');
        counter_int <= (others => '0');

        wait until ( reset_n = '0' );

        for i in 0 to 80000 loop
            wait until rising_edge(clk);
            counter_int <= counter_int + 1;
        end loop;
        wait;
    end process;

end architecture;
