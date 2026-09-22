----------------------------------------
-- SciTile version of the Frontend Board
----------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.mudaq.all;

entity top is
port (
    fpga_reset                  : in    std_logic;

    LVDS_clk_si1_fpga_A         : in    std_logic; -- 125 MHz base clock for LVDS PLLs - right // SI5345
    LVDS_clk_si1_fpga_B         : in    std_logic; -- 125 MHz base clock for LVDS PLLs - left // SI5345
    transceiver_pll_clock       : in    std_logic_vector(0 downto 0); --_vector(1 downto 0); -- 156.25 MHz  clock for transceiver PLL-- Using 1 or 2 with 156 Mhz gives warings about coupling in clock builder
  --extra_transceiver_pll_clocks: in    std_logic_vector(1 downto 0); -- 125 MHz base clock for transceiver PLLs // SI5345

    lvds_firefly_clk            : in    std_logic; -- 125 MHz base clock

    systemclock                 : in    std_logic; -- 50 MHz system clock // SI5345
    systemclock_bottom          : in    std_logic; -- 50 MHz system clock // SI5345
    clk_125_top                 : in    std_logic; -- 125 MHz clock spare // SI5345
    clk_125_bottom              : in    std_logic; -- 125 Mhz clock spare // SI5345
    spare_clk_osc               : in    std_logic; -- Spare clock // 50 MHz oscillator

    -- Tile DAB signals for FEB connector #3  / Inner Ring on SSW
	mutrig_din                    : in    std_logic_vector(3 downto 0);
	mutrig_pll_test               : out   std_logic_vector(3 downto 0); -- test pulse injection
	mutrig_pll_reset              : out   std_logic_vector(3 downto 0); -- main reset (synchronisation and ASIC state machines)
	--RS485 interface for ASICs
	mutrig_uart_txd               : out   std_logic_vector(3 downto 0);
	mutrig_uart_rxd               : in    std_logic_vector(3 downto 0);
	mutrig_uart_dir               : out   std_logic_vector(3 downto 0);

    -- Fireflies
    firefly1_tx_data            : out   std_logic_vector(3 downto 0); -- transceiver
    firefly2_tx_data            : out   std_logic_vector(3 downto 0); -- transceiver
    firefly1_rx_data            : in    std_logic;-- transceiver
    firefly2_rx_data            : in    std_logic_vector(2 downto 0);-- transceiver

    firefly1_lvds_rx_in         : in    std_logic;--_vector(1 downto 0); -- receiver for slow control or something else
    firefly2_lvds_rx_in         : in    std_logic;--_vector(1 downto 0); -- receiver for slow control or something else

    Firefly_ModSel_n            : out   std_logic_vector(1 downto 0);-- Module select: active low, when host wants to communicate (I2C) with module
    Firefly_Rst_n               : out   std_logic_vector(1 downto 0);-- Module reset: active low, complete reset of module. Module indicates reset done by "low" interrupt_n (data_not_ready is negated).
    Firefly_Scl                 : inout std_logic;-- I2C Clock: module asserts low for clock stretch, timing infos: page 47
    Firefly_Sda                 : inout std_logic;-- I2C Data
  --Firefly_LPM                 : out   std_logic;-- Firefly Low Power Mode: Modules power consumption should be below 1.5 W. active high. Overrideable by I2C commands. Override default: high power (page 19 of documentation).
    Firefly_Int_n               : in    std_logic_vector(1 downto 0);-- Firefly Interrupt: when low: operational fault or status critical. after reset: goes high, and data_not_ready is read with '0' (byte 2 bit 0) and flag field is read
    Firefly_ModPrs_n            : in    std_logic_vector(1 downto 0);-- Module present: Pulled to ground if module is present

    -- LEDs, test points and buttons
    PushButton                  : in    std_logic_vector(1 downto 0);
    FPGA_Test                   : out   std_logic_vector(7 downto 0);

    --LCD
    lcd_csn                     : out   std_logic;--//2.5V    //LCD Chip Select
    lcd_d_cn                    : out   std_logic;--//2.5V    //LCD Data / Command Select
    lcd_data                    : out   std_logic_vector(7 downto 0);--//2.5V    //LCD Data
    lcd_wen                     : out   std_logic;--//2.5V    //LCD Write Enable

    -- SI5345(0): 7 Transceiver clocks @ 125 MHz
    -- SI4345(1): Clocks for the Fibres
    -- 1 reference and 2 inputs for synch
    si45_oe_n                   : out   std_logic_vector(1 downto 0);-- active low output enable -> should always be '0'
    si45_intr_n                 : in    std_logic_vector(1 downto 0);-- fault monitor: interrupt pin: change in state of status indicators
    si45_lol_n                  : in    std_logic_vector(1 downto 0);-- fault monitor: loss of lock of DSPLL

    -- I2C sel is set to GND on PCB -> SPI interface
    si45_rst_n                  : out   std_logic_vector(1 downto 0);-- reset
    si45_spi_cs_n               : out   std_logic_vector(1 downto 0);-- chip select
    si45_spi_in                 : out   std_logic_vector(1 downto 0);-- data in
    si45_spi_out                : in    std_logic_vector(1 downto 0);-- data out
    si45_spi_sclk               : out   std_logic_vector(1 downto 0);-- clock

    -- change frequency by the FSTEPW parameter
    si45_fdec                   : out   std_logic_vector(1 downto 0);-- decrease
    si45_finc                   : out   std_logic_vector(1 downto 0);-- increase

    -- Midas slow control bus
    mscb_fpga_in                : in    std_logic;
    mscb_fpga_out               : out   std_logic;
    mscb_fpga_oe_n              : out   std_logic;

    -- Backplane slot signal
    ref_adr                     : in    std_logic_vector(7 downto 0);

    -- MAX10 IF
    max10_spi_sclk              : out   std_logic;
    max10_spi_mosi              : inout std_logic;
    max10_spi_miso              : inout std_logic;
    max10_spi_D1                : inout std_logic;
    max10_spi_D2                : inout std_logic;
    max10_spi_D3                : inout std_logic;
    max10_spi_csn               : out   std_logic
);
end entity;

architecture rtl of top is


    -- non-inverted io signals
    -- clocks & resets
    signal clk_125, reset_125_n     : std_logic;
    signal clk_156, reset_156_n     : std_logic;

    -- Debouncers
    signal pb_db_n                  : std_logic_vector(1 downto 0);

    constant N_LINKS                : integer := 1;
    constant N_MODULES              : integer := 4;
    constant IS_TILE_B              : boolean := false;

    signal fifo_write               : std_logic_vector(N_LINKS-1 downto 0);
    signal fifo_wdata               : std_logic_vector(36*(N_LINKS-1)+35 downto 0);

    signal debug_write              : std_logic_vector(N_LINKS-1 downto 0);
    signal debug_wdata              : std_logic_vector(36*(N_LINKS-1)+35 downto 0);
    signal debug_almost_full        : std_logic_vector(N_LINKS-1 downto 0);
    signal subdet_reg               : work.util.rw_t;

    signal run_state_125            : run_state_t;
    signal run_state_156            : run_state_t;
    signal run_state_125_prev       : run_state_t;
    signal ack_run_prep_permission  : std_logic;
    signal common_fifos_almost_full : std_logic_vector(N_LINKS-1 downto 0);
    signal s_run_state_all_done     : std_logic;

    -- TMB interface / internal signals after selecting connector
    signal tile_testpulse           : std_logic; -- test pulse injection
    signal tile_module_reset        : std_logic_vector(N_MODULES-1 downto 0);

    -- tile_din cannot be a signal just for the selected connector since we need all 26 inputs to go to the same rx_block
    signal tile_din                    : std_logic_vector(12 downto 0);

    --overheat shutdown
    signal spare_clk_osc_e      : std_logic;
    signal pb_reset_n           : std_logic_vector(PushButton'range);
    signal shutdown             : std_logic := '0'; -- overheat shutdown

	-- UART to Testboard MCU
	signal mutrig_I_uart_txd               : std_logic;
	signal mutrig_I_uart_rxd               : std_logic;
	signal mutrig_I_uart_dir               : std_logic;
	signal mutrig_I_uart_select            : std_logic_vector(1 downto 0);

begin
    --unused nets
    lcd_csn  <= '0';
    lcd_d_cn <= '0';
    lcd_data(7 downto 5) <= "000";
    lcd_wen  <= '0';
    debug_almost_full <= (others =>'0');
    FPGA_Test(7 downto 3) <= "00000";

    --overheat shutdown
    spare_clk_osc_e <= spare_clk_osc when shutdown = '0' else '0';
    pb_reset_n <= pb_db_n when shutdown = '0' else (others => '0');

    --clock / reset assignments
    clk_125 <= lvds_firefly_clk;

    e_reset_125_n : entity work.reset_sync
    port map ( i_areset_n => pb_reset_n(0), o_reset_n => reset_125_n, i_clk => clk_125 );

    clk_156 <= transceiver_pll_clock(0);

    e_reset_156_n : entity work.reset_sync
    port map ( i_areset_n => pb_reset_n(0), o_reset_n => reset_156_n, i_clk => clk_156 );



--------------------------------------------------------------------
--------------------------------------------------------------------
----TILE SUB-DETECTOR FIRMWARE -------------------------------------
--------------------------------------------------------------------
--------------------------------------------------------------------

    -- io inversions:



	-- Selection/Assignment of connector pinout.
	mutrig_pll_test   <= (others => tile_testpulse);

	tile_din(3 downto 0) <= mutrig_din(3 downto 0);

	mutrig_pll_reset(3 downto 0)  <= tile_module_reset(3 downto 0);
    --pll_reset(3) has inverted pin-pair on FEB-level (fast_reset_E vs spare_out3)

    -- Select UART
	mutrig_uart_txd   <= (others => mutrig_I_uart_txd);
	--mutrig_uart_txd(0) <= '1' when mutrig_I_uart_select="00" else '0';
	--mutrig_uart_txd(1) <= '1' when mutrig_I_uart_select="01" else '0';
	--mutrig_uart_txd(2) <= '1' when mutrig_I_uart_select="10" else '0';
	--mutrig_uart_txd(3) <= '1' when mutrig_I_uart_select="11" else '0';

	mutrig_I_uart_rxd    <= mutrig_uart_rxd(0) when mutrig_I_uart_select="00" else 
                          mutrig_uart_rxd(1) when mutrig_I_uart_select="01" else 
                          mutrig_uart_rxd(2) when mutrig_I_uart_select="10" else 
                          mutrig_uart_rxd(3) when mutrig_I_uart_select="11" else
                          '0';
	mutrig_uart_dir(0) <= mutrig_I_uart_dir when mutrig_I_uart_select="00" else '0';
	mutrig_uart_dir(1) <= mutrig_I_uart_dir when mutrig_I_uart_select="01" else '0';
	mutrig_uart_dir(2) <= mutrig_I_uart_dir when mutrig_I_uart_select="10" else '0';
	mutrig_uart_dir(3) <= mutrig_I_uart_dir when mutrig_I_uart_select="11" else '0';
	
    lcd_data(3 downto 2) <= mutrig_I_uart_select;




    -- inversions from schematic:
	 -- RST: 1011
	 -- INJ: 1111
	 -- DTA: 1010

    -- scitile detector firmware
    e_tile_path : entity work.tile_path
    generic map (
        N_MODULES       => N_MODULES,
        N_INPUTSRX      => 13,
        INPUT_SIGNFLIP  => x"0000000"&"0101",
        RESET_SIGNFLIP  =>            "0111",
        LVDS_PLL_FREQ   => 125.0,
        LVDS_DATA_RATE  => 1250.0--,
    )
    port map (
        i_reg_addr                  => subdet_reg.addr(15 downto 0),
        i_reg_re                    => subdet_reg.re,
        o_reg_rdata                 => subdet_reg.rdata,
        i_reg_we                    => subdet_reg.we,
        i_reg_wdata                 => subdet_reg.wdata,

        o_module_reset              => tile_module_reset,

        o_testpulse                 => tile_testpulse,
        i_data                      => tile_din,


        o_fifo_write                => fifo_write,
        o_fifo_wdata                => fifo_wdata,
        i_common_fifos_almost_full  => common_fifos_almost_full,

        o_fifo_debug_data           => debug_wdata,
        o_fifo_debug_wr             => debug_write,
        i_debug_almost_full         => debug_almost_full,

        i_run_state                 => run_state_125,
        o_run_state_all_done        => s_run_state_all_done,

        i_clk_ref_A                 => LVDS_clk_si1_fpga_A,
        i_clk_ref_B                 => LVDS_clk_si1_fpga_B,

        o_test_led                  => lcd_data(4),

        i_reset_156_n               => reset_156_n,
        i_clk_156                   => clk_156,
        i_reset_125_n               => reset_125_n,
        i_clk_125                   => clk_125--,
    );

--------------------------------------------------------------------
--------------------------------------------------------------------
---- COMMON FIRMWARE PART ------------------------------------------
--------------------------------------------------------------------
--------------------------------------------------------------------

    db1 : entity work.debouncer
    port map (
        i_d(0)      => PushButton(0),
        o_q(0)      => pb_db_n(0),
        i_reset_n   => '1',
        i_clk       => spare_clk_osc_e--,
    );

    db2 : entity work.debouncer
    port map (
        i_d(0)      => PushButton(1),
        o_q(0)      => pb_db_n(1),
        i_reset_n   => '1',
        i_clk       => spare_clk_osc_e--,
    );

    e_fe_block : entity work.fe_block_v2_rs485
    generic map (
        g_NIOS_CLK_MHZ  => 50.0,
        g_LINKS => N_LINKS,
        g_SUBDETECTOR_SC_TREE_DEPTH => 2--,
    )
    port map (
        i_fpga_id           => ref_adr,
        i_fpga_type         => TILE_HEADER_ID,
        io_i2c_ffly_scl     => Firefly_Scl,
        io_i2c_ffly_sda     => Firefly_Sda,
        o_i2c_ffly_ModSel_n => Firefly_ModSel_n,
        o_ffly_Rst_n        => Firefly_Rst_n,
        i_ffly_Int_n        => Firefly_Int_n,
        i_ffly_ModPrs_n     => Firefly_ModPrs_n,

        i_spi_miso          => '-',
        o_spi_mosi          => open,
        o_spi_sclk          => open,
        --o_spi_ss_n          => open,

        i_i2c_scl           => '1',
        o_i2c_scl_oe        => open,
        i_i2c_sda           => '1',
        o_i2c_sda_oe        => open,

        o_uart485_0_txd     => mutrig_I_uart_txd,
        o_uart485_0_txe     => mutrig_I_uart_dir,
        i_uart485_0_rxd     => mutrig_I_uart_rxd,
        --o_uart485_0_rts_n   => mutrig_I_uart_select,
        o_spi_ss_n(1 downto 0) => mutrig_I_uart_select,

        i_spi_si_miso       => si45_spi_out,
        o_spi_si_mosi       => si45_spi_in,
        o_spi_si_sclk       => si45_spi_sclk,
        o_spi_si_ss_n       => si45_spi_cs_n,

        o_si45_oe_n         => si45_oe_n,
        i_si45_intr_n       => si45_intr_n,
        i_si45_lol_n        => si45_lol_n,
        o_si45_rst_n        => si45_rst_n,
        o_si45_fdec         => si45_fdec,
        o_si45_finc         => si45_finc,

        o_ffly1_tx          => firefly1_tx_data,
        o_ffly2_tx          => firefly2_tx_data,
        i_ffly1_rx          => firefly1_rx_data,
        i_ffly2_rx          => firefly2_rx_data,

        i_ffly1_lvds_rx     => firefly1_lvds_rx_in,
        i_ffly2_lvds_rx     => firefly2_lvds_rx_in,

        i_can_terminate     => s_run_state_all_done,

        i_fifo_write        => fifo_write,
        i_fifo_wdata        => fifo_wdata,
        o_fifos_almost_full => common_fifos_almost_full,
        --i_debug_wdata       => debug_wdata,
        --i_debug_write       => debug_write,
        --o_debug_almost_full => debug_almost_full,

        i_mscb_data         => mscb_fpga_in,
        o_mscb_data         => mscb_fpga_out,
        o_mscb_oe           => mscb_fpga_oe_n,

        o_max10_spi_sclk    => max10_spi_miso, --max10_spi_sclk, Replacement, due to broken line, see known issues in https://www.physi.uni-heidelberg.de/Forschung/he/mu3e/restricted/notes/Mu3e-Note-0057-Frontendboard_v2_0_Manual.pdf
        io_max10_spi_mosi   => max10_spi_mosi,
        io_max10_spi_miso   => 'Z',
        io_max10_spi_D1     => max10_spi_D1,
        io_max10_spi_D2     => max10_spi_D2,
        io_max10_spi_D3     => max10_spi_D3,
        o_max10_spi_csn     => max10_spi_csn,

        o_subdet_reg_addr   => subdet_reg.addr(15 downto 0),
        o_subdet_reg_re     => subdet_reg.re,
        i_subdet_reg_rdata  => subdet_reg.rdata,
        o_subdet_reg_we     => subdet_reg.we,
        o_subdet_reg_wdata  => subdet_reg.wdata,

        -- reset system
        o_run_state_125             => run_state_125,
        i_ack_run_prep_permission   => '1', -- KB:TODO: do we want to keep things until ready? - reimplement all_ready?

        -- clocks
        i_nios_clk          => spare_clk_osc_e,
        o_nios_clk_mon      => lcd_data(0),
        i_clk_156           => clk_156,
        o_clk_156_mon       => lcd_data(1),
        i_clk_125           => clk_125,

        i_shutdown_max      => fpga_reset,
        o_shutdown          => shutdown,

        i_areset_n          => '1'--,--pb_db(0)--,
    );

    max10_spi_sclk <= '1'; -- This is temporary until we only have v2.1 boards with the
    -- correct connection; for now we use it to know 2.1 from 2.0

    --FPGA_Test(0) <= clk_156;
    --FPGA_Test(1) <= clk_125;
    --FPGA_Test(2) <= clk_125_top;
    FPGA_Test(0) <= tile_testpulse;


end architecture;
