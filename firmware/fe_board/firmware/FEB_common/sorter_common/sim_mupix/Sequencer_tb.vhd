--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mupix.all;
use work.mudaq.all;

entity sequencer_tb is
end entity;

architecture rtl of sequencer_tb is

    constant WRITECLK_PERIOD : time := 10 ns;

    signal      reset_n                         : std_logic; -- async reset
    signal      writeclk                        : std_logic; -- clock for write/input side
    signal      runend                          : std_logic;
    signal      tofifo_counters                 : sorterfifodata_t;
    signal      fromfifo_counters               : sorterfifodata_t;
    signal      read_counterfifo                : std_logic;
    signal      write_counterfifo               : std_logic;
    signal      counterfifo_almostfull          : std_logic;
    signal      counterfifo_empty               : std_logic;

    signal      outcommand                      : command_t;
    signal      command_enable                  : std_logic;
    signal      outoverflow                     : std_logic_vector(15 downto 0);

begin

    e_scfifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 7,
        g_DATA_WIDTH => tofifo_counters'length,
        g_SHOWAHEAD => "OFF"--,
    )
    port map (
        i_we => write_counterfifo,
        i_wdata => tofifo_counters,
        o_almost_full => counterfifo_almostfull,

        i_rack => read_counterfifo,
        o_rdata => fromfifo_counters,
        o_rempty => counterfifo_empty,

        i_reset_n => reset_n,
        i_clk => writeclk--,
    );

    dut: entity work.sequencer_ng
    port map (
        i_runend            => runend,
        i_fifo_data         => fromfifo_counters,
        i_fifo_empty        => counterfifo_empty,
        o_fifo_read         => read_counterfifo,
        o_command           => outcommand,
        o_command_enable    => command_enable,
        o_overflow          => outoverflow,
        i_reset_n           => reset_n,
        i_clk               => writeclk--,
    );

    wclockgen: process
    begin
        writeclk <= '0';
        wait for WRITECLK_PERIOD/2;
        writeclk <= '1';
        wait for WRITECLK_PERIOD/2;
    end process;


    resetgen: process
    begin
        reset_n <= '0';
        wait for 10 ns;
        reset_n <= '1';
        wait;
    end process;

    runendp: process
    begin
        runend <= '0';
        wait for 16000 ns;
        runend <= '1';
        wait;
    end process;


hitgen: process
begin
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 50 ns;
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0000000";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    -- Single hit
    tofifo_counters(TSINFIFORANGE)          <= "00000000001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(0)                      <= '1';
    write_counterfifo                       <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    -- Two single hits following each other
    tofifo_counters(TSINFIFORANGE)          <= "00000010001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(0)                      <= '1';
    write_counterfifo                       <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00000010010";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(0)                      <= '1';
    write_counterfifo                       <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0000010";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    -- two hits from one chip
    tofifo_counters(TSINFIFORANGE)          <= "00000100001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(3 downto 0)             <= "0010";
    write_counterfifo                       <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0000011";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    -- three hits from one chip
    tofifo_counters(TSINFIFORANGE)          <= "00000110001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(3 downto 0)             <= "0011";
    write_counterfifo                       <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0000100";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    -- fifteen hits from one chip
    tofifo_counters(TSINFIFORANGE)          <= "00001000001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(3 downto 0)             <= "1111";
    write_counterfifo                       <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0000101";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    -- two hits, different chips chip
    tofifo_counters(TSINFIFORANGE)          <= "00001010001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    tofifo_counters(15 downto 8)            <= "00010001";
    write_counterfifo                       <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0000110";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    -- three hits, different chips chip
    tofifo_counters(TSINFIFORANGE)          <= "00001100001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    tofifo_counters(15 downto 8)            <= "00010001";
    tofifo_counters(23 downto 16)           <= "00100001";
    write_counterfifo                       <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0000111";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    -- five hits, three different chips chip
    tofifo_counters(TSINFIFORANGE)          <= "00001110001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000010";
    tofifo_counters(15 downto 8)            <= "00010010";
    tofifo_counters(23 downto 16)           <= "00100001";
    write_counterfifo                       <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- hit at ts 0 in block
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0001000";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- two hits at ts 0 in block
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0001001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000010";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- three hits at ts 0 in block
    tofifo_counters(TSBLOCKINFIFORANGE)     <= "0001010";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000011";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- three hits at ts 1 in block
    tofifo_counters(TSINFIFORANGE)          <= "00010110001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000011";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- three hits at ts 2 in block
    tofifo_counters(TSINFIFORANGE)          <= "00011000010";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000011";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- three hits at ts 15 in block
    tofifo_counters(TSINFIFORANGE)          <= "00011011111";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000011";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- three hits at ts 2 in block
    tofifo_counters(TSINFIFORANGE)          <= "00011100010";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000011";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- two hits at ts 2 in block, no gap
    tofifo_counters(TSINFIFORANGE)          <= "00011110010";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000010";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00100000010";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000010";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- one hit at ts 2 in block, no gap
    tofifo_counters(TSINFIFORANGE)          <= "00100010010";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00100100010";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    -- one hit per ts, no gap
    tofifo_counters(TSINFIFORANGE)          <= "00100110000";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00100110001";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00100110010";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00100110011";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "11111111111";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00000000000";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "11111111111";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000011";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00000000000";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 8*WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00000010000";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(MEMOVERFLOWBIT)         <= '1';
    tofifo_counters(7 downto 0)             <= "00000001";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00000100000";
    tofifo_counters(HASMEMBIT)              <= '0';
    tofifo_counters(MEMOVERFLOWBIT)         <= '0';
    tofifo_counters(7 downto 0)             <= "00000000";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for 9*WRITECLK_PERIOD;
    tofifo_counters(TSINFIFORANGE)          <= "00000110000";
    tofifo_counters(HASMEMBIT)              <= '1';
    tofifo_counters(MEMOVERFLOWBIT)         <= '1';
    tofifo_counters(7 downto 0)             <= "00000000";
    write_counterfifo   <= '1';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    wait for WRITECLK_PERIOD;
    tofifo_counters     <= (others => '0');
    write_counterfifo   <= '0';
    for i in 0 to 4000 loop
        wait for 9*WRITECLK_PERIOD;
        tofifo_counters(TSBLOCKINFIFORANGE)     <= tofifo_counters(TSBLOCKINFIFORANGE) + '1';
        write_counterfifo   <= '1';
        wait for WRITECLK_PERIOD;
        write_counterfifo   <= '0';
    end loop;
end process;

end architecture;
