-- altera vhdl_input_version vhdl_2008
-- File name: scifi_histogram_adapter.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- Version : 26.5.0
-- Date    : 20260714
-- Change  : Add the readyless four-MTS to eight-ASIC histogram adapter. Each
--           accepted MTS beat keeps payload, true TS48, direct arrival48,
--           physical latency48, and error atomic while ASIC[38:35] selects
--           exactly one logical HIST lane. Register the complete demux beat
--           and diagnostic event counts to break the MTS-to-HIST timing cone.
--           Decode parallel ASIC claims and use a fixed balanced winner tree
--           so the registered output keeps lowest-physical-source priority
--           without a source-order combinational loop. Hold payload registers
--           while their valid qualifier is low; only ownership state resets.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

entity scifi_histogram_adapter is
    generic (
        N_MTS_INPUTS    : positive    := 4;
        N_ASICS         : positive    := 8
    );
    port (
        csi_clock                 : in  std_logic;
        rsi_reset                 : in  std_logic;
        asi_mts_valid             : in  std_logic_vector(N_MTS_INPUTS - 1 downto 0);
        asi_mts_data              : in  slv39_array_t(N_MTS_INPUTS - 1 downto 0);
        coe_mts_timestamp         : in  slv48_array_t(N_MTS_INPUTS - 1 downto 0);
        coe_mts_arrival           : in  slv48_array_t(N_MTS_INPUTS - 1 downto 0);
        coe_mts_latency           : in  slv48_array_t(N_MTS_INPUTS - 1 downto 0);
        asi_mts_error             : in  std_logic_vector(N_MTS_INPUTS - 1 downto 0);
        aso_hist_valid            : out std_logic_vector(N_ASICS - 1 downto 0);
        aso_hist_data             : out slv39_array_t(N_ASICS - 1 downto 0);
        coe_hist_timestamp        : out slv48_array_t(N_ASICS - 1 downto 0);
        coe_hist_arrival          : out slv48_array_t(N_ASICS - 1 downto 0);
        coe_hist_latency          : out slv48_array_t(N_ASICS - 1 downto 0);
        aso_hist_error            : out std_logic_vector(N_ASICS - 1 downto 0);
        coe_collision_count       : out std_logic_vector(31 downto 0);
        coe_invalid_asic_count    : out std_logic_vector(31 downto 0)
    );
end entity scifi_histogram_adapter;

architecture rtl of scifi_histogram_adapter is
    constant MAX_MTS_INPUTS_CONST : positive := 4;
    constant COUNT_MAX_CONST      : unsigned(31 downto 0) := (others => '1');

    type claim_array_t is array (0 to MAX_MTS_INPUTS_CONST - 1) of
        std_logic_vector(N_ASICS - 1 downto 0);

    signal mts_valid_pad_c       : std_logic_vector(MAX_MTS_INPUTS_CONST - 1 downto 0);
    signal mts_data_pad_c        : slv39_array_t(0 to MAX_MTS_INPUTS_CONST - 1);
    signal mts_timestamp_pad_c   : slv48_array_t(0 to MAX_MTS_INPUTS_CONST - 1);
    signal mts_arrival_pad_c     : slv48_array_t(0 to MAX_MTS_INPUTS_CONST - 1);
    signal mts_latency_pad_c     : slv48_array_t(0 to MAX_MTS_INPUTS_CONST - 1);
    signal mts_error_pad_c       : std_logic_vector(MAX_MTS_INPUTS_CONST - 1 downto 0);
    signal claim_c               : claim_array_t;
    signal winner_c              : claim_array_t;
    signal collision_source_c    : std_logic_vector(MAX_MTS_INPUTS_CONST - 1 downto 0);
    signal invalid_source_c      : std_logic_vector(MAX_MTS_INPUTS_CONST - 1 downto 0);
    signal hist_valid_c          : std_logic_vector(N_ASICS - 1 downto 0);
    signal hist_data_c           : slv39_array_t(N_ASICS - 1 downto 0);
    signal hist_timestamp_c      : slv48_array_t(N_ASICS - 1 downto 0);
    signal hist_arrival_c        : slv48_array_t(N_ASICS - 1 downto 0);
    signal hist_latency_c        : slv48_array_t(N_ASICS - 1 downto 0);
    signal hist_error_c          : std_logic_vector(N_ASICS - 1 downto 0);
    signal hist_valid_q          : std_logic_vector(N_ASICS - 1 downto 0);
    signal hist_data_q           : slv39_array_t(N_ASICS - 1 downto 0);
    signal hist_timestamp_q      : slv48_array_t(N_ASICS - 1 downto 0);
    signal hist_arrival_q        : slv48_array_t(N_ASICS - 1 downto 0);
    signal hist_latency_q        : slv48_array_t(N_ASICS - 1 downto 0);
    signal hist_error_q          : std_logic_vector(N_ASICS - 1 downto 0);
    signal collision_events_c    : unsigned(2 downto 0);
    signal invalid_events_c      : unsigned(2 downto 0);
    signal collision_events_q    : unsigned(2 downto 0);
    signal invalid_events_q      : unsigned(2 downto 0);
    signal collision_count_q     : unsigned(31 downto 0);
    signal invalid_count_q       : unsigned(31 downto 0);

    function sat_add_count(
        lhs    : unsigned(31 downto 0);
        rhs    : unsigned
    ) return unsigned is
        variable sum_v    : unsigned(32 downto 0);
    begin
        sum_v := ('0' & lhs) + resize(rhs, sum_v'length);
        if sum_v(sum_v'high) = '1' then
            return COUNT_MAX_CONST;
        end if;
        return sum_v(31 downto 0);
    end function sat_add_count;

    function masked_word_f(
        value  : std_logic_vector;
        select_bit : std_logic
    ) return std_logic_vector is
        variable mask_v : std_logic_vector(value'range);
    begin
        mask_v := (others => select_bit);
        return value and mask_v;
    end function masked_word_f;

    function reduce_or8_f(
        value : std_logic_vector
    ) return std_logic is
        alias value_norm : std_logic_vector(7 downto 0) is value;
        variable pair_v : std_logic_vector(3 downto 0);
        variable quad_v : std_logic_vector(1 downto 0);
    begin
        pair_v(0) := value_norm(0) or value_norm(1);
        pair_v(1) := value_norm(2) or value_norm(3);
        pair_v(2) := value_norm(4) or value_norm(5);
        pair_v(3) := value_norm(6) or value_norm(7);
        quad_v(0) := pair_v(0) or pair_v(1);
        quad_v(1) := pair_v(2) or pair_v(3);
        return quad_v(0) or quad_v(1);
    end function reduce_or8_f;

    function count_four_f(
        value : std_logic_vector(3 downto 0)
    ) return unsigned is
        variable pair_low_v  : unsigned(1 downto 0);
        variable pair_high_v : unsigned(1 downto 0);
    begin
        pair_low_v :=
            resize(unsigned(value(0 downto 0)), pair_low_v'length) +
            resize(unsigned(value(1 downto 1)), pair_low_v'length);
        pair_high_v :=
            resize(unsigned(value(2 downto 2)), pair_high_v'length) +
            resize(unsigned(value(3 downto 3)), pair_high_v'length);
        return resize(pair_low_v, 3) + resize(pair_high_v, 3);
    end function count_four_f;
begin
    assert N_MTS_INPUTS <= 4
        report "scifi_histogram_adapter supports the Phase-I MTSx4 physical contract"
        severity failure;
    assert N_ASICS = 8
        report "scifi_histogram_adapter requires the Phase-I eight-ASIC logical contract"
        severity failure;

    aso_hist_valid            <= hist_valid_q;
    aso_hist_data             <= hist_data_q;
    coe_hist_timestamp        <= hist_timestamp_q;
    coe_hist_arrival          <= hist_arrival_q;
    coe_hist_latency          <= hist_latency_q;
    aso_hist_error            <= hist_error_q;
    coe_collision_count       <= std_logic_vector(collision_count_q);
    coe_invalid_asic_count    <= std_logic_vector(invalid_count_q);

    -- Pad the generic source count to the fixed Phase-I MTSx4 arbitration tree.
    -- Absent sources claim no lane and contribute zero payload or diagnostics.
    source_pad_gen : for mts_idx in 0 to MAX_MTS_INPUTS_CONST - 1 generate
        source_present_gen : if mts_idx < N_MTS_INPUTS generate
        begin
            mts_valid_pad_c(mts_idx)     <= asi_mts_valid(mts_idx);
            mts_data_pad_c(mts_idx)      <= asi_mts_data(mts_idx);
            mts_timestamp_pad_c(mts_idx) <= coe_mts_timestamp(mts_idx);
            mts_arrival_pad_c(mts_idx)   <= coe_mts_arrival(mts_idx);
            mts_latency_pad_c(mts_idx)   <= coe_mts_latency(mts_idx);
            mts_error_pad_c(mts_idx)     <= asi_mts_error(mts_idx);
        end generate source_present_gen;

        source_absent_gen : if mts_idx >= N_MTS_INPUTS generate
        begin
            mts_valid_pad_c(mts_idx)     <= '0';
            mts_data_pad_c(mts_idx)      <= (others => '0');
            mts_timestamp_pad_c(mts_idx) <= (others => '0');
            mts_arrival_pad_c(mts_idx)   <= (others => '0');
            mts_latency_pad_c(mts_idx)   <= (others => '0');
            mts_error_pad_c(mts_idx)     <= '0';
        end generate source_absent_gen;

        claim_gen : for asic_idx in 0 to N_ASICS - 1 generate
        begin
            claim_c(mts_idx)(asic_idx) <= mts_valid_pad_c(mts_idx)
                when (mts_data_pad_c(mts_idx)(38) = '0') and
                     (mts_data_pad_c(mts_idx)(37 downto 35) =
                      std_logic_vector(to_unsigned(asic_idx, 3)))
                else '0';
        end generate claim_gen;

        invalid_source_c(mts_idx) <=
            mts_valid_pad_c(mts_idx) and mts_data_pad_c(mts_idx)(38);
    end generate source_pad_gen;

    -- Each source independently claims one ASIC. Fixed prefix masks implement
    -- lowest-physical-source priority without a loop-carried valid variable.
    winner_c(0) <= claim_c(0);
    winner_c(1) <= claim_c(1) and not claim_c(0);
    winner_c(2) <= claim_c(2) and not (claim_c(0) or claim_c(1));
    winner_c(3) <= claim_c(3) and not ((claim_c(0) or claim_c(1)) or claim_c(2));

    -- A later source contributes one collision exactly when its single claim
    -- overlaps any lower-numbered source. This equals the original k-1 count
    -- for k duplicate claims on one lane.
    collision_source_c(0) <= '0';
    collision_source_c(1) <= reduce_or8_f(claim_c(1) and claim_c(0));
    collision_source_c(2) <= reduce_or8_f(
        claim_c(2) and (claim_c(0) or claim_c(1))
    );
    collision_source_c(3) <= reduce_or8_f(
        claim_c(3) and ((claim_c(0) or claim_c(1)) or claim_c(2))
    );

    -- This is a readyless observation demultiplexer: there is deliberately no
    -- ready path back to MTS. Winner-masked payloads are combined through two
    -- pairs and one final OR level before the existing output register stage.
    demux_comb : process (all)
        variable valid_v        : std_logic_vector(N_ASICS - 1 downto 0);
        variable data_v         : slv39_array_t(N_ASICS - 1 downto 0);
        variable timestamp_v    : slv48_array_t(N_ASICS - 1 downto 0);
        variable arrival_v      : slv48_array_t(N_ASICS - 1 downto 0);
        variable latency_v      : slv48_array_t(N_ASICS - 1 downto 0);
        variable error_v        : std_logic_vector(N_ASICS - 1 downto 0);
    begin
        for asic_idx in 0 to N_ASICS - 1 loop
            valid_v(asic_idx) :=
                (winner_c(0)(asic_idx) or winner_c(1)(asic_idx)) or
                (winner_c(2)(asic_idx) or winner_c(3)(asic_idx));
            data_v(asic_idx) :=
                (masked_word_f(mts_data_pad_c(0), winner_c(0)(asic_idx)) or
                 masked_word_f(mts_data_pad_c(1), winner_c(1)(asic_idx))) or
                (masked_word_f(mts_data_pad_c(2), winner_c(2)(asic_idx)) or
                 masked_word_f(mts_data_pad_c(3), winner_c(3)(asic_idx)));
            timestamp_v(asic_idx) :=
                (masked_word_f(mts_timestamp_pad_c(0), winner_c(0)(asic_idx)) or
                 masked_word_f(mts_timestamp_pad_c(1), winner_c(1)(asic_idx))) or
                (masked_word_f(mts_timestamp_pad_c(2), winner_c(2)(asic_idx)) or
                 masked_word_f(mts_timestamp_pad_c(3), winner_c(3)(asic_idx)));
            arrival_v(asic_idx) :=
                (masked_word_f(mts_arrival_pad_c(0), winner_c(0)(asic_idx)) or
                 masked_word_f(mts_arrival_pad_c(1), winner_c(1)(asic_idx))) or
                (masked_word_f(mts_arrival_pad_c(2), winner_c(2)(asic_idx)) or
                 masked_word_f(mts_arrival_pad_c(3), winner_c(3)(asic_idx)));
            latency_v(asic_idx) :=
                (masked_word_f(mts_latency_pad_c(0), winner_c(0)(asic_idx)) or
                 masked_word_f(mts_latency_pad_c(1), winner_c(1)(asic_idx))) or
                (masked_word_f(mts_latency_pad_c(2), winner_c(2)(asic_idx)) or
                 masked_word_f(mts_latency_pad_c(3), winner_c(3)(asic_idx)));
            error_v(asic_idx) :=
                ((mts_error_pad_c(0) and winner_c(0)(asic_idx)) or
                 (mts_error_pad_c(1) and winner_c(1)(asic_idx))) or
                ((mts_error_pad_c(2) and winner_c(2)(asic_idx)) or
                 (mts_error_pad_c(3) and winner_c(3)(asic_idx)));
        end loop;

        hist_valid_c          <= valid_v;
        hist_data_c           <= data_v;
        hist_timestamp_c      <= timestamp_v;
        hist_arrival_c        <= arrival_v;
        hist_latency_c        <= latency_v;
        hist_error_c          <= error_v;
        collision_events_c    <= count_four_f(collision_source_c);
        invalid_events_c      <= count_four_f(invalid_source_c);
    end process demux_comb;

    -- One readyless pipeline stage is sufficient to isolate the MTS output
    -- registers from HIST's range/filter stage. All sidebands are registered
    -- together, so the added cycle cannot tear a histogram observation. The
    -- small event counts are also registered before the saturating counters;
    -- otherwise the priority demux and a 32-bit carry chain share one cycle.
    adapter_pipeline_reg : process (csi_clock)
    begin
        if rising_edge(csi_clock) then
            if rsi_reset = '1' then
                hist_valid_q         <= (others    => '0');
                collision_events_q   <= (others    => '0');
                invalid_events_q     <= (others    => '0');
                collision_count_q    <= (others    => '0');
                invalid_count_q      <= (others    => '0');
            else
                hist_valid_q         <= hist_valid_c;
                for asic_idx in 0 to N_ASICS - 1 loop
                    if hist_valid_c(asic_idx) = '1' then
                        hist_data_q(asic_idx)      <= hist_data_c(asic_idx);
                        hist_timestamp_q(asic_idx) <= hist_timestamp_c(asic_idx);
                        hist_arrival_q(asic_idx)   <= hist_arrival_c(asic_idx);
                        hist_latency_q(asic_idx)   <= hist_latency_c(asic_idx);
                        hist_error_q(asic_idx)     <= hist_error_c(asic_idx);
                    end if;
                end loop;
                collision_events_q   <= collision_events_c;
                invalid_events_q     <= invalid_events_c;
                collision_count_q    <= sat_add_count(collision_count_q, collision_events_q);
                invalid_count_q      <= sat_add_count(invalid_count_q, invalid_events_q);
            end if;
        end if;
    end process adapter_pipeline_reg;
end architecture rtl;
