-- Testbench for the FPGA programming IF

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;

entity programming_tb is
end entity;

architecture rtl of programming_tb is

    signal reset_n:    std_logic;
    signal clk:        std_logic;
    signal slowclk:    std_logic;

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

    signal start : std_logic;
    signal spi_flash_request : std_logic;
    signal spi_flash_granted : std_logic;

    signal fpga_conf_done : std_logic;
    signal fpga_nstatus : std_logic;
    signal fpga_nconfig : std_logic;
    signal fpga_data : std_logic_vector(7 downto 0);
    signal fpga_clk : std_logic;

    signal lfsr : std_logic_vector(7 downto 0) := X"01";

begin

    dut1 : entity work.spiflash
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

    dut2 : entity work.ps_programmer
    port map (
        i_start             => start,
        i_start_address     => X"88BB11",

        -- Interface to SPI flash
        o_spi_strobe        => spi_strobe,
        o_spi_command       => spi_command,
        o_spi_addr          => spi_addr,
        spi_next_byte       => spi_next_byte,
        o_spi_continue      => spi_continue,
        i_spi_byte_out      => spi_byte_out,
        i_spi_byte_ready    => spi_byte_ready,

        o_spi_flash_request => spi_flash_request,
        i_spi_flash_granted => spi_flash_granted,

        -- Interface to FPGA
        i_fpga_conf_done    => fpga_conf_done,
        i_fpga_nstatus      => fpga_nstatus,
        o_fpga_nconfig      => fpga_nconfig,
        o_fpga_data         => fpga_data,
        o_fpga_clk          => fpga_clk,

        i_reset_n           => reset_n,
        i_clk               => clk--,
    );

    spi_flash_granted <= spi_flash_request after 50 ns;
    fpga_nstatus      <= fpga_nconfig after 700 ns;


    clkgen:process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end process;

    slowclkgen:process
    begin
    slowclk <= '0';
    wait for 10 ns;
    slowclk <= '1';
    wait for 10 ns;
    end process;

    resetgen: process
    begin
        reset_n <= '0';
        wait for 50 ns;
        reset_n <= '1';
        wait;
    end process;

    startgen: process
    begin
    start <= '0';
    wait for 200 ns;
    start <= '1';
    wait for 10 ns;
    start <= '0';
    wait;
    end process;

    confdonegen:process
    begin
    fpga_conf_done <= '0';
    wait for 8010 ns;
    fpga_conf_done <= '1';
    wait;
    end process;

    PROCESS(slowclk)
        variable tmp : std_logic := '0';
    BEGIN
    IF rising_edge(slowclk) THEN
        tmp := lfsr(4) XOR lfsr(3) XOR lfsr(2) XOR lfsr(0);
        lfsr <= tmp & lfsr(7 downto 1);
    END IF;
    END PROCESS;

    spi_miso <= lfsr(7);

end architecture;
