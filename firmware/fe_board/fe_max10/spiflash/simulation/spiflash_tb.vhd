-- Testbench for the quad spi IF


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mudaq.all;

entity spiflash_tb is
end entity;

architecture rtl of spiflash_tb is

    signal reset_n:    std_logic;
    signal clk:        std_logic;

    signal spi_strobe :  std_logic;
    signal spi_ack :     std_logic;
    signal spi_command : std_logic_vector(7 downto 0);
    signal spi_addr :    std_logic_vector(23 downto 0);
    signal spi_data :    std_logic_vector(7 downto 0);
    signal spi_next_byte: std_logic;
    signal spi_continue : std_logic;
    signal spi_byte_out : std_logic_vector(7 downto 0);
    signal spi_byte_ready  : std_logic;

    signal spi_sclk:   std_logic;
    signal spi_csn:    std_logic;
    signal spi_mosi:   std_logic;
    signal spi_miso:   std_logic;
    signal spi_D2:     std_logic;
    signal spi_D3:     std_logic;

begin

    dut : entity work.spiflash
    port map (
        i_spi_strobe        => spi_strobe,
        o_spi_ack           => spi_ack,
        i_spi_command       => spi_command,
        i_spi_addr          => spi_addr,
        i_spi_data          => spi_data,
        o_spi_next_byte     => spi_next_byte,
        i_spi_continue      => spi_continue,
        o_spi_byte_out      => spi_byte_out,
        o_spi_byte_ready    => spi_byte_ready,

        o_spi_sclk          => spi_sclk,
        o_spi_csn           => spi_csn,
        io_spi_mosi         => spi_mosi,
        io_spi_miso         => spi_miso,
        io_spi_D2           => spi_D2,
        io_spi_D3           => spi_D3,

        i_reset_n           => reset_n,
        i_clk               => clk--,
    );

    clkgen:process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end process;

    resetgen: process
    begin
        reset_n <= '0';
        wait for 50 ns;
        reset_n <= '1';
        wait;
    end process;

    stimuli: process
    begin
        spi_strobe      <= '0';
        spi_command     <= (others => '0');
        spi_addr        <= (others => '0');
        spi_data        <= (others => '0');
        spi_continue    <= '0';
        spi_mosi        <= 'Z';
        wait for 100 ns;
        spi_command     <= COMMAND_WRITE_ENABLE;
        spi_strobe      <= '1';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_WRITE_DISABLE;
        spi_strobe      <= '1';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_READ_STATUS_REGISTER1;
        spi_strobe      <= '1';
        spi_miso        <= '1';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_READ_STATUS_REGISTER2;
        spi_strobe      <= '1';
        spi_miso        <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_READ_STATUS_REGISTER3;
        spi_strobe      <= '1';
        spi_miso        <= '0';
        wait for 220 ns;
        spi_miso        <= '1';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        spi_miso        <= 'Z';
        wait for 15 ns;
        spi_command     <= COMMAND_READ_STATUS_REGISTER1;
        spi_strobe      <= '1';
        spi_miso        <= '1';
        spi_continue    <= '1';
        wait for 400 ns;
        spi_continue    <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_WRITE_ENABLE_VSR;
        spi_strobe      <= '1';
        spi_miso        <= '1';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_READ_DATA;
        spi_strobe      <= '1';
        spi_miso        <= '1';
        spi_addr        <= X"80FF01";
        wait for 700 ns;
        spi_miso        <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_READ_DATA;
        spi_strobe      <= '1';
        spi_miso        <= '1';
        spi_continue    <= '1';
        spi_addr        <= X"80FF01";
        wait for 900 ns;
        spi_miso        <= '0';
        wait for 400 ns;
        spi_miso        <= '1';
        wait for 800 ns;
        spi_miso        <= '0';
        wait for 800 ns;
        spi_continue    <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_FAST_READ;
        spi_strobe      <= '1';
        spi_miso        <= '1';
        spi_addr        <= X"80FF01";
        wait for 900 ns;
        spi_miso        <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_DUAL_OUTPUT_FAST_READ;
        spi_strobe      <= '1';
        spi_miso        <= '1';
        spi_addr        <= X"80FF01";
        wait for 655 ns;
        spi_mosi        <= '0';
        wait for 195 ns;
        spi_miso        <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        spi_mosi        <= 'Z';
        wait for 15 ns;
        spi_command     <= COMMAND_QUAD_OUTPUT_FAST_READ;
        spi_strobe      <= '1';
        spi_miso        <= '1';
        spi_addr        <= X"80FF01";
        wait for 655 ns;
        spi_mosi        <= '0';
        spi_D2          <= '1';
        spi_D3          <= '0';
        wait for 60 ns;
        spi_miso        <= '0';
        spi_D2          <= '0';
        spi_D3          <= '1';
        wait for 60 ns;
        spi_mosi        <= '1';
        spi_D2          <= '1';
        spi_D3          <= '1';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        spi_mosi        <= 'Z';
        spi_D2          <= 'Z';
        spi_D3          <= 'Z';
        wait for 15 ns;
        spi_command     <= COMMAND_QUAD_OUTPUT_FAST_READ;
        spi_strobe      <= '1';
        spi_miso        <= '1';
        spi_addr        <= X"80FF01";
        spi_continue    <= '1';
        wait for 660 ns;
        spi_mosi        <= '0';
        spi_D2          <= '1';
        spi_D3          <= '0';
        wait for 160 ns;
        spi_miso        <= '0';
        spi_D2          <= '0';
        spi_D3          <= '1';
        wait for 260 ns;
        spi_mosi        <= '1';
        spi_D2          <= '1';
        spi_D3          <= '1';
        wait for 100 ns;
        spi_continue    <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        spi_mosi        <= 'Z';
        spi_D2          <= 'Z';
        spi_D3          <= 'Z';
        wait for 15 ns;
        spi_command     <= COMMAND_DUAL_IO_FAST_READ;
        spi_strobe      <= '1';
        spi_miso        <= 'Z';
        spi_addr        <= X"80FF01";
        wait for 505 ns;
        spi_mosi        <= '0';
        spi_miso        <= '1';
        wait for 60 ns;
        spi_miso        <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        spi_miso        <= 'Z';
        spi_mosi        <= 'Z';
        spi_D2          <= 'Z';
        spi_D3          <= 'Z';
        wait for 15 ns;
        spi_command     <= COMMAND_QUAD_IO_FAST_READ;
        spi_strobe      <= '1';
        spi_miso        <= 'Z';
        spi_addr        <= X"80FF01";
        wait for 345 ns;
        spi_mosi        <= '0';
        spi_miso        <= '1';
        spi_D2          <= '1';
        spi_D3          <= '0';
        wait for 20 ns;
        spi_miso        <= '0';
        spi_D2          <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        spi_miso        <= 'Z';
        spi_mosi        <= 'Z';
        spi_D2          <= 'Z';
        spi_D3          <= 'Z';
        wait for 15 ns;
        spi_command     <= COMMAND_PAGE_PROGRAM;
        spi_strobe      <= '1';
        spi_addr        <= X"80FF01";
        spi_data        <= X"81";
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_PAGE_PROGRAM;
        spi_strobe      <= '1';
        spi_addr        <= X"80FF01";
        spi_data        <= X"81";
        spi_continue    <= '1';
        wait for 680 ns;
        spi_data        <= X"00";
        wait for 160 ns;
        spi_data        <= X"81";
        wait for 160 ns;
        spi_continue    <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_QUAD_PAGE_PROGRAM;
        spi_strobe      <= '1';
        spi_addr        <= X"80FF01";
        spi_data        <= X"81";
        wait until spi_ack = '1';
        spi_strobe      <= '0';
        wait for 15 ns;
        spi_command     <= COMMAND_QUAD_PAGE_PROGRAM;
        spi_strobe      <= '1';
        spi_addr        <= X"80FF01";
        spi_data        <= X"81";
        spi_continue    <= '1';
        wait for 680 ns;
        spi_data        <= X"00";
        wait for 160 ns;
        spi_data        <= X"81";
        wait for 160 ns;
        spi_continue    <= '0';
        wait until spi_ack = '1';
        spi_strobe      <= '0';

        wait;

    end process;

end architecture;
