----------------------------------------
-- Mupix version of the Frontend Board
-- Martin Mueller, September 2020
----------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;
use work.mupix.all;

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

    -- Block A: Connections for three chips -- layer 0
    clock_A                     : out   std_logic;
    data_in_A                   : in    std_logic_vector(9 downto 1);
    fast_reset_A                : out   std_logic;
    SIN_A                       : out   std_logic;
    mosi_A                      : out   std_logic;
    csn_A                       : out   std_logic_vector(1 downto 0);

    -- Block B: Connections for three chips -- layer 0
    clock_B                     : out   std_logic;
    data_in_B                   : in    std_logic_vector(9 downto 1);
    fast_reset_B                : out   std_logic;
    SIN_B                       : out   std_logic;
    mosi_B                      : out   std_logic;
    csn_B                       : out   std_logic_vector(1 downto 0);

    -- Block C: Connections for three chips -- layer 1
    clock_C                     : out   std_logic;
    data_in_C                   : in    std_logic_vector(9 downto 1);
    fast_reset_C                : out   std_logic;
    SIN_C                       : out   std_logic;
    mosi_C                      : out   std_logic;
    csn_C                       : out   std_logic_vector(1 downto 0);

    -- Block D: Connections for three chips -- layer 1
    clock_D                     : out   std_logic;
    data_in_D                   : in    std_logic_vector(9 downto 1);
    fast_reset_D                : out   std_logic;
    SIN_D                       : out   std_logic;
    mosi_D                      : out   std_logic;
    csn_D                       : out   std_logic_vector(1 downto 0);

    -- Block E: Connections for three chips -- layer 1
    -- clock_E                     : out   std_logic;
    -- data_in_E                   : in    std_logic_vector(9 downto 1);
    -- fast_reset_E                : out   std_logic;
    -- SIN_E                       : out   std_logic;

    -- Extra signals

    --clock_aux                   : out   std_logic; -- Pin in use for csn_A[2] M.Mueller
    --spare_out                   : out   std_logic_vector(3 downto 2); -- Pins in use for csn_* M.Mueller

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
    FPGA_Test                   : in    std_logic_vector(7 downto 0);

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
    max10_spi_csn               : out   std_logic--;
);
end entity;

architecture rtl of top is

    -- Debouncers
    signal pb_db_n                  : std_logic_vector(1 downto 0);
    signal spare_clk_osc_e          : std_logic;

    constant NPORTS                 : integer := 4;
    constant N_LINKS                : integer := 1;
    constant g_N_SPI                : integer := 4;
    constant g_CHIPS_PER_SPI        : integer := 2;

    signal fifo_write               : std_logic_vector(N_LINKS-1 downto 0);
    signal fifo_wdata               : std_logic_vector(36*(N_LINKS-1)+35 downto 0);

    signal data_bypass              : std_logic_vector(31 downto 0);
    signal data_bypass_we           : std_logic;

    signal mupix_reg                : work.util.rw_t;

    signal i2c_scl, i2c_scl_oe, i2c_sda, i2c_sda_oe : std_logic;
    signal spi_miso, spi_mosi, spi_sclk : std_logic;
    signal spi_ss_n                 : std_logic_vector(15 downto 0);

    signal run_state_125            : run_state_t;
    signal run_state_125_reg        : run_state_t;
    signal run_state_156            : run_state_t;
    signal ack_run_prep_permission  : std_logic;

    signal sync_reset_cnt           : std_logic;
    signal nios_clock               : std_logic;

    signal mp_ctrl_clock            : std_logic_vector(g_N_SPI-1 downto 0);
    signal mp_ctrl_SIN              : std_logic_vector(g_N_SPI-1  downto 0);
    signal mp_ctrl_mosi             : std_logic_vector(g_N_SPI-1  downto 0);
    signal mp_ctrl_cs               : std_logic_vector(g_N_SPI*g_CHIPS_PER_SPI-1 downto 0);

    signal shutdown                 : std_logic := '0'; -- overheat shutdown
    signal pb_reset_n               : std_logic_vector(1  downto 0);

    signal trig_en                  : std_logic;
    signal trig_ts_final            : std_logic_vector(31 downto 0);

begin

    spare_clk_osc_e <= spare_clk_osc when ( shutdown = '0' ) else '0';
    pb_reset_n <= pb_db_n when ( shutdown = '0' ) else (others => '0');

--------------------------------------------------------------------
--------------------------------------------------------------------
----MUPIX SUB-DETECTOR FIRMWARE ------------------------------------
--------------------------------------------------------------------
--------------------------------------------------------------------

    clock_A <= mp_ctrl_clock(0);
    clock_B <= mp_ctrl_clock(1);
    clock_C <= mp_ctrl_clock(2);
    clock_D <= mp_ctrl_clock(3);

    -- NOTE: in a second version one can use this pin and not fast_reset_
    SIN_A <= '0'; --mp_ctrl_SIN(0);
    SIN_B <= '0'; --mp_ctrl_SIN(1);
    SIN_C <= '0'; --mp_ctrl_SIN(2);
    SIN_D <= '0'; --mp_ctrl_SIN(3);

    -- use this for serial out
    -- here the line is inverted
    fast_reset_B <= '1' when run_state_125_reg = RUN_STATE_SYNC else mp_ctrl_SIN(0);  -- MP 1 ("0000") & MP 2 ("0001") QUAD 1
    fast_reset_A <= '1' when run_state_125_reg = RUN_STATE_SYNC else mp_ctrl_SIN(1);  -- MP 3 ("0000") & MP 4 ("0001") QUAD 1
    fast_reset_D <= '1' when run_state_125_reg = RUN_STATE_SYNC else mp_ctrl_SIN(2);  -- MP 1 & MP 2 QUAD 2
    fast_reset_C <= '1' when run_state_125_reg = RUN_STATE_SYNC else mp_ctrl_SIN(3);  -- MP 3 & MP 4 QUAD 2

    mosi_A <= mp_ctrl_mosi(0);
    mosi_B <= mp_ctrl_mosi(1);
    mosi_C <= mp_ctrl_mosi(2);
    mosi_D <= mp_ctrl_mosi(3);

    csn_A <= mp_ctrl_cs(g_CHIPS_PER_SPI*0 + g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*0);
    csn_B <= mp_ctrl_cs(g_CHIPS_PER_SPI*1 + g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*1);
    csn_C <= mp_ctrl_cs(g_CHIPS_PER_SPI*2 + g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*2);
    csn_D <= mp_ctrl_cs(g_CHIPS_PER_SPI*3 + g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*3);

    e_mupix_block : entity work.mupix_block
    generic map (
        g_SIN_INVERT => '0',
        g_IS_QUAD => '1',
        g_USE_TRIGGER => 1,
        g_N_SPI => g_N_SPI,
        g_CHIPS_PER_SPI => g_CHIPS_PER_SPI,
        g_IS_TELESCOPE => '0',
        g_LINK_ORDER => MP_LINK_ORDER_QUAD_MODULE,
        g_MP_LADDER_ADDR_ARRAY => MP_LADDER_ADDR_ARRAY_QUAD,
        g_LINK_INVERT => MP_LINK_INVERT_QUAD--,
    )
    port map (
        i_fpga_id               => ref_adr,

        -- config signals to mupix
        o_clock                 => mp_ctrl_clock,
        o_SIN                   => mp_ctrl_SIN,
        o_mosi                  => mp_ctrl_mosi,
        o_cs                    => mp_ctrl_cs,

        -- mupix dac regs
        i_reg_addr              => mupix_reg.addr(15 downto 0),
        i_reg_re                => mupix_reg.re,
        o_reg_rdata             => mupix_reg.rdata,
        i_reg_we                => mupix_reg.we,
        i_reg_wdata             => mupix_reg.wdata,

        -- data
        o_fifo_wdata            => fifo_wdata,
        o_fifo_write            => fifo_write(0),

        o_data_bypass           => data_bypass,
        o_data_bypass_we        => data_bypass_we,

        i_run_state_125           => run_state_125_reg,
        i_run_state_156           => run_state_156,
        o_ack_run_prep_permission => ack_run_prep_permission,

        i_lvds_data_in          => data_in_D & data_in_C & data_in_B & data_in_A,

        -- 156.25 MHz
        i_clk_156               => transceiver_pll_clock(0),
        i_clk_125               => lvds_firefly_clk,
        i_lvds_rx_inclock_A     => LVDS_clk_si1_fpga_A,
        i_lvds_rx_inclock_B     => LVDS_clk_si1_fpga_B,
        i_sync_reset_cnt        => sync_reset_cnt,

        -- trigger for quad module
        i_trigger_en            => trig_en,
        i_trigger_timestamp     => trig_ts_final,

        i_areset_n              => pb_reset_n(1)--,
    );

    -- trigger for quad module
    e_trigger : entity work.trigger_500MHz
    generic map (
        g_N     => 4,
        g_ToT   => "0000"--,
    )
    port map (
        o_trig          => trig_ts_final,
        o_trig_en       => trig_en,
        i_trigger       => FPGA_Test(7) & FPGA_Test(6) & FPGA_Test(5) & FPGA_Test(4),
        i_run_state_125 => run_state_125_reg,
        i_reset_n       => pb_reset_n(1),
        i_clk           => lvds_firefly_clk--,
    );

    process(lvds_firefly_clk)
    begin
    if rising_edge(lvds_firefly_clk) then
        run_state_125_reg <= run_state_125;
        if(run_state_125_reg = RUN_STATE_SYNC)then
            --fast_reset_A    <= '1';
            --fast_reset_B    <= '1';
            --fast_reset_C    <= '1';
            --fast_reset_D    <= '1';
            --fast_reset_E    <= '1';
            sync_reset_cnt  <= '1';
        else
            --fast_reset_A    <= '0';
            --fast_reset_B    <= '0';
            --fast_reset_C    <= '0';
            --fast_reset_D    <= '0';
            --fast_reset_E    <= '0';
            sync_reset_cnt  <= '0';
        end if;
    end if;
    end process;

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

    e_fe_block : entity work.fe_block_v2
    generic map (
        g_NIOS_CLK_MHZ  => 50.0,
        g_SUBDETECTOR_SC_TREE_DEPTH => 4--,
    )
    port map (
        i_fpga_id           => ref_adr,
        i_fpga_type         => MUPIX_HEADER_ID,

        io_i2c_ffly_scl     => Firefly_Scl,
        io_i2c_ffly_sda     => Firefly_Sda,
        o_i2c_ffly_ModSel_n => Firefly_ModSel_n,
        o_ffly_Rst_n        => Firefly_Rst_n,
        i_ffly_Int_n        => Firefly_Int_n,
        i_ffly_ModPrs_n     => Firefly_ModPrs_n,

        i_spi_miso          => '1',
        o_spi_mosi          => open,
        o_spi_sclk          => open,
        o_spi_ss_n          => open,

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

        i_fifo_write        => fifo_write,
        i_fifo_wdata        => fifo_wdata,

        i_data_bypass       => open,
        i_data_bypass_we    => open,

        i_mscb_data         => mscb_fpga_in,
        o_mscb_data         => mscb_fpga_out,
        o_mscb_oe           => mscb_fpga_oe_n,

        -- NOTE: replacement, due to broken line (see known issues in
        -- <https://www.physi.uni-heidelberg.de/Forschung/he/mu3e/restricted/notes/Mu3e-Note-0057-Frontendboard_v2_0_Manual.pdf>)
        o_max10_spi_sclk    => max10_spi_miso, --max10_spi_sclk
        io_max10_spi_mosi   => max10_spi_mosi,
        io_max10_spi_miso   => 'Z',
        io_max10_spi_D1     => max10_spi_D1,
        io_max10_spi_D2     => max10_spi_D2,
        io_max10_spi_D3     => max10_spi_D3,
        o_max10_spi_csn     => max10_spi_csn,

        o_subdet_reg_addr   => mupix_reg.addr(15 downto 0),
        o_subdet_reg_re     => mupix_reg.re,
        i_subdet_reg_rdata  => mupix_reg.rdata,
        o_subdet_reg_we     => mupix_reg.we,
        o_subdet_reg_wdata  => mupix_reg.wdata,

        -- reset system
        o_run_state_125     => run_state_125,
        o_run_state_156     => run_state_156,
        i_ack_run_prep_permission => ack_run_prep_permission,

        -- clocks
        i_nios_clk          => spare_clk_osc_e,
        o_nios_clk_mon      => lcd_data(0),
        i_clk_156           => transceiver_pll_clock(0),
        o_clk_156_mon       => lcd_data(1),
        i_clk_125           => lvds_firefly_clk,

        i_shutdown_max      => fpga_reset,
        o_shutdown          => shutdown,

        i_areset_n          => pb_reset_n(0)--,
    );

    max10_spi_sclk <= '1'; -- This is temporary until we only have v2.1 boards with the
    -- correct connection; for now we use it to know 2.1 from 2.0


    --FPGA_Test(0) <= transceiver_pll_clock(0);
    --FPGA_Test(1) <= lvds_firefly_clk;
    --FPGA_Test(2) <= clk_125_top;

end architecture;
