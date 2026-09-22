-- altera vhdl_input_version vhdl_2008
-- File name: coalescing_queue.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--      Date: Mar 20, 2026
-- Revision: 2.0
--      Date: Jul 13, 2026
--      Change: Implement the counted multi-input coalescer as an eight-wide
--              match engine feeding a circular live-cell ring.  Up to two
--              new miss cells are appended per cycle while every descriptor
--              can coalesce into an existing cell, including the retiring
--              head.  A preloaded full-generation pending payload isolates
--              group intake from active retirement.  Wide counts retain
--              exact residuals.
-- Revision: 2.1
--      Date: Jul 13, 2026
--      Change: Pipeline the generic deep-core intake through raw capture,
--              equality/leader masks, and a balanced eight-way group sum.
--              Sparse work descriptors retain their first-lane indices so
--              ordering and counted contention behavior remain unchanged.
-- Revision: 2.2
--      Date: Jul 13, 2026
--      Change: Dequeue a sparse work descriptor when it is dispatched and
--              retain any counted residual only in the lookup registers.
--              Add private wrapper-forwarded pulses for exact commit,
--              resident update, head pop, and append coverage.
-- Revision: 2.3
--      Date: Jul 13, 2026
--      Change: Split the generic deep-core commit into match capture,
--              resident read, arithmetic plan, and storage apply stages.
--              A matched-head pop forwards the registered post-match count
--              directly instead of traversing the indexed live array.
-- Revision: 2.4
--      Date: Jul 13, 2026
--      Change: Register generic-core pop, append, payload, pointer, and
--              per-slot storage controls before applying them.  Idle head
--              prefetch uses the same scheduled apply boundary, removing
--              live-level decisions from the deep live-array write cone.
-- Revision: 2.5
--      Date: Jul 13, 2026
--      Change: Hold generic-core intake and FSM advancement on the edge that
--              applies registered storage controls.  All later CAM and
--              indexed reads use the settled registered live image, removing
--              apply-to-read forwarding through the process variables.
-- Revision: 2.6
--      Date: Jul 13, 2026
--      Change: Release the fitted AUTO CAM map: depths 4..31 use zero stages,
--              32..63 use one stage, and 64..256 use two stages.
-- =========
-- Description: Counted multi-input coalescer for histogram bin updates.
--
-- Version: 26.5.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.histogram_statistics_v2_pkg.all;

entity coalescing_queue_fast is
    generic (
        N_BINS         : natural := 256;
        QUEUE_DEPTH    : natural := 8;
        KICK_WIDTH     : natural := 4;
        N_INPUTS       : natural := 8;
        OVERFLOW_WIDTH : natural := 16;
        CAM_PIPELINE_MODE   : string  := "AUTO";
        CAM_PIPELINE_STAGES : natural := 0
    );
    port (
        i_clk            : in  std_logic;
        i_rst            : in  std_logic;
        i_clear          : in  std_logic;

        i_hit_valid      : in  std_logic_vector(N_INPUTS - 1 downto 0);
        i_hit_bank       : in  std_logic_vector(N_INPUTS - 1 downto 0);
        i_hit_bin        : in  hs_unsigned_array_t(0 to N_INPUTS - 1)(clog2(N_BINS) - 1 downto 0);
        i_hit_count      : in  hs_unsigned_array_t(0 to N_INPUTS - 1)(KICK_WIDTH - 1 downto 0);
        o_hit_accept     : out std_logic_vector(N_INPUTS - 1 downto 0);

        i_drain_ready    : in  std_logic;
        o_drain_valid    : out std_logic;
        o_drain_bank     : out std_logic;
        o_drain_bin      : out unsigned(clog2(N_BINS) - 1 downto 0);
        o_drain_count    : out unsigned(KICK_WIDTH - 1 downto 0);

        o_occupancy      : out unsigned(clog2(QUEUE_DEPTH + 1) - 1 downto 0);
        o_occupancy_max  : out unsigned(clog2(QUEUE_DEPTH + 1) - 1 downto 0);
        o_overflow_count : out unsigned(OVERFLOW_WIDTH - 1 downto 0);

        -- Private wrapper-forwarded verification hooks.  These keep the
        -- established focused contention aliases at the public dut boundary
        -- without changing the public coalescing_queue entity.
        o_dbg_engine_has_match       : out std_logic_vector(7 downto 0);
        o_dbg_engine_miss            : out std_logic_vector(7 downto 0);
        o_dbg_live_has_match         : out std_logic_vector(QUEUE_DEPTH - 1 downto 0);
        o_dbg_live_rd_ptr            : out natural range 0 to QUEUE_DEPTH - 1;
        o_dbg_resident_to_drain      : out std_logic;
        o_dbg_miss_stage_valid       : out std_logic_vector(7 downto 0);
        o_dbg_engine_allocate        : out std_logic_vector(7 downto 0);
        o_dbg_engine_allocate_count  : out natural range 0 to 2;
        o_dbg_append_commit_count    : out natural range 0 to 2;
        o_dbg_free_cells             : out natural range 0 to QUEUE_DEPTH
    );
end entity coalescing_queue_fast;

architecture rtl of coalescing_queue_fast is

    constant BIN_WIDTH_CONST         : positive := clog2(N_BINS);
    constant OCC_WIDTH_CONST         : positive := clog2(QUEUE_DEPTH + 1);
    constant KICK_MAX_NAT_CONST      : natural  := (2 ** KICK_WIDTH) - 1;
    constant BATCH_COUNT_MAX_CONST   : natural  := N_INPUTS * KICK_MAX_NAT_CONST;
    constant BATCH_COUNT_WIDTH_CONST : positive := clog2(BATCH_COUNT_MAX_CONST + 1);
    constant BLOCKED_WIDTH_CONST     : positive := clog2(N_INPUTS + 1);
    constant WORK_CAPACITY_CONST     : positive := 8;
    constant ENGINE_WIDTH_CONST      : positive := 8;
    constant MAX_APPENDS_CONST       : positive := 2;

    subtype bin_t           is unsigned(BIN_WIDTH_CONST - 1 downto 0);
    subtype kick_t          is unsigned(KICK_WIDTH - 1 downto 0);
    subtype batch_count_t   is unsigned(BATCH_COUNT_WIDTH_CONST - 1 downto 0);
    subtype fill_sum_t      is unsigned(KICK_WIDTH downto 0);
    subtype occupancy_t     is unsigned(OCC_WIDTH_CONST - 1 downto 0);
    subtype blocked_fixed_t is unsigned(3 downto 0);

    type bin_array_t         is array (natural range <>) of bin_t;
    type kick_array_t        is array (natural range <>) of kick_t;
    type batch_count_array_t is array (natural range <>) of batch_count_t;
    type bank_array_t        is array (natural range <>) of std_logic;
    type member_array_t      is array (natural range <>) of
        std_logic_vector(N_INPUTS - 1 downto 0);
    type engine_match_array_t is array (0 to ENGINE_WIDTH_CONST - 1) of
        std_logic_vector(QUEUE_DEPTH - 1 downto 0);
    type slot_kick_array_t       is array (0 to QUEUE_DEPTH - 1) of kick_t;
    type slot_batch_array_t      is array (0 to QUEUE_DEPTH - 1) of batch_count_t;
    type slot_fill_array_t       is array (0 to QUEUE_DEPTH - 1) of fill_sum_t;
    type engine_slot_kick_matrix_t is array (0 to ENGINE_WIDTH_CONST - 1) of
        slot_kick_array_t;
    type engine_slot_batch_matrix_t is array (0 to ENGINE_WIDTH_CONST - 1) of
        slot_batch_array_t;
    type engine_slot_fill_matrix_t is array (0 to ENGINE_WIDTH_CONST - 1) of
        slot_fill_array_t;
    type fixed_batch_array_t   is array (0 to 7) of batch_count_t;
    type fixed_blocked_array_t is array (0 to 7) of blocked_fixed_t;
    type fixed_kick_array_t    is array (0 to 7) of kick_t;

    signal input_any_c : std_logic;

    signal raw_batch_valid_q : std_logic := '0';
    signal raw_valid_q       : std_logic_vector(N_INPUTS - 1 downto 0) := (others => '0');
    signal raw_bank_q        : bank_array_t(0 to N_INPUTS - 1) := (others => '0');
    signal raw_bin_q         : bin_array_t(0 to N_INPUTS - 1) := (others => (others => '0'));
    signal raw_count_q       : kick_array_t(0 to N_INPUTS - 1) := (others => (others => '0'));

    signal mask_leader_c : std_logic_vector(N_INPUTS - 1 downto 0);
    signal mask_member_c : member_array_t(0 to N_INPUTS - 1);

    signal mask_batch_valid_q : std_logic := '0';
    signal mask_leader_q      : std_logic_vector(N_INPUTS - 1 downto 0) := (others => '0');
    signal mask_member_q      : member_array_t(0 to N_INPUTS - 1) := (others => (others => '0'));
    signal mask_bank_q        : bank_array_t(0 to N_INPUTS - 1) := (others => '0');
    signal mask_bin_q         : bin_array_t(0 to N_INPUTS - 1) := (others => (others => '0'));
    signal mask_count_q       : kick_array_t(0 to N_INPUTS - 1) := (others => (others => '0'));

    signal reduced_valid_c : std_logic_vector(N_INPUTS - 1 downto 0);
    signal reduced_bank_c  : bank_array_t(0 to N_INPUTS - 1);
    signal reduced_bin_c   : bin_array_t(0 to N_INPUTS - 1);
    signal reduced_count_c : batch_count_array_t(0 to N_INPUTS - 1);

    signal group_batch_valid_q : std_logic := '0';
    signal group_valid_q       : std_logic_vector(N_INPUTS - 1 downto 0) := (others => '0');
    signal group_bank_q        : bank_array_t(0 to N_INPUTS - 1) := (others => '0');
    signal group_bin_q         : bin_array_t(0 to N_INPUTS - 1) := (others => (others => '0'));
    signal group_count_q       : batch_count_array_t(0 to N_INPUTS - 1) := (others => (others => '0'));

    signal compact_group_valid_c : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
    signal compact_group_bank_c  : bank_array_t(0 to WORK_CAPACITY_CONST - 1);
    signal compact_group_bin_c   : bin_array_t(0 to WORK_CAPACITY_CONST - 1);
    signal compact_group_count_c : batch_count_array_t(0 to WORK_CAPACITY_CONST - 1);

    signal pending_valid_q : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0) := (others => '0');
    signal pending_bank_q  : bank_array_t(0 to WORK_CAPACITY_CONST - 1) := (others => '0');
    signal pending_bin_q   : bin_array_t(0 to WORK_CAPACITY_CONST - 1) := (others => (others => '0'));
    signal pending_count_q : batch_count_array_t(0 to WORK_CAPACITY_CONST - 1) := (others => (others => '0'));
    signal pending_gen_q   : std_logic := '0';
    signal pending_any_c   : std_logic;
    signal pending_current_any_c : std_logic;
    signal pending_payload_load_c : std_logic;

    signal active_valid_q : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0) := (others => '0');
    signal active_gen_q   : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0) := (others => '0');
    signal active_bank_q  : bank_array_t(0 to WORK_CAPACITY_CONST - 1) := (others => '0');
    signal active_bin_q   : bin_array_t(0 to WORK_CAPACITY_CONST - 1) := (others => (others => '0'));
    signal active_count_q : batch_count_array_t(0 to WORK_CAPACITY_CONST - 1) := (others => (others => '0'));
    signal active_any_c   : std_logic;
    signal active_current_valid_c : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
    signal active_future_valid_c  : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
    signal active_future_any_c    : std_logic;
    signal payload_promotion_free_c : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
    signal current_gen_q          : std_logic := '0';

    signal engine_valid_c : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal engine_bank_c  : bank_array_t(0 to ENGINE_WIDTH_CONST - 1);
    signal engine_bin_c   : bin_array_t(0 to ENGINE_WIDTH_CONST - 1);
    signal engine_count_c : batch_count_array_t(0 to ENGINE_WIDTH_CONST - 1);
    signal engine_match_c : engine_match_array_t;
    signal engine_match_active_c : engine_match_array_t;
    signal engine_has_match_c       : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal engine_candidate_fill_c  : engine_slot_fill_matrix_t;
    signal engine_candidate_live_c  : engine_slot_kick_matrix_t;
    signal engine_candidate_open_c  : engine_match_array_t;
    signal engine_candidate_residual_c : engine_slot_batch_matrix_t;
    signal engine_candidate_residual_valid_c : engine_match_array_t;
    signal engine_match_residual_c  : batch_count_array_t(0 to ENGINE_WIDTH_CONST - 1);
    signal engine_match_residual_valid_c : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal engine_miss_c            : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal miss_stage_valid_q       : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0) :=
        (others => '0');
    signal miss_stage_bank_q        : bank_array_t(0 to ENGINE_WIDTH_CONST - 1) :=
        (others => '0');
    signal miss_stage_bin_q         : bin_array_t(0 to ENGINE_WIDTH_CONST - 1) :=
        (others => (others => '0'));
    signal miss_stage_count_q       : batch_count_array_t(0 to ENGINE_WIDTH_CONST - 1) :=
        (others => (others => '0'));
    signal allocation_candidate_c   : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal engine_miss_pair_any_c   : std_logic_vector(3 downto 0);
    signal engine_miss_pair_two_c   : std_logic_vector(3 downto 0);
    signal engine_miss_half_any_c   : std_logic_vector(1 downto 0);
    signal engine_miss_half_two_c   : std_logic_vector(1 downto 0);
    signal engine_miss_any_c        : std_logic;
    signal engine_miss_two_c        : std_logic;
    signal engine_first_allocate_c  : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal engine_second_allocate_c : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal engine_allocate_c        : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal engine_next_valid_c      : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal engine_next_count_c      : batch_count_array_t(0 to ENGINE_WIDTH_CONST - 1);
    signal engine_allocate_count_c  : natural range 0 to MAX_APPENDS_CONST;

    -- The registered miss snapshot is the timing cut between the tagged CAM
    -- and this allocation network.  Arbitration therefore sees only local
    -- registered bits and payloads.
    signal alloc_stage_accept_slots_c : natural range 0 to MAX_APPENDS_CONST;
    signal alloc_transfer_first_c  : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    signal alloc_transfer_second_c : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);

    signal append_first_bank_c   : std_logic;
    signal append_first_bin_c    : bin_t;
    signal append_first_count_c  : kick_t;
    signal append_second_bank_c  : std_logic;
    signal append_second_bin_c   : bin_t;
    signal append_second_count_c : kick_t;
    signal append_commit_count_c : natural range 0 to MAX_APPENDS_CONST;

    signal engine_done_c          : std_logic;
    signal work_any_c             : std_logic;
    signal active_after_engine_valid_c :
        std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
    signal active_after_engine_count_c :
        batch_count_array_t(0 to WORK_CAPACITY_CONST - 1);

    signal live_valid_q : std_logic_vector(QUEUE_DEPTH - 1 downto 0) := (others => '0');
    signal live_open_q  : std_logic_vector(QUEUE_DEPTH - 1 downto 0) := (others => '0');
    signal live_bank_q  : bank_array_t(0 to QUEUE_DEPTH - 1) := (others => '0');
    signal live_bin_q   : bin_array_t(0 to QUEUE_DEPTH - 1) := (others => (others => '0'));
    signal live_count_q : kick_array_t(0 to QUEUE_DEPTH - 1) := (others => (others => '0'));
    signal live_level_q : natural range 0 to QUEUE_DEPTH := 0;
    signal live_rd_ptr_q : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal live_wr_ptr_q : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal live_has_match_c       : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
    signal live_match_new_count_c : slot_kick_array_t;
    signal live_match_new_open_c  : std_logic_vector(QUEUE_DEPTH - 1 downto 0);

    signal live_valid_next_c : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
    signal live_open_next_c  : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
    signal live_bank_next_c  : bank_array_t(0 to QUEUE_DEPTH - 1);
    signal live_bin_next_c   : bin_array_t(0 to QUEUE_DEPTH - 1);
    signal live_count_next_c : kick_array_t(0 to QUEUE_DEPTH - 1);
    signal live_level_next_c : natural range 0 to QUEUE_DEPTH;
    signal live_rd_ptr_next_c : natural range 0 to QUEUE_DEPTH - 1;
    signal live_wr_ptr_next_c : natural range 0 to QUEUE_DEPTH - 1;
    signal free_cells_c       : natural range 0 to QUEUE_DEPTH;

    signal drain_valid_q : std_logic := '0';
    signal drain_bank_q  : std_logic := '0';
    signal drain_bin_q   : bin_t := (others => '0');
    signal drain_count_q : kick_t := (others => '0');
    signal drain_can_load_c    : std_logic;
    signal resident_to_drain_c : std_logic;
    signal drain_load_count_c  : kick_t;

    signal raw_ready_c          : std_logic;
    signal raw_to_mask_fire_c   : std_logic;
    signal mask_ready_c         : std_logic;
    signal mask_to_group_fire_c : std_logic;
    signal group_ready_c           : std_logic;
    signal group_to_pending_fire_c : std_logic;

    signal occupancy_visible_c : occupancy_t;
    signal occupancy_max_q     : occupancy_t := (others => '0');
    signal blocked_now_c       : unsigned(BLOCKED_WIDTH_CONST - 1 downto 0);
    signal overflow_count_q    : unsigned(OVERFLOW_WIDTH - 1 downto 0) := (others => '0');

    -- Preserve the speculative descriptor/slot arithmetic.  Without these
    -- cut points synthesis can legally share the adders after a CAM mux,
    -- recreating the serial path that this transpose is intended to remove.
    attribute keep : boolean;
    attribute keep of engine_candidate_fill_c : signal is true;
    attribute keep of engine_candidate_live_c : signal is true;
    attribute keep of engine_candidate_residual_c : signal is true;

    function advance_ptr_f(
        ptr  : natural;
        step : natural
    ) return natural is
    begin
        return (ptr + step) mod QUEUE_DEPTH;
    end function advance_ptr_f;

    function resolve_cam_pipeline_stages_f(
        mode_name       : string;
        explicit_stages : natural;
        depth           : positive
    ) return natural is
    begin
        if mode_name = "EXPLICIT" then
            return explicit_stages;
        end if;

        -- Arria-V seed-one fitted AUTO map at the 7.273 ns target.
        if depth <= 31 then
            return 0;
        elsif depth <= 63 then
            return 1;
        end if;
        return 2;
    end function resolve_cam_pipeline_stages_f;

    constant CAM_PIPELINE_STAGES_EFFECTIVE_CONST : natural :=
        resolve_cam_pipeline_stages_f(
            CAM_PIPELINE_MODE,
            CAM_PIPELINE_STAGES,
            QUEUE_DEPTH
        );

begin

    assert N_INPUTS >= 1 and N_INPUTS <= WORK_CAPACITY_CONST
        report "coalescing_queue supports one through eight parallel inputs"
        severity failure;
    assert QUEUE_DEPTH = 4 or QUEUE_DEPTH = 8
        report "ring coalescing_queue supports queue depth 4 or 8"
        severity failure;
    assert KICK_WIDTH >= 1
        report "coalescing_queue requires KICK_WIDTH >= 1"
        severity failure;
    assert CAM_PIPELINE_MODE = "AUTO" or CAM_PIPELINE_MODE = "EXPLICIT"
        report "CAM_PIPELINE_MODE must be AUTO or EXPLICIT"
        severity failure;
    assert CAM_PIPELINE_STAGES_EFFECTIVE_CONST <= 3
        report "resolved CAM pipeline exceeds the supported three-stage bound"
        severity failure;

    input_any_comb : process(all)
        variable any_v : std_logic;
    begin
        any_v := '0';
        for input_index in 0 to N_INPUTS - 1 loop
            any_v := any_v or i_hit_valid(input_index);
        end loop;
        input_any_c <= any_v;
    end process;

    -- Intake credit is registered state only.  The complete asserted batch is
    -- accepted atomically and no resident-CAM path reaches a source FIFO pop.
    raw_ready_c <= '1' when raw_batch_valid_q = '0' and
                           i_rst = '0' and i_clear = '0' else '0';

    accept_generate : for input_index in 0 to N_INPUTS - 1 generate
        o_hit_accept(input_index) <= i_hit_valid(input_index) and raw_ready_c;
    end generate;

    pending_any_c <= '0' when
        pending_valid_q = (pending_valid_q'range => '0') else '1';
    pending_current_any_c <= '1' when pending_any_c = '1' and
                                      pending_gen_q = current_gen_q else '0';
    active_any_c <= '0' when
        active_valid_q = (active_valid_q'range => '0') else '1';

    active_generation_decode : for descriptor_index in 0 to WORK_CAPACITY_CONST - 1 generate
        active_current_valid_c(descriptor_index) <=
            active_valid_q(descriptor_index) when
                active_gen_q(descriptor_index) = current_gen_q else '0';
        active_future_valid_c(descriptor_index) <=
            active_valid_q(descriptor_index) when
                active_gen_q(descriptor_index) /= current_gen_q else '0';
    end generate;

    active_future_any_c <= '0' when
        active_future_valid_c = (active_future_valid_c'range => '0') else '1';

    -- A registered allocation transfer has no resident-CAM dependency and may
    -- safely reclaim its descriptor slot for payload promotion on this edge.
    -- Match-retired slots deliberately wait for their registered vacancy.
    payload_promotion_free_gen : for descriptor_index in 0 to WORK_CAPACITY_CONST - 1 generate
        payload_promotion_free_c(descriptor_index) <= '1' when
            active_valid_q(descriptor_index) = '0' or
            ((alloc_transfer_first_c(descriptor_index) = '1' or
              alloc_transfer_second_c(descriptor_index) = '1') and
             miss_stage_count_q(descriptor_index) <=
                 to_unsigned(KICK_MAX_NAT_CONST, BATCH_COUNT_WIDTH_CONST)) else '0';
    end generate;

    -- Active slots carry a one-bit generation.  As current descriptors retire,
    -- the same-index pending descriptors move into the vacated slots tagged as
    -- the next generation.  The pending payload is preloaded separately while
    -- invalid, so engine retirement controls only its narrow valid vector.
    work_any_c <= '0' when
        active_current_valid_c =
            (active_current_valid_c'range => '0') else '1';
    group_to_pending_fire_c <= group_batch_valid_q and
                               (not pending_any_c) and
                               (not active_future_any_c);
    pending_payload_load_c <= group_batch_valid_q and (not pending_any_c);
    group_ready_c <= (not group_batch_valid_q) or group_to_pending_fire_c;
    mask_to_group_fire_c <= mask_batch_valid_q and group_ready_c;
    mask_ready_c <= (not mask_batch_valid_q) or mask_to_group_fire_c;
    raw_to_mask_fire_c <= raw_batch_valid_q and mask_ready_c;

    build_member_mask : process(all)
        variable leader_v : boolean;
    begin
        mask_leader_c <= (others => '0');
        mask_member_c <= (others => (others => '0'));

        for leader_index in 0 to N_INPUTS - 1 loop
            leader_v := raw_valid_q(leader_index) = '1';
            if leader_index > 0 then
                for prior_index in 0 to leader_index - 1 loop
                    if raw_valid_q(prior_index) = '1' and
                       raw_bank_q(prior_index) = raw_bank_q(leader_index) and
                       raw_bin_q(prior_index) = raw_bin_q(leader_index) then
                        leader_v := false;
                    end if;
                end loop;
            end if;

            if leader_v then
                mask_leader_c(leader_index) <= '1';
                for member_index in 0 to N_INPUTS - 1 loop
                    if raw_valid_q(member_index) = '1' and
                       raw_bank_q(member_index) = raw_bank_q(leader_index) and
                       raw_bin_q(member_index) = raw_bin_q(leader_index) then
                        mask_member_c(leader_index)(member_index) <= '1';
                    end if;
                end loop;
            end if;
        end loop;
    end process;

    -- Fixed 8->4->2->1 reduction keeps simultaneous same-key lane sums exact
    -- without a serial addition chain.  Leaves above N_INPUTS are zero.
    reduce_registered_mask : process(all)
        variable terms_v : fixed_batch_array_t;
        variable pair_v  : fixed_batch_array_t;
        variable quad_v  : fixed_batch_array_t;
    begin
        reduced_valid_c <= (others => '0');
        reduced_bank_c  <= (others => '0');
        reduced_bin_c   <= (others => (others => '0'));
        reduced_count_c <= (others => (others => '0'));

        for leader_index in 0 to N_INPUTS - 1 loop
            terms_v := (others => (others => '0'));
            if mask_leader_q(leader_index) = '1' then
                for member_index in 0 to N_INPUTS - 1 loop
                    if mask_member_q(leader_index)(member_index) = '1' then
                        terms_v(member_index) := resize(
                            mask_count_q(member_index),
                            BATCH_COUNT_WIDTH_CONST
                        );
                    end if;
                end loop;
            end if;

            pair_v := (others => (others => '0'));
            pair_v(0) := terms_v(0) + terms_v(1);
            pair_v(1) := terms_v(2) + terms_v(3);
            pair_v(2) := terms_v(4) + terms_v(5);
            pair_v(3) := terms_v(6) + terms_v(7);
            quad_v := (others => (others => '0'));
            quad_v(0) := pair_v(0) + pair_v(1);
            quad_v(1) := pair_v(2) + pair_v(3);

            if mask_leader_q(leader_index) = '1' then
                reduced_valid_c(leader_index) <= '1';
                reduced_bank_c(leader_index)  <= mask_bank_q(leader_index);
                reduced_bin_c(leader_index)   <= mask_bin_q(leader_index);
                reduced_count_c(leader_index) <= quad_v(0) + quad_v(1);
            end if;
        end loop;
    end process;

    compact_group : process(all)
        variable valid_v : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
        variable bank_v  : bank_array_t(0 to WORK_CAPACITY_CONST - 1);
        variable bin_v   : bin_array_t(0 to WORK_CAPACITY_CONST - 1);
        variable count_v : batch_count_array_t(0 to WORK_CAPACITY_CONST - 1);
        variable target_v : natural range 0 to WORK_CAPACITY_CONST;
    begin
        valid_v := (others => '0');
        bank_v  := (others => '0');
        bin_v   := (others => (others => '0'));
        count_v := (others => (others => '0'));
        target_v := 0;
        for descriptor_index in 0 to N_INPUTS - 1 loop
            if group_valid_q(descriptor_index) = '1' then
                if target_v < WORK_CAPACITY_CONST then
                    valid_v(target_v) := '1';
                    bank_v(target_v)  := group_bank_q(descriptor_index);
                    bin_v(target_v)   := group_bin_q(descriptor_index);
                    count_v(target_v) := group_count_q(descriptor_index);
                    target_v := target_v + 1;
                end if;
            end if;
        end loop;
        compact_group_valid_c <= valid_v;
        compact_group_bank_c  <= bank_v;
        compact_group_bin_c   <= bin_v;
        compact_group_count_c <= count_v;
    end process;

    engine_inputs : for descriptor_index in 0 to ENGINE_WIDTH_CONST - 1 generate
        -- An allocation packet owns its descriptor until the counted cell is
        -- accepted by the append pipe.  Masking that lane prevents a held
        -- packet from matching or being granted a second time.
        engine_valid_c(descriptor_index) <=
            active_current_valid_c(descriptor_index) and
            not miss_stage_valid_q(descriptor_index);
        engine_bank_c(descriptor_index)  <= active_bank_q(descriptor_index);
        engine_bin_c(descriptor_index)   <= active_bin_q(descriptor_index);
        engine_count_c(descriptor_index) <= active_count_q(descriptor_index);
    end generate;

    -- A conventional elastic output register holds valid/data while stalled.
    drain_can_load_c <= (not drain_valid_q) or i_drain_ready;
    resident_to_drain_c <= '1' when drain_can_load_c = '1' and
                                   live_level_q > 0 else '0';

    free_cell_count_comb : process(all)
        variable free_v : natural range 0 to QUEUE_DEPTH + 1;
    begin
        free_v := QUEUE_DEPTH - live_level_q;
        if resident_to_drain_c = '1' then
            free_v := free_v + 1;
        end if;
        if free_v > QUEUE_DEPTH then
            free_cells_c <= QUEUE_DEPTH;
        else
            free_cells_c <= free_v;
        end if;
    end process;

    -- The miss snapshot is itself the elastic append stage.  Registered misses
    -- arbitrate only against same-cycle ring vacancies and commit directly,
    -- making a new tag visible before the next generation can issue.
    alloc_stage_accept_slots_c <= 2 when free_cells_c >= 2 else
                                  1 when free_cells_c = 1 else
                                  0;
    append_commit_count_c <= engine_allocate_count_c;
    alloc_transfer_first_c <= engine_first_allocate_c;
    alloc_transfer_second_c <= engine_second_allocate_c;

    -- All eight retained descriptors compare against every live cell.  The
    -- retiring head remains matchable; its post-match count is captured by the
    -- elastic drain before a same-cycle tail append can reuse that ring slot.
    find_engine_matches : process(all)
        variable row_v       : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
        variable pair_bits_v : std_logic_vector(3 downto 0);
        variable quad_bits_v : std_logic_vector(1 downto 0);
    begin
        engine_match_c     <= (others => (others => '0'));
        engine_has_match_c <= (others => '0');

        for descriptor_index in 0 to ENGINE_WIDTH_CONST - 1 loop
            row_v := (others => '0');
            -- Tag search is deliberately independent of descriptor valid.
            -- Valid qualifies only the final live-cell action, preventing an
            -- ownership bit from traversing the full CAM/priority network.
            for slot_index in 0 to QUEUE_DEPTH - 1 loop
                if live_valid_q(slot_index) = '1' and
                   live_open_q(slot_index) = '1' and
                   live_bank_q(slot_index) = engine_bank_c(descriptor_index) and
                   live_bin_q(slot_index) = engine_bin_c(descriptor_index) then
                    row_v(slot_index) := '1';
                end if;
            end loop;

            -- Same-beat duplicate tags are reduced before this engine.  A
            -- split cell remains the only open cell for its tag until it
            -- reaches KICK_MAX; only then can its residual append another
            -- cell.  The CAM row is therefore already one-hot, eliminating a
            -- priority encoder from the tag-to-live-mutation timing cone.
            pair_bits_v(0) := row_v(0) or row_v(1);
            pair_bits_v(1) := row_v(2) or row_v(3);
            pair_bits_v(2) := row_v(4) or row_v(5);
            pair_bits_v(3) := row_v(6) or row_v(7);
            quad_bits_v(0) := pair_bits_v(0) or pair_bits_v(1);
            quad_bits_v(1) := pair_bits_v(2) or pair_bits_v(3);

            engine_match_c(descriptor_index) <= row_v;
            engine_has_match_c(descriptor_index) <=
                quad_bits_v(0) or quad_bits_v(1);
        end loop;
    end process;

    qualify_engine_matches : for descriptor_index in 0 to ENGINE_WIDTH_CONST - 1 generate
        qualify_engine_match_slots : for slot_index in 0 to QUEUE_DEPTH - 1 generate
            engine_match_active_c(descriptor_index)(slot_index) <=
                engine_match_c(descriptor_index)(slot_index) and
                engine_valid_c(descriptor_index);
        end generate;
    end generate;

    -- Compute every descriptor/slot fill before the match decision.  Using the
    -- remaining cell capacity (15-live) gives the exact residual with one
    -- subtract instead of a work+live addition followed by another subtract.
    compute_match_candidates : process(all)
        variable capacity_v : batch_count_t;
        variable fill_v     : fill_sum_t;
        variable residual_v : batch_count_t;
    begin
        engine_candidate_fill_c <= (others => (others => (others => '0')));
        engine_candidate_live_c <= (others => (others => (others => '0')));
        engine_candidate_open_c <= (others => (others => '0'));
        engine_candidate_residual_c <= (others => (others => (others => '0')));
        engine_candidate_residual_valid_c <= (others => (others => '0'));
        for descriptor_index in 0 to ENGINE_WIDTH_CONST - 1 loop
            for slot_index in 0 to QUEUE_DEPTH - 1 loop
                capacity_v := resize(
                    not live_count_q(slot_index),
                    BATCH_COUNT_WIDTH_CONST
                );
                fill_v := ('0' & live_count_q(slot_index)) +
                    resize(engine_count_c(descriptor_index), fill_sum_t'length);
                residual_v := engine_count_c(descriptor_index) - capacity_v;
                engine_candidate_fill_c(descriptor_index)(slot_index) <= fill_v;
                engine_candidate_residual_c(descriptor_index)(slot_index) <= residual_v;
                if live_valid_q(slot_index) = '1' then
                    if engine_count_c(descriptor_index) < capacity_v then
                        engine_candidate_open_c(descriptor_index)(slot_index) <= '1';
                    end if;
                    if engine_count_c(descriptor_index) > capacity_v then
                        engine_candidate_live_c(descriptor_index)(slot_index) <=
                            to_unsigned(KICK_MAX_NAT_CONST, KICK_WIDTH);
                        engine_candidate_residual_valid_c(descriptor_index)(slot_index) <= '1';
                    else
                        engine_candidate_live_c(descriptor_index)(slot_index) <=
                            resize(fill_v, KICK_WIDTH);
                    end if;
                end if;
            end loop;
        end loop;
    end process;

    -- Balanced one-hot selections complete the transpose in both directions:
    -- one residual per descriptor and one updated count per resident slot.
    select_match_candidates : process(all)
        variable residual_terms_v : fixed_batch_array_t;
        variable residual_pair_v  : fixed_batch_array_t;
        variable residual_quad_v  : fixed_batch_array_t;
        variable residual_valid_terms_v : std_logic_vector(7 downto 0);
        variable residual_valid_pair_v  : std_logic_vector(3 downto 0);
        variable residual_valid_quad_v  : std_logic_vector(1 downto 0);
        variable live_terms_v : fixed_kick_array_t;
        variable live_pair_v  : fixed_kick_array_t;
        variable live_quad_v  : fixed_kick_array_t;
        variable live_valid_terms_v : std_logic_vector(7 downto 0);
        variable live_valid_pair_v  : std_logic_vector(3 downto 0);
        variable live_valid_quad_v  : std_logic_vector(1 downto 0);
        variable live_open_terms_v  : std_logic_vector(7 downto 0);
        variable live_open_pair_v   : std_logic_vector(3 downto 0);
        variable live_open_quad_v   : std_logic_vector(1 downto 0);
    begin
        engine_match_residual_c       <= (others => (others => '0'));
        engine_match_residual_valid_c <= (others => '0');
        live_match_new_count_c        <= (others => (others => '0'));
        live_match_new_open_c         <= (others => '0');
        live_has_match_c              <= (others => '0');

        for descriptor_index in 0 to ENGINE_WIDTH_CONST - 1 loop
            residual_terms_v       := (others => (others => '0'));
            residual_valid_terms_v := (others => '0');
            for slot_index in 0 to QUEUE_DEPTH - 1 loop
                if engine_match_c(descriptor_index)(slot_index) = '1' then
                    residual_terms_v(slot_index) :=
                        engine_candidate_residual_c(descriptor_index)(slot_index);
                    residual_valid_terms_v(slot_index) :=
                        engine_candidate_residual_valid_c(descriptor_index)(slot_index);
                end if;
            end loop;
            residual_pair_v := (others => (others => '0'));
            residual_pair_v(0) := residual_terms_v(0) or residual_terms_v(1);
            residual_pair_v(1) := residual_terms_v(2) or residual_terms_v(3);
            residual_pair_v(2) := residual_terms_v(4) or residual_terms_v(5);
            residual_pair_v(3) := residual_terms_v(6) or residual_terms_v(7);
            residual_quad_v := (others => (others => '0'));
            residual_quad_v(0) := residual_pair_v(0) or residual_pair_v(1);
            residual_quad_v(1) := residual_pair_v(2) or residual_pair_v(3);
            residual_valid_pair_v(0) := residual_valid_terms_v(0) or residual_valid_terms_v(1);
            residual_valid_pair_v(1) := residual_valid_terms_v(2) or residual_valid_terms_v(3);
            residual_valid_pair_v(2) := residual_valid_terms_v(4) or residual_valid_terms_v(5);
            residual_valid_pair_v(3) := residual_valid_terms_v(6) or residual_valid_terms_v(7);
            residual_valid_quad_v(0) := residual_valid_pair_v(0) or residual_valid_pair_v(1);
            residual_valid_quad_v(1) := residual_valid_pair_v(2) or residual_valid_pair_v(3);
            engine_match_residual_c(descriptor_index) <=
                residual_quad_v(0) or residual_quad_v(1);
            engine_match_residual_valid_c(descriptor_index) <=
                residual_valid_quad_v(0) or residual_valid_quad_v(1);
        end loop;

        for slot_index in 0 to QUEUE_DEPTH - 1 loop
            live_terms_v       := (others => (others => '0'));
            live_valid_terms_v := (others => '0');
            live_open_terms_v  := (others => '0');
            for descriptor_index in 0 to ENGINE_WIDTH_CONST - 1 loop
                if engine_match_active_c(descriptor_index)(slot_index) = '1' then
                    live_terms_v(descriptor_index) :=
                        engine_candidate_live_c(descriptor_index)(slot_index);
                    live_valid_terms_v(descriptor_index) := '1';
                    live_open_terms_v(descriptor_index) :=
                        engine_candidate_open_c(descriptor_index)(slot_index);
                end if;
            end loop;
            live_pair_v := (others => (others => '0'));
            live_pair_v(0) := live_terms_v(0) or live_terms_v(1);
            live_pair_v(1) := live_terms_v(2) or live_terms_v(3);
            live_pair_v(2) := live_terms_v(4) or live_terms_v(5);
            live_pair_v(3) := live_terms_v(6) or live_terms_v(7);
            live_quad_v := (others => (others => '0'));
            live_quad_v(0) := live_pair_v(0) or live_pair_v(1);
            live_quad_v(1) := live_pair_v(2) or live_pair_v(3);
            live_valid_pair_v(0) := live_valid_terms_v(0) or live_valid_terms_v(1);
            live_valid_pair_v(1) := live_valid_terms_v(2) or live_valid_terms_v(3);
            live_valid_pair_v(2) := live_valid_terms_v(4) or live_valid_terms_v(5);
            live_valid_pair_v(3) := live_valid_terms_v(6) or live_valid_terms_v(7);
            live_valid_quad_v(0) := live_valid_pair_v(0) or live_valid_pair_v(1);
            live_valid_quad_v(1) := live_valid_pair_v(2) or live_valid_pair_v(3);
            live_open_pair_v(0) := live_open_terms_v(0) or live_open_terms_v(1);
            live_open_pair_v(1) := live_open_terms_v(2) or live_open_terms_v(3);
            live_open_pair_v(2) := live_open_terms_v(4) or live_open_terms_v(5);
            live_open_pair_v(3) := live_open_terms_v(6) or live_open_terms_v(7);
            live_open_quad_v(0) := live_open_pair_v(0) or live_open_pair_v(1);
            live_open_quad_v(1) := live_open_pair_v(2) or live_open_pair_v(3);
            live_match_new_count_c(slot_index) <= live_quad_v(0) or live_quad_v(1);
            live_match_new_open_c(slot_index) <=
                live_open_quad_v(0) or live_open_quad_v(1);
            live_has_match_c(slot_index) <=
                live_valid_quad_v(0) or live_valid_quad_v(1);
        end loop;
    end process;

    engine_miss_c <= engine_valid_c and not engine_has_match_c;
    allocation_candidate_c <= miss_stage_valid_q;

    miss_pair_generate : for pair_index in 0 to 3 generate
        engine_miss_pair_any_c(pair_index) <=
            allocation_candidate_c(2 * pair_index) or
            allocation_candidate_c(2 * pair_index + 1);
        engine_miss_pair_two_c(pair_index) <=
            allocation_candidate_c(2 * pair_index) and
            allocation_candidate_c(2 * pair_index + 1);
    end generate;

    miss_half_generate : for half_index in 0 to 1 generate
        engine_miss_half_any_c(half_index) <=
            engine_miss_pair_any_c(2 * half_index) or
            engine_miss_pair_any_c(2 * half_index + 1);
        engine_miss_half_two_c(half_index) <=
            engine_miss_pair_two_c(2 * half_index) or
            engine_miss_pair_two_c(2 * half_index + 1) or
            (engine_miss_pair_any_c(2 * half_index) and
             engine_miss_pair_any_c(2 * half_index + 1));
    end generate;

    engine_miss_any_c <= engine_miss_half_any_c(0) or
                         engine_miss_half_any_c(1);
    engine_miss_two_c <= engine_miss_half_two_c(0) or
                         engine_miss_half_two_c(1) or
                         (engine_miss_half_any_c(0) and
                          engine_miss_half_any_c(1));

    engine_allocate_count_c <= 2 when alloc_stage_accept_slots_c >= 2 and
                                      engine_miss_two_c = '1' else
                               1 when alloc_stage_accept_slots_c >= 1 and
                                      engine_miss_any_c = '1' else
                               0;

    -- Select the first two misses with two four-lane priority blocks.  This
    -- fixed network avoids putting an eight-way rank adder and dynamic slot
    -- decoder between the CAM result and the live-cell registers.
    grant_engine_appends : process(all)
        variable low_first_v   : std_logic_vector(3 downto 0);
        variable low_second_v  : std_logic_vector(3 downto 0);
        variable high_first_v  : std_logic_vector(3 downto 0);
        variable high_second_v : std_logic_vector(3 downto 0);
        variable low_any_v     : std_logic;
        variable high_any_v    : std_logic;
        variable low_two_v     : std_logic;
        variable high_two_v    : std_logic;
        variable first_v       : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
        variable second_v      : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
    begin
        low_first_v  := (others => '0');
        low_second_v := (others => '0');
        high_first_v  := (others => '0');
        high_second_v := (others => '0');

        low_first_v(0) := allocation_candidate_c(0);
        low_first_v(1) := allocation_candidate_c(1) and not allocation_candidate_c(0);
        low_first_v(2) := allocation_candidate_c(2) and
                          not allocation_candidate_c(1) and not allocation_candidate_c(0);
        low_first_v(3) := allocation_candidate_c(3) and not allocation_candidate_c(2) and
                          not allocation_candidate_c(1) and not allocation_candidate_c(0);
        low_second_v(1) := allocation_candidate_c(1) and allocation_candidate_c(0);
        low_second_v(2) := allocation_candidate_c(2) and
            ((allocation_candidate_c(0) and not allocation_candidate_c(1)) or
             (not allocation_candidate_c(0) and allocation_candidate_c(1)));
        low_second_v(3) := allocation_candidate_c(3) and
            ((allocation_candidate_c(0) and not allocation_candidate_c(1) and not allocation_candidate_c(2)) or
             (not allocation_candidate_c(0) and allocation_candidate_c(1) and not allocation_candidate_c(2)) or
             (not allocation_candidate_c(0) and not allocation_candidate_c(1) and allocation_candidate_c(2)));

        high_first_v(0) := allocation_candidate_c(4);
        high_first_v(1) := allocation_candidate_c(5) and not allocation_candidate_c(4);
        high_first_v(2) := allocation_candidate_c(6) and
                           not allocation_candidate_c(5) and not allocation_candidate_c(4);
        high_first_v(3) := allocation_candidate_c(7) and not allocation_candidate_c(6) and
                           not allocation_candidate_c(5) and not allocation_candidate_c(4);
        high_second_v(1) := allocation_candidate_c(5) and allocation_candidate_c(4);
        high_second_v(2) := allocation_candidate_c(6) and
            ((allocation_candidate_c(4) and not allocation_candidate_c(5)) or
             (not allocation_candidate_c(4) and allocation_candidate_c(5)));
        high_second_v(3) := allocation_candidate_c(7) and
            ((allocation_candidate_c(4) and not allocation_candidate_c(5) and not allocation_candidate_c(6)) or
             (not allocation_candidate_c(4) and allocation_candidate_c(5) and not allocation_candidate_c(6)) or
             (not allocation_candidate_c(4) and not allocation_candidate_c(5) and allocation_candidate_c(6)));

        low_any_v  := allocation_candidate_c(0) or allocation_candidate_c(1) or
                      allocation_candidate_c(2) or allocation_candidate_c(3);
        high_any_v := allocation_candidate_c(4) or allocation_candidate_c(5) or
                      allocation_candidate_c(6) or allocation_candidate_c(7);
        low_two_v  := low_second_v(1) or low_second_v(2) or low_second_v(3);
        high_two_v := high_second_v(1) or high_second_v(2) or high_second_v(3);

        first_v  := (others => '0');
        second_v := (others => '0');
        if alloc_stage_accept_slots_c >= 1 then
            if low_any_v = '1' then
                first_v(3 downto 0) := low_first_v;
            elsif high_any_v = '1' then
                first_v(7 downto 4) := high_first_v;
            end if;
        end if;
        if alloc_stage_accept_slots_c >= 2 then
            if low_two_v = '1' then
                second_v(3 downto 0) := low_second_v;
            elsif low_any_v = '1' and high_any_v = '1' then
                second_v(7 downto 4) := high_first_v;
            elsif low_any_v = '0' and high_two_v = '1' then
                second_v(7 downto 4) := high_second_v;
            end if;
        end if;

        engine_first_allocate_c  <= first_v;
        engine_second_allocate_c <= second_v;
        engine_allocate_c        <= first_v or second_v;
    end process;

    -- Matched residuals still retire directly.  A granted miss is deliberately
    -- held unchanged here: the registered allocation packet owns that lane and
    -- applies its bounded subtract only when the append pipe accepts the cell.
    -- This removes CAM/grant logic from the active-count register input.
    progress_engine : process(all)
        variable next_valid_v : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
        variable next_count_v : batch_count_array_t(0 to ENGINE_WIDTH_CONST - 1);
    begin
        next_valid_v := (others => '1');
        next_count_v := engine_count_c;

        for descriptor_index in 0 to ENGINE_WIDTH_CONST - 1 loop
            if engine_has_match_c(descriptor_index) = '1' then
                next_count_v(descriptor_index) :=
                    engine_match_residual_c(descriptor_index);
                next_valid_v(descriptor_index) :=
                    engine_match_residual_valid_c(descriptor_index);
            end if;
        end loop;

        engine_next_valid_c      <= next_valid_v;
        engine_next_count_c      <= next_count_v;
    end process;

    -- The registered first and second masks are one-hot.  Mask-and-OR trees
    -- select from the allocation snapshot after the timing cut, so neither
    -- payload selection nor the bounded count conversion loads the CAM path.
    select_append_payloads : process(all)
        variable bank_first_terms_v  : std_logic_vector(7 downto 0);
        variable bank_second_terms_v : std_logic_vector(7 downto 0);
        variable bank_first_pair_v   : std_logic_vector(3 downto 0);
        variable bank_second_pair_v  : std_logic_vector(3 downto 0);
        variable bank_first_quad_v   : std_logic_vector(1 downto 0);
        variable bank_second_quad_v  : std_logic_vector(1 downto 0);
        variable bin_first_terms_v   : bin_array_t(0 to 7);
        variable bin_second_terms_v  : bin_array_t(0 to 7);
        variable bin_first_pair_v    : bin_array_t(0 to 3);
        variable bin_second_pair_v   : bin_array_t(0 to 3);
        variable bin_first_quad_v    : bin_array_t(0 to 1);
        variable bin_second_quad_v   : bin_array_t(0 to 1);
        variable count_first_terms_v : fixed_kick_array_t;
        variable count_second_terms_v : fixed_kick_array_t;
        variable count_first_pair_v  : kick_array_t(0 to 3);
        variable count_second_pair_v : kick_array_t(0 to 3);
        variable count_first_quad_v  : kick_array_t(0 to 1);
        variable count_second_quad_v : kick_array_t(0 to 1);
    begin
        bank_first_terms_v   := (others => '0');
        bank_second_terms_v  := (others => '0');
        bin_first_terms_v    := (others => (others => '0'));
        bin_second_terms_v   := (others => (others => '0'));
        count_first_terms_v  := (others => (others => '0'));
        count_second_terms_v := (others => (others => '0'));
        for descriptor_index in 0 to ENGINE_WIDTH_CONST - 1 loop
            if alloc_transfer_first_c(descriptor_index) = '1' then
                bank_first_terms_v(descriptor_index)  := miss_stage_bank_q(descriptor_index);
                bin_first_terms_v(descriptor_index)   := miss_stage_bin_q(descriptor_index);
                if miss_stage_count_q(descriptor_index) <=
                   to_unsigned(KICK_MAX_NAT_CONST, BATCH_COUNT_WIDTH_CONST) then
                    count_first_terms_v(descriptor_index) := resize(
                        miss_stage_count_q(descriptor_index),
                        KICK_WIDTH
                    );
                else
                    count_first_terms_v(descriptor_index) :=
                        to_unsigned(KICK_MAX_NAT_CONST, KICK_WIDTH);
                end if;
            end if;
            if alloc_transfer_second_c(descriptor_index) = '1' then
                bank_second_terms_v(descriptor_index)  := miss_stage_bank_q(descriptor_index);
                bin_second_terms_v(descriptor_index)   := miss_stage_bin_q(descriptor_index);
                if miss_stage_count_q(descriptor_index) <=
                   to_unsigned(KICK_MAX_NAT_CONST, BATCH_COUNT_WIDTH_CONST) then
                    count_second_terms_v(descriptor_index) := resize(
                        miss_stage_count_q(descriptor_index),
                        KICK_WIDTH
                    );
                else
                    count_second_terms_v(descriptor_index) :=
                        to_unsigned(KICK_MAX_NAT_CONST, KICK_WIDTH);
                end if;
            end if;
        end loop;

        for pair_index in 0 to 3 loop
            bank_first_pair_v(pair_index) :=
                bank_first_terms_v(2 * pair_index) or
                bank_first_terms_v(2 * pair_index + 1);
            bank_second_pair_v(pair_index) :=
                bank_second_terms_v(2 * pair_index) or
                bank_second_terms_v(2 * pair_index + 1);
            bin_first_pair_v(pair_index) :=
                bin_first_terms_v(2 * pair_index) or
                bin_first_terms_v(2 * pair_index + 1);
            bin_second_pair_v(pair_index) :=
                bin_second_terms_v(2 * pair_index) or
                bin_second_terms_v(2 * pair_index + 1);
            count_first_pair_v(pair_index) :=
                count_first_terms_v(2 * pair_index) or
                count_first_terms_v(2 * pair_index + 1);
            count_second_pair_v(pair_index) :=
                count_second_terms_v(2 * pair_index) or
                count_second_terms_v(2 * pair_index + 1);
        end loop;
        for quad_index in 0 to 1 loop
            bank_first_quad_v(quad_index) :=
                bank_first_pair_v(2 * quad_index) or
                bank_first_pair_v(2 * quad_index + 1);
            bank_second_quad_v(quad_index) :=
                bank_second_pair_v(2 * quad_index) or
                bank_second_pair_v(2 * quad_index + 1);
            bin_first_quad_v(quad_index) :=
                bin_first_pair_v(2 * quad_index) or
                bin_first_pair_v(2 * quad_index + 1);
            bin_second_quad_v(quad_index) :=
                bin_second_pair_v(2 * quad_index) or
                bin_second_pair_v(2 * quad_index + 1);
            count_first_quad_v(quad_index) :=
                count_first_pair_v(2 * quad_index) or
                count_first_pair_v(2 * quad_index + 1);
            count_second_quad_v(quad_index) :=
                count_second_pair_v(2 * quad_index) or
                count_second_pair_v(2 * quad_index + 1);
        end loop;

        append_first_bank_c   <= bank_first_quad_v(0) or bank_first_quad_v(1);
        append_first_bin_c    <= bin_first_quad_v(0) or bin_first_quad_v(1);
        append_first_count_c  <= count_first_quad_v(0) or count_first_quad_v(1);
        append_second_bank_c  <= bank_second_quad_v(0) or bank_second_quad_v(1);
        append_second_bin_c   <= bin_second_quad_v(0) or bin_second_quad_v(1);
        append_second_count_c <= count_second_quad_v(0) or count_second_quad_v(1);
    end process;

    -- A head match is folded into the counted cell captured by the elastic
    -- drain before a same-cycle append can reuse the physical ring slot.
    select_drain_count : process(all)
        variable count_v : kick_t;
    begin
        count_v := live_count_q(live_rd_ptr_q);
        if live_has_match_c(live_rd_ptr_q) = '1' then
            count_v := live_match_new_count_c(live_rd_ptr_q);
        end if;
        drain_load_count_c <= count_v;
    end process;

    -- Build the post-engine current-generation view.  Ordinary match lanes
    -- take their CAM result; allocation-owned lanes hold until transfer, then
    -- retire or retain the exact wide residual.  The grant network itself is
    -- absent from this register-input cone.
    active_after_engine_comb : process(all)
        variable valid_v : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
        variable count_v : batch_count_array_t(0 to WORK_CAPACITY_CONST - 1);
    begin
        valid_v := active_current_valid_c;
        count_v := active_count_q;

        for descriptor_index in 0 to WORK_CAPACITY_CONST - 1 loop
            if active_current_valid_c(descriptor_index) = '1' and
               miss_stage_valid_q(descriptor_index) = '0' then
                valid_v(descriptor_index) := engine_next_valid_c(descriptor_index);
                count_v(descriptor_index) := engine_next_count_c(descriptor_index);
            end if;

            if alloc_transfer_first_c(descriptor_index) = '1' or
               alloc_transfer_second_c(descriptor_index) = '1' then
                if miss_stage_count_q(descriptor_index) >
                   to_unsigned(KICK_MAX_NAT_CONST, BATCH_COUNT_WIDTH_CONST) then
                    valid_v(descriptor_index) := '1';
                    count_v(descriptor_index) :=
                        miss_stage_count_q(descriptor_index) -
                        to_unsigned(KICK_MAX_NAT_CONST, BATCH_COUNT_WIDTH_CONST);
                else
                    valid_v(descriptor_index) := '0';
                    count_v(descriptor_index) := (others => '0');
                end if;
            end if;
        end loop;

        active_after_engine_valid_c <= valid_v;
        active_after_engine_count_c <= count_v;
    end process;

    -- A same-generation pending descriptor delayed by the pre-edge-vacancy
    -- cut is still part of the current transaction.  Hold the generation
    -- until it promotes; otherwise the final active retirement could strand
    -- that descriptor behind the generation tag.
    engine_done_c <= '1' when work_any_c = '1' and
        pending_current_any_c = '0' and
        active_after_engine_valid_c =
            (active_after_engine_valid_c'range => '0') else '0';

    ring_next_comb : process(all)
        variable valid_v : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
        variable bank_v  : bank_array_t(0 to QUEUE_DEPTH - 1);
        variable bin_v   : bin_array_t(0 to QUEUE_DEPTH - 1);
        variable count_v : kick_array_t(0 to QUEUE_DEPTH - 1);
        variable open_v  : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
        variable level_v : integer range -1 to QUEUE_DEPTH + ENGINE_WIDTH_CONST;
        variable rd_v    : natural range 0 to QUEUE_DEPTH - 1;
        variable wr_v    : natural range 0 to QUEUE_DEPTH - 1;
    begin
        valid_v := live_valid_q;
        bank_v  := live_bank_q;
        bin_v   := live_bin_q;
        count_v := live_count_q;
        open_v  := live_open_q;
        level_v := live_level_q;
        rd_v    := live_rd_ptr_q;
        wr_v    := live_wr_ptr_q;

        if resident_to_drain_c = '1' then
            valid_v(live_rd_ptr_q) := '0';
            bank_v(live_rd_ptr_q)  := '0';
            bin_v(live_rd_ptr_q)   := (others => '0');
            count_v(live_rd_ptr_q) := (others => '0');
            open_v(live_rd_ptr_q)  := '0';
            rd_v := advance_ptr_f(live_rd_ptr_q, 1);
            level_v := level_v - 1;
        end if;

        for slot_index in 0 to QUEUE_DEPTH - 1 loop
            if live_has_match_c(slot_index) = '1' then
                count_v(slot_index) := live_match_new_count_c(slot_index);
                -- A retiring head has already been closed above.  Its matched
                -- count still feeds the drain, but only a later append may
                -- reopen the physical ring slot on this edge.
                if resident_to_drain_c = '0' or
                   slot_index /= live_rd_ptr_q then
                    open_v(slot_index) := live_match_new_open_c(slot_index);
                end if;
            end if;
        end loop;

        if append_commit_count_c >= 1 then
            valid_v(live_wr_ptr_q) := '1';
            bank_v(live_wr_ptr_q)  := append_first_bank_c;
            bin_v(live_wr_ptr_q)   := append_first_bin_c;
            count_v(live_wr_ptr_q) := append_first_count_c;
            open_v(live_wr_ptr_q)  := '0';
            if append_first_count_c <
               to_unsigned(KICK_MAX_NAT_CONST, KICK_WIDTH) then
                open_v(live_wr_ptr_q) := '1';
            end if;
        end if;
        if append_commit_count_c = 2 then
            valid_v(advance_ptr_f(live_wr_ptr_q, 1)) := '1';
            bank_v(advance_ptr_f(live_wr_ptr_q, 1))  := append_second_bank_c;
            bin_v(advance_ptr_f(live_wr_ptr_q, 1))   := append_second_bin_c;
            count_v(advance_ptr_f(live_wr_ptr_q, 1)) := append_second_count_c;
            open_v(advance_ptr_f(live_wr_ptr_q, 1))  := '0';
            if append_second_count_c <
               to_unsigned(KICK_MAX_NAT_CONST, KICK_WIDTH) then
                open_v(advance_ptr_f(live_wr_ptr_q, 1)) := '1';
            end if;
        end if;

        wr_v := advance_ptr_f(live_wr_ptr_q, append_commit_count_c);
        level_v := level_v + append_commit_count_c;

        live_valid_next_c <= valid_v;
        live_open_next_c  <= open_v;
        live_bank_next_c  <= bank_v;
        live_bin_next_c   <= bin_v;
        live_count_next_c <= count_v;
        if level_v < 0 then
            live_level_next_c <= 0;
        elsif level_v > QUEUE_DEPTH then
            live_level_next_c <= QUEUE_DEPTH;
        else
            live_level_next_c <= level_v;
        end if;
        live_rd_ptr_next_c <= rd_v;
        live_wr_ptr_next_c <= wr_v;
    end process;

    capture_raw : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                raw_batch_valid_q <= '0';
                raw_valid_q       <= (others => '0');
                raw_bank_q        <= (others => '0');
                raw_bin_q         <= (others => (others => '0'));
                raw_count_q       <= (others => (others => '0'));
            elsif raw_to_mask_fire_c = '1' then
                raw_batch_valid_q <= '0';
                raw_valid_q       <= (others => '0');
            elsif raw_ready_c = '1' then
                raw_batch_valid_q <= input_any_c;
                raw_valid_q       <= i_hit_valid;
                for input_index in 0 to N_INPUTS - 1 loop
                    raw_bank_q(input_index)  <= i_hit_bank(input_index);
                    raw_bin_q(input_index)   <= i_hit_bin(input_index);
                    raw_count_q(input_index) <= i_hit_count(input_index);
                end loop;
            end if;
        end if;
    end process;

    register_member_mask : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                mask_batch_valid_q <= '0';
                mask_leader_q      <= (others => '0');
                mask_member_q      <= (others => (others => '0'));
                mask_bank_q        <= (others => '0');
                mask_bin_q         <= (others => (others => '0'));
                mask_count_q       <= (others => (others => '0'));
            elsif raw_to_mask_fire_c = '1' then
                mask_batch_valid_q <= '1';
                mask_leader_q      <= mask_leader_c;
                mask_member_q      <= mask_member_c;
                mask_bank_q        <= raw_bank_q;
                mask_bin_q         <= raw_bin_q;
                mask_count_q       <= raw_count_q;
            elsif mask_to_group_fire_c = '1' then
                mask_batch_valid_q <= '0';
                mask_leader_q      <= (others => '0');
                mask_member_q      <= (others => (others => '0'));
            end if;
        end if;
    end process;

    register_group_batch : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                group_batch_valid_q <= '0';
                group_valid_q       <= (others => '0');
                group_bank_q        <= (others => '0');
                group_bin_q         <= (others => (others => '0'));
                group_count_q       <= (others => (others => '0'));
            elsif mask_to_group_fire_c = '1' then
                group_batch_valid_q <= '1';
                group_valid_q       <= reduced_valid_c;
                group_bank_q        <= reduced_bank_c;
                group_bin_q         <= reduced_bin_c;
                group_count_q       <= reduced_count_c;
            elsif group_to_pending_fire_c = '1' then
                group_batch_valid_q <= '0';
                group_valid_q       <= (others => '0');
            end if;
        end if;
    end process;

    -- Payload capture is deliberately independent of the active engine.  The
    -- held group may be sampled repeatedly while a future generation blocks
    -- admission; pending_valid_q is the sole visibility/occupancy contract.
    register_pending_payload : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                pending_bank_q  <= (others => '0');
                pending_bin_q   <= (others => (others => '0'));
                pending_count_q <= (others => (others => '0'));
                pending_gen_q   <= '0';
            elsif pending_payload_load_c = '1' then
                pending_bank_q  <= compact_group_bank_c;
                pending_bin_q   <= compact_group_bin_c;
                pending_count_q <= compact_group_count_c;
                if work_any_c = '1' then
                    pending_gen_q <= not current_gen_q;
                else
                    pending_gen_q <= current_gen_q;
                end if;
            end if;
        end if;
    end process;

    register_work_banks : process(i_clk)
        variable active_valid_v  : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
        variable active_gen_v    : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
        variable active_bank_v   : bank_array_t(0 to WORK_CAPACITY_CONST - 1);
        variable active_bin_v    : bin_array_t(0 to WORK_CAPACITY_CONST - 1);
        variable active_count_v  : batch_count_array_t(0 to WORK_CAPACITY_CONST - 1);
        variable pending_valid_v : std_logic_vector(WORK_CAPACITY_CONST - 1 downto 0);
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                active_valid_q  <= (others => '0');
                active_gen_q    <= (others => '0');
                active_bank_q   <= (others => '0');
                active_bin_q    <= (others => (others => '0'));
                active_count_q  <= (others => (others => '0'));
                pending_valid_q <= (others => '0');
                current_gen_q   <= '0';
            else
                active_valid_v  := active_valid_q;
                active_gen_v    := active_gen_q;
                active_bank_v   := active_bank_q;
                active_bin_v    := active_bin_q;
                active_count_v  := active_count_q;
                pending_valid_v := pending_valid_q;

                -- Retire current-generation descriptors independently.  A
                -- future-generation descriptor already resident in a slot is
                -- held verbatim until current_gen_q toggles.
                for descriptor_index in 0 to WORK_CAPACITY_CONST - 1 loop
                    if active_current_valid_c(descriptor_index) = '1' then
                        active_valid_v(descriptor_index) :=
                            active_after_engine_valid_c(descriptor_index);
                        active_count_v(descriptor_index) :=
                            active_after_engine_count_c(descriptor_index);
                        if active_after_engine_valid_c(descriptor_index) = '0' then
                            active_gen_v(descriptor_index)   := current_gen_q;
                        end if;
                    end if;
                end loop;

                -- Promote only into slots which were already vacant before
                -- this edge or retire through the registered allocation path.
                -- A slot retired by a CAM match waits one edge before accepting
                -- its pending payload; consequently CAM/match state cannot
                -- drive the wide active bank/bin register load enable.
                -- pending_gen_q preserves the batch generation across that
                -- bounded promotion delay, including a simultaneous toggle of
                -- current_gen_q on the final retirement edge.
                for descriptor_index in 0 to WORK_CAPACITY_CONST - 1 loop
                    if pending_valid_q(descriptor_index) = '1' and
                       payload_promotion_free_c(descriptor_index) = '1' then
                        active_valid_v(descriptor_index) := '1';
                        active_gen_v(descriptor_index) := pending_gen_q;
                        active_bank_v(descriptor_index) := pending_bank_q(descriptor_index);
                        active_bin_v(descriptor_index) := pending_bin_q(descriptor_index);
                        active_count_v(descriptor_index) := pending_count_q(descriptor_index);
                        pending_valid_v(descriptor_index) := '0';
                    end if;
                end loop;

                -- Only one future generation may exist.  A newly accepted
                -- group either occupies pre-edge-vacant active slots or stays
                -- at the matching pending indices until a later promotion
                -- edge.  Post-retirement vacancies are deliberately excluded
                -- from the payload-load decision for the same timing cut.
                if group_to_pending_fire_c = '1' then
                    pending_valid_v := (others => '0');
                    for descriptor_index in 0 to WORK_CAPACITY_CONST - 1 loop
                        if compact_group_valid_c(descriptor_index) = '1' then
                            if payload_promotion_free_c(descriptor_index) = '1' then
                                active_valid_v(descriptor_index) := '1';
                                if work_any_c = '1' then
                                    active_gen_v(descriptor_index) := not current_gen_q;
                                else
                                    active_gen_v(descriptor_index) := current_gen_q;
                                end if;
                                active_bank_v(descriptor_index) :=
                                    compact_group_bank_c(descriptor_index);
                                active_bin_v(descriptor_index) :=
                                    compact_group_bin_c(descriptor_index);
                                active_count_v(descriptor_index) :=
                                    compact_group_count_c(descriptor_index);
                            else
                                pending_valid_v(descriptor_index) := '1';
                            end if;
                        end if;
                    end loop;
                end if;

                if engine_done_c = '1' then
                    current_gen_q <= not current_gen_q;
                end if;

                active_valid_q  <= active_valid_v;
                active_gen_q    <= active_gen_v;
                active_bank_q   <= active_bank_v;
                active_bin_q    <= active_bin_v;
                active_count_q  <= active_count_v;
                pending_valid_q <= pending_valid_v;
            end if;
        end if;
    end process;

    -- The tagged CAM terminates here.  Miss ownership and all descriptor
    -- payloads are registered before any two-grant priority/credit logic, so
    -- the CAM result drives only this local bitmap register.  Existing staged
    -- misses hold until their one-hot grant commits into a ring vacancy.
    register_miss_stage : process(i_clk)
        variable valid_v : std_logic_vector(ENGINE_WIDTH_CONST - 1 downto 0);
        variable bank_v  : bank_array_t(0 to ENGINE_WIDTH_CONST - 1);
        variable bin_v   : bin_array_t(0 to ENGINE_WIDTH_CONST - 1);
        variable count_v : batch_count_array_t(0 to ENGINE_WIDTH_CONST - 1);
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                miss_stage_valid_q <= (others => '0');
                miss_stage_bank_q  <= (others => '0');
                miss_stage_bin_q   <= (others => (others => '0'));
                miss_stage_count_q <= (others => (others => '0'));
            else
                valid_v := miss_stage_valid_q;
                -- Snapshot every descriptor unconditionally.  Consequently
                -- the CAM/miss result drives only valid_v, never a wide
                -- payload-register enable.
                bank_v  := engine_bank_c;
                bin_v   := engine_bin_c;
                count_v := engine_count_c;

                for descriptor_index in 0 to ENGINE_WIDTH_CONST - 1 loop
                    if engine_allocate_c(descriptor_index) = '1' then
                        valid_v(descriptor_index) := '0';
                    end if;
                    if engine_miss_c(descriptor_index) = '1' then
                        valid_v(descriptor_index) := '1';
                    end if;
                end loop;

                miss_stage_valid_q <= valid_v;
                miss_stage_bank_q  <= bank_v;
                miss_stage_bin_q   <= bin_v;
                miss_stage_count_q <= count_v;
            end if;
        end if;
    end process;

    register_resident_and_drain : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                live_valid_q <= (others => '0');
                live_open_q  <= (others => '0');
                live_bank_q  <= (others => '0');
                live_bin_q   <= (others => (others => '0'));
                live_count_q <= (others => (others => '0'));
                live_level_q <= 0;
                live_rd_ptr_q <= 0;
                live_wr_ptr_q <= 0;
                drain_valid_q <= '0';
                drain_bank_q  <= '0';
                drain_bin_q   <= (others => '0');
                drain_count_q <= (others => '0');
            else
                live_valid_q <= live_valid_next_c;
                live_open_q  <= live_open_next_c;
                live_bank_q  <= live_bank_next_c;
                live_bin_q   <= live_bin_next_c;
                live_count_q <= live_count_next_c;
                live_level_q <= live_level_next_c;
                live_rd_ptr_q <= live_rd_ptr_next_c;
                live_wr_ptr_q <= live_wr_ptr_next_c;

                if drain_can_load_c = '1' then
                    if resident_to_drain_c = '1' then
                        drain_valid_q <= '1';
                        drain_bank_q  <= live_bank_q(live_rd_ptr_q);
                        drain_bin_q   <= live_bin_q(live_rd_ptr_q);
                        drain_count_q <= drain_load_count_c;
                    else
                        drain_valid_q <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    occupancy_comb : process(all)
        variable visible_v : natural range 0 to QUEUE_DEPTH + 8;
    begin
        visible_v := live_level_q;
        if drain_valid_q = '1' then
            visible_v := visible_v + 1;
        end if;
        if miss_stage_valid_q /= (miss_stage_valid_q'range => '0') then
            visible_v := visible_v + 1;
        end if;
        if active_any_c = '1' then
            visible_v := visible_v + 1;
        end if;
        if pending_any_c = '1' then
            visible_v := visible_v + 1;
        end if;
        if group_batch_valid_q = '1' then
            visible_v := visible_v + 1;
        end if;
        if mask_batch_valid_q = '1' then
            visible_v := visible_v + 1;
        end if;
        if raw_batch_valid_q = '1' then
            visible_v := visible_v + 1;
        end if;
        if visible_v > QUEUE_DEPTH then
            visible_v := QUEUE_DEPTH;
        end if;
        occupancy_visible_c <= to_unsigned(visible_v, OCC_WIDTH_CONST);
    end process;

    blocked_count_comb : process(all)
        variable terms_v : fixed_blocked_array_t;
        variable pair_v  : fixed_blocked_array_t;
        variable quad_v  : fixed_blocked_array_t;
    begin
        terms_v := (others => (others => '0'));
        if raw_ready_c = '0' then
            for input_index in 0 to N_INPUTS - 1 loop
                if i_hit_valid(input_index) = '1' then
                    terms_v(input_index) := to_unsigned(1, blocked_fixed_t'length);
                end if;
            end loop;
        end if;
        pair_v := (others => (others => '0'));
        pair_v(0) := terms_v(0) + terms_v(1);
        pair_v(1) := terms_v(2) + terms_v(3);
        pair_v(2) := terms_v(4) + terms_v(5);
        pair_v(3) := terms_v(6) + terms_v(7);
        quad_v := (others => (others => '0'));
        quad_v(0) := pair_v(0) + pair_v(1);
        quad_v(1) := pair_v(2) + pair_v(3);
        blocked_now_c <= resize(quad_v(0) + quad_v(1), BLOCKED_WIDTH_CONST);
    end process;

    register_statistics : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                occupancy_max_q  <= (others => '0');
                overflow_count_q <= (others => '0');
            else
                if occupancy_visible_c > occupancy_max_q then
                    occupancy_max_q <= occupancy_visible_c;
                end if;
                overflow_count_q <= sat_add(
                    overflow_count_q,
                    resize(blocked_now_c, OVERFLOW_WIDTH)
                );
            end if;
        end if;
    end process;

    -- synthesis translate_off
    assert_open_tag_uniqueness : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '0' and i_clear = '0' then
                for first_slot in 0 to QUEUE_DEPTH - 2 loop
                    for second_slot in first_slot + 1 to QUEUE_DEPTH - 1 loop
                        assert not (
                            live_valid_q(first_slot) = '1' and
                            live_open_q(first_slot) = '1' and
                            live_valid_q(second_slot) = '1' and
                            live_open_q(second_slot) = '1' and
                            live_bank_q(first_slot) = live_bank_q(second_slot) and
                            live_bin_q(first_slot) = live_bin_q(second_slot)
                        )
                            report "coalescing_queue found duplicate open live-cell tags"
                            severity failure;
                    end loop;
                end loop;
            end if;
        end if;
    end process;
    -- synthesis translate_on

    o_drain_valid    <= drain_valid_q;
    o_drain_bank     <= drain_bank_q;
    o_drain_bin      <= drain_bin_q;
    o_drain_count    <= drain_count_q;
    o_occupancy      <= occupancy_visible_c;
    o_occupancy_max  <= occupancy_max_q;
    o_overflow_count <= overflow_count_q;
    o_dbg_engine_has_match      <= engine_has_match_c;
    o_dbg_engine_miss           <= engine_miss_c;
    o_dbg_live_has_match        <= live_has_match_c;
    o_dbg_live_rd_ptr           <= live_rd_ptr_q;
    o_dbg_resident_to_drain     <= resident_to_drain_c;
    o_dbg_miss_stage_valid      <= miss_stage_valid_q;
    o_dbg_engine_allocate       <= engine_allocate_c;
    o_dbg_engine_allocate_count <= engine_allocate_count_c;
    o_dbg_append_commit_count   <= append_commit_count_c;
    o_dbg_free_cells            <= free_cells_c;

end architecture rtl;

-- altera vhdl_input_version vhdl_2008
-- Generic tagged counted coalescer for queue depths 4..256.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.histogram_statistics_v2_pkg.all;

entity coalescing_queue_deep is
    generic (
        N_BINS         : natural := 256;
        QUEUE_DEPTH    : natural := 32;
        KICK_WIDTH     : natural := 4;
        N_INPUTS       : natural := 8;
        OVERFLOW_WIDTH : natural := 16;
        CAM_PIPELINE_MODE   : string  := "AUTO";
        CAM_PIPELINE_STAGES : natural := 0
    );
    port (
        i_clk            : in  std_logic;
        i_rst            : in  std_logic;
        i_clear          : in  std_logic;

        i_hit_valid      : in  std_logic_vector(N_INPUTS - 1 downto 0);
        i_hit_bank       : in  std_logic_vector(N_INPUTS - 1 downto 0);
        i_hit_bin        : in  hs_unsigned_array_t(0 to N_INPUTS - 1)(clog2(N_BINS) - 1 downto 0);
        i_hit_count      : in  hs_unsigned_array_t(0 to N_INPUTS - 1)(KICK_WIDTH - 1 downto 0);
        o_hit_accept     : out std_logic_vector(N_INPUTS - 1 downto 0);

        i_drain_ready    : in  std_logic;
        o_drain_valid    : out std_logic;
        o_drain_bank     : out std_logic;
        o_drain_bin      : out unsigned(clog2(N_BINS) - 1 downto 0);
        o_drain_count    : out unsigned(KICK_WIDTH - 1 downto 0);

        o_occupancy      : out unsigned(clog2(QUEUE_DEPTH + 1) - 1 downto 0);
        o_occupancy_max  : out unsigned(clog2(QUEUE_DEPTH + 1) - 1 downto 0);
        o_overflow_count : out unsigned(OVERFLOW_WIDTH - 1 downto 0);

        -- Private wrapper-forwarded commit evidence.  These do not alter the
        -- public coalescing_queue interface.
        o_dbg_commit_pulse                  : out std_logic;
        o_dbg_matched_resident_update_pulse : out std_logic;
        o_dbg_resident_head_pop_pulse       : out std_logic;
        o_dbg_append_pulse                  : out std_logic
    );
end entity coalescing_queue_deep;

architecture rtl of coalescing_queue_deep is

    constant BIN_WIDTH_CONST       : positive := clog2(N_BINS);
    constant OCC_WIDTH_CONST       : positive := clog2(QUEUE_DEPTH + 1);
    constant KICK_MAX_NAT_CONST    : natural := (2 ** KICK_WIDTH) - 1;
    constant WORK_COUNT_MAX_CONST  : natural := N_INPUTS * KICK_MAX_NAT_CONST;
    constant WORK_COUNT_WIDTH_CONST : positive := clog2(WORK_COUNT_MAX_CONST + 1);
    constant CAM_GROUP_SIZE_CONST  : positive := 31;
    constant CAM_GROUPS_CONST      : positive :=
        (QUEUE_DEPTH + CAM_GROUP_SIZE_CONST - 1) / CAM_GROUP_SIZE_CONST;
    constant CAM_INDEX_WIDTH_CONST : positive := clog2(QUEUE_DEPTH);

    function resolve_cam_stages_f(
        mode_value  : string;
        stage_value : natural;
        depth_value : natural
    ) return natural is
    begin
        if mode_value = "AUTO" then
            if depth_value <= CAM_GROUP_SIZE_CONST then
                return 0;
            elsif depth_value <= 63 then
                return 1;
            end if;
            return 2;
        end if;
        return stage_value;
    end function;

    constant CAM_PIPELINE_STAGES_EFFECTIVE_CONST : natural :=
        resolve_cam_stages_f(CAM_PIPELINE_MODE, CAM_PIPELINE_STAGES, QUEUE_DEPTH);

    subtype bin_t        is unsigned(BIN_WIDTH_CONST - 1 downto 0);
    subtype kick_t       is unsigned(KICK_WIDTH - 1 downto 0);
    subtype work_count_t is unsigned(WORK_COUNT_WIDTH_CONST - 1 downto 0);
    subtype occupancy_t  is unsigned(OCC_WIDTH_CONST - 1 downto 0);
    subtype cam_index_t  is unsigned(CAM_INDEX_WIDTH_CONST - 1 downto 0);

    type bin_array_t        is array (natural range <>) of bin_t;
    type kick_array_t       is array (natural range <>) of kick_t;
    type work_count_array_t is array (natural range <>) of work_count_t;
    type bank_array_t       is array (natural range <>) of std_logic;
    type lane_mask_array_t  is array (natural range <>) of
        std_logic_vector(N_INPUTS - 1 downto 0);
    type group_slot_array_t is array (0 to CAM_GROUPS_CONST - 1) of
        natural range 0 to QUEUE_DEPTH - 1;
    type cam_index_array_32_t is array (0 to 31) of cam_index_t;
    type cam_index_array_16_t is array (0 to 15) of cam_index_t;
    type cam_index_array_8_t  is array (0 to 7) of cam_index_t;
    type cam_index_array_4_t  is array (0 to 3) of cam_index_t;
    type cam_index_array_2_t  is array (0 to 1) of cam_index_t;

    type state_t is (
        STATE_IDLE,
        STATE_CLASSIFY,
        STATE_BUILD_WORK,
        STATE_DISPATCH,
        STATE_CAM_GROUP,
        STATE_CAM_GLOBAL,
        STATE_CAM_FINAL,
        STATE_MATCH_CAPTURE,
        STATE_MATCH_READ,
        STATE_COMMIT_PLAN,
        STATE_COMMIT_SCHEDULE,
        STATE_COMMIT_APPLY
    );

    function advance_ptr_f(ptr_value : natural; steps : natural) return natural is
        variable result_v : natural range 0 to QUEUE_DEPTH - 1 := ptr_value;
    begin
        for step_index in 1 to steps loop
            if result_v = QUEUE_DEPTH - 1 then
                result_v := 0;
            else
                result_v := result_v + 1;
            end if;
        end loop;
        return result_v;
    end function;

    -- Balanced eight-leaf reduction used by the first-lane leader detector.
    function reduce_or8_f(value : std_logic_vector(7 downto 0)) return std_logic is
        variable pair_v : std_logic_vector(3 downto 0);
        variable quad_v : std_logic_vector(1 downto 0);
    begin
        pair_v(0) := value(0) or value(1);
        pair_v(1) := value(2) or value(3);
        pair_v(2) := value(4) or value(5);
        pair_v(3) := value(6) or value(7);
        quad_v(0) := pair_v(0) or pair_v(1);
        quad_v(1) := pair_v(2) or pair_v(3);
        return quad_v(0) or quad_v(1);
    end function;

    -- Sum all members of one equality group through a fixed 8->4->2->1
    -- tree.  WORK_COUNT_WIDTH_CONST represents the full legal eight-lane
    -- total, so every intermediate uses the same lossless width.
    function sum_group_members_f(
        member_mask : std_logic_vector(N_INPUTS - 1 downto 0);
        count_value : work_count_array_t(0 to N_INPUTS - 1)
    ) return work_count_t is
        variable leaf_v : work_count_array_t(0 to 7);
        variable pair_v : work_count_array_t(0 to 3);
        variable quad_v : work_count_array_t(0 to 1);
    begin
        leaf_v := (others => (others => '0'));
        for lane_index in 0 to N_INPUTS - 1 loop
            if member_mask(lane_index) = '1' then
                leaf_v(lane_index) := count_value(lane_index);
            end if;
        end loop;

        for pair_index in 0 to 3 loop
            pair_v(pair_index) := leaf_v(2 * pair_index) +
                                  leaf_v(2 * pair_index + 1);
        end loop;
        quad_v(0) := pair_v(0) + pair_v(1);
        quad_v(1) := pair_v(2) + pair_v(3);
        return quad_v(0) + quad_v(1);
    end function;

    -- The open-tag invariant makes both the local and global candidate sets
    -- one-hot.  A padded 16-leaf OR tree therefore selects the slot index
    -- without a serial priority chain; bitwise OR is a one-hot multiplexer.
    procedure reduce_group_candidates_p(
        constant hit_value  : in  std_logic_vector(CAM_GROUPS_CONST - 1 downto 0);
        constant slot_value : in  group_slot_array_t;
        variable hit_result : out std_logic;
        variable slot_result : out natural
    ) is
        variable hit16_v : std_logic_vector(15 downto 0);
        variable hit8_v  : std_logic_vector(7 downto 0);
        variable hit4_v  : std_logic_vector(3 downto 0);
        variable hit2_v  : std_logic_vector(1 downto 0);
        variable index16_v : cam_index_array_16_t;
        variable index8_v  : cam_index_array_8_t;
        variable index4_v  : cam_index_array_4_t;
        variable index2_v  : cam_index_array_2_t;
        variable final_index_v : cam_index_t;
    begin
        hit16_v   := (others => '0');
        index16_v := (others => (others => '0'));
        for group_index in 0 to CAM_GROUPS_CONST - 1 loop
            hit16_v(group_index) := hit_value(group_index);
            if hit_value(group_index) = '1' then
                index16_v(group_index) :=
                    to_unsigned(slot_value(group_index), CAM_INDEX_WIDTH_CONST);
            end if;
        end loop;

        for pair_index in 0 to 7 loop
            hit8_v(pair_index) := hit16_v(2 * pair_index) or
                                  hit16_v(2 * pair_index + 1);
            index8_v(pair_index) := index16_v(2 * pair_index) or
                                    index16_v(2 * pair_index + 1);
        end loop;
        for pair_index in 0 to 3 loop
            hit4_v(pair_index) := hit8_v(2 * pair_index) or
                                  hit8_v(2 * pair_index + 1);
            index4_v(pair_index) := index8_v(2 * pair_index) or
                                    index8_v(2 * pair_index + 1);
        end loop;
        for pair_index in 0 to 1 loop
            hit2_v(pair_index) := hit4_v(2 * pair_index) or
                                  hit4_v(2 * pair_index + 1);
            index2_v(pair_index) := index4_v(2 * pair_index) or
                                    index4_v(2 * pair_index + 1);
        end loop;
        hit_result := hit2_v(0) or hit2_v(1);
        final_index_v := index2_v(0) or index2_v(1);
        slot_result := to_integer(final_index_v);
    end procedure;

    signal state_q : state_t := STATE_IDLE;

    -- Accepted lanes are frozen before any cross-lane equality or count
    -- reduction.  This removes the previous FIFO-to-work nested compaction
    -- cone while retaining atomic all-lane acceptance.
    signal raw_valid_q : std_logic_vector(N_INPUTS - 1 downto 0) := (others => '0');
    signal raw_bank_q  : bank_array_t(0 to N_INPUTS - 1) := (others => '0');
    signal raw_bin_q   : bin_array_t(0 to N_INPUTS - 1) := (others => (others => '0'));
    signal raw_count_q : work_count_array_t(0 to N_INPUTS - 1) :=
        (others => (others => '0'));

    signal raw_leader_c       : std_logic_vector(N_INPUTS - 1 downto 0);
    signal raw_member_mask_c  : lane_mask_array_t(0 to N_INPUTS - 1);
    signal group_valid_q      : std_logic_vector(N_INPUTS - 1 downto 0) :=
        (others => '0');
    signal group_member_mask_q : lane_mask_array_t(0 to N_INPUTS - 1) :=
        (others => (others => '0'));
    signal group_count_c : work_count_array_t(0 to N_INPUTS - 1);

    signal work_valid_q : std_logic_vector(N_INPUTS - 1 downto 0) := (others => '0');
    signal work_bank_q  : bank_array_t(0 to N_INPUTS - 1) := (others => '0');
    signal work_bin_q   : bin_array_t(0 to N_INPUTS - 1) := (others => (others => '0'));
    signal work_count_q : work_count_array_t(0 to N_INPUTS - 1) :=
        (others => (others => '0'));
    signal work_any_c   : std_logic;

    signal lookup_bank_q       : std_logic := '0';
    signal lookup_bin_q        : bin_t := (others => '0');
    signal lookup_count_q      : work_count_t := (others => '0');

    signal live_valid_q : std_logic_vector(QUEUE_DEPTH - 1 downto 0) := (others => '0');
    signal live_open_q  : std_logic_vector(QUEUE_DEPTH - 1 downto 0) := (others => '0');
    signal live_bank_q  : bank_array_t(0 to QUEUE_DEPTH - 1) := (others => '0');
    signal live_bin_q   : bin_array_t(0 to QUEUE_DEPTH - 1) :=
        (others => (others => '0'));
    signal live_count_q : kick_array_t(0 to QUEUE_DEPTH - 1) :=
        (others => (others => '0'));
    signal live_level_q  : natural range 0 to QUEUE_DEPTH := 0;
    signal live_rd_ptr_q : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal live_wr_ptr_q : natural range 0 to QUEUE_DEPTH - 1 := 0;

    signal cam_group_hit_c  : std_logic_vector(CAM_GROUPS_CONST - 1 downto 0);
    signal cam_group_slot_c : group_slot_array_t;
    signal cam_match_bits_c : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
    signal cam_group_hit_q  : std_logic_vector(CAM_GROUPS_CONST - 1 downto 0) :=
        (others => '0');
    signal cam_group_slot_q : group_slot_array_t := (others => 0);
    signal cam_direct_hit_c  : std_logic;
    signal cam_direct_slot_c : natural range 0 to QUEUE_DEPTH - 1;
    signal cam_group_winner_hit_c  : std_logic;
    signal cam_group_winner_slot_c : natural range 0 to QUEUE_DEPTH - 1;
    signal cam_global_hit_q  : std_logic := '0';
    signal cam_global_slot_q : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal cam_final_hit_q   : std_logic := '0';
    signal cam_final_slot_q  : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal cam_selected_hit_c  : std_logic;
    signal cam_selected_slot_c : natural range 0 to QUEUE_DEPTH - 1;

    -- The generic backend deliberately separates tag selection, indexed
    -- resident read, count arithmetic, and physical storage mutation.  This
    -- prevents a CAM-selected slot from feeding both an indexed write and the
    -- same-edge drain payload through one combinational cone.
    signal match_candidate_hit_q  : std_logic := '0';
    signal match_candidate_slot_q : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal match_valid_q          : std_logic := '0';
    signal match_slot_q           : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal match_count_q          : kick_t := (others => '0');

    signal plan_match_q       : std_logic := '0';
    signal plan_match_head_q  : std_logic := '0';
    signal plan_match_slot_q  : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal plan_match_count_q : kick_t := (others => '0');
    signal plan_match_open_q  : std_logic := '0';
    signal plan_remaining_q   : work_count_t := (others => '0');

    -- All storage actions are decoded one cycle before mutation.  The three
    -- one-hot masks intentionally retain match -> pop -> append priority when
    -- a full-ring head slot is updated, retired, and reused on one edge.
    signal storage_apply_q       : std_logic := '0';
    signal storage_is_commit_q   : std_logic := '0';
    signal storage_match_q       : std_logic := '0';
    signal storage_pop_q         : std_logic := '0';
    signal storage_append_q      : std_logic := '0';
    signal storage_match_mask_q  : std_logic_vector(QUEUE_DEPTH - 1 downto 0) :=
        (others => '0');
    signal storage_pop_mask_q    : std_logic_vector(QUEUE_DEPTH - 1 downto 0) :=
        (others => '0');
    signal storage_append_mask_q : std_logic_vector(QUEUE_DEPTH - 1 downto 0) :=
        (others => '0');

    signal storage_match_count_q : kick_t := (others => '0');
    signal storage_match_open_q  : std_logic := '0';
    signal storage_append_bank_q : std_logic := '0';
    signal storage_append_bin_q  : bin_t := (others => '0');
    signal storage_append_count_q : kick_t := (others => '0');
    signal storage_append_open_q  : std_logic := '0';
    signal storage_drain_bank_q   : std_logic := '0';
    signal storage_drain_bin_q    : bin_t := (others => '0');
    signal storage_drain_count_q  : kick_t := (others => '0');
    signal storage_level_next_q   : natural range 0 to QUEUE_DEPTH := 0;
    signal storage_rd_ptr_next_q  : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal storage_wr_ptr_next_q  : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal storage_residual_q     : work_count_t := (others => '0');

    signal input_any_c   : std_logic;
    signal input_ready_c : std_logic;
    signal drain_can_load_c : std_logic;

    signal drain_valid_q : std_logic := '0';
    signal drain_bank_q  : std_logic := '0';
    signal drain_bin_q   : bin_t := (others => '0');
    signal drain_count_q : kick_t := (others => '0');

    signal occupancy_visible_c : occupancy_t;
    signal occupancy_max_q     : occupancy_t := (others => '0');
    signal overflow_count_q    : unsigned(OVERFLOW_WIDTH - 1 downto 0) :=
        (others => '0');

    signal commit_pulse_q                  : std_logic := '0';
    signal matched_resident_update_pulse_q : std_logic := '0';
    signal resident_head_pop_pulse_q       : std_logic := '0';
    signal append_pulse_q                  : std_logic := '0';

begin

    assert N_INPUTS >= 1 and N_INPUTS <= 8
        report "coalescing_queue_deep supports one through eight inputs"
        severity failure;
    assert QUEUE_DEPTH >= 4 and QUEUE_DEPTH <= 256
        report "coalescing_queue_deep supports queue depth 4 through 256"
        severity failure;
    assert KICK_WIDTH >= 1
        report "coalescing_queue_deep requires KICK_WIDTH >= 1"
        severity failure;
    assert CAM_PIPELINE_MODE = "AUTO" or CAM_PIPELINE_MODE = "EXPLICIT"
        report "CAM_PIPELINE_MODE must be AUTO or EXPLICIT"
        severity failure;
    assert CAM_PIPELINE_STAGES_EFFECTIVE_CONST <= 3
        report "coalescing_queue_deep supports zero through three CAM stages"
        severity failure;

    input_any_comb : process(all)
        variable any_v : std_logic;
    begin
        any_v := '0';
        for input_index in 0 to N_INPUTS - 1 loop
            any_v := any_v or i_hit_valid(input_index);
        end loop;
        input_any_c <= any_v;
    end process;

    work_any_c <= '0' when work_valid_q = (work_valid_q'range => '0') else '1';

    -- A lane is a leader only when no lower-index valid lane has the same
    -- (bank,bin) tag.  Member masks remain indexed by original lane, avoiding
    -- the timing and ordering cost of compacting leaders into new positions.
    classify_raw_comb : process(all)
        variable leader_v       : std_logic_vector(N_INPUTS - 1 downto 0);
        variable member_mask_v  : lane_mask_array_t(0 to N_INPUTS - 1);
        variable prior_equal_v  : std_logic_vector(7 downto 0);
        variable tags_equal_v   : boolean;
    begin
        leader_v      := (others => '0');
        member_mask_v := (others => (others => '0'));

        for leader_index in 0 to N_INPUTS - 1 loop
            prior_equal_v := (others => '0');
            for member_index in 0 to N_INPUTS - 1 loop
                tags_equal_v :=
                    raw_valid_q(leader_index) = '1' and
                    raw_valid_q(member_index) = '1' and
                    raw_bank_q(leader_index) = raw_bank_q(member_index) and
                    raw_bin_q(leader_index) = raw_bin_q(member_index);
                if tags_equal_v then
                    member_mask_v(leader_index)(member_index) := '1';
                    if member_index < leader_index then
                        prior_equal_v(member_index) := '1';
                    end if;
                end if;
            end loop;

            if raw_valid_q(leader_index) = '1' and
               reduce_or8_f(prior_equal_v) = '0' then
                leader_v(leader_index) := '1';
            else
                member_mask_v(leader_index) := (others => '0');
            end if;
        end loop;

        raw_leader_c      <= leader_v;
        raw_member_mask_c <= member_mask_v;
    end process;

    balanced_group_count_gen : for leader_index in 0 to N_INPUTS - 1 generate
        group_count_c(leader_index) <= sum_group_members_f(
            group_member_mask_q(leader_index),
            raw_count_q
        );
    end generate;

    -- If residents exist while the elastic output is empty, reserve one idle
    -- edge to prefetch the head.  The following source acceptance may then
    -- overlap output consumption and a same-edge resident replacement.
    input_ready_c <= '1' when state_q = STATE_IDLE and work_any_c = '0' and
                              storage_apply_q = '0' and
                              (drain_valid_q = '1' or live_level_q = 0) and
                              i_rst = '0' and i_clear = '0' else '0';
    drain_can_load_c <= (not drain_valid_q) or i_drain_ready;

    accept_gen : for input_index in 0 to N_INPUTS - 1 generate
        o_hit_accept(input_index) <= i_hit_valid(input_index) and input_ready_c;
    end generate;

    -- Every slot performs its equality comparison independently.  There is no
    -- match-dependent loop-carried state: the CAM is a bank of parallel tag
    -- comparators whose one-hot results feed balanced OR trees below.
    cam_match_gen : for slot_index in 0 to QUEUE_DEPTH - 1 generate
        cam_match_bits_c(slot_index) <= '1' when
            live_valid_q(slot_index) = '1' and
            live_open_q(slot_index) = '1' and
            live_bank_q(slot_index) = lookup_bank_q and
            live_bin_q(slot_index) = lookup_bin_q else '0';
    end generate;

    -- Each local tree has 32 padded leaves, of which at most 31 are live.
    -- AUTO depths 32..63 register the local results; depths 64..256 also
    -- register the global winner, matching the fitted Arria-V timing map.
    reduce_local_cam_groups : process(all)
        variable hit_v  : std_logic_vector(CAM_GROUPS_CONST - 1 downto 0);
        variable slot_v : group_slot_array_t;
        variable hit32_v : std_logic_vector(31 downto 0);
        variable hit16_v : std_logic_vector(15 downto 0);
        variable hit8_v  : std_logic_vector(7 downto 0);
        variable hit4_v  : std_logic_vector(3 downto 0);
        variable hit2_v  : std_logic_vector(1 downto 0);
        variable index32_v : cam_index_array_32_t;
        variable index16_v : cam_index_array_16_t;
        variable index8_v  : cam_index_array_8_t;
        variable index4_v  : cam_index_array_4_t;
        variable index2_v  : cam_index_array_2_t;
        variable final_index_v : cam_index_t;
        variable absolute_index_v : natural;
    begin
        hit_v  := (others => '0');
        slot_v := (others => 0);

        for group_index in 0 to CAM_GROUPS_CONST - 1 loop
            hit32_v   := (others => '0');
            index32_v := (others => (others => '0'));
            for local_index in 0 to CAM_GROUP_SIZE_CONST - 1 loop
                absolute_index_v :=
                    group_index * CAM_GROUP_SIZE_CONST + local_index;
                if absolute_index_v < QUEUE_DEPTH then
                    hit32_v(local_index) := cam_match_bits_c(absolute_index_v);
                    if cam_match_bits_c(absolute_index_v) = '1' then
                        index32_v(local_index) := to_unsigned(
                            absolute_index_v,
                            CAM_INDEX_WIDTH_CONST
                        );
                    end if;
                end if;
            end loop;

            for pair_index in 0 to 15 loop
                hit16_v(pair_index) := hit32_v(2 * pair_index) or
                                       hit32_v(2 * pair_index + 1);
                index16_v(pair_index) := index32_v(2 * pair_index) or
                                         index32_v(2 * pair_index + 1);
            end loop;
            for pair_index in 0 to 7 loop
                hit8_v(pair_index) := hit16_v(2 * pair_index) or
                                      hit16_v(2 * pair_index + 1);
                index8_v(pair_index) := index16_v(2 * pair_index) or
                                        index16_v(2 * pair_index + 1);
            end loop;
            for pair_index in 0 to 3 loop
                hit4_v(pair_index) := hit8_v(2 * pair_index) or
                                      hit8_v(2 * pair_index + 1);
                index4_v(pair_index) := index8_v(2 * pair_index) or
                                        index8_v(2 * pair_index + 1);
            end loop;
            for pair_index in 0 to 1 loop
                hit2_v(pair_index) := hit4_v(2 * pair_index) or
                                      hit4_v(2 * pair_index + 1);
                index2_v(pair_index) := index4_v(2 * pair_index) or
                                        index4_v(2 * pair_index + 1);
            end loop;
            hit_v(group_index) := hit2_v(0) or hit2_v(1);
            final_index_v := index2_v(0) or index2_v(1);
            slot_v(group_index) := to_integer(final_index_v);
        end loop;

        cam_group_hit_c  <= hit_v;
        cam_group_slot_c <= slot_v;
    end process;

    select_direct_group : process(all)
        variable hit_v  : std_logic;
        variable slot_v : natural range 0 to QUEUE_DEPTH - 1;
    begin
        reduce_group_candidates_p(
            cam_group_hit_c,
            cam_group_slot_c,
            hit_v,
            slot_v
        );
        cam_direct_hit_c  <= hit_v;
        cam_direct_slot_c <= slot_v;
    end process;

    select_registered_group : process(all)
        variable hit_v  : std_logic;
        variable slot_v : natural range 0 to QUEUE_DEPTH - 1;
    begin
        reduce_group_candidates_p(
            cam_group_hit_q,
            cam_group_slot_q,
            hit_v,
            slot_v
        );
        cam_group_winner_hit_c  <= hit_v;
        cam_group_winner_slot_c <= slot_v;
    end process;

    select_effective_result : process(all)
    begin
        cam_selected_hit_c  <= '0';
        cam_selected_slot_c <= 0;
        if CAM_PIPELINE_STAGES_EFFECTIVE_CONST = 0 then
            cam_selected_hit_c  <= cam_direct_hit_c;
            cam_selected_slot_c <= cam_direct_slot_c;
        elsif CAM_PIPELINE_STAGES_EFFECTIVE_CONST = 1 then
            cam_selected_hit_c  <= cam_group_winner_hit_c;
            cam_selected_slot_c <= cam_group_winner_slot_c;
        elsif CAM_PIPELINE_STAGES_EFFECTIVE_CONST = 2 then
            cam_selected_hit_c  <= cam_global_hit_q;
            cam_selected_slot_c <= cam_global_slot_q;
        else
            cam_selected_hit_c  <= cam_final_hit_q;
            cam_selected_slot_c <= cam_final_slot_q;
        end if;
    end process;

    occupancy_comb : process(all)
        variable visible_v : natural range 0 to QUEUE_DEPTH + 2;
    begin
        visible_v := live_level_q;
        if drain_valid_q = '1' then
            visible_v := visible_v + 1;
        end if;
        if work_any_c = '1' or state_q /= STATE_IDLE then
            visible_v := visible_v + 1;
        end if;
        if visible_v > QUEUE_DEPTH then
            visible_v := QUEUE_DEPTH;
        end if;
        occupancy_visible_c <= to_unsigned(visible_v, OCC_WIDTH_CONST);
    end process;

    state_and_storage : process(i_clk)
        variable live_valid_v : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
        variable live_open_v  : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
        variable live_bank_v  : bank_array_t(0 to QUEUE_DEPTH - 1);
        variable live_bin_v   : bin_array_t(0 to QUEUE_DEPTH - 1);
        variable live_count_v : kick_array_t(0 to QUEUE_DEPTH - 1);
        variable level_v      : natural range 0 to QUEUE_DEPTH;
        variable rd_ptr_v     : natural range 0 to QUEUE_DEPTH - 1;
        variable wr_ptr_v     : natural range 0 to QUEUE_DEPTH - 1;

        variable work_valid_v : std_logic_vector(N_INPUTS - 1 downto 0);
        variable work_bank_v  : bank_array_t(0 to N_INPUTS - 1);
        variable work_bin_v   : bin_array_t(0 to N_INPUTS - 1);
        variable work_count_v : work_count_array_t(0 to N_INPUTS - 1);

        variable drain_valid_v : std_logic;
        variable drain_bank_v  : std_logic;
        variable drain_bin_v   : bin_t;
        variable drain_count_v : kick_t;

        variable descriptor_found_v : boolean;
        variable descriptor_index_v : natural range 0 to N_INPUTS - 1;
        variable remaining_v         : natural range 0 to WORK_COUNT_MAX_CONST;
        variable capacity_v          : natural range 0 to KICK_MAX_NAT_CONST;
        variable updated_count_v     : natural range 0 to KICK_MAX_NAT_CONST;
        variable append_count_v      : natural range 0 to KICK_MAX_NAT_CONST;
        variable progress_v          : boolean;
        variable pop_will_v          : boolean;
        variable matched_head_pop_v  : boolean;
        variable storage_level_v     : natural range 0 to QUEUE_DEPTH;
        variable storage_rd_ptr_v    : natural range 0 to QUEUE_DEPTH - 1;
        variable storage_wr_ptr_v    : natural range 0 to QUEUE_DEPTH - 1;
        variable storage_match_mask_v : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
        variable storage_pop_mask_v   : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
        variable storage_append_mask_v : std_logic_vector(QUEUE_DEPTH - 1 downto 0);

        variable blocked_lanes_v : natural range 0 to N_INPUTS;
        variable overflow_sum_v  : unsigned(OVERFLOW_WIDTH downto 0);
        variable overflow_v      : unsigned(OVERFLOW_WIDTH - 1 downto 0);
        variable occupancy_max_v : occupancy_t;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                state_q <= STATE_IDLE;
                raw_valid_q <= (others => '0');
                raw_bank_q  <= (others => '0');
                raw_bin_q   <= (others => (others => '0'));
                raw_count_q <= (others => (others => '0'));
                group_valid_q <= (others => '0');
                group_member_mask_q <= (others => (others => '0'));
                work_valid_q <= (others => '0');
                work_bank_q  <= (others => '0');
                work_bin_q   <= (others => (others => '0'));
                work_count_q <= (others => (others => '0'));
                lookup_bank_q  <= '0';
                lookup_bin_q   <= (others => '0');
                lookup_count_q <= (others => '0');

                live_valid_q <= (others => '0');
                live_open_q  <= (others => '0');
                live_bank_q  <= (others => '0');
                live_bin_q   <= (others => (others => '0'));
                live_count_q <= (others => (others => '0'));
                live_level_q  <= 0;
                live_rd_ptr_q <= 0;
                live_wr_ptr_q <= 0;

                cam_group_hit_q  <= (others => '0');
                cam_group_slot_q <= (others => 0);
                cam_global_hit_q  <= '0';
                cam_global_slot_q <= 0;
                cam_final_hit_q   <= '0';
                cam_final_slot_q  <= 0;

                match_candidate_hit_q  <= '0';
                match_candidate_slot_q <= 0;
                match_valid_q          <= '0';
                match_slot_q           <= 0;
                match_count_q          <= (others => '0');

                plan_match_q       <= '0';
                plan_match_head_q  <= '0';
                plan_match_slot_q  <= 0;
                plan_match_count_q <= (others => '0');
                plan_match_open_q  <= '0';
                plan_remaining_q   <= (others => '0');

                storage_apply_q       <= '0';
                storage_is_commit_q   <= '0';
                storage_match_q       <= '0';
                storage_pop_q         <= '0';
                storage_append_q      <= '0';
                storage_match_mask_q  <= (others => '0');
                storage_pop_mask_q    <= (others => '0');
                storage_append_mask_q <= (others => '0');
                storage_match_count_q <= (others => '0');
                storage_match_open_q  <= '0';
                storage_append_bank_q <= '0';
                storage_append_bin_q  <= (others => '0');
                storage_append_count_q <= (others => '0');
                storage_append_open_q  <= '0';
                storage_drain_bank_q  <= '0';
                storage_drain_bin_q   <= (others => '0');
                storage_drain_count_q <= (others => '0');
                storage_level_next_q  <= 0;
                storage_rd_ptr_next_q <= 0;
                storage_wr_ptr_next_q <= 0;
                storage_residual_q    <= (others => '0');

                drain_valid_q <= '0';
                drain_bank_q  <= '0';
                drain_bin_q   <= (others => '0');
                drain_count_q <= (others => '0');
                occupancy_max_q  <= (others => '0');
                overflow_count_q <= (others => '0');
                commit_pulse_q                  <= '0';
                matched_resident_update_pulse_q <= '0';
                resident_head_pop_pulse_q       <= '0';
                append_pulse_q                  <= '0';
            else
                commit_pulse_q                  <= '0';
                matched_resident_update_pulse_q <= '0';
                resident_head_pop_pulse_q       <= '0';
                append_pulse_q                  <= '0';

                live_valid_v := live_valid_q;
                live_open_v  := live_open_q;
                live_bank_v  := live_bank_q;
                live_bin_v   := live_bin_q;
                live_count_v := live_count_q;
                level_v      := live_level_q;
                rd_ptr_v     := live_rd_ptr_q;
                wr_ptr_v     := live_wr_ptr_q;

                work_valid_v := work_valid_q;
                work_bank_v  := work_bank_q;
                work_bin_v   := work_bin_q;
                work_count_v := work_count_q;

                drain_valid_v := drain_valid_q;
                drain_bank_v  := drain_bank_q;
                drain_bin_v   := drain_bin_q;
                drain_count_v := drain_count_q;
                if drain_valid_q = '1' and i_drain_ready = '1' then
                    drain_valid_v := '0';
                end if;

                -- Apply only registered, per-slot storage controls here.  No
                -- live-level or CAM decision feeds the physical live arrays
                -- on this edge.  Assignment order is the architectural
                -- match -> pop -> append priority used for full-ring reuse.
                if storage_apply_q = '1' then
                    for slot_index in 0 to QUEUE_DEPTH - 1 loop
                        if storage_match_mask_q(slot_index) = '1' then
                            live_count_v(slot_index) := storage_match_count_q;
                            live_open_v(slot_index)  := storage_match_open_q;
                        end if;
                        if storage_pop_mask_q(slot_index) = '1' then
                            live_valid_v(slot_index) := '0';
                            live_open_v(slot_index)  := '0';
                            live_bank_v(slot_index)  := '0';
                            live_bin_v(slot_index)   := (others => '0');
                            live_count_v(slot_index) := (others => '0');
                        end if;
                        if storage_append_mask_q(slot_index) = '1' then
                            live_valid_v(slot_index) := '1';
                            live_open_v(slot_index)  := storage_append_open_q;
                            live_bank_v(slot_index)  := storage_append_bank_q;
                            live_bin_v(slot_index)   := storage_append_bin_q;
                            live_count_v(slot_index) := storage_append_count_q;
                        end if;
                    end loop;

                    level_v  := storage_level_next_q;
                    rd_ptr_v := storage_rd_ptr_next_q;
                    wr_ptr_v := storage_wr_ptr_next_q;
                    if storage_pop_q = '1' then
                        drain_valid_v := '1';
                        drain_bank_v  := storage_drain_bank_q;
                        drain_bin_v   := storage_drain_bin_q;
                        drain_count_v := storage_drain_count_q;
                    end if;
                    storage_apply_q <= '0';
                end if;

                occupancy_max_v := occupancy_max_q;
                if occupancy_visible_c > occupancy_max_q then
                    occupancy_max_v := occupancy_visible_c;
                end if;

                blocked_lanes_v := 0;
                if input_ready_c = '0' then
                    for input_index in 0 to N_INPUTS - 1 loop
                        if i_hit_valid(input_index) = '1' then
                            blocked_lanes_v := blocked_lanes_v + 1;
                        end if;
                    end loop;
                end if;
                overflow_sum_v := ('0' & overflow_count_q) +
                    to_unsigned(blocked_lanes_v, OVERFLOW_WIDTH + 1);
                if overflow_sum_v(OVERFLOW_WIDTH) = '1' then
                    overflow_v := (others => '1');
                else
                    overflow_v := overflow_sum_v(OVERFLOW_WIDTH - 1 downto 0);
                end if;

                -- The registered storage action above mutates the live image
                -- on this edge.  Hold the control pipeline for that one edge
                -- so CAM capture and indexed reads cannot observe the old
                -- signal image or synthesize a same-process forwarding path.
                if storage_apply_q = '0' then
                case state_q is
                    when STATE_IDLE =>
                        if work_any_c = '1' then
                            state_q <= STATE_DISPATCH;
                        elsif input_any_c = '1' and input_ready_c = '1' then
                            for input_index in 0 to N_INPUTS - 1 loop
                                raw_valid_q(input_index) <= '0';
                                raw_bank_q(input_index)  <= i_hit_bank(input_index);
                                raw_bin_q(input_index)   <= i_hit_bin(input_index);
                                raw_count_q(input_index) <= resize(
                                    i_hit_count(input_index),
                                    WORK_COUNT_WIDTH_CONST
                                );
                                if i_hit_valid(input_index) = '1' and
                                   i_hit_count(input_index) /=
                                       to_unsigned(0, KICK_WIDTH) then
                                    raw_valid_q(input_index) <= '1';
                                end if;
                            end loop;
                            state_q <= STATE_CLASSIFY;
                        end if;

                        -- Idle prefetch is scheduled, not applied, on this
                        -- edge.  A simultaneously accepted batch remains
                        -- safely behind raw classification while the next
                        -- edge retires the old head from registered controls.
                        if work_any_c = '0' and storage_apply_q = '0' and
                           drain_can_load_c = '1' and live_level_q > 0 then
                            storage_pop_mask_v := (others => '0');
                            storage_pop_mask_v(live_rd_ptr_q) := '1';

                            storage_apply_q       <= '1';
                            storage_is_commit_q   <= '0';
                            storage_match_q       <= '0';
                            storage_pop_q         <= '1';
                            storage_append_q      <= '0';
                            storage_match_mask_q  <= (others => '0');
                            storage_pop_mask_q    <= storage_pop_mask_v;
                            storage_append_mask_q <= (others => '0');
                            storage_drain_bank_q  <= live_bank_q(live_rd_ptr_q);
                            storage_drain_bin_q   <= live_bin_q(live_rd_ptr_q);
                            storage_drain_count_q <= live_count_q(live_rd_ptr_q);
                            storage_level_next_q  <= live_level_q - 1;
                            storage_rd_ptr_next_q <=
                                advance_ptr_f(live_rd_ptr_q, 1);
                            storage_wr_ptr_next_q <= live_wr_ptr_q;
                            storage_residual_q    <= (others => '0');
                        end if;

                    when STATE_CLASSIFY =>
                        group_valid_q       <= raw_leader_c;
                        group_member_mask_q <= raw_member_mask_c;
                        state_q <= STATE_BUILD_WORK;

                    when STATE_BUILD_WORK =>
                        work_valid_v := group_valid_q;
                        for descriptor_index in 0 to N_INPUTS - 1 loop
                            work_bank_v(descriptor_index) :=
                                raw_bank_q(descriptor_index);
                            work_bin_v(descriptor_index) :=
                                raw_bin_q(descriptor_index);
                            if group_valid_q(descriptor_index) = '1' then
                                work_count_v(descriptor_index) :=
                                    group_count_c(descriptor_index);
                            else
                                work_count_v(descriptor_index) := (others => '0');
                            end if;
                        end loop;
                        state_q <= STATE_DISPATCH;

                    when STATE_DISPATCH =>
                        descriptor_found_v := false;
                        descriptor_index_v := 0;
                        for descriptor_index in 0 to N_INPUTS - 1 loop
                            if not descriptor_found_v and
                               work_valid_v(descriptor_index) = '1' then
                                descriptor_found_v := true;
                                descriptor_index_v := descriptor_index;
                            end if;
                        end loop;
                        if descriptor_found_v then
                            lookup_bank_q  <= work_bank_v(descriptor_index_v);
                            lookup_bin_q   <= work_bin_v(descriptor_index_v);
                            lookup_count_q <= work_count_v(descriptor_index_v);
                            work_valid_v(descriptor_index_v) := '0';
                            state_q <= STATE_CAM_GROUP;
                        else
                            state_q <= STATE_IDLE;
                        end if;

                    when STATE_CAM_GROUP =>
                        if CAM_PIPELINE_STAGES_EFFECTIVE_CONST >= 1 then
                            cam_group_hit_q  <= cam_group_hit_c;
                            cam_group_slot_q <= cam_group_slot_c;
                        end if;
                        if CAM_PIPELINE_STAGES_EFFECTIVE_CONST >= 2 then
                            state_q <= STATE_CAM_GLOBAL;
                        else
                            state_q <= STATE_MATCH_CAPTURE;
                        end if;

                    when STATE_CAM_GLOBAL =>
                        cam_global_hit_q  <= cam_group_winner_hit_c;
                        cam_global_slot_q <= cam_group_winner_slot_c;
                        if CAM_PIPELINE_STAGES_EFFECTIVE_CONST >= 3 then
                            state_q <= STATE_CAM_FINAL;
                        else
                            state_q <= STATE_MATCH_CAPTURE;
                        end if;

                    when STATE_CAM_FINAL =>
                        cam_final_hit_q  <= cam_global_hit_q;
                        cam_final_slot_q <= cam_global_slot_q;
                        state_q <= STATE_MATCH_CAPTURE;

                    when STATE_MATCH_CAPTURE =>
                        match_candidate_hit_q  <= cam_selected_hit_c;
                        match_candidate_slot_q <= cam_selected_slot_c;
                        state_q <= STATE_MATCH_READ;

                    when STATE_MATCH_READ =>
                        match_valid_q <= '0';
                        match_slot_q  <= match_candidate_slot_q;
                        match_count_q <= (others => '0');
                        if match_candidate_hit_q = '1' and
                           live_valid_q(match_candidate_slot_q) = '1' and
                           live_open_q(match_candidate_slot_q) = '1' and
                           live_bank_q(match_candidate_slot_q) = lookup_bank_q and
                           live_bin_q(match_candidate_slot_q) = lookup_bin_q then
                            match_valid_q <= '1';
                            match_count_q <= live_count_q(match_candidate_slot_q);
                        end if;
                        state_q <= STATE_COMMIT_PLAN;

                    when STATE_COMMIT_PLAN =>
                        remaining_v  := to_integer(lookup_count_q);
                        plan_match_q       <= match_valid_q;
                        plan_match_head_q  <= '0';
                        plan_match_slot_q  <= match_slot_q;
                        plan_match_count_q <= (others => '0');
                        plan_match_open_q  <= '0';

                        if match_valid_q = '1' then
                            capacity_v := KICK_MAX_NAT_CONST -
                                to_integer(match_count_q);
                            if remaining_v >= capacity_v then
                                updated_count_v := KICK_MAX_NAT_CONST;
                                remaining_v := remaining_v - capacity_v;
                                plan_match_open_q <= '0';
                            else
                                updated_count_v :=
                                    to_integer(match_count_q) +
                                    remaining_v;
                                remaining_v := 0;
                                if updated_count_v < KICK_MAX_NAT_CONST then
                                    plan_match_open_q <= '1';
                                else
                                    plan_match_open_q <= '0';
                                end if;
                            end if;
                            plan_match_count_q <=
                                to_unsigned(updated_count_v, KICK_WIDTH);
                            if match_slot_q = live_rd_ptr_q then
                                plan_match_head_q <= '1';
                            end if;
                        end if;

                        plan_remaining_q <=
                            to_unsigned(remaining_v, WORK_COUNT_WIDTH_CONST);
                        state_q <= STATE_COMMIT_SCHEDULE;

                    when STATE_COMMIT_SCHEDULE =>
                        remaining_v         := to_integer(plan_remaining_q);
                        progress_v          := false;
                        pop_will_v          := drain_can_load_c = '1' and
                                               live_level_q > 0;
                        matched_head_pop_v  := pop_will_v and
                                               plan_match_q = '1' and
                                               plan_match_head_q = '1';

                        storage_level_v      := live_level_q;
                        storage_rd_ptr_v     := live_rd_ptr_q;
                        storage_wr_ptr_v     := live_wr_ptr_q;
                        storage_match_mask_v := (others => '0');
                        storage_pop_mask_v   := (others => '0');
                        storage_append_mask_v := (others => '0');

                        if plan_match_q = '1' then
                            storage_match_mask_v(plan_match_slot_q) := '1';
                            progress_v := true;
                        end if;

                        if pop_will_v then
                            storage_pop_mask_v(storage_rd_ptr_v) := '1';
                            storage_drain_bank_q <=
                                live_bank_q(storage_rd_ptr_v);
                            storage_drain_bin_q <=
                                live_bin_q(storage_rd_ptr_v);
                            if matched_head_pop_v then
                                storage_drain_count_q <= plan_match_count_q;
                            else
                                storage_drain_count_q <=
                                    live_count_q(storage_rd_ptr_v);
                            end if;
                            storage_rd_ptr_v :=
                                advance_ptr_f(storage_rd_ptr_v, 1);
                            storage_level_v := storage_level_v - 1;
                            progress_v := true;
                        end if;

                        if remaining_v > 0 and
                           storage_level_v < QUEUE_DEPTH then
                            if remaining_v > KICK_MAX_NAT_CONST then
                                append_count_v := KICK_MAX_NAT_CONST;
                            else
                                append_count_v := remaining_v;
                            end if;

                            storage_append_mask_v(storage_wr_ptr_v) := '1';
                            storage_append_bank_q <= lookup_bank_q;
                            storage_append_bin_q  <= lookup_bin_q;
                            storage_append_count_q <=
                                to_unsigned(append_count_v, KICK_WIDTH);
                            if append_count_v < KICK_MAX_NAT_CONST then
                                storage_append_open_q <= '1';
                            else
                                storage_append_open_q <= '0';
                            end if;

                            storage_wr_ptr_v :=
                                advance_ptr_f(storage_wr_ptr_v, 1);
                            storage_level_v := storage_level_v + 1;
                            remaining_v := remaining_v - append_count_v;
                            progress_v := true;
                        end if;

                        if progress_v then
                            storage_apply_q       <= '1';
                            storage_is_commit_q   <= '1';
                            storage_match_q       <= plan_match_q;
                            if pop_will_v then
                                storage_pop_q <= '1';
                            else
                                storage_pop_q <= '0';
                            end if;
                            if storage_append_mask_v /=
                               (storage_append_mask_v'range => '0') then
                                storage_append_q <= '1';
                            else
                                storage_append_q <= '0';
                            end if;
                            storage_match_mask_q  <= storage_match_mask_v;
                            storage_pop_mask_q    <= storage_pop_mask_v;
                            storage_append_mask_q <= storage_append_mask_v;
                            storage_match_count_q <= plan_match_count_q;
                            storage_match_open_q  <= plan_match_open_q;
                            storage_level_next_q  <= storage_level_v;
                            storage_rd_ptr_next_q <= storage_rd_ptr_v;
                            storage_wr_ptr_next_q <= storage_wr_ptr_v;
                            storage_residual_q    <=
                                to_unsigned(remaining_v, WORK_COUNT_WIDTH_CONST);
                            state_q <= STATE_COMMIT_APPLY;
                        end if;

                    when STATE_COMMIT_APPLY =>
                        if storage_is_commit_q = '1' then
                            matched_resident_update_pulse_q <= storage_match_q;
                            resident_head_pop_pulse_q       <= storage_pop_q;
                            append_pulse_q                  <= storage_append_q;
                            commit_pulse_q <= storage_match_q or
                                              storage_pop_q or
                                              storage_append_q;

                            if storage_residual_q =
                                to_unsigned(0, WORK_COUNT_WIDTH_CONST) then
                                state_q <= STATE_DISPATCH;
                            else
                                lookup_count_q <= storage_residual_q;
                                state_q <= STATE_CAM_GROUP;
                            end if;
                        end if;
                end case;
                end if;

                live_valid_q <= live_valid_v;
                live_open_q  <= live_open_v;
                live_bank_q  <= live_bank_v;
                live_bin_q   <= live_bin_v;
                live_count_q <= live_count_v;
                live_level_q  <= level_v;
                live_rd_ptr_q <= rd_ptr_v;
                live_wr_ptr_q <= wr_ptr_v;

                work_valid_q <= work_valid_v;
                work_bank_q  <= work_bank_v;
                work_bin_q   <= work_bin_v;
                work_count_q <= work_count_v;

                drain_valid_q <= drain_valid_v;
                drain_bank_q  <= drain_bank_v;
                drain_bin_q   <= drain_bin_v;
                drain_count_q <= drain_count_v;
                occupancy_max_q  <= occupancy_max_v;
                overflow_count_q <= overflow_v;
            end if;
        end if;
    end process;

    -- synthesis translate_off
    report_configuration : process
    begin
        report "DEEP_QUEUE_CONFIG depth=" & natural'image(QUEUE_DEPTH) &
            " mode=" & CAM_PIPELINE_MODE &
            " requested=" & natural'image(CAM_PIPELINE_STAGES) &
            " effective=" & natural'image(CAM_PIPELINE_STAGES_EFFECTIVE_CONST)
            severity note;
        wait;
    end process;

    assert_open_tag_uniqueness : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '0' and i_clear = '0' then
                for first_slot in 0 to QUEUE_DEPTH - 2 loop
                    for second_slot in first_slot + 1 to QUEUE_DEPTH - 1 loop
                        assert not (
                            live_valid_q(first_slot) = '1' and
                            live_open_q(first_slot) = '1' and
                            live_valid_q(second_slot) = '1' and
                            live_open_q(second_slot) = '1' and
                            live_bank_q(first_slot) = live_bank_q(second_slot) and
                            live_bin_q(first_slot) = live_bin_q(second_slot)
                        )
                            report "coalescing_queue_deep duplicate open tag"
                            severity failure;
                    end loop;
                end loop;
            end if;
        end if;
    end process;
    -- synthesis translate_on

    o_drain_valid    <= drain_valid_q;
    o_drain_bank     <= drain_bank_q;
    o_drain_bin      <= drain_bin_q;
    o_drain_count    <= drain_count_q;
    o_occupancy      <= occupancy_visible_c;
    o_occupancy_max  <= occupancy_max_q;
    o_overflow_count <= overflow_count_q;
    o_dbg_commit_pulse                  <= commit_pulse_q;
    o_dbg_matched_resident_update_pulse <= matched_resident_update_pulse_q;
    o_dbg_resident_head_pop_pulse       <= resident_head_pop_pulse_q;
    o_dbg_append_pulse                  <= append_pulse_q;

end architecture rtl;

-- altera vhdl_input_version vhdl_2008
-- Public wrapper preserving the depth-4/8 closed fast path.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.histogram_statistics_v2_pkg.all;

entity coalescing_queue is
    generic (
        N_BINS         : natural := 256;
        QUEUE_DEPTH    : natural := 8;
        KICK_WIDTH     : natural := 4;
        N_INPUTS       : natural := 8;
        OVERFLOW_WIDTH : natural := 16;
        CAM_PIPELINE_MODE   : string  := "AUTO";
        CAM_PIPELINE_STAGES : natural := 0
    );
    port (
        i_clk            : in  std_logic;
        i_rst            : in  std_logic;
        i_clear          : in  std_logic;

        i_hit_valid      : in  std_logic_vector(N_INPUTS - 1 downto 0);
        i_hit_bank       : in  std_logic_vector(N_INPUTS - 1 downto 0);
        i_hit_bin        : in  hs_unsigned_array_t(0 to N_INPUTS - 1)(clog2(N_BINS) - 1 downto 0);
        i_hit_count      : in  hs_unsigned_array_t(0 to N_INPUTS - 1)(KICK_WIDTH - 1 downto 0);
        o_hit_accept     : out std_logic_vector(N_INPUTS - 1 downto 0);

        i_drain_ready    : in  std_logic;
        o_drain_valid    : out std_logic;
        o_drain_bank     : out std_logic;
        o_drain_bin      : out unsigned(clog2(N_BINS) - 1 downto 0);
        o_drain_count    : out unsigned(KICK_WIDTH - 1 downto 0);

        o_occupancy      : out unsigned(clog2(QUEUE_DEPTH + 1) - 1 downto 0);
        o_occupancy_max  : out unsigned(clog2(QUEUE_DEPTH + 1) - 1 downto 0);
        o_overflow_count : out unsigned(OVERFLOW_WIDTH - 1 downto 0)
    );
end entity coalescing_queue;

architecture rtl of coalescing_queue is

    function effective_stages_f(
        mode_value  : string;
        stage_value : natural;
        depth_value : natural
    ) return natural is
    begin
        if mode_value = "AUTO" then
            if depth_value <= 31 then
                return 0;
            elsif depth_value <= 63 then
                return 1;
            end if;
            return 2;
        end if;
        return stage_value;
    end function;

    constant EFFECTIVE_STAGES_CONST : natural := effective_stages_f(
        CAM_PIPELINE_MODE,
        CAM_PIPELINE_STAGES,
        QUEUE_DEPTH
    );
    constant USE_FROZEN_FAST_CORE_CONST : boolean :=
        QUEUE_DEPTH = 8 and EFFECTIVE_STAGES_CONST = 0;

    -- Stable wrapper-level names consumed by focused white-box contention
    -- coverage.  The generic branch forwards registered commit events; the
    -- fast branch derives equivalent events from its frozen exact hooks.
    signal engine_has_match_c      : std_logic_vector(7 downto 0);
    signal engine_miss_c           : std_logic_vector(7 downto 0);
    signal live_has_match_c        : std_logic_vector(QUEUE_DEPTH - 1 downto 0);
    signal live_rd_ptr_q           : natural range 0 to QUEUE_DEPTH - 1;
    signal resident_to_drain_c     : std_logic;
    signal miss_stage_valid_q      : std_logic_vector(7 downto 0);
    signal engine_allocate_c       : std_logic_vector(7 downto 0);
    signal engine_allocate_count_c : natural range 0 to 2;
    signal append_commit_count_c   : natural range 0 to 2;
    signal free_cells_c            : natural range 0 to QUEUE_DEPTH;

    signal fast_engine_has_match_c      : std_logic_vector(7 downto 0) := (others => '0');
    signal fast_engine_miss_c           : std_logic_vector(7 downto 0) := (others => '0');
    signal fast_live_has_match_c        : std_logic_vector(QUEUE_DEPTH - 1 downto 0) :=
        (others => '0');
    signal fast_live_rd_ptr_q           : natural range 0 to QUEUE_DEPTH - 1 := 0;
    signal fast_resident_to_drain_c     : std_logic := '0';
    signal fast_miss_stage_valid_q      : std_logic_vector(7 downto 0) := (others => '0');
    signal fast_engine_allocate_c       : std_logic_vector(7 downto 0) := (others => '0');
    signal fast_engine_allocate_count_c : natural range 0 to 2 := 0;
    signal fast_append_commit_count_c   : natural range 0 to 2 := 0;
    signal fast_free_cells_c            : natural range 0 to QUEUE_DEPTH := QUEUE_DEPTH;

    signal deep_commit_pulse_c                  : std_logic := '0';
    signal deep_matched_resident_update_pulse_c : std_logic := '0';
    signal deep_resident_head_pop_pulse_c       : std_logic := '0';
    signal deep_append_pulse_c                  : std_logic := '0';

    signal commit_pulse_q                  : std_logic := '0';
    signal matched_resident_update_pulse_q : std_logic := '0';
    signal resident_head_pop_pulse_q       : std_logic := '0';
    signal append_pulse_q                  : std_logic := '0';

begin

    assert QUEUE_DEPTH >= 4 and QUEUE_DEPTH <= 256
        report "coalescing_queue wrapper supports depth 4 through 256"
        severity failure;
    assert CAM_PIPELINE_MODE = "AUTO" or CAM_PIPELINE_MODE = "EXPLICIT"
        report "CAM_PIPELINE_MODE must be AUTO or EXPLICIT"
        severity failure;
    assert EFFECTIVE_STAGES_CONST <= 3
        report "coalescing_queue wrapper supports zero through three CAM stages"
        severity failure;

    frozen_fast_gen : if USE_FROZEN_FAST_CORE_CONST generate
        fast_inst : entity work.coalescing_queue_fast
            generic map (
                N_BINS         => N_BINS,
                QUEUE_DEPTH    => QUEUE_DEPTH,
                KICK_WIDTH     => KICK_WIDTH,
                N_INPUTS       => N_INPUTS,
                OVERFLOW_WIDTH => OVERFLOW_WIDTH,
                CAM_PIPELINE_MODE   => CAM_PIPELINE_MODE,
                CAM_PIPELINE_STAGES => CAM_PIPELINE_STAGES
            )
            port map (
                i_clk            => i_clk,
                i_rst            => i_rst,
                i_clear          => i_clear,
                i_hit_valid      => i_hit_valid,
                i_hit_bank       => i_hit_bank,
                i_hit_bin        => i_hit_bin,
                i_hit_count      => i_hit_count,
                o_hit_accept     => o_hit_accept,
                i_drain_ready    => i_drain_ready,
                o_drain_valid    => o_drain_valid,
                o_drain_bank     => o_drain_bank,
                o_drain_bin      => o_drain_bin,
                o_drain_count    => o_drain_count,
                o_occupancy      => o_occupancy,
                o_occupancy_max  => o_occupancy_max,
                o_overflow_count => o_overflow_count,
                o_dbg_engine_has_match      => fast_engine_has_match_c,
                o_dbg_engine_miss           => fast_engine_miss_c,
                o_dbg_live_has_match        => fast_live_has_match_c,
                o_dbg_live_rd_ptr           => fast_live_rd_ptr_q,
                o_dbg_resident_to_drain     => fast_resident_to_drain_c,
                o_dbg_miss_stage_valid      => fast_miss_stage_valid_q,
                o_dbg_engine_allocate       => fast_engine_allocate_c,
                o_dbg_engine_allocate_count => fast_engine_allocate_count_c,
                o_dbg_append_commit_count   => fast_append_commit_count_c,
                o_dbg_free_cells            => fast_free_cells_c
            );
    end generate;

    generic_deep_gen : if not USE_FROZEN_FAST_CORE_CONST generate
        deep_inst : entity work.coalescing_queue_deep
            generic map (
                N_BINS         => N_BINS,
                QUEUE_DEPTH    => QUEUE_DEPTH,
                KICK_WIDTH     => KICK_WIDTH,
                N_INPUTS       => N_INPUTS,
                OVERFLOW_WIDTH => OVERFLOW_WIDTH,
                CAM_PIPELINE_MODE   => CAM_PIPELINE_MODE,
                CAM_PIPELINE_STAGES => CAM_PIPELINE_STAGES
            )
            port map (
                i_clk            => i_clk,
                i_rst            => i_rst,
                i_clear          => i_clear,
                i_hit_valid      => i_hit_valid,
                i_hit_bank       => i_hit_bank,
                i_hit_bin        => i_hit_bin,
                i_hit_count      => i_hit_count,
                o_hit_accept     => o_hit_accept,
                i_drain_ready    => i_drain_ready,
                o_drain_valid    => o_drain_valid,
                o_drain_bank     => o_drain_bank,
                o_drain_bin      => o_drain_bin,
                o_drain_count    => o_drain_count,
                o_occupancy      => o_occupancy,
                o_occupancy_max  => o_occupancy_max,
                o_overflow_count => o_overflow_count,
                o_dbg_commit_pulse                  => deep_commit_pulse_c,
                o_dbg_matched_resident_update_pulse => deep_matched_resident_update_pulse_c,
                o_dbg_resident_head_pop_pulse       => deep_resident_head_pop_pulse_c,
                o_dbg_append_pulse                  => deep_append_pulse_c
            );

    end generate;

    engine_has_match_c <= fast_engine_has_match_c when
        USE_FROZEN_FAST_CORE_CONST else (others => '0');
    engine_miss_c <= fast_engine_miss_c when
        USE_FROZEN_FAST_CORE_CONST else (others => '0');
    live_has_match_c <= fast_live_has_match_c when
        USE_FROZEN_FAST_CORE_CONST else (others => '0');
    live_rd_ptr_q <= fast_live_rd_ptr_q when
        USE_FROZEN_FAST_CORE_CONST else 0;
    resident_to_drain_c <= fast_resident_to_drain_c when
        USE_FROZEN_FAST_CORE_CONST else '0';
    miss_stage_valid_q <= fast_miss_stage_valid_q when
        USE_FROZEN_FAST_CORE_CONST else (others => '0');
    engine_allocate_c <= fast_engine_allocate_c when
        USE_FROZEN_FAST_CORE_CONST else (others => '0');
    engine_allocate_count_c <= fast_engine_allocate_count_c when
        USE_FROZEN_FAST_CORE_CONST else 0;
    append_commit_count_c <= fast_append_commit_count_c when
        USE_FROZEN_FAST_CORE_CONST else 0;
    free_cells_c <= fast_free_cells_c when
        USE_FROZEN_FAST_CORE_CONST else QUEUE_DEPTH;

    matched_resident_update_pulse_q <=
        '1' when USE_FROZEN_FAST_CORE_CONST and
                 fast_engine_has_match_c /= x"00" else
        deep_matched_resident_update_pulse_c;
    resident_head_pop_pulse_q <=
        fast_resident_to_drain_c when USE_FROZEN_FAST_CORE_CONST else
        deep_resident_head_pop_pulse_c;
    append_pulse_q <=
        '1' when USE_FROZEN_FAST_CORE_CONST and
                 fast_append_commit_count_c > 0 else
        deep_append_pulse_c;
    commit_pulse_q <=
        (matched_resident_update_pulse_q or
         resident_head_pop_pulse_q or
         append_pulse_q) when USE_FROZEN_FAST_CORE_CONST else
        deep_commit_pulse_c;

end architecture rtl;
