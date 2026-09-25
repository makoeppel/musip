library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mupix_ctrl_tb is
end entity;

architecture rtl of mupix_ctrl_tb is

    constant CLK_MHZ        : positive := 125;
    signal clk, reset_n     : std_logic := '0';

    signal counter          : std_logic_vector(31 downto 0);
    signal counter_int      : unsigned(31 downto 0);

    signal reg_addr         : std_logic_vector(7 downto 0);
    signal reg_re           : std_logic;
    signal reg_rdata        : std_logic_vector(31 downto 0);
    signal reg_we           : std_logic;
    signal reg_wdata        : std_logic_vector(31 downto 0);

    signal clock            : std_logic_vector( 3 downto 0);
    signal SIN              : std_logic_vector( 3 downto 0);
    signal mosi             : std_logic_vector( 3 downto 0);
    signal csn              : std_logic_vector(11 downto 0);

begin

    clk <= not clk after ( 500 ns / CLK_MHZ );
    reset_n <= '0', '1' after ( 500 ns / CLK_MHZ );

    e_mp_ctrl : entity work.mupix_ctrl
    port map (
        i_reg_addr           => reg_addr,
        i_reg_re            => reg_re,
        o_reg_rdata         => reg_rdata,
        i_reg_we            => reg_we,
        i_reg_wdata         => reg_wdata,

        o_clock             => clock,
        o_SIN               => SIN,
        o_mosi              => mosi,
        o_csn               => csn,

        i_reset_n           => reset_n,
        i_clk               => clk--,
    );

    counter <= std_logic_vector(counter_int);

    process
    begin
        counter_int <= (others => '0');
        wait until ( reset_n = '1' );
        for i in 0 to 80000 loop
            wait until rising_edge(clk);
            counter_int <= counter_int + 1;
        end loop;
        wait;
    end process;

    process
    begin
        reg_addr    <= (others => '0');
        reg_re      <= '0';
        reg_we      <= '0';
        reg_wdata   <= (others => '0');

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        wait until rising_edge(clk);
        reg_addr <= X"47";
        reg_we <= '1';
        reg_wdata <= X"00000003";
        wait until rising_edge(clk);
        reg_we <= '0';

        wait until rising_edge(clk);
        reg_addr <= X"49";
        reg_we <= '1';
        reg_wdata <= X"00000002";
        wait until rising_edge(clk);
        reg_we <= '0';

        wait until rising_edge(clk);
        reg_addr <= X"48";
        reg_we <= '1';
        reg_wdata <= X"00000000";
        wait until rising_edge(clk);
        reg_we <= '0';

        wait until rising_edge(clk);
        reg_addr <= X"4A";
        reg_we <= '1';
        reg_wdata <= X"2A000A03";
        wait until rising_edge(clk);
        reg_wdata <= X"FA3F002F";
        wait until rising_edge(clk);
        reg_wdata <= X"1E041041";
        wait until rising_edge(clk);
        reg_wdata <= X"041E9A51";
        wait until rising_edge(clk);
        reg_wdata <= X"40280000";
        wait until rising_edge(clk);
        reg_wdata <= X"1400C20A";
        wait until rising_edge(clk);
        reg_wdata <= X"028A001F";
        wait until rising_edge(clk);
        reg_wdata <= X"00020038";
        wait until rising_edge(clk);
        reg_wdata <= X"0000FC09";
        wait until rising_edge(clk);
        reg_wdata <= X"F0001C80";
        wait until rising_edge(clk);
        reg_wdata <= X"00148000";
        wait until rising_edge(clk);
        reg_wdata <= X"11802E00";
        wait until rising_edge(clk);
        reg_wdata <= X"00000000";
        wait until rising_edge(clk);
        reg_we <= '0';

        wait for 800 ns;

    end process;

end architecture;
