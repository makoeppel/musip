--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use ieee.math_real.all; -- for UNIFORM, TRUNC
use ieee.std_logic_textio.all; -- for write std_logic_vector to line
library std;
use std.textio.all; -- FOR LOGFILE WRITING
library mutrig_sim;
use mutrig_sim.txt_util.all;
library modelsim_lib;
use modelsim_lib.util.all;

--use work.mudaq_registers.all;
--use work.pcie_components.all;
--use work.mudaq_components.all;
--use work.mutrig_components.all;
--use work.devboard_components.all;
--use work.gbt_components.all;
--use work.lvds_components.all;

library mutrig_sim;
use mutrig_sim.txt_util.all;
use mutrig_sim.datapath_types.all;
use mutrig_sim.datapath_helpers.all;

entity testbench_standalone is
end entity;

architecture RTL of testbench_standalone is

    constant N_ASICS : natural := 4;
    constant N_ASICS_MAX : natural := 4;

    -- ASIC signals --{{{
    signal i_asic_tx_p : std_logic_vector(N_ASICS-1 downto 0):=(others =>'0');
    --SPI INPUTS
    signal asics_sclk : std_logic;
    signal asics_mosi : std_logic;
    signal asics_miso : std_logic:='0';
    signal asic_cs : std_logic_vector(N_ASICS-1 downto 0):=(others => '1');
    --}}}

    ----spi interface (not used, we just force the configuration vector)
    --signal s_spi_clk : std_logic := '0';
    --signal s_spi_clk_ena : std_logic := '0'; --ENABLE SIGNAL FOR THE SPI CLOCK
    --signal SPI_data : STD_LOGIC_VECTOR(0 to N_CONF_BITS-1):=(others=>'0'); --THE DATA VECTOR TO BE SENT TO THE SPI SLAVE
    --signal SPI_return_data : STD_LOGIC_VECTOR(0 to N_CONF_BITS-1):=(others=>'0');
    --signal config : stic3_spi_config;
    --signal slave_config : stic3_spi_config;


    --system signals receiver
    signal i_rst : std_logic:='0';
    signal i_refclk_125 : std_logic:='0';
    signal i_tsclk_125 : std_logic:='0';
    --receiver fifos
    signal i_coreclk : std_logic:='0';

    --monitoring
    signal o_receivers_pll_clock : std_logic;
    signal o_receivers_pll_lock : std_logic;
    signal o_receivers_dpa_lock : std_logic_vector(N_ASICS-1 downto 0);
    signal o_receivers_ready : std_logic_vector(N_ASICS-1 downto 0);
    signal o_frame_desync : std_logic_vector(1 downto 0);
    --counters
    signal i_SC_reset_counters : std_logic;
    signal i_SC_counterselect : std_logic_vector(5 downto 0);
    signal o_counter_numerator : std_logic_vector(31 downto 0);
    signal o_counter_denominator_low : std_logic_vector(31 downto 0);
    signal o_counter_denominator_high : std_logic_vector(31 downto 0);
    signal o_counter_numerator_b : std_logic_vector(31 downto 0);
    signal o_counter_denominator_b : std_logic_vector(63 downto 0);
    --fifo interface
    signal s_A_fifo_empty : std_logic:='0';
    signal s_A_fifo_data : std_logic_vector(35 downto 0);
    signal s_A_fifo_rd : std_logic;
    signal s_A_fifo_rd_last : std_logic;
    --fifo interface
    signal s_B_fifo_empty : std_logic:='0';
    signal s_B_fifo_data : std_logic_vector(35 downto 0);
    signal s_B_fifo_rd : std_logic;
    signal s_B_fifo_rd_last : std_logic;

    signal i_RC_may_generate : std_logic:='1';
    signal o_RC_all_done : std_logic;

    signal i_SC_mask : std_logic_vector(N_ASICS-1 downto 0);
    signal i_SC_datagen_enable : std_logic;
    signal s_header_payload : std_logic :='0';

begin

    i_RC_may_generate <= '1', '0' after 1 us;

    -- basic stimulus for receiver
    i_coreclk <= not i_coreclk after 3 ns; -- 166 MHz system core clock (actually 156MHz)
    i_refclk_125 <= not i_refclk_125 after 4 ns; -- 125 MHz tranceiver reference clock
    i_rst <= '1' after 20 ns, '0' after 200 ns;--, '1' after 3 us, '0' after 3.1 us; -- Basic reset of GBT

    -- basic stimulus for asics
    i_tsclk_125 <= not i_tsclk_125 after 4 ns;

    i_SC_datagen_enable <= '1', '0' after 10 us;

    i_SC_mask <= (0=>'0', others=>'0');

    --dut
    e_dut : entity work.mutrig_datapath
    generic map (
        N_ASICS => N_ASICS,
        C_CHANNELNO_PREFIX_A => "00",
        C_CHANNELNO_PREFIX_B => "10"
    )
    port map (
        i_rst_core => i_rst,
        i_rst_rx => i_rst,
        i_stic_txd => i_asic_tx_p,
        i_refclk_125_A => i_refclk_125,
        i_refclk_125_B => i_refclk_125,
        i_ts_clk => i_tsclk_125,
        i_ts_rst => i_rst,
        o_receivers_usrclk => o_receivers_pll_clock,
        o_receivers_pll_lock => o_receivers_pll_lock,
        o_receivers_dpa_lock => o_receivers_dpa_lock,
        o_receivers_ready => o_receivers_ready,

        i_clk_core => i_coreclk,
        o_A_fifo_empty => s_A_fifo_empty,
        o_A_fifo_data => s_A_fifo_data,
        i_A_fifo_rd => s_A_fifo_rd,
        i_SC_disable_dec => '1', --disable decoder to speed up simulation
        i_SC_mask => i_SC_mask,
        o_frame_desync => o_frame_desync,
        i_SC_datagen_enable => i_SC_datagen_enable,
        i_SC_datagen_shortmode => '0',
        i_SC_datagen_count => (5=>'1',others=>'0'),
        i_SC_rx_wait_for_all => '1',
        i_SC_rx_wait_for_all_sticky => '1',

        i_RC_may_generate => i_RC_may_generate,
        o_RC_all_done => o_RC_all_done,
        i_SC_reset_counters => i_SC_reset_counters,
        i_SC_counterselect => i_SC_counterselect,
        o_counter_numerator => o_counter_numerator,
        o_counter_denominator_low => o_counter_denominator_low,
        o_counter_denominator_high => o_counter_denominator_high
    );

    o_counter_denominator_b<=work.util.gray2bin(o_counter_denominator_high&o_counter_denominator_low);
    o_counter_numerator_b<=work.util.gray2bin(o_counter_numerator);
    ---------------------------------------------------------------
    -- fifo readout stimulus
    fifo_ro: process(i_coreclk)
    begin
    if rising_edge(i_coreclk) then
        if (i_rst='1') then s_A_fifo_rd <='0';
        else
            s_A_fifo_rd_last<=s_A_fifo_rd;
            if(s_A_fifo_rd='0') then
                if (s_A_fifo_empty='0') then
                    s_A_fifo_rd<= '1'; --read only when not empty
                else
                    s_A_fifo_rd<= '0';
                end if;
            else
                s_A_fifo_rd <= '0'; --read only every other cycle
            end if;
        end if;
    end if;
    end process;

    -- fifo readout logger
    fifo_logging: process(i_coreclk)
    file log_file : TEXT open write_mode is "readout_data.txt";
    variable l : line;
    begin
    if rising_edge(i_rst) then
        -- write header
        write(l, string'("--------------------------------------------------"));

    elsif rising_edge(i_coreclk) and ( s_A_fifo_rd_last = '1' ) then
        if(s_A_fifo_data(33 downto 32)="10") then
            write(log_file,"Frame Header / Payload 1"&
                HT & "RAW "& to_hstring(s_A_fifo_data) &
                LF);
                s_header_payload<='1';
        elsif(s_A_fifo_data(33 downto 32)="11") then
            write(log_file,"Frame Trailer "&
                HT & "RAW "& to_hstring(s_A_fifo_data) &
                HT & "L2F="& "0x" & to_hstring(s_A_fifo_data(1 downto 1)) &
                HT & "CRC="& "0x" & to_hstring(s_A_fifo_data(0 downto 0)) &
                LF);
        elsif(s_A_fifo_data(33 downto 32)="00") then
            if(s_header_payload='1') then
                write(log_file,"Frame Header / Payload 2"&
                    HT & "RAW "& to_hstring(s_A_fifo_data) &
                    HT & "TS(LO)="& "0x" & to_hstring(s_A_fifo_data(31 downto 16)) &
                    HT & "FSYN="& "0x" & to_hstring(s_A_fifo_data(15 downto 15)) &
                    HT & "FID ="& "0x" & to_hstring(s_A_fifo_data(14 downto 0)) &
                    LF);
                s_header_payload<='0';
            else
                write(log_file,"Hit data");
                write(log_file,
                    HT & " RAW "& to_hstring(s_A_fifo_data) &
                    HT & "ASIC "& natural'image(to_integer(unsigned(s_A_fifo_data(31 downto 28)))) &
                    HT & "TYPE "& natural'image(to_integer(unsigned(s_A_fifo_data(27 downto 27)))) &
                    HT & "  CH "& natural'image(to_integer(unsigned(s_A_fifo_data(26 downto 22)))) &
                    HT & " EBH "& to_hstring(s_A_fifo_data(21 downto 21)) &
                    HT & " ECC "& to_hstring(s_A_fifo_data(20 downto  6)) &
                    HT & " EFC "& to_hstring(s_A_fifo_data( 5 downto  1)) &
                    HT & "EFLG "& to_hstring(s_A_fifo_data( 0 downto  0)) &
                    LF);
            end if;
        end if;

        flush(log_file);
    end if;
    end process;

    --generate counter selection
    stim_counterctrl: process
    begin
        i_SC_counterselect <= "00"&"0000";
        i_SC_reset_counters <= '0';
        wait for 20 us;
        i_SC_reset_counters <= '1';
        wait for 100 ns;
        i_SC_reset_counters <= '0';
        wait for 100 ns;
        i_SC_counterselect <= "00"&X"0";
        wait for 100 ns;
        i_SC_counterselect <= "00"&X"1";
        wait for 100 ns;
        i_SC_counterselect <= "00"&X"2";
        wait for 100 ns;
        i_SC_counterselect <= "00"&X"3";
    end process;

end architecture;
