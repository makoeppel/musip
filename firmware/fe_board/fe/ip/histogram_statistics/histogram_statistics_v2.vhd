-- altera vhdl_input_version vhdl_2008
-- File name: histogram_statistics_v2.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- Version : 26.5.0
-- Date    : 20260713
-- Change  : Add the Phase-I eight-lane readyless Type1 source (source 3),
--           carrying payload, true timestamp, and precomputed signed 48-bit
--           latency per lane. Delay mode is now the delivered default and
--           range-checks the complete latency before binning. Eight parallel
--           mappers feed binned per-lane FIFOs and an eight-input live-cell
--           coalescer with same-cycle grouping and split-on-kick-saturation.
--           Pending-ledger lane deltas use balanced saturating reductions so
--           queue admission does not traverse an eight-deep counter chain.
--           Compile-time AUTO/EXPLICIT CAM pipeline controls propagate to the
--           live-cell queue for deeper timing-closure profiles.
-- Version : 26.4.5
-- Date    : 20260605
-- Change  : Keep the FEB SciFi v4 real-MuTRiG Type0 burst fix at 32-bit
--           counters and 32-entry ingress FIFOs, but restore the default
--           coalescer to four live cells. Directed stress shows the ingress
--           FIFO was the bottleneck (`coal_status=0x00000100`), while the
--           160-cell profile creates a long queue search/ready timing path.
-- Version : 26.4.4
-- Date    : 20260604
-- Change  : Restore the FEB SciFi v4 default sizing for real-MuTRiG Type0 bursts:
--           32-bit bin/live counters, 32-entry per-port ingress FIFOs, and the
--           160-cell coalescer profile. The previous 20-bit/4-entry/4-cell
--           resource-reduced defaults can drop a 32-channel eight-lane Type0
--           burst before the arbiter drains the ingress FIFOs.
-- Version : 26.4.3
-- Date    : 20260529
-- Change  : gts-unify (BUG-012): delay-mode subtracts the MTS-exported arrival GTS
--           (asi_type1_{up,down}_gts, co-sampled with the emission ts in one MTS
--           epoch) instead of a local free-running gts_8n. Removes the random
--           per-SYNC ~2^20 delay-peak offset. gts_8n / gts_counter_clear /
--           runctl_reset_hold removed; added asi_type1_{up,down}_gts inputs. Use
--           source=TYPE1_UP/DOWN for delay mode (EXT0/EXT1 carry no arrival).
-- Version : 26.3.15
-- Date    : 20260520
-- Change  : Pair with pingpong_sram Revision 1.7 seamless bank-follow host
--           read. A host burst that straddles an interval bank swap follows to
--           the just-frozen bank and returns all burstcount beats as valid
--           OKAY data instead of holding waitrequest. avs_hist_bin_response
--           stays OK/zero (this design returns all-valid beats, no error
--           response needed). This stops the sc_hub read-timeout that padded
--           short replies with 0xEEEEEEEE.
-- =======================================
-- Revision: 1.32
--      Date: May 27, 2026
--      Change: Hold gts_counter_clear LEVEL-asserted throughout the
--              run_state_cmd = SYNC interval so the local gts_8n stays at
--              zero for the entire SYNC->RUN host dwell, matching
--              mts_processor.counter_gts_8n which holds at zero whenever
--              (processor_state = RESET, reset_flow = SYNC). The 1.31 attempt
--              dropped runctl_run_start but left only the runctl_sync_start
--              pulse for SYNC entry; once the pulse cleared, gts_8n
--              incremented freely during the dwell while MTS's counter
--              stayed at zero, so the post-RUNNING delay-mode key always
--              had a constant offset equal to the dwell length (UNDERFLOW
--              saturation). Replacing the SYNC pulse with the
--              bool_to_sl(run_state_cmd = SYNC) level term holds the local
--              gts_8n for the same window as MTS, so the two counters
--              start incrementing simultaneously on the RUNNING transition
--              and delay = gts_8n - hit_ts collapses to the MTS pipeline
--              latency (small positive). Packaged as 26.4.2.0527.
-- Revision: 1.31
--      Date: May 27, 2026
--      Change: Drop runctl_run_start from gts_counter_clear so the local
--              gts_8n only re-zeroes on SYNC, matching mts_processor's
--              counter_gts_8n reset condition. Before this fix the RUNNING
--              command re-cleared gts_8n while MTS counter_gts_8n kept
--              counting from the prior SYNC, so delay = gts_8n - hit_ts
--              wrapped to a huge unsigned value on every hit and both
--              UNDERFLOW and OVERFLOW counters saturated in mode=1 (delay)
--              on silicon. With this fix the histogram and MTS counters
--              stay aligned across the standard RUN_PREPARE -> SYNC ->
--              RUNNING sequence regardless of the host SYNC -> RUNNING
--              dwell time. Packaged as 26.4.1.0527.
-- Revision: 1.30
--      Date: May 26, 2026
--      Change: Close the silicon-zero Type1 ingress hole at idx=0 and make
--              CONTROL[3:2] = csr_in_port functional. (a) Add an elsif for
--              cfg_source_select in {HIST_SOURCE_TYPE1_UP_CONST,
--              HIST_SOURCE_TYPE1_DOWN_CONST} so port 0 samples readyless
--              whenever Type1 up/down is selected. Before this branch the
--              idx=0 chain only fired for TYPE0 or for cfg_in_port in
--              {EXT0, EXT1}; on silicon cfg_in_port stayed at
--              IN_PORT_FILL_CONST because the CSR write process never wrote
--              csr_in_port, so every Type1 bin read zero for both rate
--              (mode 0) and delay (mode 1) paths regardless of bank.
--              (b) Wire csr_in_port <= unsigned(writedata(3:2)) in the CSR
--              write process so a host write of CONTROL[3:2] flips
--              cfg_in_port and the read-back field reflects the chosen
--              ingress mode instead of always reporting FILL.
--              Downstream key/filter dispatch
--              (build_delay_key_from_ts for mode 1, build_fixed and
--              build_key for rate mode) already operates on
--              port_data(0)/port_ts(0), which are correctly muxed from
--              asi_type1_up/down for both banks, so no further plumbing
--              was needed inside the binning core.
-- Revision: 1.29
--      Date: May 20, 2026
--      Change: Zero port_offset_v for TYPE0 (ENABLE_DEBUG_INPUTS cfg_mode<0 or
--              cfg_source_select = HIST_SOURCE_TYPE0_CONST) in divider_pipe.
--              Pairs with Rev 1.28 per-port ingress sampling.
-- Revision: 1.28
--      Date: May 20, 2026
--      Change: Add an (idx > 0) and cfg_source_select = HIST_SOURCE_TYPE0_CONST
--              branch in the per-port ingress loop driving stream_ready_v/
--              stream_sampled_v readyless for ports 1..N_PORTS-1. Previously
--              only ASIC0 (bins 0..31) ever populated because the 8-port
--              rr_arbiter only saw port 0. Pairs with the 8-lane
--              emulator_mutrig_qsys8 independent-ASIC datapath.
-- Revision: 1.27
--      Date: May 19, 2026
--      Change: Restore the SYNC-entry GTS counter clear pulse used to delimit
--              measurement windows without reintroducing the latched
--              gts_reset_reg reset-equivalent state.
-- Revision: 1.26
--      Date: May 19, 2026
--      Change: Make the run-control RESET command self-exit to IDLE when
--              the readyless ctrl word is no longer active, and replace the
--              latched GTS reset register with a direct active-command clear.
-- Revision: 1.4
--		Date: Apr 27, 2026
--		Change: Replicate configurable filter fields per ingress port
--		        so the hot-path match logic is not driven by one
--		        high-fanout shared CSR/config source.
-- Revision: 1.5
--		Date: Apr 27, 2026
--		Change: Package metadata bump for the one-hit-per-clock arbiter
--		        drain fix in rr_arbiter.vhd.
-- Revision: 1.6
--		Date: Apr 29, 2026
--		Change: Wire FIFO level into rr_arbiter so its registered
--		        grant-to-pop pipeline can avoid re-selecting a FIFO that
--		        will become empty after the pending pop.
-- Revision: 1.7
--		Date: Apr 29, 2026
--		Change: Add combined signed MTS-delay debug mode -7, sampling
--		        debug_1 and debug_2 into independent ingress FIFOs so upper
--		        and lower hit-stack timestamp-delta streams can share one
--		        histogram without changing the normal rate path.
-- Revision: 1.8
--		Date: Apr 29, 2026
--		Change: Apply the runtime CSR filter in debug modes using a
--		        synthetic debug word: bits [15:0] are the sample,
--		        bits [23:16] are the zero-based debug source index,
--		        and bits [31:24] are the absolute debug mode.
-- Revision: 1.9
--		Date: Apr 29, 2026
--		Change: Latch last-interval accepted and dropped hit counters
--		        before the rate-window reset so a host can read a stable
--		        one-second rate without racing TOTAL_HITS reset.
-- Revision: 1.10
--		Date: May 11, 2026
--		Change: Drop ctrl ready output to match the rc-network readyless
--		        contract; ctrl is broadcast-only (USE_READY=0).
-- Revision: 1.11
--		Date: May 14, 2026
--		Change: Add positive stream delay mode 1. The selected update-key
--		        slice is treated as a trimmed hit timestamp; the histogram
--		        bins the modulo difference between the internal run-control
--		        GTS counter and that timestamp.
-- Revision: 1.12
--		Date: May 14, 2026
--		Change: Compute stream-delay mode from a full 48-bit true hit
--		        timestamp sideband, then trim the positive delay result to
--		        SAR_TICK_WIDTH so the histogram fill path keeps the same
--		        configured width as normal mode.
-- Revision: 1.13
--		Date: May 14, 2026
--		Change: Add LOCK_KEY_RANGES so fixed-format integrations can use
--		        static generic update/filter bit ranges in the hot ingress
--		        path instead of timing through the CSR-programmable range
--		        extractor.
-- Revision: 1.14
--		Date: May 16, 2026
--		Change: Replace the public generic fill input contract with explicit
--		        FEB V3 Type0 lane and Type1 up/down inputs. Type1 timestamp
--		        is a separate 48-bit sideband, CSR CONTROL[17:16] selects
--		        Type0/up/down, and the coalescer kick count is now a generic
--		        so the V3 image can use 4-bit coalesced updates.
-- Revision: 1.15
--		Date: May 16, 2026
--		Change: Make the V3 fixed-format datapath the default resource target:
--		        source-aware Type0/Type1 key and filter slices are used when
--		        LOCK_KEY_RANGES is enabled, and the default ingress FIFO depth
--		        is reduced for direct MTS/FEB traffic.
-- Revision: 1.16
--		Date: May 16, 2026
--		Change: Make the V3 default resource profile explicit: legacy
--		        debug/snoop paths are disabled unless requested, the
--		        coalescer uses the bunched live-cell queue, and the default
--		        tick width covers a 5 ms FEB run without carrying a 32-bit
--		        key path through every pipeline stage.
-- Revision: 1.17
--		Date: May 16, 2026
--		Change: Tighten the FEB V3 resource profile: 20-bit bin counters,
--		        4-entry ingress FIFOs, 8 live coalescer cells, and
--		        power-of-two-only bin widths with CSR-visible rejection for
--		        unsupported widths.
-- Revision: 1.18
--		Date: May 16, 2026
--		Change: Match the V3 bunched-coalescer evidence envelope with four
--		        live cells and narrow live interval statistics to the same
--		        20-bit counter width used by the histogram bins.
-- Revision: 1.19
--      Date: May 17, 2026
--      Change: Pipeline per-bank pending-hit accounting into registered
--              increment/decrement deltas so ping-pong read stability does
--              not put all ingress accepts and coalescer drains through one
--              wide same-cycle counter update.
-- Revision: 1.20
--      Date: May 17, 2026
--      Change: Register the FIFO-write side of the pending-hit delta before
--              summing per-bank increments, while retaining a current-cycle
--              bank-pending write-seen guard for ping-pong read arbitration.
-- Revision: 1.21
--      Date: May 17, 2026
--      Change: Clear the live measurement window on the run-control RUNNING
--              transition so ping-pong rate intervals are phase-aligned to
--              the FEB run rather than to earlier CSR programming traffic.
-- Revision: 1.22
--      Date: May 17, 2026
--      Change: Force one final ping-pong interval on run-control TERMINATING
--              after pending updates drain, making the final partial run bank
--              readable without waiting for a full extra interval.
-- Revision: 1.23
--      Date: May 17, 2026
--      Change: Drive hist_bin waitrequest from the ping-pong read engine so
--              decomposed generated-Qsys reads cannot be silently dropped.
-- Revision: 1.24
--      Date: May 17, 2026
--      Change: Force the termination interval only after the histogram
--              ingress, queue, and SRAM update pipeline are fully drained.
-- Revision: 1.25
--      Date: May 17, 2026
--      Change: Pair with pingpong_sram 1.6 so same-cycle interval-boundary
--              updates are preserved before generated-Qsys readout.
-- Revision: 1.3
--		Date: Apr 25, 2026
--		Change: Parameterize the ingress FIFO depth for bursty post-stack
--		        taps and saturate the 8-bit PORT_STATUS max-level field
--		        instead of truncating full FIFO levels to zero.
-- Revision: 1.2
--		Date: Apr 9, 2026
--		Change: Decouple build_key from filter_pass_v gating in ingress_comb
--		        to break cfg_filter_key_low → ingress_stage_key timing path
--		        (-2.554 ns at 137.5 MHz standalone). Key is always computed;
--		        only write_req is gated by filter result.
-- Revision: 1.1
--		Date: Apr 9, 2026
--		Change: Register measure_clear_pulse to break timing path from
--		        AVMM interconnect address decode to queue_hit_bin
--		        (-0.472 ns violation at 125 MHz pll_sclk domain).
-- Revision: 1.0 (file created)
--		Date: Mar 20, 2026
-- =========
-- Description:	[Histogram Statistics v2 top-level]
--
--			Multi-port online histogram with configurable bins, coalescing queue,
--			and ping-pong readout.  Accepts up to 8 Avalon-ST input ports, extracts
--			a configurable key field, maps keys to bin indices via bin_divider,
--			coalesces concurrent updates in a queue, and stores counts in dual-bank
--			M10K SRAM with automatic interval-based bank swap.
--
--			Data path:
--				ingress -> eight full-width bin_dividers -> eight binned hit_fifos
--				-> multi-input coalescing_queue -> pingpong_sram
--
--			Control:
--				AVMM CSR slave for run-time configuration (bounds, bin width, filter).
--				AVMM hist_bin slave for host readout of histogram bins.
--

-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.histogram_statistics_v2_pkg.all;

entity histogram_statistics_v2 is
    generic (
        UPDATE_KEY_BIT_HI        : natural := 37;
        UPDATE_KEY_BIT_LO        : natural := 30;
        UPDATE_KEY_REPRESENTATION: string  := "UNSIGNED";
        LOCK_KEY_RANGES          : boolean := false;
        FILTER_KEY_BIT_HI        : natural := 38;
        FILTER_KEY_BIT_LO        : natural := 35;
        SAR_TICK_WIDTH           : natural := 21;
        SAR_KEY_WIDTH            : natural := 16;
        N_BINS                   : natural := 256;
        MAX_COUNT_BITS           : natural := 32;
        DEF_LEFT_BOUND           : integer := -1000;
        DEF_BIN_WIDTH            : natural := 16;
        DEF_MODE                 : integer := 1;
        DEF_SOURCE_SELECT        : natural := 3;
        POWER2_BIN_WIDTH_ONLY    : boolean := true;
        AVS_ADDR_WIDTH           : natural := 8;
        N_PORTS                  : natural := 8;
        FIFO_ADDR_WIDTH          : natural := 5;
        CHANNELS_PER_PORT        : natural := 32;
        COAL_QUEUE_DEPTH         : natural := 8;
        COAL_CAM_PIPELINE_MODE   : string  := "AUTO";
        COAL_CAM_PIPELINE_STAGES : natural := 0;
        ENABLE_PINGPONG          : boolean := true;
        DEF_INTERVAL_CLOCKS      : natural := 125000000;
        AVST_DATA_WIDTH          : natural := 45;
        TYPE0_DATA_WIDTH         : natural := 45;
        TYPE1_DATA_WIDTH         : natural := 39;
        AVST_CHANNEL_WIDTH       : natural := 4;
        KICK_COUNT_WIDTH         : natural := 4;
        N_DEBUG_INTERFACE        : natural := 0;
        ENABLE_DEBUG_INPUTS      : boolean := false;
        VERSION_MAJOR            : natural := 26;
        VERSION_MINOR            : natural := 5;
        VERSION_PATCH            : natural := 0;
        BUILD                    : natural := 713;
        IP_UID                   : natural := 1212765012;  -- ASCII "HIST" = 0x48495354
        VERSION_DATE             : natural := 20260713;
        VERSION_GIT              : natural := 0;
        INSTANCE_ID              : natural := 0;
        SNOOP_EN                 : boolean := false;
        ENABLE_PACKET            : boolean := false;
        DEBUG                    : natural := 0
    );
    port (
        avs_hist_bin_readdata           : out std_logic_vector(31 downto 0);
        avs_hist_bin_read               : in  std_logic;
        avs_hist_bin_address            : in  std_logic_vector(AVS_ADDR_WIDTH - 1 downto 0);
        avs_hist_bin_waitrequest        : out std_logic;
        avs_hist_bin_write              : in  std_logic;
        avs_hist_bin_writedata          : in  std_logic_vector(31 downto 0);
        avs_hist_bin_burstcount         : in  std_logic_vector(AVS_ADDR_WIDTH downto 0);
        avs_hist_bin_readdatavalid      : out std_logic;
        avs_hist_bin_writeresponsevalid : out std_logic;
        avs_hist_bin_response           : out std_logic_vector(1 downto 0);

        avs_csr_readdata                : out std_logic_vector(31 downto 0);
        avs_csr_read                    : in  std_logic;
        avs_csr_address                 : in  std_logic_vector(4 downto 0);
        avs_csr_waitrequest             : out std_logic;
        avs_csr_write                   : in  std_logic;
        avs_csr_writedata               : in  std_logic_vector(31 downto 0);

        asi_type0_lane0_ready           : out std_logic;
        asi_type0_lane0_valid           : in  std_logic;
        asi_type0_lane0_data            : in  std_logic_vector(TYPE0_DATA_WIDTH - 1 downto 0);
        asi_type0_lane0_startofpacket   : in  std_logic;
        asi_type0_lane0_endofpacket     : in  std_logic;
        asi_type0_lane0_channel         : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type0_lane0_error           : in  std_logic_vector(2 downto 0) := (others => '0');
        asi_type0_lane0_endofrun        : in  std_logic := '0';

        asi_type0_lane1_ready           : out std_logic;
        asi_type0_lane1_valid           : in  std_logic;
        asi_type0_lane1_data            : in  std_logic_vector(TYPE0_DATA_WIDTH - 1 downto 0);
        asi_type0_lane1_startofpacket   : in  std_logic;
        asi_type0_lane1_endofpacket     : in  std_logic;
        asi_type0_lane1_channel         : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type0_lane1_error           : in  std_logic_vector(2 downto 0) := (others => '0');
        asi_type0_lane1_endofrun        : in  std_logic := '0';

        asi_type0_lane2_ready           : out std_logic;
        asi_type0_lane2_valid           : in  std_logic;
        asi_type0_lane2_data            : in  std_logic_vector(TYPE0_DATA_WIDTH - 1 downto 0);
        asi_type0_lane2_startofpacket   : in  std_logic;
        asi_type0_lane2_endofpacket     : in  std_logic;
        asi_type0_lane2_channel         : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type0_lane2_error           : in  std_logic_vector(2 downto 0) := (others => '0');
        asi_type0_lane2_endofrun        : in  std_logic := '0';

        asi_type0_lane3_ready           : out std_logic;
        asi_type0_lane3_valid           : in  std_logic;
        asi_type0_lane3_data            : in  std_logic_vector(TYPE0_DATA_WIDTH - 1 downto 0);
        asi_type0_lane3_startofpacket   : in  std_logic;
        asi_type0_lane3_endofpacket     : in  std_logic;
        asi_type0_lane3_channel         : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type0_lane3_error           : in  std_logic_vector(2 downto 0) := (others => '0');
        asi_type0_lane3_endofrun        : in  std_logic := '0';

        asi_type0_lane4_ready           : out std_logic;
        asi_type0_lane4_valid           : in  std_logic;
        asi_type0_lane4_data            : in  std_logic_vector(TYPE0_DATA_WIDTH - 1 downto 0);
        asi_type0_lane4_startofpacket   : in  std_logic;
        asi_type0_lane4_endofpacket     : in  std_logic;
        asi_type0_lane4_channel         : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type0_lane4_error           : in  std_logic_vector(2 downto 0) := (others => '0');
        asi_type0_lane4_endofrun        : in  std_logic := '0';

        asi_type0_lane5_ready           : out std_logic;
        asi_type0_lane5_valid           : in  std_logic;
        asi_type0_lane5_data            : in  std_logic_vector(TYPE0_DATA_WIDTH - 1 downto 0);
        asi_type0_lane5_startofpacket   : in  std_logic;
        asi_type0_lane5_endofpacket     : in  std_logic;
        asi_type0_lane5_channel         : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type0_lane5_error           : in  std_logic_vector(2 downto 0) := (others => '0');
        asi_type0_lane5_endofrun        : in  std_logic := '0';

        asi_type0_lane6_ready           : out std_logic;
        asi_type0_lane6_valid           : in  std_logic;
        asi_type0_lane6_data            : in  std_logic_vector(TYPE0_DATA_WIDTH - 1 downto 0);
        asi_type0_lane6_startofpacket   : in  std_logic;
        asi_type0_lane6_endofpacket     : in  std_logic;
        asi_type0_lane6_channel         : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type0_lane6_error           : in  std_logic_vector(2 downto 0) := (others => '0');
        asi_type0_lane6_endofrun        : in  std_logic := '0';

        asi_type0_lane7_ready           : out std_logic;
        asi_type0_lane7_valid           : in  std_logic;
        asi_type0_lane7_data            : in  std_logic_vector(TYPE0_DATA_WIDTH - 1 downto 0);
        asi_type0_lane7_startofpacket   : in  std_logic;
        asi_type0_lane7_endofpacket     : in  std_logic;
        asi_type0_lane7_channel         : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type0_lane7_error           : in  std_logic_vector(2 downto 0) := (others => '0');
        asi_type0_lane7_endofrun        : in  std_logic := '0';

        asi_type1_up_ready              : out std_logic;
        asi_type1_up_valid              : in  std_logic;
        asi_type1_up_data               : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0);
        asi_type1_up_ts                 : in  std_logic_vector(47 downto 0);
        -- arrival GTS co-sampled with asi_type1_up_ts (mts up-bank counter_gts_8n);
        -- delay-mode key = up_gts - up_ts (one epoch). gts-unify, BUG-012.
        asi_type1_up_gts                : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_up_startofpacket      : in  std_logic;
        asi_type1_up_endofpacket        : in  std_logic;
        asi_type1_up_channel            : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type1_up_empty              : in  std_logic := '0';
        asi_type1_up_error              : in  std_logic := '0';

        asi_type1_down_ready            : out std_logic;
        asi_type1_down_valid            : in  std_logic;
        asi_type1_down_data             : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0);
        asi_type1_down_ts               : in  std_logic_vector(47 downto 0);
        -- arrival GTS co-sampled with asi_type1_down_ts (mts down-bank counter_gts_8n).
        asi_type1_down_gts              : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_down_startofpacket    : in  std_logic;
        asi_type1_down_endofpacket      : in  std_logic;
        asi_type1_down_channel          : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);
        asi_type1_down_empty            : in  std_logic := '0';
        asi_type1_down_error            : in  std_logic := '0';

        -- Phase-I passive Type1 taps. These lanes are intentionally readyless:
        -- histogram pressure is absorbed by the per-lane binned FIFOs and can
        -- never stall the MTS or the existing sorter datapath. latency is a
        -- signed two's-complement 48-bit value co-sampled with data/ts/valid.
        asi_type1_lane0_valid           : in  std_logic := '0';
        asi_type1_lane0_data            : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0) := (others => '0');
        asi_type1_lane0_ts              : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane0_latency         : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane0_error           : in  std_logic := '0';

        asi_type1_lane1_valid           : in  std_logic := '0';
        asi_type1_lane1_data            : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0) := (others => '0');
        asi_type1_lane1_ts              : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane1_latency         : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane1_error           : in  std_logic := '0';

        asi_type1_lane2_valid           : in  std_logic := '0';
        asi_type1_lane2_data            : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0) := (others => '0');
        asi_type1_lane2_ts              : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane2_latency         : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane2_error           : in  std_logic := '0';

        asi_type1_lane3_valid           : in  std_logic := '0';
        asi_type1_lane3_data            : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0) := (others => '0');
        asi_type1_lane3_ts              : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane3_latency         : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane3_error           : in  std_logic := '0';

        asi_type1_lane4_valid           : in  std_logic := '0';
        asi_type1_lane4_data            : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0) := (others => '0');
        asi_type1_lane4_ts              : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane4_latency         : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane4_error           : in  std_logic := '0';

        asi_type1_lane5_valid           : in  std_logic := '0';
        asi_type1_lane5_data            : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0) := (others => '0');
        asi_type1_lane5_ts              : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane5_latency         : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane5_error           : in  std_logic := '0';

        asi_type1_lane6_valid           : in  std_logic := '0';
        asi_type1_lane6_data            : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0) := (others => '0');
        asi_type1_lane6_ts              : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane6_latency         : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane6_error           : in  std_logic := '0';

        asi_type1_lane7_valid           : in  std_logic := '0';
        asi_type1_lane7_data            : in  std_logic_vector(TYPE1_DATA_WIDTH - 1 downto 0) := (others => '0');
        asi_type1_lane7_ts              : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane7_latency         : in  std_logic_vector(47 downto 0) := (others => '0');
        asi_type1_lane7_error           : in  std_logic := '0';

        asi_hit_type1_extended_0_valid   : in  std_logic := '0';
        asi_hit_type1_extended_0_data    : in  std_logic_vector(86 downto 0) := (others => '0');
        asi_hit_type1_extended_1_valid   : in  std_logic := '0';
        asi_hit_type1_extended_1_data    : in  std_logic_vector(86 downto 0) := (others => '0');

        aso_hist_fill_out_ready         : in  std_logic := '1';
        aso_hist_fill_out_valid         : out std_logic;
        aso_hist_fill_out_data          : out std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        aso_hist_fill_out_startofpacket : out std_logic;
        aso_hist_fill_out_endofpacket   : out std_logic;
        aso_hist_fill_out_channel       : out std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        -- rc-network is readyless (USE_READY=0 broadcast); no ready output
        -- on this entity boundary. The original constant '1' driver has been
        -- removed.
        asi_ctrl_data                   : in  std_logic_vector(8 downto 0);
        asi_ctrl_valid                  : in  std_logic;

        asi_debug_1_valid               : in  std_logic;
        asi_debug_1_data                : in  std_logic_vector(15 downto 0);
        asi_debug_2_valid               : in  std_logic;
        asi_debug_2_data                : in  std_logic_vector(15 downto 0);
        asi_debug_3_valid               : in  std_logic;
        asi_debug_3_data                : in  std_logic_vector(15 downto 0);
        asi_debug_4_valid               : in  std_logic;
        asi_debug_4_data                : in  std_logic_vector(15 downto 0);
        asi_debug_5_valid               : in  std_logic;
        asi_debug_5_data                : in  std_logic_vector(15 downto 0);
        asi_debug_6_valid               : in  std_logic;
        asi_debug_6_data                : in  std_logic_vector(15 downto 0);

        i_interval_reset                : in  std_logic := '0';
        i_rst                           : in  std_logic;
        i_clk                           : in  std_logic
    );
end entity histogram_statistics_v2;

architecture rtl of histogram_statistics_v2 is

    constant MAX_PORTS_CONST        : natural := HS_MAX_PORTS_CONST;
    -- Keep the ingress queue deep enough that bursty measurement traffic
    -- does not get dropped before it reaches the divider/coalescer.
    constant FIFO_ADDR_WIDTH_CONST  : natural := FIFO_ADDR_WIDTH;
    constant BIN_INDEX_WIDTH_CONST  : natural := clog2(N_BINS);
    constant KICK_WIDTH_CONST       : natural := KICK_COUNT_WIDTH;
    constant COUNT_WIDTH_CONST      : natural := MAX_COUNT_BITS;
    constant STATS_COUNT_WIDTH_CONST : natural := MAX_COUNT_BITS;
    constant PORT_WIDTH_CONST       : natural := clog2(MAX_PORTS_CONST);

    function max_nat(
        lhs : natural;
        rhs : natural
    ) return natural is
    begin
        if lhs > rhs then
            return lhs;
        end if;
        return rhs;
    end function max_nat;

    -- One extra signed bit above both possible operands prevents the CSR
    -- auto-right-bound sum from wrapping before representability is checked.
    -- BIN_WIDTH is 16 bits and N_BINS needs clog2(N_BINS) magnitude bits.
    constant RIGHT_CALC_WIDTH_CONST : natural := max_nat(
        SAR_TICK_WIDTH,
        17 + clog2(N_BINS)
    ) + 1;

    constant DELAY_TIMESTAMP_WIDTH_CONST : natural := 48;
    constant HIST_SOURCE_TYPE0_CONST      : unsigned(1 downto 0) := "00";
    constant HIST_SOURCE_TYPE1_UP_CONST   : unsigned(1 downto 0) := "01";
    constant HIST_SOURCE_TYPE1_DOWN_CONST : unsigned(1 downto 0) := "10";
    constant HIST_SOURCE_TYPE1_ALL_CONST  : unsigned(1 downto 0) := "11";
    constant IN_PORT_FILL_CONST           : unsigned(1 downto 0) := "00";
    constant IN_PORT_EXT0_CONST           : unsigned(1 downto 0) := "01";
    constant IN_PORT_EXT1_CONST           : unsigned(1 downto 0) := "10";
    -- The full signed MTS latency is kept through the range-check/mapping
    -- stage. Only the already-binned result is stored in the per-lane FIFO.
    constant DIVIDER_TICK_WIDTH_CONST     : natural := DELAY_TIMESTAMP_WIDTH_CONST;
    constant FIFO_COUNT_LOW_CONST         : natural := 0;
    constant FIFO_COUNT_HIGH_CONST        : natural := KICK_WIDTH_CONST - 1;
    constant FIFO_BIN_LOW_CONST           : natural := KICK_WIDTH_CONST;
    constant FIFO_BIN_HIGH_CONST          : natural := KICK_WIDTH_CONST + BIN_INDEX_WIDTH_CONST - 1;
    constant FIFO_BANK_BIT_CONST          : natural := KICK_WIDTH_CONST + BIN_INDEX_WIDTH_CONST;
    constant FIFO_WORD_WIDTH_CONST        : natural := FIFO_BANK_BIT_CONST + 1;
    constant PENDING_DELTA_WIDTH_CONST    : natural := max_nat(clog2(MAX_PORTS_CONST + 1), KICK_WIDTH_CONST) + 1;
    constant UPDATE_KEY_LOW_CONST        : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_LO, 8);
    constant UPDATE_KEY_HIGH_CONST       : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_HI, 8);
    constant FILTER_KEY_LOW_CONST        : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_LO, 8);
    constant FILTER_KEY_HIGH_CONST       : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_HI, 8);
    -- LOCK_KEY_RANGES update-key slices: ASIC[2:0] concatenated with CH[4:0],
    -- 8-bit field, gives 256 unique (asic, channel) combos for 8 ASICs * 32 CH
    -- which maps 1:1 onto N_BINS=256 with BIN_WIDTH=1. Type0 layout puts ASIC
    -- at bits[44:41] and CH at bits[40:36] (env_pkg HS_TYPE0_ASIC/CH); we drop
    -- the unused ASIC[3] MSB and key on bits[43:36]. Type1 layout is the same
    -- shape but shifted: ASIC at bits[38:35], CH at bits[34:30] (env_pkg
    -- HS_TYPE1_ASIC/CH); we key on bits[37:30].
    constant TYPE0_UPDATE_KEY_LOW_CONST  : natural := 36;
    constant TYPE0_UPDATE_KEY_HIGH_CONST : natural := 43;
    constant TYPE0_FILTER_KEY_LOW_CONST  : natural := 41;
    constant TYPE0_FILTER_KEY_HIGH_CONST : natural := 44;
    constant TYPE1_UPDATE_KEY_LOW_CONST  : natural := 30;
    constant TYPE1_UPDATE_KEY_HIGH_CONST : natural := 37;
    constant TYPE1_FILTER_KEY_LOW_CONST  : natural := 35;
    constant TYPE1_FILTER_KEY_HIGH_CONST : natural := 38;
    constant RUNCTL_IDLE_CMD_CONST        : std_logic_vector(8 downto 0) := "000000001";
    constant RUNCTL_PREPARE_CMD_CONST     : std_logic_vector(8 downto 0) := "000000010";
    constant RUNCTL_SYNC_CMD_CONST        : std_logic_vector(8 downto 0) := "000000100";
    constant RUNCTL_RUNNING_CMD_CONST     : std_logic_vector(8 downto 0) := "000001000";
    constant RUNCTL_TERMINATING_CMD_CONST : std_logic_vector(8 downto 0) := "000010000";
    constant RUNCTL_LINK_TEST_CMD_CONST   : std_logic_vector(8 downto 0) := "000100000";
    constant RUNCTL_SYNC_TEST_CMD_CONST   : std_logic_vector(8 downto 0) := "001000000";
    constant RUNCTL_RESET_CMD_CONST       : std_logic_vector(8 downto 0) := "010000000";
    constant RUNCTL_OUT_OF_DAQ_CMD_CONST  : std_logic_vector(8 downto 0) := "100000000";

    subtype tick_t      is signed(SAR_TICK_WIDTH - 1 downto 0);
    subtype right_calc_t is signed(RIGHT_CALC_WIDTH_CONST - 1 downto 0);
    subtype tick_slv_t  is std_logic_vector(SAR_TICK_WIDTH - 1 downto 0);
    subtype delay_ts_t  is unsigned(DELAY_TIMESTAMP_WIDTH_CONST - 1 downto 0);
    subtype fifo_level_t is unsigned(FIFO_ADDR_WIDTH_CONST downto 0);
    subtype port_index_t is unsigned(PORT_WIDTH_CONST - 1 downto 0);
    subtype bin_index_t is unsigned(BIN_INDEX_WIDTH_CONST - 1 downto 0);
    subtype stats_count_t is unsigned(STATS_COUNT_WIDTH_CONST - 1 downto 0);
    subtype status_byte_t is unsigned(7 downto 0);
    subtype bank_pending_count_t is unsigned(STATS_COUNT_WIDTH_CONST - 1 downto 0);

    function calculate_right_bound_f(
        left_bound : tick_t;
        bin_width  : unsigned(15 downto 0)
    ) return right_calc_t is
        variable width_v   : unsigned(RIGHT_CALC_WIDTH_CONST - 1 downto 0);
        variable n_bins_v  : unsigned(RIGHT_CALC_WIDTH_CONST - 1 downto 0);
        variable product_v : unsigned((2 * RIGHT_CALC_WIDTH_CONST) - 1 downto 0);
    begin
        width_v   := resize(bin_width, RIGHT_CALC_WIDTH_CONST);
        n_bins_v  := to_unsigned(N_BINS, RIGHT_CALC_WIDTH_CONST);
        product_v := width_v * n_bins_v;
        return resize(left_bound, RIGHT_CALC_WIDTH_CONST) + signed(resize(product_v, RIGHT_CALC_WIDTH_CONST));
    end function calculate_right_bound_f;

    function right_bound_fits_f(
        right_bound : right_calc_t
    ) return boolean is
        variable narrowed_v : tick_t;
    begin
        narrowed_v := resize(right_bound, SAR_TICK_WIDTH);
        return resize(narrowed_v, RIGHT_CALC_WIDTH_CONST) = right_bound;
    end function right_bound_fits_f;

    function default_right_bound_f return tick_t is
        variable calculated_v : right_calc_t;
    begin
        calculated_v := calculate_right_bound_f(
            to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH),
            to_unsigned(DEF_BIN_WIDTH, 16)
        );
        return resize(calculated_v, SAR_TICK_WIDTH);
    end function default_right_bound_f;


    type run_state_t is (
        IDLE,
        RUN_PREPARE,
        SYNC,
        RUNNING,
        TERMINATING,
        LINK_TEST,
        SYNC_TEST,
        RESET,
        OUT_OF_DAQ,
        ERROR
    );

    type status_pair_max_array_t is array (0 to (MAX_PORTS_CONST / 2) - 1) of status_byte_t;

    signal port_valid     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal port_data      : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(AVST_DATA_WIDTH - 1 downto 0);
    signal port_ts        : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DELAY_TIMESTAMP_WIDTH_CONST - 1 downto 0);
    -- arrival GTS per port, co-sampled with port_ts from the MTS bank conduits.
    -- delay-mode subtracts this (not a local free-running counter) from port_ts.
    signal port_arrival_gts : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DELAY_TIMESTAMP_WIDTH_CONST - 1 downto 0);
    signal port_latency   : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DELAY_TIMESTAMP_WIDTH_CONST - 1 downto 0);
    signal port_error     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal port_channel   : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(AVST_CHANNEL_WIDTH - 1 downto 0);
    signal port_ready     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal ingress_accept : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_debug_data_next : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(15 downto 0) := (others => (others => '0'));
    signal ingress_debug_source_next : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(2 downto 0) := (others => (others => '0'));
    -- Selected-sample retime.  The source mux and ready qualification terminate
    -- here; key/filter extraction starts from these local registers one cycle
    -- later.  This keeps the passive taps at one beat/lane/clock while cutting
    -- the high-fanout source-select -> port mux -> key-extractor timing cone.
    signal sample_stage_valid : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal sample_stage_data : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(AVST_DATA_WIDTH - 1 downto 0) := (others => (others => '0'));
    signal sample_stage_ts : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DELAY_TIMESTAMP_WIDTH_CONST - 1 downto 0) := (others => (others => '0'));
    signal sample_stage_arrival_gts : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DELAY_TIMESTAMP_WIDTH_CONST - 1 downto 0) := (others => (others => '0'));
    signal sample_stage_latency : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DELAY_TIMESTAMP_WIDTH_CONST - 1 downto 0) := (others => (others => '0'));
    signal sample_stage_debug_data : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(15 downto 0) := (others => (others => '0'));
    signal sample_stage_debug_source : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(2 downto 0) := (others => (others => '0'));
    signal sample_stage_source_select : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(1 downto 0) := (others => to_unsigned(DEF_SOURCE_SELECT, 2));
    signal sample_stage_mode : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(3 downto 0) := (others => std_logic_vector(to_signed(DEF_MODE, 4)));
    signal sample_stage_key_unsigned : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED"));
    signal sample_stage_update_key_low : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(7 downto 0) := (others => to_unsigned(UPDATE_KEY_BIT_LO, 8));
    signal sample_stage_update_key_high : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(7 downto 0) := (others => to_unsigned(UPDATE_KEY_BIT_HI, 8));
    signal sample_stage_filter_enable : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal sample_stage_filter_reject : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal sample_stage_filter_key_low : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(7 downto 0) := (others => to_unsigned(FILTER_KEY_BIT_LO, 8));
    signal sample_stage_filter_key_high : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(7 downto 0) := (others => to_unsigned(FILTER_KEY_BIT_HI, 8));
    signal sample_stage_filter_key : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(SAR_KEY_WIDTH - 1 downto 0) := (others => (others => '0'));
    signal sample_stage_bank : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_write_req : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_key_next : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DIVIDER_TICK_WIDTH_CONST - 1 downto 0);
    signal ingress_bank_next : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_filter_field_next : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(SAR_KEY_WIDTH - 1 downto 0) := (others => (others => '0'));
    -- Dynamic runtime filter slicing is retimed separately from the equality
    -- comparison. This stage preserves one hit/lane/clock throughput while
    -- cutting the six-level range-select + compare cone seen in slow-corner
    -- Phase-I standalone timing.
    signal filter_stage_valid : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal filter_stage_field : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(SAR_KEY_WIDTH - 1 downto 0) := (others => (others => '0'));
    signal filter_stage_filter_key : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(SAR_KEY_WIDTH - 1 downto 0) := (others => (others => '0'));
    signal filter_stage_filter_enable : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal filter_stage_filter_reject : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal filter_stage_key : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DIVIDER_TICK_WIDTH_CONST - 1 downto 0) := (others => (others => '0'));
    signal filter_stage_bank : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_stage_valid : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_stage_write_req : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_stage_key : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DIVIDER_TICK_WIDTH_CONST - 1 downto 0);
    signal ingress_stage_bank : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal fifo_write     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal fifo_read      : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal fifo_empty     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal fifo_full      : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal fifo_level     : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(FIFO_ADDR_WIDTH_CONST downto 0);
    signal fifo_level_max : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(FIFO_ADDR_WIDTH_CONST downto 0);
    signal fifo_rd_data   : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(FIFO_WORD_WIDTH_CONST - 1 downto 0);
    signal fifo_wr_data   : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(FIFO_WORD_WIDTH_CONST - 1 downto 0);
    signal accept_pulse   : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal drop_pulse     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal accept_stat_pulse_d1 : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal drop_stat_pulse_d1   : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal divider_stat_valid_d1     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal divider_stat_underflow_d1 : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal divider_stat_overflow_d1  : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');

    signal divider_in_valid   : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal divider_in_key     : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(DIVIDER_TICK_WIDTH_CONST - 1 downto 0);
    signal divider_in_count   : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(KICK_WIDTH_CONST - 1 downto 0);
    signal divider_in_bank    : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');

    signal divider_valid      : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal divider_underflow  : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal divider_overflow   : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal divider_bin_index  : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(BIN_INDEX_WIDTH_CONST - 1 downto 0);
    signal divider_count      : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(KICK_WIDTH_CONST - 1 downto 0);
    signal divider_bank       : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal queue_hit_valid    : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal queue_hit_accept   : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal queue_hit_bank     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal queue_hit_bin      : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(BIN_INDEX_WIDTH_CONST - 1 downto 0);
    signal queue_hit_count    : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(KICK_WIDTH_CONST - 1 downto 0);

    signal queue_drain_valid    : std_logic;
    signal queue_drain_bank     : std_logic;
    signal queue_drain_bin      : bin_index_t;
    signal queue_drain_count    : unsigned(KICK_WIDTH_CONST - 1 downto 0);
    signal queue_drain_ready    : std_logic;
    signal queue_occupancy      : unsigned(clog2(COAL_QUEUE_DEPTH + 1) - 1 downto 0) := (others => '0');
    signal queue_occupancy_max  : unsigned(clog2(COAL_QUEUE_DEPTH + 1) - 1 downto 0) := (others => '0');
    signal queue_overflow_count : unsigned(15 downto 0) := (others => '0');
    signal bank_pending_count   : hs_unsigned_array_t(0 to 1)(STATS_COUNT_WIDTH_CONST - 1 downto 0) := (others => (others => '0'));
    signal bank_pending         : std_logic_vector(1 downto 0) := (others => '0');
    signal fifo_write_d1        : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal fifo_write_bank_d1   : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal bank_pending_write_seen : std_logic_vector(1 downto 0) := (others => '0');
    signal bank_pending_inc_count      : hs_unsigned_array_t(0 to 1)(PENDING_DELTA_WIDTH_CONST - 1 downto 0) := (others => (others => '0'));
    signal bank_pending_dec_count      : hs_unsigned_array_t(0 to 1)(PENDING_DELTA_WIDTH_CONST - 1 downto 0) := (others => (others => '0'));
    signal bank_pending_inc_seen       : std_logic_vector(1 downto 0) := (others => '0');
    signal bank_pending_inc_count_d1   : hs_unsigned_array_t(0 to 1)(PENDING_DELTA_WIDTH_CONST - 1 downto 0) := (others => (others => '0'));
    signal bank_pending_dec_count_d1   : hs_unsigned_array_t(0 to 1)(PENDING_DELTA_WIDTH_CONST - 1 downto 0) := (others => (others => '0'));
    signal bank_pending_inc_seen_d1    : std_logic_vector(1 downto 0) := (others => '0');

    signal hist_readdata        : std_logic_vector(31 downto 0);
    signal hist_readdatavalid   : std_logic;
    signal hist_waitrequest     : std_logic;
    signal hist_update_busy     : std_logic;
    signal hist_pipeline_busy   : std_logic := '0';
    signal cfg_pipeline_busy_q  : std_logic := '1';
    signal cfg_pipeline_quiet_q : std_logic := '0';
    signal hist_writeresp_valid : std_logic := '0';
    signal active_bank          : std_logic;
    signal flushing             : std_logic;
    signal flush_addr           : bin_index_t;
    signal interval_pulse       : std_logic;
    signal clear_pulse          : std_logic;
    signal measure_clear_comb   : std_logic;
    signal measure_clear_pulse  : std_logic := '0';
    signal datapath_clear_pulse : std_logic := '0';
    signal term_flush_armed      : std_logic := '0';
    signal force_interval_pulse  : std_logic := '0';

    signal csr_mode             : std_logic_vector(3 downto 0) := std_logic_vector(to_signed(DEF_MODE, 4));
    signal csr_in_port          : unsigned(1 downto 0) := IN_PORT_FILL_CONST;
    signal csr_key_unsigned     : std_logic := bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED");
    signal csr_filter_enable    : std_logic := '0';
    signal csr_filter_reject    : std_logic := '0';
    signal csr_error            : std_logic := '0';
    signal csr_error_info       : std_logic_vector(3 downto 0) := (others => '0');
    signal csr_left_bound       : tick_t := to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH);
    signal csr_right_bound      : tick_t := default_right_bound_f;
    signal csr_bin_width        : unsigned(15 downto 0) := to_unsigned(DEF_BIN_WIDTH, 16);
    signal csr_update_key_low   : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_LO, 8);
    signal csr_update_key_high  : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_HI, 8);
    signal csr_filter_key_low   : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_LO, 8);
    signal csr_filter_key_high  : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_HI, 8);
    signal csr_update_key       : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
    signal csr_filter_key       : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
    signal csr_source_select    : unsigned(1 downto 0) := to_unsigned(DEF_SOURCE_SELECT, 2);
    signal csr_underflow_count  : stats_count_t := (others => '0');
    signal csr_overflow_count   : stats_count_t := (others => '0');
    signal csr_total_hits       : stats_count_t := (others => '0');
    signal csr_dropped_hits     : stats_count_t := (others => '0');
    signal csr_last_interval_total_hits   : stats_count_t := (others => '0');
    signal csr_last_interval_dropped_hits : stats_count_t := (others => '0');
    signal csr_interval_cfg     : unsigned(31 downto 0) := to_unsigned(DEF_INTERVAL_CLOCKS, 32);
    signal csr_scratch          : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_meta_sel         : std_logic_vector(1 downto 0)  := (others => '0');
    signal csr_bank_status      : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_port_status      : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_coal_status      : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_readdata_mux     : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_readdata_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal run_state_cmd        : run_state_t := IDLE;
    signal runctl_sync_start    : std_logic := '0';
    signal runctl_run_start     : std_logic := '0';
    signal cfg_apply_request    : std_logic := '0';
    signal cfg_apply_pending    : std_logic := '0';
    signal cfg_mode             : std_logic_vector(3 downto 0) := std_logic_vector(to_signed(DEF_MODE, 4));
    signal cfg_in_port          : unsigned(1 downto 0) := IN_PORT_FILL_CONST;
    signal cfg_key_unsigned     : std_logic := bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED");
    signal cfg_filter_enable    : std_logic := '0';
    signal cfg_filter_reject    : std_logic := '0';
    signal cfg_left_bound       : tick_t := to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH);
    signal cfg_right_bound      : tick_t := default_right_bound_f;
    signal cfg_bin_width        : unsigned(15 downto 0) := to_unsigned(DEF_BIN_WIDTH, 16);
    signal cfg_update_key_low   : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_LO, 8);
    signal cfg_update_key_high  : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_HI, 8);
    signal cfg_filter_key_low   : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_LO, 8);
    signal cfg_filter_key_high  : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_HI, 8);
    signal cfg_update_key       : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
    signal cfg_filter_key       : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
    signal cfg_source_select    : unsigned(1 downto 0) := to_unsigned(DEF_SOURCE_SELECT, 2);
    signal cfg_interval_cfg     : unsigned(31 downto 0) := to_unsigned(DEF_INTERVAL_CLOCKS, 32);
    signal cfg_filter_enable_port  : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal cfg_filter_reject_port  : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal cfg_filter_key_low_port : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(7 downto 0) := (others => to_unsigned(FILTER_KEY_BIT_LO, 8));
    signal cfg_filter_key_high_port: hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(7 downto 0) := (others => to_unsigned(FILTER_KEY_BIT_HI, 8));
    signal cfg_filter_key_port     : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(SAR_KEY_WIDTH - 1 downto 0) := (others => (others => '0'));
    -- Replicate the static source selection at config-commit time.  Each lane's
    -- input mux then has a local two-bit launch register instead of sharing the
    -- former >1000-fanout cfg_source_select register.
    signal cfg_source_select_port  : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(1 downto 0) := (others => to_unsigned(DEF_SOURCE_SELECT, 2));

    signal status_active_bank_shadow        : std_logic := '0';
    signal status_flushing_shadow           : std_logic := '0';
    signal status_flush_addr_shadow         : std_logic_vector(7 downto 0) := (others => '0');
    signal status_fifo_empty_shadow         : std_logic_vector(7 downto 0) := (others => '1');
    signal status_fifo_pair_max_shadow      : status_pair_max_array_t := (others => (others => '0'));
    signal status_queue_occupancy_shadow    : status_byte_t := (others => '0');
    signal status_queue_occupancy_max_shadow : status_byte_t := (others => '0');
    signal status_queue_overflow_shadow     : unsigned(15 downto 0) := (others => '0');

    function extend_to_hist_data(
        data_word : std_logic_vector
    ) return std_logic_vector is
        variable result_v : std_logic_vector(AVST_DATA_WIDTH - 1 downto 0) := (others => '0');
    begin
        for bit_idx_v in data_word'range loop
            if bit_idx_v <= result_v'high then
                result_v(bit_idx_v) := data_word(bit_idx_v);
            end if;
        end loop;
        return result_v;
    end function extend_to_hist_data;

    function match_filter(
        data_word       : std_logic_vector;
        filter_enable   : std_logic;
        filter_reject   : std_logic;
        filter_hi       : unsigned(7 downto 0);
        filter_lo       : unsigned(7 downto 0);
        filter_key      : unsigned
    ) return boolean is
        variable field_v : unsigned(filter_key'range);
        variable match_v : boolean;
    begin
        if filter_enable = '0' then
            return true;
        end if;
        field_v := resize(
            extract_unsigned(data_word, to_integer(filter_hi), to_integer(filter_lo)),
            filter_key'length
        );
        match_v := field_v = filter_key;
        if filter_reject = '1' then
            return not match_v;
        end if;
        return match_v;
    end function match_filter;

    function is_power2_u(
        value : unsigned
    ) return boolean is
        variable seen_one_v : boolean := false;
    begin
        for bit_idx in value'range loop
            if value(bit_idx) = '1' then
                if seen_one_v then
                    return false;
                end if;
                seen_one_v := true;
            end if;
        end loop;
        return seen_one_v;
    end function is_power2_u;

    function extract_fixed_unsigned(
        data_word : std_logic_vector;
        bit_hi    : natural;
        bit_lo    : natural
    ) return unsigned is
        variable result_v  : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
        variable src_idx_v : natural;
    begin
        for dst_idx_v in 0 to SAR_KEY_WIDTH - 1 loop
            src_idx_v := dst_idx_v + bit_lo;
            if (dst_idx_v <= (bit_hi - bit_lo)) and (src_idx_v >= data_word'low) and (src_idx_v <= data_word'high) then
                result_v(dst_idx_v) := data_word(src_idx_v);
            end if;
        end loop;
        return result_v;
    end function extract_fixed_unsigned;

    function extract_fixed_signed(
        data_word : std_logic_vector;
        bit_hi    : natural;
        bit_lo    : natural
    ) return signed is
        variable raw_v      : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
        variable result_v   : signed(SAR_KEY_WIDTH - 1 downto 0);
        variable sign_bit_v : std_logic := '0';
        variable src_idx_v  : natural;
    begin
        if (bit_hi >= data_word'low) and (bit_hi <= data_word'high) then
            sign_bit_v := data_word(bit_hi);
        end if;

        raw_v := (others => sign_bit_v);
        for dst_idx_v in 0 to SAR_KEY_WIDTH - 1 loop
            src_idx_v := dst_idx_v + bit_lo;
            if (dst_idx_v <= (bit_hi - bit_lo)) and (src_idx_v >= data_word'low) and (src_idx_v <= data_word'high) then
                raw_v(dst_idx_v) := data_word(src_idx_v);
            end if;
        end loop;

        result_v := signed(raw_v);
        return result_v;
    end function extract_fixed_signed;

    function fixed_update_hi(
        source_select : unsigned(1 downto 0)
    ) return natural is
    begin
        if source_select = HIST_SOURCE_TYPE0_CONST then
            return TYPE0_UPDATE_KEY_HIGH_CONST;
        end if;
        return TYPE1_UPDATE_KEY_HIGH_CONST;
    end function fixed_update_hi;

    function fixed_update_lo(
        source_select : unsigned(1 downto 0)
    ) return natural is
    begin
        if source_select = HIST_SOURCE_TYPE0_CONST then
            return TYPE0_UPDATE_KEY_LOW_CONST;
        end if;
        return TYPE1_UPDATE_KEY_LOW_CONST;
    end function fixed_update_lo;

    function fixed_filter_hi(
        source_select : unsigned(1 downto 0)
    ) return natural is
    begin
        if source_select = HIST_SOURCE_TYPE0_CONST then
            return TYPE0_FILTER_KEY_HIGH_CONST;
        end if;
        return TYPE1_FILTER_KEY_HIGH_CONST;
    end function fixed_filter_hi;

    function fixed_filter_lo(
        source_select : unsigned(1 downto 0)
    ) return natural is
    begin
        if source_select = HIST_SOURCE_TYPE0_CONST then
            return TYPE0_FILTER_KEY_LOW_CONST;
        end if;
        return TYPE1_FILTER_KEY_LOW_CONST;
    end function fixed_filter_lo;

    function match_fixed_filter(
        data_word       : std_logic_vector;
        source_select   : unsigned(1 downto 0);
        filter_enable   : std_logic;
        filter_reject   : std_logic;
        filter_key      : unsigned
    ) return boolean is
        variable field_v : unsigned(filter_key'range);
        variable match_v : boolean;
    begin
        if filter_enable = '0' then
            return true;
        end if;

        field_v := resize(
            extract_fixed_unsigned(
                data_word,
                fixed_filter_hi(source_select),
                fixed_filter_lo(source_select)
            ),
            filter_key'length
        );
        match_v := field_v = filter_key;
        if filter_reject = '1' then
            return not match_v;
        end if;
        return match_v;
    end function match_fixed_filter;

    function build_key(
        data_word    : std_logic_vector;
        key_hi       : unsigned(7 downto 0);
        key_lo       : unsigned(7 downto 0);
        key_unsigned : std_logic
    ) return std_logic_vector is
        variable result_v : tick_t := (others => '0');
        variable raw_u_v  : unsigned(SAR_KEY_WIDTH - 1 downto 0);
        variable raw_s_v  : signed(SAR_KEY_WIDTH - 1 downto 0);
    begin
        if key_unsigned = '1' then
            raw_u_v  := resize(
                extract_unsigned(data_word, to_integer(key_hi), to_integer(key_lo)),
                SAR_KEY_WIDTH
            );
            result_v := signed(resize(raw_u_v, SAR_TICK_WIDTH));
        else
            raw_s_v  := resize(
                extract_signed(data_word, to_integer(key_hi), to_integer(key_lo)),
                SAR_KEY_WIDTH
            );
            result_v := resize(raw_s_v, SAR_TICK_WIDTH);
        end if;
        return std_logic_vector(result_v);
    end function build_key;

    function build_fixed_key(
        data_word     : std_logic_vector;
        source_select : unsigned(1 downto 0);
        key_unsigned  : std_logic
    ) return std_logic_vector is
        variable result_v : tick_t := (others => '0');
        variable raw_u_v  : unsigned(SAR_KEY_WIDTH - 1 downto 0);
        variable raw_s_v  : signed(SAR_KEY_WIDTH - 1 downto 0);
    begin
        if key_unsigned = '1' then
            raw_u_v := extract_fixed_unsigned(
                data_word,
                fixed_update_hi(source_select),
                fixed_update_lo(source_select)
            );
            result_v := signed(resize(raw_u_v, SAR_TICK_WIDTH));
        else
            raw_s_v := extract_fixed_signed(
                data_word,
                fixed_update_hi(source_select),
                fixed_update_lo(source_select)
            );
            result_v := resize(raw_s_v, SAR_TICK_WIDTH);
        end if;
        return std_logic_vector(result_v);
    end function build_fixed_key;

    function build_delay_key(
        data_word : std_logic_vector;
        key_hi    : unsigned(7 downto 0);
        key_lo    : unsigned(7 downto 0);
        gts_value : unsigned
    ) return std_logic_vector is
        variable gts_full_v : delay_ts_t := (others => '0');
        variable hit_full_v : delay_ts_t := (others => '0');
        variable delay_v    : delay_ts_t := (others => '0');
        variable result_v   : tick_t := (others => '0');
    begin
        gts_full_v := resize(gts_value, DELAY_TIMESTAMP_WIDTH_CONST);
        hit_full_v := resize(
            extract_unsigned(data_word, to_integer(key_hi), to_integer(key_lo)),
            DELAY_TIMESTAMP_WIDTH_CONST
        );

        delay_v := gts_full_v - hit_full_v;

        for bit_idx_v in 0 to SAR_TICK_WIDTH - 1 loop
            if bit_idx_v < DELAY_TIMESTAMP_WIDTH_CONST then
                result_v(bit_idx_v) := delay_v(bit_idx_v);
            end if;
        end loop;

        return std_logic_vector(result_v);
    end function build_delay_key;

    function build_delay_key_from_ts(
        hit_ts    : std_logic_vector(DELAY_TIMESTAMP_WIDTH_CONST - 1 downto 0);
        gts_value : unsigned
    ) return std_logic_vector is
        variable gts_full_v : delay_ts_t := (others => '0');
        variable hit_full_v : delay_ts_t := (others => '0');
        variable delay_v    : delay_ts_t := (others => '0');
        variable result_v   : tick_t := (others => '0');
    begin
        gts_full_v := resize(gts_value, DELAY_TIMESTAMP_WIDTH_CONST);
        hit_full_v := unsigned(hit_ts);
        delay_v    := gts_full_v - hit_full_v;

        for bit_idx_v in 0 to SAR_TICK_WIDTH - 1 loop
            if bit_idx_v < DELAY_TIMESTAMP_WIDTH_CONST then
                result_v(bit_idx_v) := delay_v(bit_idx_v);
            end if;
        end loop;

        return std_logic_vector(result_v);
    end function build_delay_key_from_ts;

    function build_debug_key(
        debug_mode : integer;
        data_word  : std_logic_vector(15 downto 0)
    ) return std_logic_vector is
        variable result_v : tick_t := (others => '0');
    begin
        case debug_mode is
            when -1 | -7 =>
                result_v := resize(signed(data_word), SAR_TICK_WIDTH);
            when others =>
                result_v := signed(resize(unsigned(data_word), SAR_TICK_WIDTH));
        end case;
        return std_logic_vector(result_v);
    end function build_debug_key;

    function build_debug_filter_word(
        debug_source : natural;
        debug_mode   : integer;
        data_word    : std_logic_vector(15 downto 0)
    ) return std_logic_vector is
        variable result_v : std_logic_vector(AVST_DATA_WIDTH - 1 downto 0) := (others => '0');
        variable source_v : unsigned(7 downto 0) := to_unsigned(debug_source, 8);
        variable mode_v   : unsigned(7 downto 0) := (others => '0');
    begin
        if debug_mode < 0 then
            mode_v := to_unsigned(-debug_mode, 8);
        end if;

        for bit_idx_v in 0 to 15 loop
            if bit_idx_v <= result_v'high then
                result_v(bit_idx_v) := data_word(bit_idx_v);
            end if;
        end loop;

        for bit_idx_v in 0 to 7 loop
            if bit_idx_v + 16 <= result_v'high then
                result_v(bit_idx_v + 16) := source_v(bit_idx_v);
            end if;
            if bit_idx_v + 24 <= result_v'high then
                result_v(bit_idx_v + 24) := mode_v(bit_idx_v);
            end if;
        end loop;

        return result_v;
    end function build_debug_filter_word;

    function clip_status_byte_f(
        value_in : unsigned
    ) return status_byte_t is
        variable clipped_v : status_byte_t := (others => '0');
    begin
        if value_in'length > status_byte_t'length then
            if value_in(value_in'left downto status_byte_t'length) /= 0 then
                clipped_v := (others => '1');
            else
                clipped_v := resize(value_in, status_byte_t'length);
            end if;
        else
            clipped_v := resize(value_in, status_byte_t'length);
        end if;
        return clipped_v;
    end function clip_status_byte_f;

begin

    assert DEF_MODE >= -8 and DEF_MODE <= 7
        report "DEF_MODE must fit the signed four-bit CONTROL.mode field"
        severity failure;
    assert DEF_SOURCE_SELECT <= 3
        report "DEF_SOURCE_SELECT must fit CONTROL.source_select"
        severity failure;
    assert right_bound_fits_f(calculate_right_bound_f(
        to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH),
        to_unsigned(DEF_BIN_WIDTH, 16)
    ))
        report "Default LEFT_BOUND + BIN_WIDTH*N_BINS must fit SAR_TICK_WIDTH"
        severity failure;

    -- cfg_in_port = EXT0/EXT1 routes port 0 from the readyless 87-bit
    -- extended sinks (MTS upper/lower bank), taking priority over the
    -- cfg_source_select datapath stream. Extended data layout:
    --   [86:39] = 48-bit true hit timestamp -> port_ts(0)
    --   [38:0]  = 39-bit Type1 payload       -> port_data(0)
    port_valid(0) <= asi_hit_type1_extended_0_valid when cfg_in_port = IN_PORT_EXT0_CONST else
                     asi_hit_type1_extended_1_valid when cfg_in_port = IN_PORT_EXT1_CONST else
                     asi_type0_lane0_valid when cfg_source_select_port(0) = HIST_SOURCE_TYPE0_CONST else
                     asi_type1_up_valid    when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_UP_CONST else
                     asi_type1_down_valid  when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_DOWN_CONST else
                     asi_type1_lane0_valid when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_ALL_CONST else
                     '0';
    port_valid(1) <= asi_type0_lane1_valid when cfg_source_select_port(1) = HIST_SOURCE_TYPE0_CONST else asi_type1_lane1_valid when cfg_source_select_port(1) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_valid(2) <= asi_type0_lane2_valid when cfg_source_select_port(2) = HIST_SOURCE_TYPE0_CONST else asi_type1_lane2_valid when cfg_source_select_port(2) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_valid(3) <= asi_type0_lane3_valid when cfg_source_select_port(3) = HIST_SOURCE_TYPE0_CONST else asi_type1_lane3_valid when cfg_source_select_port(3) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_valid(4) <= asi_type0_lane4_valid when cfg_source_select_port(4) = HIST_SOURCE_TYPE0_CONST else asi_type1_lane4_valid when cfg_source_select_port(4) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_valid(5) <= asi_type0_lane5_valid when cfg_source_select_port(5) = HIST_SOURCE_TYPE0_CONST else asi_type1_lane5_valid when cfg_source_select_port(5) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_valid(6) <= asi_type0_lane6_valid when cfg_source_select_port(6) = HIST_SOURCE_TYPE0_CONST else asi_type1_lane6_valid when cfg_source_select_port(6) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_valid(7) <= asi_type0_lane7_valid when cfg_source_select_port(7) = HIST_SOURCE_TYPE0_CONST else asi_type1_lane7_valid when cfg_source_select_port(7) = HIST_SOURCE_TYPE1_ALL_CONST else '0';

    port_data(0) <= extend_to_hist_data(asi_hit_type1_extended_0_data(TYPE1_DATA_WIDTH - 1 downto 0)) when cfg_in_port = IN_PORT_EXT0_CONST else
                    extend_to_hist_data(asi_hit_type1_extended_1_data(TYPE1_DATA_WIDTH - 1 downto 0)) when cfg_in_port = IN_PORT_EXT1_CONST else
                    extend_to_hist_data(asi_type0_lane0_data) when cfg_source_select_port(0) = HIST_SOURCE_TYPE0_CONST else
                    extend_to_hist_data(asi_type1_up_data)    when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_UP_CONST else
                    extend_to_hist_data(asi_type1_down_data)  when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_DOWN_CONST else
                    extend_to_hist_data(asi_type1_lane0_data) when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_ALL_CONST else
                    (others => '0');
    port_data(1) <= extend_to_hist_data(asi_type0_lane1_data) when cfg_source_select_port(1) = HIST_SOURCE_TYPE0_CONST else extend_to_hist_data(asi_type1_lane1_data) when cfg_source_select_port(1) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_data(2) <= extend_to_hist_data(asi_type0_lane2_data) when cfg_source_select_port(2) = HIST_SOURCE_TYPE0_CONST else extend_to_hist_data(asi_type1_lane2_data) when cfg_source_select_port(2) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_data(3) <= extend_to_hist_data(asi_type0_lane3_data) when cfg_source_select_port(3) = HIST_SOURCE_TYPE0_CONST else extend_to_hist_data(asi_type1_lane3_data) when cfg_source_select_port(3) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_data(4) <= extend_to_hist_data(asi_type0_lane4_data) when cfg_source_select_port(4) = HIST_SOURCE_TYPE0_CONST else extend_to_hist_data(asi_type1_lane4_data) when cfg_source_select_port(4) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_data(5) <= extend_to_hist_data(asi_type0_lane5_data) when cfg_source_select_port(5) = HIST_SOURCE_TYPE0_CONST else extend_to_hist_data(asi_type1_lane5_data) when cfg_source_select_port(5) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_data(6) <= extend_to_hist_data(asi_type0_lane6_data) when cfg_source_select_port(6) = HIST_SOURCE_TYPE0_CONST else extend_to_hist_data(asi_type1_lane6_data) when cfg_source_select_port(6) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_data(7) <= extend_to_hist_data(asi_type0_lane7_data) when cfg_source_select_port(7) = HIST_SOURCE_TYPE0_CONST else extend_to_hist_data(asi_type1_lane7_data) when cfg_source_select_port(7) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');

    port_ts(0) <= asi_hit_type1_extended_0_data(86 downto 39) when cfg_in_port = IN_PORT_EXT0_CONST else
                  asi_hit_type1_extended_1_data(86 downto 39) when cfg_in_port = IN_PORT_EXT1_CONST else
                  asi_type1_up_ts   when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_UP_CONST else
                  asi_type1_down_ts when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_DOWN_CONST else
                  asi_type1_lane0_ts when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_ALL_CONST else
                  (others => '0');
    port_ts(1) <= asi_type1_lane1_ts when cfg_source_select_port(1) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_ts(2) <= asi_type1_lane2_ts when cfg_source_select_port(2) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_ts(3) <= asi_type1_lane3_ts when cfg_source_select_port(3) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_ts(4) <= asi_type1_lane4_ts when cfg_source_select_port(4) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_ts(5) <= asi_type1_lane5_ts when cfg_source_select_port(5) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_ts(6) <= asi_type1_lane6_ts when cfg_source_select_port(6) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_ts(7) <= asi_type1_lane7_ts when cfg_source_select_port(7) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');

    -- Arrival GTS for the active port (port 0), bank-matched to port_ts(0)'s ts.
    -- The MTS exports counter_gts_8n co-sampled with the emission ts, so
    -- delay = arrival_gts - hit_ts collapses to the MTS pipeline latency in ONE
    -- epoch (no cross-IP SYNC race). Use source=TYPE1_UP/DOWN (FILL in_port) for
    -- delay mode; the EXT0/EXT1 extended packets carry no arrival sideband.
    port_arrival_gts(0) <= asi_type1_up_gts   when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_UP_CONST else
                           asi_type1_down_gts when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_DOWN_CONST else
                           (others => '0');
    port_arrival_gts(1) <= (others => '0');
    port_arrival_gts(2) <= (others => '0');
    port_arrival_gts(3) <= (others => '0');
    port_arrival_gts(4) <= (others => '0');
    port_arrival_gts(5) <= (others => '0');
    port_arrival_gts(6) <= (others => '0');
    port_arrival_gts(7) <= (others => '0');

    port_latency(0) <= asi_type1_lane0_latency when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_latency(1) <= asi_type1_lane1_latency when cfg_source_select_port(1) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_latency(2) <= asi_type1_lane2_latency when cfg_source_select_port(2) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_latency(3) <= asi_type1_lane3_latency when cfg_source_select_port(3) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_latency(4) <= asi_type1_lane4_latency when cfg_source_select_port(4) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_latency(5) <= asi_type1_lane5_latency when cfg_source_select_port(5) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_latency(6) <= asi_type1_lane6_latency when cfg_source_select_port(6) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');
    port_latency(7) <= asi_type1_lane7_latency when cfg_source_select_port(7) = HIST_SOURCE_TYPE1_ALL_CONST else (others => '0');

    -- Error is retained as part of the lane contract and remains qualified by
    -- the matching valid beat. Histogram counting intentionally mirrors the
    -- legacy Type1 policy: errored hits are observable and are not silently
    -- removed from the measured population.
    port_error(0) <= asi_type1_lane0_error when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_ALL_CONST else
                     asi_type1_up_error when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_UP_CONST else
                     asi_type1_down_error when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_DOWN_CONST else '0';
    port_error(1) <= asi_type1_lane1_error when cfg_source_select_port(1) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_error(2) <= asi_type1_lane2_error when cfg_source_select_port(2) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_error(3) <= asi_type1_lane3_error when cfg_source_select_port(3) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_error(4) <= asi_type1_lane4_error when cfg_source_select_port(4) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_error(5) <= asi_type1_lane5_error when cfg_source_select_port(5) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_error(6) <= asi_type1_lane6_error when cfg_source_select_port(6) = HIST_SOURCE_TYPE1_ALL_CONST else '0';
    port_error(7) <= asi_type1_lane7_error when cfg_source_select_port(7) = HIST_SOURCE_TYPE1_ALL_CONST else '0';

    port_channel(0) <= asi_type0_lane0_channel when cfg_source_select_port(0) = HIST_SOURCE_TYPE0_CONST else
                       asi_type1_up_channel    when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_UP_CONST else
                       asi_type1_down_channel  when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_DOWN_CONST else
                       (others => '0');
    port_channel(1) <= asi_type0_lane1_channel when cfg_source_select_port(1) = HIST_SOURCE_TYPE0_CONST else (others => '0');
    port_channel(2) <= asi_type0_lane2_channel when cfg_source_select_port(2) = HIST_SOURCE_TYPE0_CONST else (others => '0');
    port_channel(3) <= asi_type0_lane3_channel when cfg_source_select_port(3) = HIST_SOURCE_TYPE0_CONST else (others => '0');
    port_channel(4) <= asi_type0_lane4_channel when cfg_source_select_port(4) = HIST_SOURCE_TYPE0_CONST else (others => '0');
    port_channel(5) <= asi_type0_lane5_channel when cfg_source_select_port(5) = HIST_SOURCE_TYPE0_CONST else (others => '0');
    port_channel(6) <= asi_type0_lane6_channel when cfg_source_select_port(6) = HIST_SOURCE_TYPE0_CONST else (others => '0');
    port_channel(7) <= asi_type0_lane7_channel when cfg_source_select_port(7) = HIST_SOURCE_TYPE0_CONST else (others => '0');

    asi_type0_lane0_ready <= port_ready(0) when cfg_source_select_port(0) = HIST_SOURCE_TYPE0_CONST else '0';
    asi_type0_lane1_ready <= port_ready(1) when cfg_source_select_port(1) = HIST_SOURCE_TYPE0_CONST else '0';
    asi_type0_lane2_ready <= port_ready(2) when cfg_source_select_port(2) = HIST_SOURCE_TYPE0_CONST else '0';
    asi_type0_lane3_ready <= port_ready(3) when cfg_source_select_port(3) = HIST_SOURCE_TYPE0_CONST else '0';
    asi_type0_lane4_ready <= port_ready(4) when cfg_source_select_port(4) = HIST_SOURCE_TYPE0_CONST else '0';
    asi_type0_lane5_ready <= port_ready(5) when cfg_source_select_port(5) = HIST_SOURCE_TYPE0_CONST else '0';
    asi_type0_lane6_ready <= port_ready(6) when cfg_source_select_port(6) = HIST_SOURCE_TYPE0_CONST else '0';
    asi_type0_lane7_ready <= port_ready(7) when cfg_source_select_port(7) = HIST_SOURCE_TYPE0_CONST else '0';
    asi_type1_up_ready    <= port_ready(0) when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_UP_CONST else '0';
    asi_type1_down_ready  <= port_ready(0) when cfg_source_select_port(0) = HIST_SOURCE_TYPE1_DOWN_CONST else '0';

    aso_hist_fill_out_valid         <= asi_type0_lane0_valid when (SNOOP_EN and cfg_source_select_port(0) = HIST_SOURCE_TYPE0_CONST) else '0';
    aso_hist_fill_out_data          <= extend_to_hist_data(asi_type0_lane0_data) when (SNOOP_EN and cfg_source_select_port(0) = HIST_SOURCE_TYPE0_CONST) else (others => '0');
    aso_hist_fill_out_startofpacket <= asi_type0_lane0_startofpacket when (SNOOP_EN and ENABLE_PACKET and cfg_source_select_port(0) = HIST_SOURCE_TYPE0_CONST) else '0';
    aso_hist_fill_out_endofpacket   <= asi_type0_lane0_endofpacket when (SNOOP_EN and ENABLE_PACKET and cfg_source_select_port(0) = HIST_SOURCE_TYPE0_CONST) else '0';
    aso_hist_fill_out_channel       <= asi_type0_lane0_channel when (SNOOP_EN and cfg_source_select_port(0) = HIST_SOURCE_TYPE0_CONST) else (others => '0');

    -- rc-network is readyless in v26.2.0; no asi_ctrl_ready driver here.
    avs_hist_bin_waitrequest        <= hist_waitrequest;
    avs_hist_bin_writeresponsevalid <= hist_writeresp_valid;
    -- SLVERR ("10") on a read beat that hit a momentarily busy readout bank
    -- (pingpong swap window); OKAY ("00") otherwise. A completed SLVERR beat
    -- lets the sc_hub fill the reply word and continue the burst full length,
    -- so a transient bank-busy read no longer times out and pads 0xEEEEEEEE.
    avs_hist_bin_response           <= (others => '0');
    avs_csr_waitrequest             <= '0';
    avs_hist_bin_readdata           <= hist_readdata;
    avs_hist_bin_readdatavalid      <= hist_readdatavalid;
    avs_csr_readdata                <= csr_readdata_reg;

    clear_pulse        <= bool_to_sl((avs_hist_bin_write = '1') and (hist_waitrequest = '0') and (avs_hist_bin_writedata = x"00000000"));
    measure_clear_comb <= clear_pulse or i_interval_reset;
    runctl_sync_start  <= bool_to_sl((asi_ctrl_valid = '1') and (asi_ctrl_data = RUNCTL_SYNC_CMD_CONST) and (run_state_cmd /= SYNC));
    -- Run control is contractually one-hot. Decode RUNNING from its dedicated
    -- bit here so the direct clear enable does not inherit a nine-bit equality
    -- cone on every wide datapath register.
    runctl_run_start   <= bool_to_sl((asi_ctrl_valid = '1') and (asi_ctrl_data(3) = '1') and (run_state_cmd /= RUNNING));
    -- RUNNING-edge clear is deliberately direct. Every datapath state element
    -- sees this enable on the command edge; unlike the old registered pulse it
    -- cannot produce a second late clear that erases the first following hit.
    datapath_clear_pulse <= measure_clear_pulse or runctl_run_start;
    -- gts_counter_clear / runctl_reset_hold REMOVED (gts-unify, BUG-012): the local
    -- gts_8n is gone, so there is no local counter to clear against MTS. The arrival
    -- reference is now the MTS-exported counter_gts_8n (port_arrival_gts), already
    -- in the MTS SYNC epoch, so no cross-IP clear-condition matching is needed.

    -- register measure_clear to break timing from AVMM interconnect address decode
    measure_clear_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                measure_clear_pulse <= '0';
            else
                measure_clear_pulse <= measure_clear_comb;
            end if;
        end if;
    end process measure_clear_reg;

    hist_writeresp_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                hist_writeresp_valid <= '0';
            else
                hist_writeresp_valid <= avs_hist_bin_write;
            end if;
        end if;
    end process hist_writeresp_reg;

    run_management_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                run_state_cmd <= IDLE;
            elsif asi_ctrl_valid = '1' then
                case asi_ctrl_data is
                    when RUNCTL_IDLE_CMD_CONST =>
                        run_state_cmd <= IDLE;
                    when RUNCTL_PREPARE_CMD_CONST =>
                        run_state_cmd <= RUN_PREPARE;
                    when RUNCTL_SYNC_CMD_CONST =>
                        run_state_cmd <= SYNC;
                    when RUNCTL_RUNNING_CMD_CONST =>
                        run_state_cmd <= RUNNING;
                    when RUNCTL_TERMINATING_CMD_CONST =>
                        run_state_cmd <= TERMINATING;
                    when RUNCTL_LINK_TEST_CMD_CONST =>
                        run_state_cmd <= LINK_TEST;
                    when RUNCTL_SYNC_TEST_CMD_CONST =>
                        run_state_cmd <= SYNC_TEST;
                    when RUNCTL_RESET_CMD_CONST =>
                        run_state_cmd <= RESET;
                    when RUNCTL_OUT_OF_DAQ_CMD_CONST =>
                        run_state_cmd <= OUT_OF_DAQ;
                    when others =>
                        run_state_cmd <= ERROR;
                end case;
            else
                if run_state_cmd = RESET then
                    run_state_cmd <= IDLE;
                end if;
            end if;
        end if;
    end process run_management_reg;

    pipeline_busy_comb : process (all)
        variable busy_v : std_logic;
    begin
        busy_v := '0';
        for idx in 0 to MAX_PORTS_CONST - 1 loop
            -- Include the combinational intake token.  On the first
            -- TERMINATING cycle the adapter's final beat is accepted into the
            -- sample register at the same edge on which the flush controller
            -- evaluates busy; omitting this token can snapshot one cycle too
            -- early even though every registered downstream stage was empty.
            if (ingress_accept(idx) = '1') or
               (sample_stage_valid(idx) = '1') or
               (filter_stage_valid(idx) = '1') or
               (ingress_stage_valid(idx) = '1') or
               (divider_in_valid(idx) = '1') or
               (divider_valid(idx) = '1') or
               (fifo_write(idx) = '1') or
               (fifo_write_d1(idx) = '1') or
               (fifo_read(idx) = '1') or
               (fifo_empty(idx) = '0') or
               (queue_hit_valid(idx) = '1') then
                busy_v := '1';
            end if;
        end loop;

        if (queue_drain_valid = '1') or
           (hist_update_busy = '1') or
           (bank_pending(0) = '1') or
           (bank_pending(1) = '1') or
           (bank_pending_inc_seen(0) = '1') or
           (bank_pending_inc_seen(1) = '1') or
           (bank_pending_inc_seen_d1(0) = '1') or
           (bank_pending_inc_seen_d1(1) = '1') or
           (queue_occupancy /= 0) then
            busy_v := '1';
        end if;

        hist_pipeline_busy <= busy_v;
    end process pipeline_busy_comb;

    termination_flush_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                term_flush_armed     <= '0';
                force_interval_pulse <= '0';
            else
                force_interval_pulse <= '0';

                if runctl_run_start = '1' then
                    term_flush_armed <= '1';
                elsif run_state_cmd = TERMINATING then
                    if (term_flush_armed = '1') and
                       (hist_pipeline_busy = '0') and
                       (csr_total_hits /= 0) then
                        force_interval_pulse <= '1';
                        term_flush_armed <= '0';
                    end if;
                elsif run_state_cmd = IDLE then
                    term_flush_armed <= '0';
                end if;
            end if;
        end if;
    end process termination_flush_reg;

    -- gts_counter_reg REMOVED (gts-unify, BUG-012): the local free-running gts_8n
    -- and the MTS counter_gts_8n are two independent SYNC-zeroed counters; their
    -- relative offset is random per SYNC (~2^20), so delay = gts_8n - hit_ts slid
    -- out of the bin window. Delay mode now subtracts the MTS-exported arrival GTS
    -- (port_arrival_gts) which is co-sampled with hit_ts in one epoch.

    ingress_sample_comb : process (all)
        variable sampled_v         : std_logic;
        variable stream_ready_v    : std_logic;
        variable stream_sampled_v  : std_logic;
        variable debug_mode_v      : integer;
        variable debug_dual_mts_v  : boolean;
        variable debug_active_v    : boolean;
        variable debug_valid_v     : std_logic;
        variable debug_data_v      : std_logic_vector(15 downto 0);
        variable debug_source_v    : natural;
    begin
        accept_pulse             <= (others => '0');
        port_ready               <= (others => '0');
        ingress_accept           <= (others => '0');
        ingress_debug_data_next  <= (others => (others => '0'));
        ingress_debug_source_next <= (others => (others => '0'));
        debug_mode_v     := to_integer(signed(cfg_mode));
        debug_dual_mts_v := ENABLE_DEBUG_INPUTS and (debug_mode_v = -7);
        debug_valid_v    := '0';
        debug_data_v     := (others => '0');
        debug_source_v   := 0;

        if ENABLE_DEBUG_INPUTS then
            case debug_mode_v is
                when -1 =>
                    debug_valid_v := asi_debug_1_valid;
                    debug_data_v  := asi_debug_1_data;
                when -2 =>
                    debug_valid_v := asi_debug_2_valid;
                    debug_data_v  := asi_debug_2_data;
                when -3 =>
                    debug_valid_v := asi_debug_3_valid;
                    debug_data_v  := asi_debug_3_data;
                when -4 =>
                    debug_valid_v := asi_debug_4_valid;
                    debug_data_v  := asi_debug_4_data;
                when -5 =>
                    debug_valid_v := asi_debug_5_valid;
                    debug_data_v  := asi_debug_5_data;
                when -6 =>
                    debug_valid_v := asi_debug_6_valid;
                    debug_data_v  := asi_debug_6_data;
                when others =>
                    null;
            end case;
        end if;

        for idx in 0 to MAX_PORTS_CONST - 1 loop
            debug_active_v := false;
            if debug_dual_mts_v and idx < 2 then
                debug_active_v := true;
            elsif ENABLE_DEBUG_INPUTS and (debug_mode_v < 0) and (idx = 0) then
                debug_active_v := true;
            end if;

            if (idx < N_PORTS) or (idx = 0 and cfg_in_port /= IN_PORT_FILL_CONST) or debug_active_v then
                stream_ready_v   := '0';
                stream_sampled_v := '0';
                if (idx < N_PORTS) and (cfg_apply_pending = '0') then
                    if (idx = 0) and (cfg_source_select_port(idx) = HIST_SOURCE_TYPE0_CONST) then
                        if SNOOP_EN then
                            stream_ready_v   := aso_hist_fill_out_ready;
                            stream_sampled_v := port_valid(idx) and aso_hist_fill_out_ready;
                        else
                            stream_ready_v   := '1';
                            stream_sampled_v := port_valid(idx);
                        end if;
                    elsif (idx = 0) and
                          (cfg_source_select_port(idx) = HIST_SOURCE_TYPE1_UP_CONST or
                           cfg_source_select_port(idx) = HIST_SOURCE_TYPE1_DOWN_CONST) then
                        -- TYPE1 up/down ingress: 39-bit avalon_streaming tap from
                        -- mts_preprocessor.hit_type1_out plus the 48-bit MTS
                        -- hit_type1_ts conduit on port_ts(0). The tap is readyless
                        -- (memory: histogram taps advertise readyless). cfg_in_port
                        -- is wired read-only to IN_PORT_FILL_CONST on silicon, so
                        -- the EXT0/EXT1 elsif below never fires for TYPE1 — without
                        -- this branch nothing samples and silicon bins read zero
                        -- for both rate and delay modes.
                        stream_ready_v   := '1';
                        stream_sampled_v := port_valid(idx);
                    elsif (cfg_source_select_port(idx) = HIST_SOURCE_TYPE1_ALL_CONST) and
                          ((idx > 0) or (cfg_in_port = IN_PORT_FILL_CONST)) then
                        -- Eight explicit logical Type1 lanes are passive taps.
                        -- They never consume ready; local binned FIFOs absorb
                        -- downstream queue pressure.
                        stream_ready_v   := '1';
                        stream_sampled_v := port_valid(idx);
                    elsif (idx = 0) and (cfg_in_port = IN_PORT_EXT0_CONST or cfg_in_port = IN_PORT_EXT1_CONST) then
                        -- Extended debug-plane inputs are readyless; histogram backpressure is absorbed locally.
                        stream_ready_v   := '1';
                        stream_sampled_v := port_valid(idx);
                    elsif (idx > 0) and (cfg_source_select_port(idx) = HIST_SOURCE_TYPE0_CONST) then
                        -- Per-ASIC TYPE0 lanes 1..N_PORTS-1 each carry one
                        -- asic-tagged stream (arb selected_out_k -> tapK -> port idx).
                        -- Sample readyless like lane 0's non-snoop path so all
                        -- N_PORTS ASICs bin, not just ASIC0. Without this branch the
                        -- The eight parallel mapper/FIFO lanes must see every
                        -- configured Type0 source, not only logical lane 0.
                        stream_ready_v   := '1';
                        stream_sampled_v := port_valid(idx);
                    end if;
                end if;
                port_ready(idx) <= stream_ready_v;

                sampled_v := stream_sampled_v;
                if ENABLE_DEBUG_INPUTS and (debug_mode_v < 0) then
                    debug_source_v := 0;
                    if debug_dual_mts_v then
                        case idx is
                            when 0 =>
                                debug_valid_v := asi_debug_1_valid;
                                debug_data_v  := asi_debug_1_data;
                                debug_source_v := 0;
                            when 1 =>
                                debug_valid_v := asi_debug_2_valid;
                                debug_data_v  := asi_debug_2_data;
                                debug_source_v := 1;
                            when others =>
                                debug_valid_v := '0';
                                debug_data_v  := (others => '0');
                                debug_source_v := 0;
                        end case;
                        sampled_v := debug_valid_v and not cfg_apply_pending;
                    elsif idx = 0 then
                        debug_source_v := natural((-debug_mode_v) - 1);
                        sampled_v := debug_valid_v and not cfg_apply_pending;
                    else
                        sampled_v := '0';
                    end if;
                end if;

                accept_pulse(idx)   <= sampled_v;
                ingress_accept(idx) <= sampled_v;
                ingress_debug_data_next(idx) <= debug_data_v;
                ingress_debug_source_next(idx) <= to_unsigned(debug_source_v, 3);
            end if;

        end loop;
    end process ingress_sample_comb;

    selected_sample_stage_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                sample_stage_valid         <= (others => '0');
                sample_stage_data          <= (others => (others => '0'));
                sample_stage_ts            <= (others => (others => '0'));
                sample_stage_arrival_gts   <= (others => (others => '0'));
                sample_stage_latency       <= (others => (others => '0'));
                sample_stage_debug_data    <= (others => (others => '0'));
                sample_stage_debug_source  <= (others => (others => '0'));
                sample_stage_source_select <= (others => to_unsigned(DEF_SOURCE_SELECT, 2));
                sample_stage_mode          <= (others => std_logic_vector(to_signed(DEF_MODE, 4)));
                sample_stage_key_unsigned  <= (others => bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED"));
                sample_stage_update_key_low <= (others => to_unsigned(UPDATE_KEY_BIT_LO, 8));
                sample_stage_update_key_high <= (others => to_unsigned(UPDATE_KEY_BIT_HI, 8));
                sample_stage_filter_enable <= (others => '0');
                sample_stage_filter_reject <= (others => '0');
                sample_stage_filter_key_low <= (others => to_unsigned(FILTER_KEY_BIT_LO, 8));
                sample_stage_filter_key_high <= (others => to_unsigned(FILTER_KEY_BIT_HI, 8));
                sample_stage_filter_key <= (others => (others => '0'));
                sample_stage_bank          <= (others => '0');
            elsif datapath_clear_pulse = '1' then
                -- The payload/configuration registers are stale whenever the
                -- validity token is clear.  Clearing only that token keeps the
                -- exact run-boundary flush while removing the run-control
                -- pulse from hundreds of wide register enables.
                sample_stage_valid <= (others => '0');
            else
                sample_stage_valid <= (others => '0');
                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    if (idx < N_PORTS) and (ingress_accept(idx) = '1') then
                        sample_stage_valid(idx)         <= '1';
                        sample_stage_data(idx)          <= port_data(idx);
                        sample_stage_ts(idx)            <= port_ts(idx);
                        sample_stage_arrival_gts(idx)   <= port_arrival_gts(idx);
                        sample_stage_latency(idx)       <= port_latency(idx);
                        sample_stage_debug_data(idx)    <= ingress_debug_data_next(idx);
                        sample_stage_debug_source(idx)  <= ingress_debug_source_next(idx);
                        sample_stage_source_select(idx) <= cfg_source_select_port(idx);
                        sample_stage_mode(idx)          <= cfg_mode;
                        sample_stage_key_unsigned(idx)  <= cfg_key_unsigned;
                        sample_stage_update_key_low(idx) <= cfg_update_key_low;
                        sample_stage_update_key_high(idx) <= cfg_update_key_high;
                        sample_stage_filter_enable(idx) <= cfg_filter_enable_port(idx);
                        sample_stage_filter_reject(idx) <= cfg_filter_reject_port(idx);
                        sample_stage_filter_key_low(idx) <= cfg_filter_key_low_port(idx);
                        sample_stage_filter_key_high(idx) <= cfg_filter_key_high_port(idx);
                        sample_stage_filter_key(idx) <= cfg_filter_key_port(idx);
                        sample_stage_bank(idx)          <= active_bank;
                    end if;
                end loop;
            end if;
        end if;
    end process selected_sample_stage_reg;

    ingress_key_comb : process (all)
        variable debug_mode_v      : integer;
        variable debug_filter_v    : std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        variable update_key_low_v  : unsigned(7 downto 0);
        variable update_key_high_v : unsigned(7 downto 0);
        variable filter_key_low_v  : unsigned(7 downto 0);
        variable filter_key_high_v : unsigned(7 downto 0);
    begin
        ingress_key_next  <= (others => (others => '0'));
        ingress_bank_next <= sample_stage_bank;
        ingress_filter_field_next <= (others => (others => '0'));

        for idx in 0 to MAX_PORTS_CONST - 1 loop
            if LOCK_KEY_RANGES then
                update_key_low_v  := UPDATE_KEY_LOW_CONST;
                update_key_high_v := UPDATE_KEY_HIGH_CONST;
                filter_key_low_v  := FILTER_KEY_LOW_CONST;
                filter_key_high_v := FILTER_KEY_HIGH_CONST;
            else
                update_key_low_v  := sample_stage_update_key_low(idx);
                update_key_high_v := sample_stage_update_key_high(idx);
                filter_key_low_v  := sample_stage_filter_key_low(idx);
                filter_key_high_v := sample_stage_filter_key_high(idx);
            end if;

            if sample_stage_valid(idx) = '1' then
                debug_mode_v := to_integer(signed(sample_stage_mode(idx)));
                if ENABLE_DEBUG_INPUTS and (debug_mode_v < 0) then
                    ingress_key_next(idx) <= std_logic_vector(resize(signed(build_debug_key(
                        debug_mode => debug_mode_v,
                        data_word  => sample_stage_debug_data(idx)
                    )), DIVIDER_TICK_WIDTH_CONST));
                    debug_filter_v := build_debug_filter_word(
                        debug_source => to_integer(sample_stage_debug_source(idx)),
                        debug_mode   => debug_mode_v,
                        data_word    => sample_stage_debug_data(idx)
                    );

                    ingress_filter_field_next(idx) <= resize(
                        extract_unsigned(
                            debug_filter_v,
                            to_integer(filter_key_high_v),
                            to_integer(filter_key_low_v)
                        ),
                        SAR_KEY_WIDTH
                    );
                elsif debug_mode_v = 1 then
                    if sample_stage_source_select(idx) = HIST_SOURCE_TYPE1_ALL_CONST then
                        -- Explicit MTS latency is signed two's complement.
                        -- Preserve all 48 bits through the divider's full signed
                        -- range check; never modulo-trim low bits.
                        ingress_key_next(idx) <= sample_stage_latency(idx);
                    else
                        -- Legacy up/down compatibility: reproduce the MTS epoch
                        -- subtraction at the full 48-bit width.
                        ingress_key_next(idx) <= std_logic_vector(
                            unsigned(sample_stage_arrival_gts(idx)) - unsigned(sample_stage_ts(idx))
                        );
                    end if;

                    if LOCK_KEY_RANGES then
                        ingress_filter_field_next(idx) <= resize(
                            extract_fixed_unsigned(
                                sample_stage_data(idx),
                                fixed_filter_hi(sample_stage_source_select(idx)),
                                fixed_filter_lo(sample_stage_source_select(idx))
                            ),
                            SAR_KEY_WIDTH
                        );
                    else
                        ingress_filter_field_next(idx) <= resize(
                            extract_unsigned(
                                sample_stage_data(idx),
                                to_integer(filter_key_high_v),
                                to_integer(filter_key_low_v)
                            ),
                            SAR_KEY_WIDTH
                        );
                    end if;
                else
                    -- Key extraction starts from the selected-sample registers,
                    -- independently of the filter result.  The source-select and
                    -- input-port mux are therefore no longer in this register path.
                    if LOCK_KEY_RANGES then
                        ingress_key_next(idx) <= std_logic_vector(resize(signed(build_fixed_key(
                            data_word     => sample_stage_data(idx),
                            source_select => sample_stage_source_select(idx),
                            key_unsigned  => sample_stage_key_unsigned(idx)
                        )), DIVIDER_TICK_WIDTH_CONST));

                        ingress_filter_field_next(idx) <= resize(
                            extract_fixed_unsigned(
                                sample_stage_data(idx),
                                fixed_filter_hi(sample_stage_source_select(idx)),
                                fixed_filter_lo(sample_stage_source_select(idx))
                            ),
                            SAR_KEY_WIDTH
                        );
                    else
                        ingress_key_next(idx) <= std_logic_vector(resize(signed(build_key(
                            data_word    => sample_stage_data(idx),
                            key_hi       => update_key_high_v,
                            key_lo       => update_key_low_v,
                            key_unsigned => sample_stage_key_unsigned(idx)
                        )), DIVIDER_TICK_WIDTH_CONST));

                        ingress_filter_field_next(idx) <= resize(
                            extract_unsigned(
                                sample_stage_data(idx),
                                to_integer(filter_key_high_v),
                                to_integer(filter_key_low_v)
                            ),
                            SAR_KEY_WIDTH
                        );
                    end if;
                end if;
            end if;
        end loop;
    end process ingress_key_comb;

    filter_extract_stage_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                filter_stage_valid         <= (others => '0');
                filter_stage_field         <= (others => (others => '0'));
                filter_stage_filter_key    <= (others => (others => '0'));
                filter_stage_filter_enable <= (others => '0');
                filter_stage_filter_reject <= (others => '0');
                filter_stage_key           <= (others => (others => '0'));
                filter_stage_bank          <= (others => '0');
            elsif datapath_clear_pulse = '1' then
                -- Payload and configuration remain stale while valid is low.
                filter_stage_valid <= (others => '0');
            else
                filter_stage_valid <= (others => '0');
                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    if (idx < N_PORTS) and (sample_stage_valid(idx) = '1') then
                        filter_stage_valid(idx)         <= '1';
                        filter_stage_field(idx)         <= ingress_filter_field_next(idx);
                        filter_stage_filter_key(idx)    <= sample_stage_filter_key(idx);
                        filter_stage_filter_enable(idx) <= sample_stage_filter_enable(idx);
                        filter_stage_filter_reject(idx) <= sample_stage_filter_reject(idx);
                        filter_stage_key(idx)           <= ingress_key_next(idx);
                        filter_stage_bank(idx)          <= ingress_bank_next(idx);
                    end if;
                end loop;
            end if;
        end if;
    end process filter_extract_stage_reg;

    filter_stage_match_comb : process (all)
        variable field_match_v : boolean;
    begin
        ingress_write_req <= (others => '0');
        for idx in 0 to MAX_PORTS_CONST - 1 loop
            if (idx < N_PORTS) and (filter_stage_valid(idx) = '1') then
                if filter_stage_filter_enable(idx) = '0' then
                    ingress_write_req(idx) <= '1';
                else
                    field_match_v := filter_stage_field(idx) = filter_stage_filter_key(idx);
                    if (
                        (field_match_v and filter_stage_filter_reject(idx) = '0')
                        or ((not field_match_v) and filter_stage_filter_reject(idx) = '1')
                    ) then
                        ingress_write_req(idx) <= '1';
                    end if;
                end if;
            end if;
        end loop;
    end process filter_stage_match_comb;

    ingress_stage_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                ingress_stage_valid     <= (others => '0');
                ingress_stage_write_req <= (others => '0');
                ingress_stage_key       <= (others => (others => '0'));
                ingress_stage_bank      <= (others => '0');
            elsif datapath_clear_pulse = '1' then
                -- Key and bank payloads are consumed only with valid/write_req.
                -- Preserve their stale values across a datapath flush and
                -- clear only the control tokens that make them observable.
                ingress_stage_valid     <= (others => '0');
                ingress_stage_write_req <= (others => '0');
            else
                ingress_stage_valid     <= (others => '0');
                ingress_stage_write_req <= (others => '0');
                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    if (idx < N_PORTS) and (filter_stage_valid(idx) = '1') then
                        ingress_stage_valid(idx)     <= '1';
                        ingress_stage_write_req(idx) <= ingress_write_req(idx);
                        ingress_stage_key(idx)       <= filter_stage_key(idx);
                        ingress_stage_bank(idx)      <= filter_stage_bank(idx);
                    end if;
                end loop;
            end if;
        end if;
    end process ingress_stage_reg;

    -- Eight independent full-width mappers. Delay source 3 reaches these with
    -- the complete signed latency[47:0], so large out-of-range values cannot
    -- alias into the configured window through low-bit trimming.
    divider_gen : for idx in 0 to MAX_PORTS_CONST - 1 generate
    begin
        divider_in_valid(idx) <= ingress_stage_valid(idx) and ingress_stage_write_req(idx);
        divider_in_key(idx)   <= ingress_stage_key(idx);
        divider_in_count(idx) <= to_unsigned(1, KICK_WIDTH_CONST);
        divider_in_bank(idx)  <= ingress_stage_bank(idx);

        divider_inst : entity work.bin_divider
            generic map (
                TICK_WIDTH            => DIVIDER_TICK_WIDTH_CONST,
                BIN_INDEX_WIDTH       => BIN_INDEX_WIDTH_CONST,
                COUNT_WIDTH           => KICK_WIDTH_CONST,
                POWER2_BIN_WIDTH_ONLY => POWER2_BIN_WIDTH_ONLY
            )
            port map (
                i_clk         => i_clk,
                i_rst         => i_rst,
                i_clear       => datapath_clear_pulse,
                i_valid       => divider_in_valid(idx),
                i_key         => signed(divider_in_key(idx)),
                i_count       => divider_in_count(idx),
                i_user        => divider_in_bank(idx),
                i_left_bound  => resize(cfg_left_bound, DIVIDER_TICK_WIDTH_CONST),
                i_right_bound => resize(cfg_right_bound, DIVIDER_TICK_WIDTH_CONST),
                i_bin_width   => resize(cfg_bin_width, DIVIDER_TICK_WIDTH_CONST),
                o_valid       => divider_valid(idx),
                o_underflow   => divider_underflow(idx),
                o_overflow    => divider_overflow(idx),
                o_bin_index   => divider_bin_index(idx),
                o_count       => divider_count(idx),
                o_user        => divider_bank(idx)
            );
    end generate divider_gen;

    -- Mapper outputs are buffered after binning. Queue pressure only holds the
    -- corresponding FIFO head; it never appears as ready on a Type1 tap.
    mapper_to_fifo_comb : process (all)
    begin
        fifo_write   <= (others => '0');
        fifo_wr_data <= (others => (others => '0'));
        drop_pulse   <= (others => '0');

        for idx in 0 to MAX_PORTS_CONST - 1 loop
            if (divider_valid(idx) = '1') and
               (divider_underflow(idx) = '0') and
               (divider_overflow(idx) = '0') then
                if (fifo_full(idx) = '0') or (fifo_read(idx) = '1') then
                    fifo_write(idx) <= '1';
                    fifo_wr_data(idx)(FIFO_COUNT_HIGH_CONST downto FIFO_COUNT_LOW_CONST) <= std_logic_vector(divider_count(idx));
                    fifo_wr_data(idx)(FIFO_BIN_HIGH_CONST downto FIFO_BIN_LOW_CONST) <= std_logic_vector(divider_bin_index(idx));
                    fifo_wr_data(idx)(FIFO_BANK_BIT_CONST) <= divider_bank(idx);
                else
                    -- This is the only controlled loss after a readyless
                    -- source sample. The exact lane count is reflected in
                    -- DROPPED_HITS and the pending-bank ledger.
                    drop_pulse(idx) <= '1';
                end if;
            end if;
        end loop;
    end process mapper_to_fifo_comb;

    fifo_gen : for idx in 0 to MAX_PORTS_CONST - 1 generate
    begin
        fifo_inst : entity work.hit_fifo
            generic map (
                DATA_WIDTH      => FIFO_WORD_WIDTH_CONST,
                FIFO_ADDR_WIDTH => FIFO_ADDR_WIDTH_CONST
            )
            port map (
                i_clk        => i_clk,
                i_rst        => i_rst,
                i_clear      => datapath_clear_pulse,
                i_write      => fifo_write(idx),
                i_write_data => fifo_wr_data(idx),
                i_read       => fifo_read(idx),
                o_read_data  => fifo_rd_data(idx),
                o_empty      => fifo_empty(idx),
                o_full       => fifo_full(idx),
                o_level      => fifo_level(idx),
                o_level_max  => fifo_level_max(idx)
            );

        queue_hit_valid(idx) <= not fifo_empty(idx);
        queue_hit_bank(idx)  <= fifo_rd_data(idx)(FIFO_BANK_BIT_CONST);
        queue_hit_bin(idx)   <= unsigned(fifo_rd_data(idx)(FIFO_BIN_HIGH_CONST downto FIFO_BIN_LOW_CONST));
        queue_hit_count(idx) <= unsigned(fifo_rd_data(idx)(FIFO_COUNT_HIGH_CONST downto FIFO_COUNT_LOW_CONST));
        fifo_read(idx)       <= queue_hit_valid(idx) and queue_hit_accept(idx);
    end generate fifo_gen;

    queue_inst : entity work.coalescing_queue
        generic map (
            N_BINS              => N_BINS,
            QUEUE_DEPTH         => COAL_QUEUE_DEPTH,
            KICK_WIDTH          => KICK_WIDTH_CONST,
            N_INPUTS            => MAX_PORTS_CONST,
            OVERFLOW_WIDTH      => 16,
            CAM_PIPELINE_MODE   => COAL_CAM_PIPELINE_MODE,
            CAM_PIPELINE_STAGES => COAL_CAM_PIPELINE_STAGES
        )
        port map (
            i_clk            => i_clk,
            i_rst            => i_rst,
            i_clear          => datapath_clear_pulse,
            i_hit_valid      => queue_hit_valid,
            i_hit_bank       => queue_hit_bank,
            i_hit_bin        => queue_hit_bin,
            i_hit_count      => queue_hit_count,
            o_hit_accept     => queue_hit_accept,
            i_drain_ready    => queue_drain_ready,
            o_drain_valid    => queue_drain_valid,
            o_drain_bank     => queue_drain_bank,
            o_drain_bin      => queue_drain_bin,
            o_drain_count    => queue_drain_count,
            o_occupancy      => queue_occupancy,
            o_occupancy_max  => queue_occupancy_max,
            o_overflow_count => queue_overflow_count
        );

    pending_write_seen_comb : process (all)
        variable seen_v : std_logic_vector(1 downto 0);
        variable bank_idx_v : natural;
    begin
        seen_v := (others => '0');
        for idx in 0 to MAX_PORTS_CONST - 1 loop
            -- The selected-sample retime precedes filter evaluation.  Treat its
            -- captured bank as conservatively pending so host readout cannot
            -- cross the extra pipeline cycle before a surviving hit reaches the
            -- existing divider/FIFO pending ledger.  A filtered sample merely
            -- extends waitrequest for one bounded cycle.
            if sample_stage_valid(idx) = '1' then
                bank_idx_v := 0;
                if sample_stage_bank(idx) = '1' then
                    bank_idx_v := 1;
                end if;
                seen_v(bank_idx_v) := '1';
            end if;

            if filter_stage_valid(idx) = '1' then
                bank_idx_v := 0;
                if filter_stage_bank(idx) = '1' then
                    bank_idx_v := 1;
                end if;
                seen_v(bank_idx_v) := '1';
            end if;

            if divider_in_valid(idx) = '1' then
                bank_idx_v := 0;
                if divider_in_bank(idx) = '1' then
                    bank_idx_v := 1;
                end if;
                seen_v(bank_idx_v) := '1';
            end if;
        end loop;
        bank_pending_write_seen <= seen_v;
    end process pending_write_seen_comb;

    pending_write_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or datapath_clear_pulse = '1' then
                fifo_write_d1      <= (others => '0');
                fifo_write_bank_d1 <= (others => '0');
            else
                fifo_write_d1 <= divider_in_valid;
                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    fifo_write_bank_d1(idx) <= divider_in_bank(idx);
                end loop;
            end if;
        end if;
    end process pending_write_reg;

    pending_delta_comb : process (all)
        type pending_term_array_t is array (0 to MAX_PORTS_CONST - 1) of
            unsigned(PENDING_DELTA_WIDTH_CONST - 1 downto 0);
        type pending_pair_array_t is array (0 to (MAX_PORTS_CONST / 2) - 1) of
            unsigned(PENDING_DELTA_WIDTH_CONST - 1 downto 0);
        variable inc_count_v : hs_unsigned_array_t(0 to 1)(PENDING_DELTA_WIDTH_CONST - 1 downto 0);
        variable dec_count_v : hs_unsigned_array_t(0 to 1)(PENDING_DELTA_WIDTH_CONST - 1 downto 0);
        variable inc_seen_v  : std_logic_vector(1 downto 0);
        variable inc_terms_v : pending_term_array_t;
        variable dec_terms_v : pending_term_array_t;
        variable inc_pairs_v : pending_pair_array_t;
        variable dec_pairs_v : pending_pair_array_t;
        variable inc_quad0_v : unsigned(PENDING_DELTA_WIDTH_CONST - 1 downto 0);
        variable inc_quad1_v : unsigned(PENDING_DELTA_WIDTH_CONST - 1 downto 0);
        variable dec_quad0_v : unsigned(PENDING_DELTA_WIDTH_CONST - 1 downto 0);
        variable dec_quad1_v : unsigned(PENDING_DELTA_WIDTH_CONST - 1 downto 0);
        variable drain_term_v : unsigned(PENDING_DELTA_WIDTH_CONST - 1 downto 0);
        variable bank_value_v : std_logic;
    begin
        inc_count_v := (others => (others => '0'));
        dec_count_v := (others => (others => '0'));
        inc_seen_v  := (others => '0');

        -- Form the two bank deltas with a balanced three-level reduction.
        -- The previous in-loop saturating accumulator synthesized as an
        -- eight-deep adder chain on the queue-accept path.  Keeping the same
        -- saturating result while reducing 8 -> 4 -> 2 -> 1 removes that
        -- serial cone from the 125 MHz datapath.
        for bank_idx in 0 to 1 loop
            if bank_idx = 0 then
                bank_value_v := '0';
            else
                bank_value_v := '1';
            end if;
            inc_terms_v := (others => (others => '0'));
            dec_terms_v := (others => (others => '0'));
            drain_term_v := (others => '0');

            for idx in 0 to MAX_PORTS_CONST - 1 loop
                if fifo_write_d1(idx) = '1' and
                   fifo_write_bank_d1(idx) = bank_value_v then
                    inc_terms_v(idx) := to_unsigned(1, PENDING_DELTA_WIDTH_CONST);
                    inc_seen_v(bank_idx) := '1';
                end if;

                if divider_valid(idx) = '1' and
                   ((divider_underflow(idx) = '1') or
                    (divider_overflow(idx) = '1') or
                    (drop_pulse(idx) = '1')) and
                   divider_bank(idx) = bank_value_v then
                    dec_terms_v(idx) := resize(divider_count(idx), PENDING_DELTA_WIDTH_CONST);
                end if;
            end loop;

            for pair_idx in 0 to (MAX_PORTS_CONST / 2) - 1 loop
                inc_pairs_v(pair_idx) := sat_add(
                    inc_terms_v(2 * pair_idx),
                    inc_terms_v((2 * pair_idx) + 1)
                );
                dec_pairs_v(pair_idx) := sat_add(
                    dec_terms_v(2 * pair_idx),
                    dec_terms_v((2 * pair_idx) + 1)
                );
            end loop;

            inc_quad0_v := sat_add(inc_pairs_v(0), inc_pairs_v(1));
            inc_quad1_v := sat_add(inc_pairs_v(2), inc_pairs_v(3));
            dec_quad0_v := sat_add(dec_pairs_v(0), dec_pairs_v(1));
            dec_quad1_v := sat_add(dec_pairs_v(2), dec_pairs_v(3));

            if queue_drain_valid = '1' and queue_drain_ready = '1' and
               queue_drain_bank = bank_value_v then
                drain_term_v := resize(queue_drain_count, PENDING_DELTA_WIDTH_CONST);
            end if;

            inc_count_v(bank_idx) := sat_add(inc_quad0_v, inc_quad1_v);
            dec_count_v(bank_idx) := sat_add(
                sat_add(dec_quad0_v, dec_quad1_v),
                drain_term_v
            );
        end loop;

        bank_pending_inc_count <= inc_count_v;
        bank_pending_dec_count <= dec_count_v;
        bank_pending_inc_seen  <= inc_seen_v;
    end process pending_delta_comb;

    bank_pending(0) <= bool_to_sl(bank_pending_count(0) /= 0) or bank_pending_write_seen(0) or bank_pending_inc_seen(0) or bank_pending_inc_seen_d1(0);
    bank_pending(1) <= bool_to_sl(bank_pending_count(1) /= 0) or bank_pending_write_seen(1) or bank_pending_inc_seen(1) or bank_pending_inc_seen_d1(1);

    pending_delta_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or datapath_clear_pulse = '1' then
                bank_pending_inc_count_d1 <= (others => (others => '0'));
                bank_pending_dec_count_d1 <= (others => (others => '0'));
                bank_pending_inc_seen_d1  <= (others => '0');
            else
                bank_pending_inc_count_d1 <= bank_pending_inc_count;
                bank_pending_dec_count_d1 <= bank_pending_dec_count;
                bank_pending_inc_seen_d1  <= bank_pending_inc_seen;
            end if;
        end if;
    end process pending_delta_reg;

    bank_pending_reg : process (i_clk)
        variable next_pending_v : hs_unsigned_array_t(0 to 1)(STATS_COUNT_WIDTH_CONST - 1 downto 0);
        variable inc_v          : bank_pending_count_t;
        variable dec_v          : bank_pending_count_t;
        variable sum_v          : bank_pending_count_t;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or datapath_clear_pulse = '1' then
                bank_pending_count <= (others => (others => '0'));
            else
                next_pending_v := bank_pending_count;

                for bank_idx in 0 to 1 loop
                    inc_v := resize(bank_pending_inc_count_d1(bank_idx), STATS_COUNT_WIDTH_CONST);
                    dec_v := resize(bank_pending_dec_count_d1(bank_idx), STATS_COUNT_WIDTH_CONST);
                    sum_v := sat_add(bank_pending_count(bank_idx), inc_v);
                    if sum_v > dec_v then
                        next_pending_v(bank_idx) := sum_v - dec_v;
                    else
                        next_pending_v(bank_idx) := (others => '0');
                    end if;
                end loop;

                bank_pending_count <= next_pending_v;
            end if;
        end if;
    end process bank_pending_reg;

    pingpong_inst : entity work.pingpong_sram
        generic map (
            N_BINS       => N_BINS,
            COUNT_WIDTH  => COUNT_WIDTH_CONST,
            UPDATE_WIDTH => KICK_WIDTH_CONST
        )
        port map (
            i_clk               => i_clk,
            i_rst               => i_rst,
            i_clear             => datapath_clear_pulse,
            i_enable_pingpong   => bool_to_sl(ENABLE_PINGPONG),
            i_interval_clocks   => cfg_interval_cfg,
            i_force_interval    => force_interval_pulse,
            i_upd_valid         => queue_drain_valid,
            i_upd_bank          => queue_drain_bank,
            i_upd_bin           => queue_drain_bin,
            i_upd_count         => queue_drain_count,
            i_bank_pending      => bank_pending,
            o_upd_ready         => queue_drain_ready,
            i_hist_read         => avs_hist_bin_read,
            i_hist_address      => unsigned(avs_hist_bin_address),
            i_hist_burstcount   => unsigned(avs_hist_bin_burstcount),
            o_hist_readdata     => hist_readdata,
            o_hist_readdatavalid=> hist_readdatavalid,
            o_hist_waitrequest  => hist_waitrequest,
            o_update_busy       => hist_update_busy,
            o_active_bank       => active_bank,
            o_flushing          => flushing,
            o_flush_addr        => flush_addr,
            o_interval_pulse    => interval_pulse
        );

    stats_pipe : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                accept_stat_pulse_d1    <= (others => '0');
                drop_stat_pulse_d1      <= (others => '0');
                divider_stat_valid_d1   <= (others => '0');
                divider_stat_underflow_d1 <= (others => '0');
                divider_stat_overflow_d1  <= (others => '0');
            else
                accept_stat_pulse_d1    <= accept_pulse;
                drop_stat_pulse_d1      <= drop_pulse;
                divider_stat_valid_d1   <= divider_valid;
                divider_stat_underflow_d1 <= divider_underflow;
                divider_stat_overflow_d1  <= divider_overflow;
            end if;
        end if;
    end process stats_pipe;

    stats_reg : process (i_clk)
        type stats_term_array_t is array (0 to 7) of unsigned(3 downto 0);
        type stats_pair_array_t is array (0 to 3) of unsigned(3 downto 0);
        type stats_quad_array_t is array (0 to 1) of unsigned(3 downto 0);
        variable total_hits_v    : stats_count_t;
        variable dropped_hits_v  : stats_count_t;
        variable underflow_cnt_v : stats_count_t;
        variable overflow_cnt_v  : stats_count_t;
        variable accept_count_v  : unsigned(3 downto 0);
        variable drop_count_v    : unsigned(3 downto 0);
        variable underflow_count_v : unsigned(3 downto 0);
        variable overflow_count_v  : unsigned(3 downto 0);
        variable accept_term_v     : stats_term_array_t;
        variable drop_term_v       : stats_term_array_t;
        variable underflow_term_v  : stats_term_array_t;
        variable overflow_term_v   : stats_term_array_t;
        variable accept_pair_v     : stats_pair_array_t;
        variable drop_pair_v       : stats_pair_array_t;
        variable underflow_pair_v  : stats_pair_array_t;
        variable overflow_pair_v   : stats_pair_array_t;
        variable accept_quad_v     : stats_quad_array_t;
        variable drop_quad_v       : stats_quad_array_t;
        variable underflow_quad_v  : stats_quad_array_t;
        variable overflow_quad_v   : stats_quad_array_t;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                csr_underflow_count <= (others => '0');
                csr_overflow_count  <= (others => '0');
                csr_total_hits      <= (others => '0');
                csr_dropped_hits    <= (others => '0');
                csr_last_interval_total_hits   <= (others => '0');
                csr_last_interval_dropped_hits <= (others => '0');
            else
                total_hits_v    := csr_total_hits;
                dropped_hits_v  := csr_dropped_hits;
                underflow_cnt_v := csr_underflow_count;
                overflow_cnt_v  := csr_overflow_count;
                accept_count_v  := (others => '0');
                drop_count_v    := (others => '0');
                underflow_count_v := (others => '0');
                overflow_count_v  := (others => '0');
                accept_term_v     := (others => (others => '0'));
                drop_term_v       := (others => (others => '0'));
                underflow_term_v  := (others => (others => '0'));
                overflow_term_v   := (others => (others => '0'));

                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    if accept_stat_pulse_d1(idx) = '1' then
                        accept_term_v(idx)(0) := '1';
                    end if;
                    if drop_stat_pulse_d1(idx) = '1' then
                        drop_term_v(idx)(0) := '1';
                    end if;
                    if divider_stat_valid_d1(idx) = '1' then
                        if divider_stat_underflow_d1(idx) = '1' then
                            underflow_term_v(idx)(0) := '1';
                        elsif divider_stat_overflow_d1(idx) = '1' then
                            overflow_term_v(idx)(0) := '1';
                        end if;
                    end if;
                end loop;

                -- Keep the eight event reductions as an explicit 8 -> 4 -> 2
                -- tree.  A source bit therefore reaches the saturating CSR
                -- adder through three bounded reductions, independent of its
                -- lane index, rather than through a tool-dependent loop chain.
                for pair_idx in 0 to 3 loop
                    accept_pair_v(pair_idx) :=
                        accept_term_v(2 * pair_idx) + accept_term_v(2 * pair_idx + 1);
                    drop_pair_v(pair_idx) :=
                        drop_term_v(2 * pair_idx) + drop_term_v(2 * pair_idx + 1);
                    underflow_pair_v(pair_idx) :=
                        underflow_term_v(2 * pair_idx) + underflow_term_v(2 * pair_idx + 1);
                    overflow_pair_v(pair_idx) :=
                        overflow_term_v(2 * pair_idx) + overflow_term_v(2 * pair_idx + 1);
                end loop;
                for quad_idx in 0 to 1 loop
                    accept_quad_v(quad_idx) :=
                        accept_pair_v(2 * quad_idx) + accept_pair_v(2 * quad_idx + 1);
                    drop_quad_v(quad_idx) :=
                        drop_pair_v(2 * quad_idx) + drop_pair_v(2 * quad_idx + 1);
                    underflow_quad_v(quad_idx) :=
                        underflow_pair_v(2 * quad_idx) + underflow_pair_v(2 * quad_idx + 1);
                    overflow_quad_v(quad_idx) :=
                        overflow_pair_v(2 * quad_idx) + overflow_pair_v(2 * quad_idx + 1);
                end loop;
                accept_count_v := accept_quad_v(0) + accept_quad_v(1);
                drop_count_v := drop_quad_v(0) + drop_quad_v(1);
                underflow_count_v := underflow_quad_v(0) + underflow_quad_v(1);
                overflow_count_v := overflow_quad_v(0) + overflow_quad_v(1);

                if accept_count_v /= 0 then
                    total_hits_v := sat_add(total_hits_v, resize(accept_count_v, total_hits_v'length));
                end if;
                if drop_count_v /= 0 then
                    dropped_hits_v := sat_add(dropped_hits_v, resize(drop_count_v, dropped_hits_v'length));
                end if;

                -- Reduce the eight mapper flags at their native four-bit
                -- width, then perform one saturating stats update. Chaining
                -- eight 32-bit sat_inc operations here created a 26-level
                -- counter-to-counter path after enabling all eight Type1
                -- lanes.
                if underflow_count_v /= 0 then
                    underflow_cnt_v := sat_add(
                        underflow_cnt_v,
                        resize(underflow_count_v, underflow_cnt_v'length)
                    );
                end if;
                if overflow_count_v /= 0 then
                    overflow_cnt_v := sat_add(
                        overflow_cnt_v,
                        resize(overflow_count_v, overflow_cnt_v'length)
                    );
                end if;

                -- interval_pulse is consumed directly here, one cycle after
                -- the SRAM bank switch that generated it. At this edge the
                -- delayed accept vector still represents the final old-bank
                -- sampling edge; first-new-bank accepts arrive one edge later.
                if datapath_clear_pulse = '1' then
                    csr_last_interval_total_hits   <= (others => '0');
                    csr_last_interval_dropped_hits <= (others => '0');
                    underflow_cnt_v := (others => '0');
                    overflow_cnt_v  := (others => '0');
                    total_hits_v    := (others => '0');
                    dropped_hits_v  := (others => '0');
                elsif interval_pulse = '1' then
                    csr_last_interval_total_hits   <= total_hits_v;
                    csr_last_interval_dropped_hits <= dropped_hits_v;
                    underflow_cnt_v := (others => '0');
                    overflow_cnt_v  := (others => '0');
                    total_hits_v    := (others => '0');
                    dropped_hits_v  := (others => '0');
                end if;

                csr_total_hits      <= total_hits_v;
                csr_dropped_hits    <= dropped_hits_v;
                csr_underflow_count <= underflow_cnt_v;
                csr_overflow_count  <= overflow_cnt_v;
            end if;
        end if;
    end process stats_reg;

    -- Snapshot the hot datapath status first, then format the CSR-visible words
    -- one cycle later. CSR polling does not need single-cycle visibility.
    status_shadow : process (i_clk)
        variable fifo_empty_v    : std_logic_vector(7 downto 0);
        variable fifo_pair_max_v : status_pair_max_array_t;
        variable pair_max_v      : fifo_level_t;
        variable port_lo_v       : natural;
        variable port_hi_v       : natural;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                status_active_bank_shadow         <= '0';
                status_flushing_shadow            <= '0';
                status_flush_addr_shadow          <= (others => '0');
                status_fifo_empty_shadow          <= (others => '1');
                status_fifo_pair_max_shadow       <= (others => (others => '0'));
                status_queue_occupancy_shadow     <= (others => '0');
                status_queue_occupancy_max_shadow <= (others => '0');
                status_queue_overflow_shadow      <= (others => '0');
            else
                fifo_empty_v    := (others => '1');
                fifo_pair_max_v := (others => (others => '0'));

                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    if idx < N_PORTS then
                        fifo_empty_v(idx) := fifo_empty(idx);
                    end if;
                end loop;

                for pair_idx in 0 to (MAX_PORTS_CONST / 2) - 1 loop
                    port_lo_v  := pair_idx * 2;
                    port_hi_v  := port_lo_v + 1;
                    pair_max_v := (others => '0');

                    if port_lo_v < N_PORTS then
                        pair_max_v := fifo_level_max(port_lo_v);
                    end if;

                    if (port_hi_v < N_PORTS) and (fifo_level_max(port_hi_v) > pair_max_v) then
                        pair_max_v := fifo_level_max(port_hi_v);
                    end if;

                    fifo_pair_max_v(pair_idx) := clip_status_byte_f(pair_max_v);
                end loop;

                status_active_bank_shadow         <= active_bank;
                status_flushing_shadow            <= flushing;
                status_flush_addr_shadow          <= std_logic_vector(resize(flush_addr, 8));
                status_fifo_empty_shadow          <= fifo_empty_v;
                status_fifo_pair_max_shadow       <= fifo_pair_max_v;
                status_queue_occupancy_shadow     <= clip_status_byte_f(queue_occupancy);
                status_queue_occupancy_max_shadow <= clip_status_byte_f(queue_occupancy_max);
                status_queue_overflow_shadow      <= queue_overflow_count;
            end if;
        end if;
    end process status_shadow;

    status_csr : process (i_clk)
        variable bank_status_v : std_logic_vector(31 downto 0);
        variable port_status_v : std_logic_vector(31 downto 0);
        variable coal_status_v : std_logic_vector(31 downto 0);
        variable fifo_max_v    : status_byte_t;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                csr_bank_status <= (others => '0');
                csr_port_status <= (others => '0');
                csr_coal_status <= (others => '0');
            else
                fifo_max_v := status_fifo_pair_max_shadow(status_fifo_pair_max_shadow'low);
                for pair_idx in status_fifo_pair_max_shadow'range loop
                    if status_fifo_pair_max_shadow(pair_idx) > fifo_max_v then
                        fifo_max_v := status_fifo_pair_max_shadow(pair_idx);
                    end if;
                end loop;

                bank_status_v := (others => '0');
                bank_status_v(0)           := status_active_bank_shadow;
                bank_status_v(1)           := status_flushing_shadow;
                bank_status_v(15 downto 8) := status_flush_addr_shadow;

                port_status_v := (others => '0');
                port_status_v(7 downto 0)   := status_fifo_empty_shadow;
                port_status_v(23 downto 16) := std_logic_vector(fifo_max_v);

                coal_status_v := (others => '0');
                coal_status_v(7 downto 0)   := std_logic_vector(status_queue_occupancy_shadow);
                coal_status_v(15 downto 8)  := std_logic_vector(status_queue_occupancy_max_shadow);
                coal_status_v(31 downto 16) := std_logic_vector(status_queue_overflow_shadow);

                csr_bank_status <= bank_status_v;
                csr_port_status <= port_status_v;
                csr_coal_status <= coal_status_v;
            end if;
        end if;
    end process status_csr;

    cfg_apply_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                cfg_apply_pending   <= '0';
                cfg_pipeline_busy_q <= '1';
                cfg_pipeline_quiet_q <= '0';
                cfg_mode            <= std_logic_vector(to_signed(DEF_MODE, 4));
                cfg_in_port         <= IN_PORT_FILL_CONST;
                cfg_key_unsigned    <= bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED");
                cfg_filter_enable   <= '0';
                cfg_filter_reject   <= '0';
                cfg_left_bound      <= to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH);
                cfg_right_bound     <= default_right_bound_f;
                cfg_bin_width       <= to_unsigned(DEF_BIN_WIDTH, 16);
                cfg_update_key_low  <= to_unsigned(UPDATE_KEY_BIT_LO, 8);
                cfg_update_key_high <= to_unsigned(UPDATE_KEY_BIT_HI, 8);
                cfg_filter_key_low  <= to_unsigned(FILTER_KEY_BIT_LO, 8);
                cfg_filter_key_high <= to_unsigned(FILTER_KEY_BIT_HI, 8);
                cfg_update_key      <= (others => '0');
                cfg_filter_key      <= (others => '0');
                cfg_source_select   <= to_unsigned(DEF_SOURCE_SELECT, 2);
                cfg_interval_cfg    <= to_unsigned(DEF_INTERVAL_CLOCKS, 32);
                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    cfg_filter_enable_port(idx)  <= '0';
                    cfg_filter_reject_port(idx)  <= '0';
                    cfg_filter_key_low_port(idx) <= to_unsigned(FILTER_KEY_BIT_LO, 8);
                    cfg_filter_key_high_port(idx) <= to_unsigned(FILTER_KEY_BIT_HI, 8);
                    cfg_filter_key_port(idx)     <= (others => '0');
                    cfg_source_select_port(idx)  <= to_unsigned(DEF_SOURCE_SELECT, 2);
                end loop;
            else
                -- Keep the wide pipeline-empty reduction off the replicated
                -- configuration-register enables.  A commit needs two
                -- consecutive registered quiet observations while ingress is
                -- frozen by cfg_apply_pending.  Clearing the qualifier whenever
                -- no request is pending also prevents a previously idle pipeline
                -- from making a newly requested apply commit prematurely.
                cfg_pipeline_busy_q <= hist_pipeline_busy;
                if (cfg_apply_pending = '1') and
                   (cfg_pipeline_busy_q = '0') then
                    cfg_pipeline_quiet_q <= '1';
                else
                    cfg_pipeline_quiet_q <= '0';
                end if;

                -- Freeze new ingress while pending, then commit only after all
                -- mapper stages, binned FIFOs, live cells, and SRAM updates
                -- carrying the old interpretation have drained and remained
                -- quiet for a full registered observation cycle.
                if (cfg_apply_pending = '1') and
                   (cfg_pipeline_busy_q = '0') and
                   (cfg_pipeline_quiet_q = '1') then
                    cfg_apply_pending   <= '0';
                    cfg_mode            <= csr_mode;
                    cfg_in_port         <= csr_in_port;
                    cfg_key_unsigned    <= csr_key_unsigned;
                    cfg_filter_enable   <= csr_filter_enable;
                    cfg_filter_reject   <= csr_filter_reject;
                    cfg_left_bound      <= csr_left_bound;
                    cfg_right_bound     <= csr_right_bound;
                    cfg_bin_width       <= csr_bin_width;
                    cfg_update_key_low  <= csr_update_key_low;
                    cfg_update_key_high <= csr_update_key_high;
                    cfg_filter_key_low  <= csr_filter_key_low;
                    cfg_filter_key_high <= csr_filter_key_high;
                    cfg_update_key      <= csr_update_key;
                    cfg_filter_key      <= csr_filter_key;
                    cfg_source_select   <= csr_source_select;
                    cfg_interval_cfg    <= csr_interval_cfg;
                    for idx in 0 to MAX_PORTS_CONST - 1 loop
                        cfg_filter_enable_port(idx)  <= csr_filter_enable;
                        cfg_filter_reject_port(idx)  <= csr_filter_reject;
                        cfg_filter_key_low_port(idx) <= csr_filter_key_low;
                        cfg_filter_key_high_port(idx) <= csr_filter_key_high;
                        cfg_filter_key_port(idx)     <= csr_filter_key;
                        cfg_source_select_port(idx)  <= csr_source_select;
                    end loop;
                elsif cfg_apply_request = '1' then
                    cfg_apply_pending <= '1';
                end if;
            end if;
        end if;
    end process cfg_apply_reg;

    csr_reg : process (i_clk)
        variable next_right_v : right_calc_t;
        variable commit_ok_v  : boolean;
        variable control_mode_v : std_logic_vector(3 downto 0);
        variable control_source_v : unsigned(1 downto 0);
        variable control_mode_i_v : integer;
        variable source_data_width_v : natural;
        variable key_ranges_ok_v : boolean;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                cfg_apply_request   <= '0';
                csr_mode            <= std_logic_vector(to_signed(DEF_MODE, 4));
                csr_in_port         <= IN_PORT_FILL_CONST;
                csr_key_unsigned    <= bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED");
                csr_filter_enable   <= '0';
                csr_filter_reject   <= '0';
                csr_error           <= '0';
                csr_error_info      <= (others => '0');
                csr_left_bound      <= to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH);
                csr_right_bound     <= default_right_bound_f;
                csr_bin_width       <= to_unsigned(DEF_BIN_WIDTH, 16);
                csr_update_key_low  <= to_unsigned(UPDATE_KEY_BIT_LO, 8);
                csr_update_key_high <= to_unsigned(UPDATE_KEY_BIT_HI, 8);
                csr_filter_key_low  <= to_unsigned(FILTER_KEY_BIT_LO, 8);
                csr_filter_key_high <= to_unsigned(FILTER_KEY_BIT_HI, 8);
                csr_update_key      <= (others => '0');
                csr_filter_key      <= (others => '0');
                csr_source_select   <= to_unsigned(DEF_SOURCE_SELECT, 2);
                csr_interval_cfg    <= to_unsigned(DEF_INTERVAL_CLOCKS, 32);
                csr_scratch         <= (others => '0');
                csr_meta_sel        <= (others => '0');
            else
                cfg_apply_request <= '0';
                if avs_csr_write = '1' then
                    case to_integer(unsigned(avs_csr_address)) is
                        when 0 =>   -- UID: read-only, ignore writes
                            null;
                        when 1 =>   -- META: write selector for read-mux page
                            csr_meta_sel <= avs_csr_writedata(1 downto 0);
                        when 2 =>   -- CONTROL
                            control_mode_v   := avs_csr_writedata(7 downto 4);
                            control_source_v := unsigned(avs_csr_writedata(17 downto 16));
                            control_mode_i_v := to_integer(signed(control_mode_v));
                            csr_mode          <= avs_csr_writedata(7 downto 4);
                            csr_in_port       <= unsigned(avs_csr_writedata(3 downto 2));
                            csr_key_unsigned  <= avs_csr_writedata(8);
                            csr_filter_enable <= avs_csr_writedata(12);
                            csr_filter_reject <= avs_csr_writedata(13);
                            csr_source_select <= unsigned(avs_csr_writedata(17 downto 16));
                            if avs_csr_writedata(0) = '1' then
                                commit_ok_v     := true;
                                key_ranges_ok_v := true;
                                csr_error      <= '0';
                                csr_error_info <= (others => '0');
                                if control_source_v = HIST_SOURCE_TYPE0_CONST then
                                    source_data_width_v := TYPE0_DATA_WIDTH;
                                else
                                    source_data_width_v := TYPE1_DATA_WIDTH;
                                end if;

                                if not LOCK_KEY_RANGES then
                                    if csr_update_key_high < csr_update_key_low then
                                        key_ranges_ok_v := false;
                                    elsif to_integer(csr_update_key_high) >= source_data_width_v then
                                        key_ranges_ok_v := false;
                                    elsif (to_integer(csr_update_key_high) - to_integer(csr_update_key_low) + 1) > SAR_KEY_WIDTH then
                                        key_ranges_ok_v := false;
                                    end if;
                                    if csr_filter_key_high < csr_filter_key_low then
                                        key_ranges_ok_v := false;
                                    elsif to_integer(csr_filter_key_high) >= source_data_width_v then
                                        key_ranges_ok_v := false;
                                    elsif (to_integer(csr_filter_key_high) - to_integer(csr_filter_key_low) + 1) > SAR_KEY_WIDTH then
                                        key_ranges_ok_v := false;
                                    end if;
                                end if;

                                if (not ENABLE_DEBUG_INPUTS) and (control_mode_i_v < 0) then
                                    commit_ok_v     := false;
                                    csr_error      <= '1';
                                    csr_error_info <= x"4";
                                elsif (control_source_v = HIST_SOURCE_TYPE0_CONST) and (control_mode_i_v = 1) then
                                    commit_ok_v     := false;
                                    csr_error      <= '1';
                                    csr_error_info <= x"3";
                                elsif not key_ranges_ok_v then
                                    commit_ok_v     := false;
                                    csr_error      <= '1';
                                    csr_error_info <= x"7";
                                elsif POWER2_BIN_WIDTH_ONLY and (csr_bin_width /= 0) and (not is_power2_u(csr_bin_width)) then
                                    commit_ok_v     := false;
                                    csr_error      <= '1';
                                    csr_error_info <= x"5";
                                elsif csr_bin_width = 0 then
                                    if csr_right_bound <= csr_left_bound then
                                        commit_ok_v     := false;
                                        csr_error      <= '1';
                                        csr_error_info <= x"2";
                                    end if;
                                else
                                    next_right_v := calculate_right_bound_f(csr_left_bound, csr_bin_width);
                                    if not right_bound_fits_f(next_right_v) then
                                        commit_ok_v     := false;
                                        csr_error      <= '1';
                                        csr_error_info <= x"6";
                                    else
                                        csr_right_bound <= resize(next_right_v, SAR_TICK_WIDTH);
                                    end if;
                                end if;
                                if commit_ok_v then
                                    cfg_apply_request <= '1';
                                end if;
                            end if;
                        when 3 =>   -- LEFT_BOUND
                            csr_left_bound <= resize(signed(avs_csr_writedata), SAR_TICK_WIDTH);
                        when 4 =>   -- RIGHT_BOUND
                            csr_right_bound <= resize(signed(avs_csr_writedata), SAR_TICK_WIDTH);
                        when 5 =>   -- BIN_WIDTH
                            csr_bin_width <= unsigned(avs_csr_writedata(15 downto 0));
                        when 6 =>   -- KEY_LOC
                            csr_update_key_low  <= unsigned(avs_csr_writedata(7 downto 0));
                            csr_update_key_high <= unsigned(avs_csr_writedata(15 downto 8));
                            csr_filter_key_low  <= unsigned(avs_csr_writedata(23 downto 16));
                            csr_filter_key_high <= unsigned(avs_csr_writedata(31 downto 24));
                        when 7 =>   -- KEY_VALUE
                            csr_update_key <= unsigned(avs_csr_writedata(SAR_KEY_WIDTH - 1 downto 0));
                            csr_filter_key <= resize(unsigned(avs_csr_writedata(31 downto 16)), csr_filter_key'length);
                        when 10 =>  -- INTERVAL_CFG
                            csr_interval_cfg <= unsigned(avs_csr_writedata);
                        when 16 =>  -- SCRATCH
                            csr_scratch <= avs_csr_writedata;
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process csr_reg;

    csr_read_comb : process (all)
        variable control_v       : std_logic_vector(31 downto 0);
        variable version_v       : std_logic_vector(31 downto 0);
        variable meta_v          : std_logic_vector(31 downto 0);
    begin
        control_v := (others => '0');
        control_v(1)            := cfg_apply_pending;
        control_v(3 downto 2)   := std_logic_vector(csr_in_port);
        control_v(7 downto 4)   := csr_mode;
        control_v(8)            := csr_key_unsigned;
        control_v(12)           := csr_filter_enable;
        control_v(13)           := csr_filter_reject;
        control_v(17 downto 16) := std_logic_vector(csr_source_select);
        control_v(24)           := csr_error;
        control_v(31 downto 28) := csr_error_info;

        version_v := (others => '0');
        version_v(31 downto 24) := std_logic_vector(to_unsigned(VERSION_MAJOR, 8));
        version_v(23 downto 16) := std_logic_vector(to_unsigned(VERSION_MINOR, 8));
        version_v(15 downto 12) := std_logic_vector(to_unsigned(VERSION_PATCH, 4));
        version_v(11 downto 0)  := std_logic_vector(to_unsigned(BUILD, 12));

        -- META read-mux: page selected by csr_meta_sel
        case csr_meta_sel is
            when "00"   => meta_v := version_v;
            when "01"   => meta_v := std_logic_vector(to_unsigned(VERSION_DATE, 32));
            when "10"   => meta_v := std_logic_vector(to_unsigned(VERSION_GIT, 32));
            when others => meta_v := std_logic_vector(to_unsigned(INSTANCE_ID, 32));
        end case;

        case to_integer(unsigned(avs_csr_address)) is
            when 0 =>   -- UID (RO)
                csr_readdata_mux <= std_logic_vector(to_unsigned(IP_UID, 32));
            when 1 =>   -- META (RO, page-selected)
                csr_readdata_mux <= meta_v;
            when 2 =>   -- CONTROL
                csr_readdata_mux <= control_v;
            when 3 =>   -- LEFT_BOUND
                csr_readdata_mux <= std_logic_vector(resize(csr_left_bound, 32));
            when 4 =>   -- RIGHT_BOUND
                csr_readdata_mux <= std_logic_vector(resize(csr_right_bound, 32));
            when 5 =>   -- BIN_WIDTH
                csr_readdata_mux <= x"0000" & std_logic_vector(csr_bin_width);
            when 6 =>   -- KEY_LOC
                csr_readdata_mux <= std_logic_vector(csr_filter_key_high) &
                                   std_logic_vector(csr_filter_key_low) &
                                   std_logic_vector(csr_update_key_high) &
                                   std_logic_vector(csr_update_key_low);
            when 7 =>   -- KEY_VALUE
                csr_readdata_mux <= std_logic_vector(resize(csr_filter_key, 16)) &
                                   std_logic_vector(resize(csr_update_key, 16));
            when 8 =>   -- UNDERFLOW_COUNT
                csr_readdata_mux <= std_logic_vector(resize(csr_underflow_count, 32));
            when 9 =>   -- OVERFLOW_COUNT
                csr_readdata_mux <= std_logic_vector(resize(csr_overflow_count, 32));
            when 10 =>  -- INTERVAL_CFG
                csr_readdata_mux <= std_logic_vector(csr_interval_cfg);
            when 11 =>  -- BANK_STATUS
                csr_readdata_mux <= csr_bank_status;
            when 12 =>  -- PORT_STATUS
                csr_readdata_mux <= csr_port_status;
            when 13 =>  -- TOTAL_HITS
                csr_readdata_mux <= std_logic_vector(resize(csr_total_hits, 32));
            when 14 =>  -- DROPPED_HITS
                csr_readdata_mux <= std_logic_vector(resize(csr_dropped_hits, 32));
            when 15 =>  -- COAL_STATUS
                csr_readdata_mux <= csr_coal_status;
            when 16 =>  -- SCRATCH
                csr_readdata_mux <= csr_scratch;
            when 17 =>  -- LAST_INTERVAL_TOTAL_HITS
                csr_readdata_mux <= std_logic_vector(resize(csr_last_interval_total_hits, 32));
            when 18 =>  -- LAST_INTERVAL_DROPPED_HITS
                csr_readdata_mux <= std_logic_vector(resize(csr_last_interval_dropped_hits, 32));
            when others =>
                csr_readdata_mux <= (others => '0');
        end case;
    end process csr_read_comb;

    csr_read_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                csr_readdata_reg <= (others => '0');
            elsif avs_csr_read = '1' then
                csr_readdata_reg <= csr_readdata_mux;
            end if;
        end if;
    end process csr_read_reg;

end architecture rtl;
