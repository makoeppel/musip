library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;
use work.mudaq.all;

entity tile_path is
generic (
    N_MODULES : positive;
    N_INPUTSRX : positive := 13;
    INPUT_SIGNFLIP : std_logic_vector := (31 downto 0 => '0');
    RESET_SIGNFLIP : std_logic_vector(3 downto 0) := X"0";
    LVDS_PLL_FREQ : real;
    LVDS_DATA_RATE : real--;
);
port (
    -- read latency - 1
    i_reg_addr      : in    std_logic_vector(15 downto 0);
    i_reg_re        : in    std_logic;
    o_reg_rdata     : out   std_logic_vector(31 downto 0);
    i_reg_we        : in    std_logic;
    i_reg_wdata     : in    std_logic_vector(31 downto 0);

    -- to detector module
    o_module_reset  : out   std_logic_vector(N_MODULES-1 downto 0);
    o_testpulse     : out   std_logic;
    i_data          : in    std_logic_vector(N_INPUTSRX-1 downto 0);

    -- data out to common firmware
    o_fifo_wdata    : out   std_logic_vector(36-1 downto 0);
    o_fifo_write    : out   std_logic_vector(0 downto 0);
    i_common_fifos_almost_full : in std_logic_vector(0 downto 0);
    o_fifo_debug_data           : out std_logic_vector(36-1 downto 0);
    o_fifo_debug_wr             : out std_logic_vector(0 downto 0);
    i_debug_almost_full         : in  std_logic_vector(0 downto 0);

    -- simulation inputs
    --i_enablesim             : in  std_logic := '0';
    --i_simdata               : in  std_logic_vector(8*N_MODULES * N_INPUTSRX-1 downto 0) := (others => '0');
    --i_simdatak              : in  std_logic_vector(N_MODULES * N_INPUTSRX-1 downto 0) := (others => '0');

    -- reset system
    i_run_state             : in  run_state_t; --run state sync to i_clk_125
    o_run_state_all_done    : out std_logic; -- all fifos empty, all data read

    -- 125 MHz
    i_clk_ref_A             : in  std_logic; -- lvds reference only
    i_clk_ref_B             : in  std_logic; -- lvds reference only

    o_test_led              : out std_logic;

    i_reset_156_n           : in  std_logic;
    i_clk_156               : in  std_logic;
    i_reset_125_n           : in  std_logic;
    i_clk_125               : in  std_logic--;
);
end entity;

architecture arch of tile_path is

    -- MuTrig PLL test
    signal s_testpulse : std_logic;
    signal s_rec_frame_info_rdy: std_logic_vector(N_INPUTSRX - 1 downto 0);
    -- Slow control / Registers
    signal i_SC_mutrig, o_SC_mutrig : work.mutrig_sc_types.t_sc_mutrig;
    signal sc_iram                          : work.util.rw_t;
    signal sc_regs                          : work.util.rw_t;
    signal mt_sorter_reg                    : work.util.rw_t;


    -- counters
    signal s_counter, s_lvds_status : std_logic_vector(31 downto 0);
    signal s_addr_counter : std_logic_vector(9 downto 0);
    signal s_addr_lvds_status : std_logic_vector(15 downto 0);    

    -- chip reset synchronization/shift
    signal s_module_rst                       : std_logic;
    signal s_module_resets                    : std_logic_vector(N_MODULES-1 downto 0);

    function f_xor_vs (v : in std_logic_vector(N_MODULES-1 downto 0); s : in std_logic) return std_logic_vector is
      variable vo : std_logic_vector(N_MODULES-1 downto 0);
      begin
        for i in v'range loop
          vo(i) := v(i) xor s;
        end loop;
      return vo;
    end function f_xor_vs;

begin
    --unused nets
    o_test_led <= '0';

    ---- 100 kHz for PLL test ----
    e_test_pulse : entity work.clkdiv
    generic map ( g_N => 1250 )
    port map ( o_clk => s_testpulse, i_reset_n => not i_run_state(RUN_STATE_BITPOS_SYNC), i_clk => i_clk_125 );
    o_testpulse <= '0' when o_SC_mutrig.pll_test_mode(0) = '0' else s_testpulse;

    ---- Register mapping ----
    e_lvl1_sc_node : entity work.sc_node
      generic map (
        g_SLAVE1_ADDR_MATCH => "0000------------",
        g_SLAVE2_ADDR_MATCH => "00010000--------"--, --X"10xx"
      )
      port map (
        i_master_addr  => i_reg_addr,
        i_master_re    => i_reg_re,
        o_master_rdata => o_reg_rdata,
        i_master_we    => i_reg_we,
        i_master_wdata => i_reg_wdata,

        o_slave0_addr  => sc_regs.addr(15 downto 0),
        o_slave0_re    => sc_regs.re,
        i_slave0_rdata => sc_regs.rdata,
        o_slave0_we    => sc_regs.we,
        o_slave0_wdata => sc_regs.wdata,

        o_slave1_addr  => sc_iram.addr(15 downto 0),
        o_slave1_re    => open,
        i_slave1_rdata => sc_iram.rdata,
        o_slave1_we    => sc_iram.we,
        o_slave1_wdata => sc_iram.wdata,
        o_slave2_addr  => mt_sorter_reg.addr(15 downto 0),
        o_slave2_re    => mt_sorter_reg.re,
        i_slave2_rdata => mt_sorter_reg.rdata,
        o_slave2_we    => mt_sorter_reg.we,
        o_slave2_wdata => mt_sorter_reg.wdata,

        i_reset_n      => i_reset_156_n,
        i_clk          => i_clk_156--,
    );

    e_reg_mapping : entity work.mutrig_reg_mapping
    generic map (
        N_MODULES => N_MODULES, --unused
        N_INPUTSRX  => N_INPUTSRX--,
    )
    port map (
        i_reg_addr   => sc_regs.addr(15 downto 0),
        i_reg_re     => sc_regs.re,
        o_reg_rdata  => sc_regs.rdata,
        i_reg_we     => sc_regs.we,
        i_reg_wdata  => sc_regs.wdata,

        -- inputs
        i_SC_mutrig  => i_SC_mutrig,
        i_counter    => s_counter,
        i_lvds_status => s_lvds_status,
        -- outputs
        o_addr_counter => s_addr_counter,
        o_addr_lvds_status => s_addr_lvds_status,

        o_SC_mutrig  => o_SC_mutrig,
        o_SC_mutrig_156 => open,

        i_clk_125     => i_clk_125,
        i_reset_n     => i_reset_156_n,
        i_reset_125_n => i_reset_125_n,
        i_clk         => i_clk_156--,
    );

    e_sc_iram : entity work.ram_1r1w
    generic map (
        g_DATA_WIDTH => 32,
        g_ADDR_WIDTH => 12--,
    )
    port map (
        i_raddr => sc_iram.addr(11 downto 0),
        o_rdata => sc_iram.rdata,
        i_rclk  => i_clk_156,

        i_waddr => sc_iram.addr(11 downto 0),
        i_wdata => sc_iram.wdata,
        i_we    => sc_iram.we,
        i_wclk  => i_clk_156--,
    );

    ---- Reset ----
    s_module_rst    <= (not i_reset_125_n) or o_SC_mutrig.subdet_reset(0) or i_run_state(RUN_STATE_BITPOS_SYNC);
    s_module_resets <= f_xor_vs(RESET_SIGNFLIP(N_MODULES-1 downto 0), s_module_rst);
	 
    e_resetshift : entity work.rst_shift_block
	 generic map (P_WIDTH => 4)
    port map (
        i_d         => s_module_resets,  -- datain
        i_clk_125   => i_clk_125,                     -- data clk
        i_clk       => i_clk_156,                     -- reconfiguration clk
        i_reset_125_n => i_reset_125_n,               -- sync reset
        i_reset_n   => i_reset_156_n,                 -- reconfiguration reset
        i_cdata     => o_SC_mutrig.subdet_resetdly(23 downto 0), -- reconfiguration input
        i_we        => o_SC_mutrig.subdet_resetdly_written,  -- reconfiguration state machine start signal
        o_d         => o_module_reset                 -- dataout shifted
    );

    ---- Tile Datapath ----
    e_mutrig_datapath : entity work.tile_datapath
    generic map (
        N_INPUTSRX      => N_INPUTSRX,
        LVDS_PLL_FREQ   => LVDS_PLL_FREQ,
        LVDS_DATA_RATE  => LVDS_DATA_RATE,
        INPUT_SIGNFLIP  => INPUT_SIGNFLIP--,
    )
    port map (

        -- RX part
        --i_rst_rx                    => not s_lvds_rx_rst_n,
        i_data                      => i_data,
        i_refclk_125_A              => i_clk_ref_A,
        i_refclk_125_B              => i_clk_ref_B,

        -- interface to asic fifos
        o_fifo_data                 => o_fifo_wdata,
        o_fifo_wr                   => o_fifo_write(0),
        i_common_fifos_almost_full  => i_common_fifos_almost_full(0),
        o_fifo_debug_data           => o_fifo_debug_data,
        o_fifo_debug_wr             => o_fifo_debug_wr(0),
        i_debug_almost_full         => i_debug_almost_full(0),

        -- slow control / monitoring
        i_SC_mutrig                 => o_SC_mutrig,
        o_SC_mutrig                 => i_SC_mutrig,

        i_addr_counter              => s_addr_counter,
        i_addr_lvds_status          => s_addr_lvds_status,
        o_counter                   => s_counter,
        o_lvds_status               => s_lvds_status,
        -- slow control node for the sorter
        i_reg_addr                  => mt_sorter_reg.addr(15 downto 0),
        i_reg_re                    => mt_sorter_reg.re,
        o_reg_rdata                 => mt_sorter_reg.rdata,
        i_reg_we                    => mt_sorter_reg.we,
        i_reg_wdata                 => mt_sorter_reg.wdata,

        -- simulation
        --i_enablesim                 => i_enablesim,
        --i_simdata                   => i_simdata,
        --i_simdatak                  => i_simdatak,

        -- run control
        i_RC_may_generate           => i_run_state(RUN_STATE_BITPOS_RUNNING),
        o_RC_all_done               => o_run_state_all_done,
        i_run_state_125             => i_run_state,
        o_rec_frame_info_rdy        => s_rec_frame_info_rdy,

        -- reset / clk
        i_reset_156_n               => i_reset_156_n,
        i_clk_156                   => i_clk_156,
        i_reset_125_n               => i_reset_125_n,
        i_clk_125                   => i_clk_125--,

    );

end architecture;
