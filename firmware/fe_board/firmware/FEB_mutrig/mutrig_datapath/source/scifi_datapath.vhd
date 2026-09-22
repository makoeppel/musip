-- File name: scifi_datapath.vhd
-- Author: Marius Köppel, Yifeng Wang, Konrad Briggle
-- =======================================
-- Version : 26.8.0
-- Date    : 20260817
-- Change  : Add the readyless post-MTS histogram. Both bank wrappers feed one
--           eight-ASIC observation plane through scifi_histogram_adapter into
--           one histogram_statistics_v2, with an end-of-run drain owner that
--           holds RUNNING until the observed plane is quiet. The sorter and
--           legacy paths are unchanged.
-- Version : 26.4.6
-- Date    : 20260608
-- Change  : Change the prbs + lapse correction with MTS IP
-- =======================================
--
-- Mu3e Scifi Datapath
-- Marius Köppel, Konrad Briggle based on Simon Corrodi based on KIP DAQ

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;
use work.mutrig.all;
use work.lvds_registers.all;
use work.sorter_pkg.all;
use work.mudaq.all;
use work.mutrig_hit_types.all;


entity scifi_datapath is
generic(
    N_INPUTSRX          : positive := 13;
    LVDS_PLL_FREQ       : real := 125.0;
    LVDS_DATA_RATE      : real := 1250.0;
    INPUT_SIGNFLIP      : std_logic_vector(31 downto 0):=x"00000000";
    C_ASICNO_PREFIX     : std_logic_vector(13*4-1 downto 0):=x"CBA9876543210"; -- [mts-int] keep existing ASIC prefix before the phase-1 path switch.
    USE_MTS             : boolean := true -- [mts-int] default SciFi timestamp path uses the MTS lane; false keeps legacy lapse/divide path.
);
port (
    -- RX part
    i_data                      : in  std_logic_vector(N_INPUTSRX-1 downto 0);   -- serial data
    i_refclk_125_A              : in  std_logic;    -- ref clk for lvds pll (A-Side)
    i_refclk_125_B              : in  std_logic;    -- ref clk for lvds pll (B-Side)
    i_scifi_lvds_los_n          : in    std_logic_vector(7 downto 0);

    -- interface to asic fifos
    o_fifo_data                 : out std_logic_vector(71 downto 0);
    o_fifo_wr                   : out std_logic_vector(1 downto 0);
    i_common_fifos_almost_full  : in  std_logic_vector(1 downto 0);
    o_fifo_debug_data           : out std_logic_vector(71 downto 0);
    o_fifo_debug_wr             : out std_logic_vector(1 downto 0);
    i_debug_almost_full         : in  std_logic_vector(1 downto 0);

    -- slow control / monitoring
    i_SC_mutrig                 : in  work.mutrig_sc_types.t_sc_mutrig;
    i_SC_mutrig_156             : in  work.mutrig_sc_types.t_sc_mutrig;
    o_SC_mutrig                 : out work.mutrig_sc_types.t_sc_mutrig;
    i_addr_counter              : in  std_logic_vector(9 downto 0);
    i_addr_lvds_status          : in  std_logic_vector(15 downto 0);
    o_counter                   : out std_logic_vector(31 downto 0);
    o_lvds_status               : out std_logic_vector(31 downto 0);
    i_scifi_temp_mutrig         : in  slv32_array_t(N_INPUTSRX-1 downto 0) := (others => (others => '1'));
    i_scifi_temp_sipm           : in  slv32_array_t(N_INPUTSRX-1 downto 0) := (others => (others => '1'));
    i_scifi_temp_dab            : in  slv32_array_t(N_INPUTSRX-1 downto 0) := (others => (others => '1'));

    -- sorter reg mapping
    i_reg_addr                  : in  std_logic_vector(15 downto 0);
    i_reg_re                    : in  std_logic;
    o_reg_rdata                 : out std_logic_vector(31 downto 0);
    i_reg_we                    : in  std_logic;
    i_reg_wdata                 : in  std_logic_vector(31 downto 0);

    -- histogram Avalon-MM slaves (125 MHz), bridged from the Mu3e SC tree
    i_hist_csr_address          : in  std_logic_vector(4 downto 0) := (others => '0');
    i_hist_csr_read             : in  std_logic := '0';
    i_hist_csr_write            : in  std_logic := '0';
    i_hist_csr_writedata        : in  std_logic_vector(31 downto 0) := (others => '0');
    o_hist_csr_waitrequest      : out std_logic := '0';
    o_hist_csr_readdata         : out std_logic_vector(31 downto 0) := (others => '0');
    i_hist_bin_address          : in  std_logic_vector(7 downto 0) := (others => '0');
    i_hist_bin_read             : in  std_logic := '0';
    i_hist_bin_write            : in  std_logic := '0';
    i_hist_bin_writedata        : in  std_logic_vector(31 downto 0) := (others => '0');
    i_hist_bin_burstcount       : in  std_logic_vector(8 downto 0) := (others => '0');
    o_hist_bin_waitrequest      : out std_logic := '0';
    o_hist_bin_readdata         : out std_logic_vector(31 downto 0) := (others => '0');
    o_hist_bin_readdatavalid    : out std_logic := '0';
    o_hist_bin_writeresponsevalid : out std_logic := '0';
    o_hist_bin_response         : out std_logic_vector(1 downto 0) := (others => '0');

    -- run control
    i_RC_may_generate           : in  std_logic; --do not generate new frames for runstates that are not RUNNING, allows to let fifos run empty
    o_RC_all_done               : out std_logic; --all fifos empty, all data read
    i_run_state_125             : in  run_state_t;
    o_rec_frame_info_rdy        : out std_logic_vector(N_INPUTSRX-1 downto 0) := (others => '0');

    -- simulation input
    i_enablesim                 : in  std_logic := '0';
    i_simdata                   : in  std_logic_vector(8*N_INPUTSRX-1 downto 0) := (others => '0');
    i_simdatak                  : in  std_logic_vector(N_INPUTSRX-1 downto 0) := (others => '0');

    -- reset / clk
    i_reset_156_n               : in  std_logic;
    i_clk_156                   : in  std_logic;
    i_ts_rst                    : in  std_logic;
    i_reset_125_n               : in  std_logic;
    i_clk_125                   : in  std_logic--;
);
end entity;

architecture rtl of scifi_datapath is

    -- reset synchronizers
    signal s_datapath_rst, s_lvds_rx_rst, s_lapse_rst, s_prbs_rst : std_logic;
    signal s_mts_rst : std_logic; -- [mts-int] MTS reset excludes PREP/SYNC so run-control commands reach the processor.

    -- serdes-frame_rcv
    signal s_receivers_ready, s_hits_valid : std_logic_vector(N_INPUTSRX-1 downto 0);
    signal s_receivers_data, s_receivers_data_reg : std_logic_vector(8*N_INPUTSRX-1 downto 0);
    signal s_receivers_data_isk, s_receivers_data_isk_reg : std_logic_vector(N_INPUTSRX-1 downto 0);
    signal lvds_status : lvds_status_array_t(N_INPUTSRX-1 downto 0);

    -- frame_rcv/datagen - fifo: fifo side, frame-receiver side, dummy datagenerator side
    signal s_new_frame, s_frame_info_rdy, s_crc_error, s_rec_crc_error, s_rec_new_frame, s_gen_new_frame, s_rec_frame_info_rdy, s_gen_frame_info_rdy, s_rec_end_of_frame, s_rec_busy : std_logic_vector(N_INPUTSRX-1 downto 0);
    signal s_frame_number, s_frame_info, s_rec_frame_number, s_rec_frame_info, s_gen_frame_number, s_gen_frame_info : slv16_array_t(N_INPUTSRX-1 downto 0);
    signal s_rec_event_data, s_data : work.mutrig_hit_types.t_v_hit_presort(N_INPUTSRX-1 downto 0);

    -- data generator
    signal s_gen_event_data : work.mutrig_hit_types.t_v_hit_presort(N_INPUTSRX-1 downto 0);
    signal s_gen_busy : std_logic_vector(N_INPUTSRX-1 downto 0);

    -- mux
    signal s_mux_data, s_mux_data_prbs_t, s_mux_data_prbs_t_reg : work.mutrig_hit_types.t_v_hit_presort(3 downto 0);
    signal s_mts_data_in : work.mutrig_hit_types.t_v_hit_presort(7 downto 0);

    -- sorter
    type mt_sorter_reg_t is array (natural range <>) of work.util.rw_t;
    signal mt_sorter_regs : mt_sorter_reg_t(1 downto 0);
    signal mts_regs : mt_sorter_reg_t(1 downto 0);
    signal mts_reg_rdata : std_logic_vector(31 downto 0);
    signal mts_reg_selected : std_logic;
    signal s_running : std_logic;
    signal s_counter125 : std_logic_vector(63 downto 0);
    signal out_is_hit : std_logic_vector(1 downto 0);
    signal s_mux_data_prbs_t_div : work.mutrig_hit_types.t_v_hit_presort_div(5 downto 0);
    signal s_mts_ingress_overflow : slv32_array_t(1 downto 0) := (others => (others => '0')); -- [mts-int] per-bank readyless ingress drop counters.

    -- [hist] Readyless histogram observation plane. Two bank wrappers carry
    -- the eight logical ASIC IDs; the adapter demultiplexes on the ASIC field
    -- of the merged Type1 word and never drives a ready back into MTS.
    signal s_mts_hist_valid        : std_logic_vector(1 downto 0);
    signal s_mts_hist_data         : slv39_array_t(1 downto 0);
    signal s_mts_hist_timestamp    : slv48_array_t(1 downto 0);
    signal s_mts_hist_arrival      : slv48_array_t(1 downto 0);
    signal s_mts_hist_latency      : slv48_array_t(1 downto 0);
    signal s_mts_hist_error        : std_logic_vector(1 downto 0);
    signal s_mts_ingress_busy      : std_logic_vector(1 downto 0);

    signal s_hist_valid            : std_logic_vector(7 downto 0);
    signal s_hist_data             : slv39_array_t(7 downto 0);
    signal s_hist_timestamp        : slv48_array_t(7 downto 0);
    signal s_hist_arrival          : slv48_array_t(7 downto 0);
    signal s_hist_latency          : slv48_array_t(7 downto 0);
    signal s_hist_error            : std_logic_vector(7 downto 0);
    signal s_hist_collision_count  : std_logic_vector(31 downto 0);
    signal s_hist_invalid_count    : std_logic_vector(31 downto 0);

    -- [hist] End-of-run drain owner. HIST keeps seeing RUNNING until the
    -- observed plane has been quiet long enough to cover the MTS stages, then
    -- one qualified TERMINATING releases its final bank swap.
    constant HIST_QUIET_TARGET_CONST : unsigned(9 downto 0) := (others => '1');
    signal s_hist_run_state        : run_state_t;
    signal s_hist_upstream_busy    : std_logic := '0';
    signal s_hist_upstream_busy_q  : std_logic := '0';
    signal s_hist_term_pending     : std_logic := '0';
    signal s_hist_term_active      : std_logic := '0';
    signal s_hist_term_seen        : std_logic := '0';
    signal s_hist_term_issue       : std_logic := '0';
    signal s_hist_quiet_streak     : unsigned(9 downto 0) := (others => '0');
    signal sorter_reset_n : std_logic := '1';
    signal sorter_out : slv64_array_t(N_INPUTSRX - 1 downto 0) := (others => (others => '1'));
    signal sorter_in : slv64_array_t(2*N_INPUTSRX - 1 downto 0) := (others => (others => '1'));

    -- pll test register
    signal pll_test_reg : slv64_array_t(N_INPUTSRX-1 downto 0);

    -- sync fifo
    signal fifo_wdata, sync_fifo_wdata_out : std_logic_vector(71 downto 0);
    signal fifo_write, sync_fifo_empty, sync_fifo_write_out : std_logic_vector(1 downto 0);

    -- Mutrig Counters per ASIC N_INPUTSRX
    signal s_asic_hitrate, s_crcerrorcounter, s_frame_rate : slv32_array_t(N_INPUTSRX-1 downto 0);
    signal s_ch_rate : slv32_array_t(N_INPUTSRX*32-1 downto 0);
    signal s_counters : slv32_array_t(16*64-1 downto 0) := (others => (others => '0'));

begin
    -- unused signals
    o_fifo_debug_data <= (others => '0');
    o_fifo_debug_wr   <= (others => '0');
    o_SC_mutrig <= work.mutrig_sc_types.t_sc_mutrig_zero;

    -- select which sorter to read out
    mt_sorter_regs(0).addr(15 downto 0) <= i_reg_addr when i_SC_mutrig_156.sorter_select = '0' else (others => '0');
    mt_sorter_regs(0).re <= i_reg_re when i_SC_mutrig_156.sorter_select = '0' else '0';
    mt_sorter_regs(0).we <= i_reg_we when i_SC_mutrig_156.sorter_select = '0' else '0';
    mt_sorter_regs(0).wdata <= i_reg_wdata when i_SC_mutrig_156.sorter_select = '0' else (others => '0');

    mt_sorter_regs(1).addr(15 downto 0) <= i_reg_addr when i_SC_mutrig_156.sorter_select = '1' else (others => '0');
    mt_sorter_regs(1).re <= i_reg_re when i_SC_mutrig_156.sorter_select = '1' else '0';
    mt_sorter_regs(1).we <= i_reg_we when i_SC_mutrig_156.sorter_select = '1' else '0';
    mt_sorter_regs(1).wdata <= i_reg_wdata when i_SC_mutrig_156.sorter_select = '1' else (others => '0');

    mts_reg_selected <= '1' when i_reg_addr(7 downto 3) = "11111" else '0';
    mts_reg_rdata <= mts_regs(0).rdata when i_reg_addr(2) = '0' else mts_regs(1).rdata;

    o_reg_rdata <=  mts_reg_rdata when mts_reg_selected = '1' else
                    mt_sorter_regs(0).rdata when i_SC_mutrig_156.sorter_select = '0' else
                    mt_sorter_regs(1).rdata;

    gen_mts_reg_decode : for k in 0 to 1 generate
    begin
        mts_regs(k).addr(1 downto 0) <= i_reg_addr(1 downto 0);
        mts_regs(k).addr(31 downto 2) <= (others => '0');
        mts_regs(k).re <= i_reg_re when mts_reg_selected = '1' and unsigned(i_reg_addr(2 downto 2)) = to_unsigned(k, 1) else '0';
        mts_regs(k).we <= i_reg_we when mts_reg_selected = '1' and unsigned(i_reg_addr(2 downto 2)) = to_unsigned(k, 1) else '0';
        mts_regs(k).wdata <= i_reg_wdata;
        gen_legacy_mts_reg_tieoff : if not USE_MTS generate
        begin
            mts_regs(k).rdata <= x"CCCCCCCC";
        end generate;
    end generate;

    --! output counter
    -- assignments according to register definitions in common/firmware/registers/mutrig_registers.vhd
    gen_counters : for i in 0 to N_INPUTSRX - 1 generate
        s_counters( 0+i*64)              <= x"BEEF000" & C_ASICNO_PREFIX(4*i+3 downto i*4); -- ASIC ID
        s_counters( 1+i*64)              <= i_scifi_temp_mutrig(i);    -- temp from mutrig
        s_counters( 2+i*64)              <= i_scifi_temp_sipm(i);      -- temp from sipm
        s_counters( 3+i*64)              <= s_asic_hitrate(i);
        s_counters( 4+i*64)              <= s_counter125(31 downto 0); -- take only the first one
        s_counters( 5+i*64)              <= s_counter125(63 downto 32);
        s_counters( 6+i*64)              <= s_crcerrorcounter(i);
        s_counters( 7+i*64)              <= s_frame_rate(i);
        s_counters(39+i*64 downto 8+i*64)<= s_ch_rate(i*32 + 31 downto i*32);
        s_counters(54+i*64)              <= pll_test_reg(i)(31 downto 0);
        s_counters(55+i*64)              <= pll_test_reg(i)(63 downto 32);
        s_counters(56+i*64)              <= sorter_in(0+i*2)(31 downto 0); -- SORTER IN 0 low
        s_counters(57+i*64)              <= sorter_in(0+i*2)(63 downto 32); -- SORTER IN 0 high
        s_counters(58+i*64)              <= sorter_in(1+i*2)(31 downto 0); -- SORTER IN 1 low
        s_counters(59+i*64)              <= sorter_in(1+i*2)(63 downto 32); -- SORTER IN 1 high
        s_counters(60+i*64)              <= sorter_out(i)(31 downto 0); -- SORTER OUT low
        s_counters(61+i*64)              <= sorter_out(i)(63 downto 32); -- SORTER OUT high
        gen_mts_overflow_counter_up : if USE_MTS and i = 0 generate -- [mts-int] expose the up-bank MTS ingress overflow counter.
        begin -- [mts-int] readyless hit dropped because one of the four up-bank MTS ingress FIFOs was full.
            s_counters(62+i*64)          <= s_mts_ingress_overflow(0); -- TODO: add directed overflow and latency-bound coverage for this counter.
        end generate; -- [mts-int] end up-bank overflow counter slot.
        gen_mts_overflow_counter_down : if USE_MTS and i = 4 generate -- [mts-int] expose the down-bank MTS ingress overflow counter.
        begin -- [mts-int] readyless hit dropped because one of the four down-bank MTS ingress FIFOs was full.
            s_counters(62+i*64)          <= s_mts_ingress_overflow(1);
        end generate; -- [mts-int] end down-bank overflow counter slot.
        gen_legacy_debug_counter : if (not USE_MTS) or (i /= 0 and i /= 4) generate -- [mts-int] preserve the legacy debug word outside bank counter slots.
        begin -- [mts-int] keep non-bank debug counter behavior from the current dev path.
            s_counters(62+i*64)          <= i_scifi_temp_dab(i);
        end generate; -- [mts-int] end legacy debug counter slot.
        s_counters(63+i*64)              <= x"BEEF000" & C_ASICNO_PREFIX(4*i+3 downto i*4); -- ASIC ID
    end generate;

    --o_SC_mutrig.receivers_ready <= s_receivers_ready;
    o_rec_frame_info_rdy <= s_frame_info_rdy;

    e_counter_ram : entity work.counter_ram
    port map (
        i_reg_addr   => i_addr_counter,
        o_reg_rdata  => o_counter,

        i_counter    => s_counters,

        i_reset_we_n => i_reset_125_n,
        i_clk_rd     => i_clk_156,
        i_clk_we     => i_clk_125--,
    );

    --! lvds status
    lvds_rx_reg_mapping_inst: entity work.lvds_rx_status
    generic map (
        g_LVDS_LINKGS => 8--,
    )
    port map (
        i_reg_addr      => i_addr_lvds_status,
        o_reg_rdata     => o_lvds_status,

        i_clk_156       => i_clk_156,

        i_hit_ena       => s_hits_valid,
        i_counter       => s_counter125(31 downto 0),
        i_lvds_status   => lvds_status,

        i_reset_125_n   => i_reset_125_n,
        i_clk_125       => i_clk_125--,
    );

    --! Reset
    s_prbs_rst      <= (not i_reset_125_n) or i_SC_mutrig.subdet_reset(1);
    s_datapath_rst  <= (not i_reset_125_n) or i_SC_mutrig.subdet_reset(1) or i_run_state_125(RUN_STATE_BITPOS_PREP);
    s_lvds_rx_rst   <= (not i_reset_125_n) or i_SC_mutrig.subdet_reset(1) or i_run_state_125(RUN_STATE_BITPOS_RESET);
    s_lapse_rst     <= (not i_reset_125_n) or i_SC_mutrig.subdet_reset(1) or i_run_state_125(RUN_STATE_BITPOS_SYNC);
    s_mts_rst       <= (not i_reset_125_n) or i_SC_mutrig.subdet_reset(1); -- [mts-int] let MTS consume PREP/SYNC/RUNNING over its run-control input.

    --! generate running signal for sorter
    process(i_clk_125, i_reset_125_n)
    begin
    if ( i_reset_125_n = '0' ) then
        s_counter125 <= (others => '0');
        s_running <= '0';
        sorter_reset_n <= '0';
        --
    elsif ( rising_edge(i_clk_125) ) then
        -- run state running
        if ( i_run_state_125 = RUN_STATE_RUNNING ) then
            s_running <= '1';
        else
            s_running <= '0';
        end if;

        -- reset sorter
        if ( i_run_state_125 = RUN_STATE_IDLE ) then
            sorter_reset_n  <= '0';
        else
            sorter_reset_n  <= '1';
        end if;

        -- count current time
        if ( i_run_state_125 = RUN_STATE_SYNC ) then
            s_counter125 <= (others => '0');
        else
            s_counter125 <= s_counter125 + '1';
        end if;
        --
    end if;
    end process;

    u_rxdeser: entity work.scifi_receiver_block
    generic map(
        g_INPUTS        => N_INPUTSRX,
        INPUT_SIGNFLIP  => INPUT_SIGNFLIP
    )
    port map(
        i_rx                => i_data,
        i_enablesim         => i_enablesim,
        i_scifi_lvds_los_n  => i_scifi_lvds_los_n,

        i_rx_inclock        => i_refclk_125_A,

        o_rx_status         => lvds_status,

        o_rx_data           => s_receivers_data,
        o_rx_k              => s_receivers_data_isk,
        o_rx_ready          => s_receivers_ready,

        i_reset_n           => not s_lvds_rx_rst,
        i_clk_global        => i_clk_125
    );

    gen_frame: for i in 0 to N_INPUTSRX-1 generate begin

        -- data generator
        u_data_dummy : entity work.mutrig_dummy_data
        generic map (
            ASIC_ID => C_ASICNO_PREFIX(4*i+3 downto i*4)--,
        )
        port map (
            -- reset / clock / enable
            i_reset             => s_datapath_rst,
            i_clk               => i_clk_125,
            i_enable            => i_SC_mutrig.datagen_enable and i_RC_may_generate,

            -- slow control signals
            i_SC_mutrig         => i_SC_mutrig,

            -- stream of hits
            o_event_data        => s_gen_event_data(i),

            -- header information
            o_frame_number      => s_gen_frame_number(i),
            o_frame_info        => s_gen_frame_info(i),
            o_frame_info_rdy    => s_gen_frame_info_rdy(i),
            o_new_frame         => s_gen_new_frame(i),
            o_busy              => s_gen_busy(i),

            -- trailer information
            o_end_of_frame      => open--,
        );

        -- data input RX -> Frame unpacker
        -- multiplex sim data (can be unregistered, since this is only used for simulation)
        process (i_enablesim, s_receivers_data, s_receivers_data_isk, i_simdata, i_simdatak)
        begin
            if ( i_enablesim = '0' ) then
                s_receivers_data_reg((i+1)*8-1 downto i*8) <= s_receivers_data((i+1)*8-1 downto i*8);
                s_receivers_data_isk_reg(i) <= s_receivers_data_isk(i);
            else
                s_receivers_data_reg((i+1)*8-1 downto i*8) <= i_simdata((i+1)*8-1 downto i*8);
                s_receivers_data_isk_reg(i) <= i_simdatak(i);
            end if;
        end process;

        -- mutrig frame unpacker
        u_frame_rcv : entity work.frame_rcv
        generic map (
            ASIC_ID => C_ASICNO_PREFIX(4*i+3 downto i*4)--,
        )
        port map (
            -- reset / clock / enable
            i_rst               => s_datapath_rst,
            i_clk               => i_clk_125,
            i_enable            => i_RC_may_generate and s_receivers_ready(i),

            -- data from lvds receiver
            i_data              => s_receivers_data_reg((i+1)*8-1 downto i*8),
            i_byteisk           => s_receivers_data_isk_reg(i),

            -- stream of hits
            o_hits              => s_rec_event_data(i),

            -- mutrig header information
            o_frame_number      => s_rec_frame_number(i),
            o_frame_info        => s_rec_frame_info(i),
            o_frame_info_ready  => s_rec_frame_info_rdy(i),
            o_new_frame         => s_rec_new_frame(i),
            o_busy              => s_rec_busy(i),

            -- mutrig trailer information
            o_end_of_frame      => s_rec_end_of_frame(i),
            o_crc_error         => s_rec_crc_error(i),
            o_crc_err_count     => open--,
        );

        -- multiplex between physical and generated data sent to the elastic buffers
        process(i_clk_125, i_reset_125_n)
        begin
        if ( i_reset_125_n /= '1' ) then
            s_data(i) <= work.mutrig_hit_types.t_hit_presort_zero;
            --
        elsif ( rising_edge(i_clk_125) ) then
            -- use busy from datagenerator to ensure safe takeover
            if ( i_SC_mutrig.datagen_enable = '1' or or_reduce(s_gen_busy) = '1') then
                s_data(i) <= s_gen_event_data(i);
                s_hits_valid(i) <= s_gen_event_data(i).valid;
                s_new_frame(i) <= s_gen_new_frame(i);
                s_crc_error(i) <= '0';
                s_frame_info_rdy(i) <= s_gen_frame_info_rdy(i);
            else
                s_data(i) <= s_rec_event_data(i);
                s_hits_valid(i) <= s_rec_event_data(i).valid;
                s_new_frame(i) <= s_rec_new_frame(i);
                s_crc_error(i) <= s_rec_crc_error(i);
                s_frame_info_rdy(i) <= s_rec_frame_info_rdy(i);
            end if;
        end if;
        end process;

        e_channel_rate : entity work.ch_rate
        generic map(
            num_ch => 32
        )
        port map(
            i_hit       => s_data(i),

            o_ch_rate   => s_ch_rate(i*32 + 31 downto i*32),

            i_clk       => i_clk_125,
            i_reset_n   => not s_datapath_rst--,
        );

    end generate;

    -- rate counters per asic
    e_asic_rate : entity work.asic_rate
    generic map(
        num_ch => N_INPUTSRX,
        reset_1s => true,
        reset_crc_1s => false
    )
    port map(
        i_hit           => s_data,
        i_new_frame     => s_new_frame,
        i_crc_error     => s_crc_error,
        o_hit_cnt       => s_asic_hitrate,
        o_frames_cnt    => s_frame_rate,
        o_crcerror_cnt  => s_crcerrorcounter,

        i_clk           => i_clk_125,
        i_reset_n       => not s_datapath_rst--,
    );

    -- --------------------------------------------------------------------------------
    -- phase 1 integration path (preparation / adaptation)
    -- --------------------------------------------------------------------------------
    gen_mts_receiver_path : if USE_MTS generate -- [mts-int] raw t_hit_presort stream from frame_rcv.
    begin
        gen_mts_mask : for k in 0 to 7 generate
        begin
            proc_mts_mask : process (all)
                variable rec_v : work.mutrig_hit_types.t_hit_presort;
            begin
                rec_v := s_data(k);
                if (i_SC_mutrig.mask_rx(k) = '0') then -- high is not to mask,? double check this
                    rec_v.valid := '0';
                end if;
                s_mts_data_in(k) <= rec_v;
            end process;
        end generate;
    end generate;

    gen_no_mts_input_tieoff : if not USE_MTS generate -- [mts-int] tie this off for sim-clean USE_MTS=false operation.
    begin
        s_mts_data_in <= (others => work.mutrig_hit_types.t_hit_presort_zero);
    end generate;

    gen_sorter_path: for i in 0 to 1 generate begin

        -- TODO: run side-by-side legacy/MTS regression before relying on USE_MTS=false equivalence.
        gen_legacy_mux_prbs : if not USE_MTS generate -- [mts-int] legacy path keeps the old pairwise channelmux and PRBS decoder.
        begin
            -- set four 2->1 mux
            gen_mux: for j in 0 to 1 generate begin
                mux : entity work.channelmux -- legacy rotating time-mux with input latching, no backpressure.
                generic map (
                    NPORTS => 2--,
                )
                port map (
                    i_clk   => i_clk_125,
                    i_rst   => s_datapath_rst,
                    i_mask  => i_SC_mutrig.mask_rx((2 + (j+i*2)*2) - 1 downto (j+i*2)*2), -- TODO: mask_rx is not folded in for the new path, need to consider this, where to mask, prefer is before the MTS
                    i_data  => s_data((2 + (j+i*2)*2) - 1 downto (j+i*2)*2),
                    o_data  => s_mux_data(j+i*2)--,
                );
            end generate;
        end generate;

        -- we set one sorter input to zero since sorter only takes multiple of 3
        gen_legacy_sorter_pad : if not USE_MTS generate
        begin
            s_mux_data_prbs_t_div(2+i*3) <= work.mutrig_hit_types.t_hit_presort_div_zero;
        end generate;


        -- --------------------------------------------------------------------------------
        -- phase 1 integration path (MTS replaces PRBS/LFSR decode and lapse correction)
        -- --------------------------------------------------------------------------------
        gen_mts_timestamp_path_up : if USE_MTS and i = 0 generate -- [mts-int] one UP-bank MTS IP merges ASIC0..3.
        begin
            e_mts_wrapper : entity work.scifi_mts_wrapper
            generic map (
                BANK         => "UP",
                OUTPUT_COUNT => 2--, -- note: this has to be 2 not 3, as for scifi only 2 part of the sorter has memory pad, the third is unconnected.
            )
            port map (
                i_clk              => i_clk_125,
                i_rst              => s_mts_rst,
                i_sc_clk           => i_clk_156,
                i_sc_reset_n       => i_reset_156_n,
                i_sc_reg_addr      => mts_regs(0).addr(1 downto 0),
                i_sc_reg_re        => mts_regs(0).re,
                o_sc_reg_rdata     => mts_regs(0).rdata,
                i_sc_reg_we        => mts_regs(0).we,
                i_sc_reg_wdata     => mts_regs(0).wdata,
                i_subdet_reset     => i_SC_mutrig.subdet_reset(1),
                i_run_state_125    => i_run_state_125, -- TODO: add directed RUNNING-to-END control coverage.
                i_hit0             => s_mts_data_in(0), -- raw type-0 hit from frame_rcv.
                i_hit1             => s_mts_data_in(1),
                i_hit2             => s_mts_data_in(2),
                i_hit3             => s_mts_data_in(3),
                o_hit              => s_mux_data_prbs_t_div(i*3+2 downto i*3),
                o_ingress_overflow => s_mts_ingress_overflow(0),
                o_hist_valid       => s_mts_hist_valid(0),
                o_hist_data        => s_mts_hist_data(0),
                o_hist_timestamp   => s_mts_hist_timestamp(0),
                o_hist_arrival     => s_mts_hist_arrival(0),
                o_hist_latency     => s_mts_hist_latency(0),
                o_hist_error       => s_mts_hist_error(0),
                o_hist_ingress_busy => s_mts_ingress_busy(0)
            );
        end generate;

        gen_mts_timestamp_path_down : if USE_MTS and i = 1 generate -- [mts-int] one DOWN-bank MTS IP merges ASIC4..7.
        begin
            e_mts_wrapper : entity work.scifi_mts_wrapper
            generic map (
                BANK         => "DOWN",
                OUTPUT_COUNT => 2--,
            )
            port map (
                i_clk              => i_clk_125,
                i_rst              => s_mts_rst,
                i_sc_clk           => i_clk_156,
                i_sc_reset_n       => i_reset_156_n,
                i_sc_reg_addr      => mts_regs(1).addr(1 downto 0),
                i_sc_reg_re        => mts_regs(1).re,
                o_sc_reg_rdata     => mts_regs(1).rdata,
                i_sc_reg_we        => mts_regs(1).we,
                i_sc_reg_wdata     => mts_regs(1).wdata,
                i_subdet_reset     => i_SC_mutrig.subdet_reset(1),
                i_run_state_125    => i_run_state_125,
                i_hit0             => s_mts_data_in(4),
                i_hit1             => s_mts_data_in(5),
                i_hit2             => s_mts_data_in(6),
                i_hit3             => s_mts_data_in(7),
                o_hit              => s_mux_data_prbs_t_div(i*3+2 downto i*3),
                o_ingress_overflow => s_mts_ingress_overflow(1),
                o_hist_valid       => s_mts_hist_valid(1),
                o_hist_data        => s_mts_hist_data(1),
                o_hist_timestamp   => s_mts_hist_timestamp(1),
                o_hist_arrival     => s_mts_hist_arrival(1),
                o_hist_latency     => s_mts_hist_latency(1),
                o_hist_error       => s_mts_hist_error(1),
                o_hist_ingress_busy => s_mts_ingress_busy(1)
            );
        end generate;

        -- --------------------------------------------------------------------------------
        -- LEGACY path
        -- --------------------------------------------------------------------------------
        gen_prbs : if not USE_MTS generate
            -- set prbs decoder
            e_prbs_t_presorter : entity work.prbs_decoder
            generic map (
                DECODE_E_A => false,
                DECODE_E_B => false--,
            )
            port map (
                -- system
                i_coreclk       => i_clk_125,
                i_rst           => s_prbs_rst,
                o_initializing  => open,

                -- data stream input
                i_A_data        => s_mux_data(i*2),
                i_B_data        => s_mux_data(i*2+1),

                -- data stream output
                o_A_data        => s_mux_data_prbs_t(i*2),
                o_B_data        => s_mux_data_prbs_t(i*2+1),

                -- disable block (make transparent)
                i_SC_disable_dec => i_SC_mutrig.disable_dec--;
            );
        end generate;

        gen_div_t: for j in 0 to 1 generate begin
            gen_legacy_timestamp_path : if not USE_MTS generate -- [mts-int] not yet with dual-uvm test in this integrations
            begin -- [mts-int] legacy lapse_counter plus T_CC_adapt block remains behaviorally unchanged, as a reference for A/B test
                -- cc correction -- [mts-int] do not change the preserved datapath.
                t_cc_correction : entity work.lapse_counter -- [mts-int] unchanged legacy timestamp correction instance.
                port map ( -- [mts-int] legacy lapse_counter ports kept intact.
                    i_enable            => i_SC_mutrig.lapse_ena, -- [mts-int] legacy port preserved.
                    i_upper_bnd         => i_SC_mutrig.lapse_upper_bnd, -- [mts-int] legacy port preserved.
                    i_lower_bnd         => i_SC_mutrig.lapse_lower_bnd, -- [mts-int] legacy port preserved.
                    i_delay             => i_SC_mutrig.lapse_delay, -- [mts-int] legacy port preserved.
                    i_replace_lat       => i_SC_mutrig.lapse_replace_latency, -- [mts-int] legacy port preserved.

                    o_latency           => open, -- [mts-int] legacy port preserved.

                    i_data              => s_mux_data_prbs_t(j+i*2), -- [mts-int] legacy input stream preserved.
                    o_data              => s_mux_data_prbs_t_reg(j+i*2), -- [mts-int] legacy intermediate record preserved.

                    i_clk               => i_clk_125, -- [mts-int] legacy clock preserved.
                    i_reset_n           => not s_lapse_rst--, -- [mts-int] legacy reset preserved.
                ); -- [mts-int] end unchanged legacy lapse_counter port map.

                -- divider from 1.6ns to 8ns -- [mts-int] legacy branch only; comments do not change division.
                e_div_t : entity work.T_CC_adapt -- [mts-int] unchanged legacy /5 divider instance.
                port map ( -- [mts-int] legacy T_CC_adapt ports kept intact.
                    --system -- [mts-int] legacy divider system ports.
                    i_clk  => i_clk_125, -- [mts-int] legacy clock preserved.
                    i_rst  => s_datapath_rst, -- [mts-int] legacy reset preserved.

                    --data stream -- [mts-int] legacy divider data ports.
                    i_data => s_mux_data_prbs_t_reg(j+i*2), -- [mts-int] legacy post-lapse input preserved.
                    o_data => s_mux_data_prbs_t_div(j+i*3)--, -- [mts-int] legacy hitsorter input preserved.
                ); -- [mts-int] end unchanged legacy T_CC_adapt port map.
            end generate; -- [mts-int] end legacy timestamp path.

            e_pll_test : entity work.pll_test -- Yifeng: that is this? I keep it like this please review this part
            port map(
                i_hit       => s_mux_data_prbs_t_div(j+i*3),

                o_pll_test0 => pll_test_reg(0+j*2+i*4),
                o_pll_test1 => pll_test_reg(1+j*2+i*4),
                o_pll_test2 => open,

                i_clk       => i_clk_125,
                i_reset_n   => not s_datapath_rst--,
            );
        end generate;

        -- --------------------------------------------------------------------------------
        -- hitsorter
        -- --------------------------------------------------------------------------------
        scifi_sorter : entity work.hitsorter
        generic map(
            IS_SORTER_TWO => i,
            g_USE_TRIGGER => 0,
            NSORTERINPUTS => 3,
            -- NOTE: minus ISMUTRIG is not the best way to do this.
            --       we need this because the sorter is only designed for
            --       multiple of 3 inputs but we have 2 for Scifi
            --       at the moment this is not working for tile
            TIMESTAMPSIZE => 12,
            HIT_WITHOUT_TS_SIZE => len_hit_presort_div_no_ts,
            IS_SCIFI => 1,
            IS_TILE => 0
        )
        port map(
            -- run control and hit data input
            i_running       => s_running,
            i_currentts     => s_counter125(12-1 downto 0),
            i_hit           => s_mux_data_prbs_t_div(i*3+2 downto i*3),

            -- hit output
            data_out        => fifo_wdata((i+1)*36 - 5 downto i*36),
            out_ena         => fifo_write(i),
            out_type        => fifo_wdata((i+1)*36 - 1 downto i*36+32),
            out_is_hit      => out_is_hit(i),

            -- slow control sorter register
            i_clk156        => i_clk_156,
            i_regs_reset_n  => i_reset_156_n,
            i_reg_addr      => mt_sorter_regs(i).addr(15 downto 0),
            i_reg_re        => mt_sorter_regs(i).re,
            o_reg_rdata     => mt_sorter_regs(i).rdata,
            i_reg_we        => mt_sorter_regs(i).we,
            i_reg_wdata     => mt_sorter_regs(i).wdata,

            -- clk / reset
            i_reset_n       => sorter_reset_n,
            i_clk           => i_clk_125--,
        );

        process(i_clk_125, sorter_reset_n)
        begin
        if ( sorter_reset_n = '0' ) then
            sorter_in(0+i*2) <= (others => '0');
            sorter_in(1+i*2) <= (others => '0');
            sorter_out(i) <= (others => '0');
        elsif rising_edge(i_clk_125) then
            if ( out_is_hit(i) = '1' ) then
                sorter_out(i) <= sorter_out(i) + '1';
            end if;
            if ( s_mux_data_prbs_t_div(i*3+0).valid = '1' ) then
                sorter_in(0+i*2) <= sorter_in(0+i*2) + '1';
            end if;
            if ( s_mux_data_prbs_t_div(i*3+1).valid = '1' ) then
                sorter_in(1+i*2) <= sorter_in(1+i*2) + '1';
            end if;
        end if;
        end process;

        -- sync output data
        e_sync_fifo_cnt : entity work.ip_dcfifo_v2
        generic map (
            g_ADDR_WIDTH => 4,
            g_DATA_WIDTH => 36,
            g_LPM_HINT => "RAM_BLOCK_TYPE=MLAB"--,
        )
        port map (
            i_wdata => fifo_wdata((i+1)*36-1 downto i*36),
            i_we => fifo_write(i),
            i_wclk => i_clk_125,

            i_rack => not sync_fifo_empty(i),
            o_rdata => sync_fifo_wdata_out((i+1)*36-1 downto i*36),
            o_rempty => sync_fifo_empty(i),
            i_rclk => i_clk_156,

            i_reset_n => '1'--,
        );

        o_fifo_data((i+1)*36-1 downto i*36) <= sync_fifo_wdata_out((i+1)*36-1 downto i*36);
        o_fifo_wr(i) <= not sync_fifo_empty(i);

    end generate;


    -- --------------------------------------------------------------------------------
    -- [hist] Readyless post-MTS histogram
    -- --------------------------------------------------------------------------------
    gen_mts_histogram : if USE_MTS generate
    begin
        -- MTS receives the external TERMINATING edge immediately so it can
        -- flush. HIST alone keeps seeing RUNNING until the observed plane is
        -- quiet. mts_processor ties coe_debug_status_data to zero in this
        -- build, so its internal stages are not observable and the drain is
        -- qualified by a quiet streak instead of a pipeline status bit.
        s_hist_upstream_busy <=
            or_reduce(s_mts_ingress_busy)
            or or_reduce(s_mts_hist_valid)
            or or_reduce(s_hist_valid);

        proc_hist_runctl_drain : process (i_clk_125, s_mts_rst)
        begin
            if s_mts_rst = '1' then
                s_hist_upstream_busy_q <= '0';
                s_hist_term_pending    <= '0';
                s_hist_term_active     <= '0';
                s_hist_term_seen       <= '0';
                s_hist_term_issue      <= '0';
                s_hist_quiet_streak    <= (others => '0');
            elsif rising_edge(i_clk_125) then
                s_hist_upstream_busy_q <= s_hist_upstream_busy;
                s_hist_term_issue      <= '0';

                -- A new run or its setup states cancel an obsolete pending
                -- termination. The RUNNING edge itself passes straight to
                -- HIST and is never delayed by this drain controller.
                if (
                    i_run_state_125(RUN_STATE_BITPOS_PREP) = '1'
                    or i_run_state_125(RUN_STATE_BITPOS_SYNC) = '1'
                    or i_run_state_125(RUN_STATE_BITPOS_RESET) = '1'
                    or i_run_state_125(RUN_STATE_BITPOS_RUNNING) = '1'
                ) then
                    s_hist_term_pending <= '0';
                    s_hist_term_active  <= '0';
                    s_hist_term_seen    <= '0';
                    s_hist_quiet_streak <= (others => '0');
                else
                    if i_run_state_125(RUN_STATE_BITPOS_TERMINATING) = '0' then
                        s_hist_term_seen <= '0';
                    end if;

                    if (
                        i_run_state_125(RUN_STATE_BITPOS_TERMINATING) = '1'
                        and s_hist_term_seen = '0'
                        and s_hist_term_active = '0'
                    ) then
                        s_hist_term_pending <= '1';
                        s_hist_term_seen    <= '1';
                        s_hist_quiet_streak <= (others => '0');
                    elsif s_hist_term_pending = '1' then
                        if s_hist_upstream_busy_q = '1' then
                            s_hist_quiet_streak <= (others => '0');
                        elsif s_hist_quiet_streak = HIST_QUIET_TARGET_CONST then
                            s_hist_term_pending <= '0';
                            s_hist_term_active  <= '1';
                            s_hist_term_issue   <= '1';
                            s_hist_quiet_streak <= (others => '0');
                        else
                            s_hist_quiet_streak <= s_hist_quiet_streak + 1;
                        end if;
                    end if;
                end if;
            end if;
        end process;

        -- Setup/new-run states always have priority and are never delayed. A
        -- qualified TERMINATING is held active even if the external command
        -- was only a pulse or has already advanced to IDLE; this gives HIST's
        -- internal FIFO/coalescer time to finish and issue its one-shot bank
        -- snapshot before the next PREP/SYNC/RUNNING sequence releases it.
        s_hist_run_state <= i_run_state_125 when (
                                i_run_state_125(RUN_STATE_BITPOS_PREP) = '1'
                                or i_run_state_125(RUN_STATE_BITPOS_SYNC) = '1'
                                or i_run_state_125(RUN_STATE_BITPOS_RESET) = '1'
                                or i_run_state_125(RUN_STATE_BITPOS_RUNNING) = '1'
                            ) else
                            RUN_STATE_TERMINATING when (
                                s_hist_term_active = '1'
                                or s_hist_term_issue = '1'
                            ) else
                            RUN_STATE_RUNNING when (
                                s_hist_term_pending = '1'
                                or (
                                    i_run_state_125(RUN_STATE_BITPOS_TERMINATING) = '1'
                                    and s_hist_term_seen = '0'
                                )
                            ) else
                            i_run_state_125;

        -- Two bank wrappers carry the eight logical ASIC IDs. This passive
        -- demultiplexer preserves each payload/TS48/latency48/error bundle
        -- and deliberately has no ready path back into MTS.
        e_histogram_adapter : entity work.scifi_histogram_adapter
        generic map (
            N_MTS_INPUTS => 2,
            N_ASICS      => 8
        )
        port map (
            csi_clock              => i_clk_125,
            rsi_reset              => s_mts_rst,
            asi_mts_valid          => s_mts_hist_valid,
            asi_mts_data           => s_mts_hist_data,
            coe_mts_timestamp      => s_mts_hist_timestamp,
            coe_mts_arrival        => s_mts_hist_arrival,
            coe_mts_latency        => s_mts_hist_latency,
            asi_mts_error          => s_mts_hist_error,
            aso_hist_valid         => s_hist_valid,
            aso_hist_data          => s_hist_data,
            coe_hist_timestamp     => s_hist_timestamp,
            coe_hist_arrival       => s_hist_arrival,
            coe_hist_latency       => s_hist_latency,
            aso_hist_error         => s_hist_error,
            coe_collision_count    => s_hist_collision_count,
            coe_invalid_asic_count => s_hist_invalid_count
        );

        -- One HIST services both SciFi sorter/datapath halves. The default
        -- preset is signed delay mode over [-1000, 3096) with 16-tick bins;
        -- source 3 consumes all eight explicit Type1 lanes. The precomputed
        -- MTS latency remains 48 bits until the HIST range/binning stage.
        e_histogram : entity work.histogram_statistics_v2
        generic map (
            DEF_LEFT_BOUND    => -1000,
            DEF_BIN_WIDTH     => 16,
            DEF_MODE          => 1,
            DEF_SOURCE_SELECT => 3,
            UPDATE_KEY_BIT_HI => 37,
            UPDATE_KEY_BIT_LO => 30,
            LOCK_KEY_RANGES   => false,
            N_PORTS           => 8,
            COAL_QUEUE_DEPTH  => 8,
            COAL_CAM_PIPELINE_MODE   => "AUTO",
            COAL_CAM_PIPELINE_STAGES => 0,
            TYPE1_DATA_WIDTH  => 39,
            INSTANCE_ID       => 0
        )
        port map (
            avs_hist_bin_readdata           => o_hist_bin_readdata,
            avs_hist_bin_read               => i_hist_bin_read,
            avs_hist_bin_address            => i_hist_bin_address,
            avs_hist_bin_waitrequest        => o_hist_bin_waitrequest,
            avs_hist_bin_write              => i_hist_bin_write,
            avs_hist_bin_writedata          => i_hist_bin_writedata,
            avs_hist_bin_burstcount         => i_hist_bin_burstcount,
            avs_hist_bin_readdatavalid      => o_hist_bin_readdatavalid,
            avs_hist_bin_writeresponsevalid => o_hist_bin_writeresponsevalid,
            avs_hist_bin_response           => o_hist_bin_response,

            avs_csr_readdata                => o_hist_csr_readdata,
            avs_csr_read                    => i_hist_csr_read,
            avs_csr_address                 => i_hist_csr_address,
            avs_csr_waitrequest             => o_hist_csr_waitrequest,
            avs_csr_write                   => i_hist_csr_write,
            avs_csr_writedata               => i_hist_csr_writedata,

            -- Post-MTS Type1 hits feed both latency and rate modes.
            -- CONTROL.source_select=3 selects the eight readyless
            -- asi_type1_lane* inputs; the pre-MTS Type0 interface is unused.
            asi_type0_lane0_ready           => open,
            asi_type0_lane0_valid           => '0',
            asi_type0_lane0_data            => (others => '0'),
            asi_type0_lane0_startofpacket   => '0',
            asi_type0_lane0_endofpacket     => '0',
            asi_type0_lane0_channel         => (others => '0'),
            asi_type0_lane1_ready           => open,
            asi_type0_lane1_valid           => '0',
            asi_type0_lane1_data            => (others => '0'),
            asi_type0_lane1_startofpacket   => '0',
            asi_type0_lane1_endofpacket     => '0',
            asi_type0_lane1_channel         => (others => '0'),
            asi_type0_lane2_ready           => open,
            asi_type0_lane2_valid           => '0',
            asi_type0_lane2_data            => (others => '0'),
            asi_type0_lane2_startofpacket   => '0',
            asi_type0_lane2_endofpacket     => '0',
            asi_type0_lane2_channel         => (others => '0'),
            asi_type0_lane3_ready           => open,
            asi_type0_lane3_valid           => '0',
            asi_type0_lane3_data            => (others => '0'),
            asi_type0_lane3_startofpacket   => '0',
            asi_type0_lane3_endofpacket     => '0',
            asi_type0_lane3_channel         => (others => '0'),
            asi_type0_lane4_ready           => open,
            asi_type0_lane4_valid           => '0',
            asi_type0_lane4_data            => (others => '0'),
            asi_type0_lane4_startofpacket   => '0',
            asi_type0_lane4_endofpacket     => '0',
            asi_type0_lane4_channel         => (others => '0'),
            asi_type0_lane5_ready           => open,
            asi_type0_lane5_valid           => '0',
            asi_type0_lane5_data            => (others => '0'),
            asi_type0_lane5_startofpacket   => '0',
            asi_type0_lane5_endofpacket     => '0',
            asi_type0_lane5_channel         => (others => '0'),
            asi_type0_lane6_ready           => open,
            asi_type0_lane6_valid           => '0',
            asi_type0_lane6_data            => (others => '0'),
            asi_type0_lane6_startofpacket   => '0',
            asi_type0_lane6_endofpacket     => '0',
            asi_type0_lane6_channel         => (others => '0'),
            asi_type0_lane7_ready           => open,
            asi_type0_lane7_valid           => '0',
            asi_type0_lane7_data            => (others => '0'),
            asi_type0_lane7_startofpacket   => '0',
            asi_type0_lane7_endofpacket     => '0',
            asi_type0_lane7_channel         => (others => '0'),

            asi_type1_up_ready              => open,
            asi_type1_up_valid              => '0',
            asi_type1_up_data               => (others => '0'),
            asi_type1_up_ts                 => (others => '0'),
            asi_type1_up_startofpacket      => '0',
            asi_type1_up_endofpacket        => '0',
            asi_type1_up_channel            => (others => '0'),
            asi_type1_down_ready            => open,
            asi_type1_down_valid            => '0',
            asi_type1_down_data             => (others => '0'),
            asi_type1_down_ts               => (others => '0'),
            asi_type1_down_startofpacket    => '0',
            asi_type1_down_endofpacket      => '0',
            asi_type1_down_channel          => (others => '0'),

            asi_type1_lane0_valid           => s_hist_valid(0),
            asi_type1_lane0_data            => s_hist_data(0),
            asi_type1_lane0_ts              => s_hist_timestamp(0),
            asi_type1_lane0_latency         => s_hist_latency(0),
            asi_type1_lane0_error           => s_hist_error(0),
            asi_type1_lane1_valid           => s_hist_valid(1),
            asi_type1_lane1_data            => s_hist_data(1),
            asi_type1_lane1_ts              => s_hist_timestamp(1),
            asi_type1_lane1_latency         => s_hist_latency(1),
            asi_type1_lane1_error           => s_hist_error(1),
            asi_type1_lane2_valid           => s_hist_valid(2),
            asi_type1_lane2_data            => s_hist_data(2),
            asi_type1_lane2_ts              => s_hist_timestamp(2),
            asi_type1_lane2_latency         => s_hist_latency(2),
            asi_type1_lane2_error           => s_hist_error(2),
            asi_type1_lane3_valid           => s_hist_valid(3),
            asi_type1_lane3_data            => s_hist_data(3),
            asi_type1_lane3_ts              => s_hist_timestamp(3),
            asi_type1_lane3_latency         => s_hist_latency(3),
            asi_type1_lane3_error           => s_hist_error(3),
            asi_type1_lane4_valid           => s_hist_valid(4),
            asi_type1_lane4_data            => s_hist_data(4),
            asi_type1_lane4_ts              => s_hist_timestamp(4),
            asi_type1_lane4_latency         => s_hist_latency(4),
            asi_type1_lane4_error           => s_hist_error(4),
            asi_type1_lane5_valid           => s_hist_valid(5),
            asi_type1_lane5_data            => s_hist_data(5),
            asi_type1_lane5_ts              => s_hist_timestamp(5),
            asi_type1_lane5_latency         => s_hist_latency(5),
            asi_type1_lane5_error           => s_hist_error(5),
            asi_type1_lane6_valid           => s_hist_valid(6),
            asi_type1_lane6_data            => s_hist_data(6),
            asi_type1_lane6_ts              => s_hist_timestamp(6),
            asi_type1_lane6_latency         => s_hist_latency(6),
            asi_type1_lane6_error           => s_hist_error(6),
            asi_type1_lane7_valid           => s_hist_valid(7),
            asi_type1_lane7_data            => s_hist_data(7),
            asi_type1_lane7_ts              => s_hist_timestamp(7),
            asi_type1_lane7_latency         => s_hist_latency(7),
            asi_type1_lane7_error           => s_hist_error(7),

            aso_hist_fill_out_ready         => '1',
            aso_hist_fill_out_valid         => open,
            aso_hist_fill_out_data          => open,
            aso_hist_fill_out_startofpacket => open,
            aso_hist_fill_out_endofpacket   => open,
            aso_hist_fill_out_channel       => open,

            asi_ctrl_data                   => s_hist_run_state(8 downto 0),
            asi_ctrl_valid                  => '1',
            asi_debug_1_valid               => '0',
            asi_debug_1_data                => (others => '0'),
            asi_debug_2_valid               => '0',
            asi_debug_2_data                => (others => '0'),
            asi_debug_3_valid               => '0',
            asi_debug_3_data                => (others => '0'),
            asi_debug_4_valid               => '0',
            asi_debug_4_data                => (others => '0'),
            asi_debug_5_valid               => '0',
            asi_debug_5_data                => (others => '0'),
            asi_debug_6_valid               => '0',
            asi_debug_6_data                => (others => '0'),
            i_interval_reset                => '0',
            i_rst                           => s_mts_rst,
            i_clk                           => i_clk_125
        );
    end generate gen_mts_histogram;

    gen_no_mts_histogram : if not USE_MTS generate
    begin
        -- The legacy timestamp path has no post-MTS Type1 plane to observe.
        -- Keep the slow-control leaf answering so an SC read cannot hang.
        o_hist_csr_waitrequest        <= '0';
        o_hist_csr_readdata           <= (others => '0');
        o_hist_bin_waitrequest        <= '0';
        o_hist_bin_readdata           <= (others => '0');
        o_hist_bin_readdatavalid      <= '0';
        o_hist_bin_writeresponsevalid <= '0';
        o_hist_bin_response           <= (others => '0');
    end generate gen_no_mts_histogram;

    -- p_RC_all_done
    -- KB: TODO: reimplement this
    o_RC_all_done <='1';
    --process(i_clk_125)
    --begin
    --if rising_edge(i_clk_125) then
    --    if( s_any_framegen_busy = '0') then
    --        RC_all_done(0) <='1';
    --    else
    --        RC_all_done(0) <= '0';
    --    end if;
    --end if;
    --end process;
    --e_sync_RC_all_done : entity work.ff_sync
    --generic map ( W => RC_all_done'length )
    --port map (
    --    i_d => RC_all_done, o_q(0) => o_RC_all_done,
    --    i_reset_n => i_reset_156_n, i_clk => i_clk_156--,
    --);

end architecture;
