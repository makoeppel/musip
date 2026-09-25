library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tdac_dp_fifo_tb is
end entity;

architecture rtl of tdac_dp_fifo_tb is

    constant CLK_MHZ        : positive := 125;
    signal clk, reset_n     : std_logic := '0';
    signal reset            : std_logic;

    signal counter_int      : unsigned(31 downto 0);

    signal full, empty,we,re1,re2 : std_logic;
    signal wdata            : std_logic_vector(27 downto 0);
    signal rdata1           : std_logic_vector(0 downto 0);
    signal rdata2           : std_logic_vector(29 downto 0);
begin

    clk <= not clk after (500 ns / CLK_MHZ);
    reset_n <= '1', '0' after 80 ns, '1' after 160 ns;
    reset <= not reset_n;

    e_dut : entity work.tdac_dp_fifo
    generic map (
        g_BITS       => 100,
        g_WDATA_WIDTH  => 28,
        g_RDATA1_WIDTH => 1,
        g_RDATA2_WIDTH => 30
    )
    port map (
        o_full    => full,
        o_empty   => empty,
        i_we      => we,
        i_wdata   => wdata,
        i_re1     => re1,
        o_rdata1  => rdata1,
        i_re2     => re2,
        o_rdata2  => rdata2,
        i_reset_n => reset_n,
        i_clk     => clk--,
    );

    process
    begin
        counter_int <= (others => '0');

        wait until ( reset_n = '0' );

        for i in 0 to 80000 loop
            wait until rising_edge(clk);
            counter_int <= counter_int + 1;
        end loop;
        wait;
    end process;

end architecture;
