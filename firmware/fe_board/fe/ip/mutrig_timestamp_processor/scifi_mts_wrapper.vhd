-- File name: scifi_mts_wrapper.vhd
-- Author: Yifeng Wang
-- =======================================
-- Version : 26.8.0
-- Date    : 20260817
-- Change  : Export the readyless histogram observation tap. The merged Type1
--           payload, the true hit timestamp, this bank's arrival GTS and the
--           derived lifetime leave the wrapper on one aligned register stage.
--           The merge, CSR and sorter demux behaviour is unchanged.
-- Version : 26.4.6
-- Date    : 20260608
-- Change  : Add configurable RR demux from the merged MTS stream to sorter lanes.
-- =======================================
--
-- SciFi adapter for the MuTRiG timestamp processor.
--
-- This wrapper accepts four raw SciFi frame-receiver t_hit_presort streams for
-- one FEB bank, queues each stream in a 256-word FIFO, and round-robin merges (check if this can bloat the latency)
-- them into one mts_processor instance. The MTS divider is the authoritative /5
-- coarse-time division: O_TCC8N is T_CC_div and O_TCC1n6 is T_CC_rem. O_ET1n6
-- is the 9-bit E-T value from the MTS ToT path; the SciFi sorter/output path
-- keeps the low 8 bits in phase 1.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;
use work.mutrig_hit_types.all;

entity scifi_mts_wrapper is
generic (
    BANK         : string := "UP";
    OUTPUT_COUNT : positive := 1--;
);
port (
    i_clk              : in  std_logic;
    i_rst              : in  std_logic;
    i_sc_clk           : in  std_logic;
    i_sc_reset_n       : in  std_logic;
    i_sc_reg_addr      : in  std_logic_vector(1 downto 0);
    i_sc_reg_re        : in  std_logic;
    o_sc_reg_rdata     : out std_logic_vector(31 downto 0);
    i_sc_reg_we        : in  std_logic;
    i_sc_reg_wdata     : in  std_logic_vector(31 downto 0);
    i_subdet_reset     : in  std_logic;
    i_run_state_125    : in  run_state_t;
    i_hit0             : in  t_hit_presort;
    i_hit1             : in  t_hit_presort;
    i_hit2             : in  t_hit_presort;
    i_hit3             : in  t_hit_presort;
    o_hit              : out t_v_hit_presort_div(2 downto 0);
    o_ingress_overflow : out std_logic_vector(31 downto 0);
    -- Passive histogram observation tap. There is deliberately no ready path
    -- back into this wrapper: an observer may only watch the merged Type1
    -- beat, never stall it. Leave unassociated on tops that carry no
    -- histogram.
    o_hist_valid       : out std_logic := '0';
    o_hist_data        : out std_logic_vector(38 downto 0) := (others => '0');
    o_hist_timestamp   : out std_logic_vector(47 downto 0) := (others => '0');
    o_hist_arrival     : out std_logic_vector(47 downto 0) := (others => '0');
    o_hist_latency     : out std_logic_vector(47 downto 0) := (others => '0');
    o_hist_error       : out std_logic := '0';
    -- Ingress occupancy for an end-of-run drain owner. mts_processor ties
    -- coe_debug_status_data to zero here, so its internal pipeline is not
    -- observable; this reports only what the wrapper itself knows.
    o_hist_ingress_busy : out std_logic := '0'
);
end entity;

architecture rtl of scifi_mts_wrapper is

    constant INPUT_COUNT_CONST        : positive := 4;
    constant OUTPUT_COUNT_MAX_CONST   : positive := 3;
    constant INGRESS_FIFO_ADDR_CONST  : positive := 8;
    constant OVERFLOW_MAX_CONST       : unsigned(31 downto 0) := (others => '1');
    constant CSR_CONTROL_WORD_CONST   : std_logic_vector(31 downto 0) := x"60000011";
    constant CSR_LATENCY_WORD_CONST   : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(2000, 32));

    type csr_state_t is (WRITING_CONTROL, WRITING_LATENCY, RUNNING);

    signal hit_inputs         : t_v_hit_presort(INPUT_COUNT_CONST - 1 downto 0);
    signal fifo_rdata         : t_v_hit_presort(INPUT_COUNT_CONST - 1 downto 0);
    signal fifo_we            : std_logic_vector(INPUT_COUNT_CONST - 1 downto 0);
    signal fifo_wfull         : std_logic_vector(INPUT_COUNT_CONST - 1 downto 0);
    signal fifo_rempty        : std_logic_vector(INPUT_COUNT_CONST - 1 downto 0);
    signal fifo_rack          : std_logic_vector(INPUT_COUNT_CONST - 1 downto 0);
    signal fifo_reset_n       : std_logic;
    signal ingress_overflow   : unsigned(31 downto 0);
    signal start_run_pending  : std_logic;
    signal run_state_last     : run_state_t;
    signal rr_lane            : unsigned(1 downto 0);
    signal selected_lane      : integer range 0 to INPUT_COUNT_CONST - 1;
    signal selected_lane_valid: std_logic;
    signal selected_hit       : t_hit_presort;
    signal hit_in_valid       : std_logic;
    signal hit_in_ready       : std_logic;
    signal hit_in_channel     : std_logic_vector(5 downto 0);
    signal hit_in_data        : std_logic_vector(44 downto 0);
    signal hit_in_sop         : std_logic;
    signal end_run_pulse      : std_logic;
    signal mts_ctrl_data      : std_logic_vector(8 downto 0);
    signal mts_ctrl_valid     : std_logic;
    signal csr_state          : csr_state_t;
    signal mts_csr_readdata   : std_logic_vector(31 downto 0);
    signal mts_csr_waitrequest: std_logic;
    signal mts_csr_read       : std_logic;
    signal mts_csr_write      : std_logic;
    signal mts_csr_address    : std_logic_vector(2 downto 0);
    signal mts_csr_writedata  : std_logic_vector(31 downto 0);
    signal boot_csr_write     : std_logic;
    signal boot_csr_address   : std_logic_vector(2 downto 0);
    signal boot_csr_writedata : std_logic_vector(31 downto 0);
    signal sc_csr_read        : std_logic;
    signal sc_csr_write       : std_logic;
    signal sc_csr_address     : std_logic_vector(2 downto 0);
    signal sc_csr_writedata   : std_logic_vector(31 downto 0);
    signal hit_out_channel    : std_logic_vector(3 downto 0);
    signal hit_out_sop        : std_logic;
    signal hit_out_eop        : std_logic;
    signal hit_out_data       : std_logic_vector(38 downto 0);
    signal hit_out_valid      : std_logic;
    signal hit_out_empty      : std_logic;
    signal hit_out_error      : std_logic;
    signal hit_out_accept     : std_logic;
    signal output_lane        : unsigned(1 downto 0);

    -- MTS co-samples these two 48-bit words with the hit_out beat: the true
    -- hit timestamp and this bank's arrival GTS. Both were previously left
    -- open. mts_processor has no latency output, so the lifetime is formed
    -- here as arrival - timestamp.
    signal hit_out_timestamp  : std_logic_vector(47 downto 0);
    signal hit_out_arrival    : std_logic_vector(47 downto 0);

    signal hist_valid_q       : std_logic := '0';
    signal hist_data_q        : std_logic_vector(38 downto 0) := (others => '0');
    signal hist_timestamp_q   : std_logic_vector(47 downto 0) := (others => '0');
    signal hist_arrival_q     : std_logic_vector(47 downto 0) := (others => '0');
    signal hist_latency_q     : std_logic_vector(47 downto 0) := (others => '0');
    signal hist_error_q       : std_logic := '0';

begin

    assert (OUTPUT_COUNT >= 1 and OUTPUT_COUNT <= OUTPUT_COUNT_MAX_CONST)
        report "scifi_mts_wrapper OUTPUT_COUNT must be 1..3"
        severity failure;

    o_ingress_overflow <= std_logic_vector(ingress_overflow);
    hit_inputs(0) <= i_hit0;
    hit_inputs(1) <= i_hit1;
    hit_inputs(2) <= i_hit2;
    hit_inputs(3) <= i_hit3;
    fifo_reset_n <= '0' when (
        i_rst = '1'
        or i_subdet_reset = '1'
        or i_run_state_125 = RUN_STATE_PREP
        or i_run_state_125 = RUN_STATE_SYNC
    ) else '1';

    mts_csr_read      <= sc_csr_read when csr_state = RUNNING else '0';
    mts_csr_write     <= sc_csr_write when csr_state = RUNNING else boot_csr_write;
    mts_csr_address   <= sc_csr_address when csr_state = RUNNING else boot_csr_address;
    mts_csr_writedata <= sc_csr_writedata when csr_state = RUNNING else boot_csr_writedata;

    selected_hit <= fifo_rdata(selected_lane);
    hit_in_valid <= selected_lane_valid;
    hit_in_sop <= selected_lane_valid;
    hit_in_channel <= selected_hit.asic(1 downto 0) & "00" & selected_hit.asic(1 downto 0);

    hit_in_data(44 downto 41) <= selected_hit.asic;
    hit_in_data(40 downto 36) <= selected_hit.channel;
    hit_in_data(35 downto 21) <= selected_hit.T_CC;
    hit_in_data(20 downto 16) <= selected_hit.T_Fine;
    hit_in_data(15 downto  1) <= selected_hit.E_CC;
    hit_in_data(0)            <= selected_hit.E_Flag;
    hit_out_accept <= '1' when (hit_out_valid = '1' and hit_out_empty = '0') else '0';

    -- Register the whole observation bundle in one stage so payload, both
    -- 48-bit words and the lifetime stay mutually aligned, and so the 48-bit
    -- subtract owns a full clock period instead of extending the observer's
    -- combinational cone. This is an observation-only delay: it shifts when a
    -- hit is seen, never the timestamps carried in it.
    o_hist_ingress_busy <= '1' when (
        fifo_rempty /= (fifo_rempty'range => '1')
        or hit_in_valid = '1'
        or end_run_pulse = '1'
        or start_run_pending = '1'
    ) else '0';

    o_hist_valid     <= hist_valid_q;
    o_hist_data      <= hist_data_q;
    o_hist_timestamp <= hist_timestamp_q;
    o_hist_arrival   <= hist_arrival_q;
    o_hist_latency   <= hist_latency_q;
    o_hist_error     <= hist_error_q;

    proc_hist_tap : process (i_clk)
    begin
    if rising_edge(i_clk) then
        if (i_rst = '1') then
            hist_valid_q     <= '0';
            hist_data_q      <= (others => '0');
            hist_timestamp_q <= (others => '0');
            hist_arrival_q   <= (others => '0');
            hist_latency_q   <= (others => '0');
            hist_error_q     <= '0';
        else
            hist_valid_q <= hit_out_accept;
            -- Hold the payload between beats so a downstream observer reading
            -- a stale word without valid cannot see a torn bundle.
            if (hit_out_accept = '1') then
                hist_data_q      <= hit_out_data;
                hist_timestamp_q <= hit_out_timestamp;
                hist_arrival_q   <= hit_out_arrival;
                hist_latency_q   <= std_logic_vector(
                    unsigned(hit_out_arrival) - unsigned(hit_out_timestamp)
                );
                hist_error_q     <= hit_out_error;
            end if;
        end if;
    end if;
    end process;

    gen_ingress_fifo : for k in 0 to INPUT_COUNT_CONST - 1 generate
    begin
        fifo_we(k) <= '1' when (
            i_run_state_125 = RUN_STATE_RUNNING
            and hit_inputs(k).valid = '1'
            and fifo_wfull(k) = '0'
        ) else '0';

        fifo_rack(k) <= '1' when (
            selected_lane_valid = '1'
            and selected_lane = k
            and hit_in_ready = '1'
        ) else '0';

        e_ingress_fifo : entity work.mutrig_rec1_scfifo
        generic map (
            g_ADDR_WIDTH => INGRESS_FIFO_ADDR_CONST,
            g_WREG_N => 0,
            g_RREG_N => 0--,
        )
        port map (
            i_we           => fifo_we(k),
            i_wdata        => hit_inputs(k),
            o_wfull        => fifo_wfull(k),
            o_wfull_n      => open,
            o_almost_full  => open,
            i_rack         => fifo_rack(k),
            o_rdata        => fifo_rdata(k),
            o_rempty       => fifo_rempty(k),
            o_rempty_n     => open,
            o_almost_empty => open,
            o_usedw        => open,
            i_reset_n      => fifo_reset_n,
            i_clk          => i_clk
        );
    end generate;

    proc_rr_select : process (all) -- input arbitration is Round-robin
        variable lane_v  : integer range 0 to INPUT_COUNT_CONST - 1;
        variable index_v : integer range 0 to INPUT_COUNT_CONST - 1;
        variable found_v : std_logic;
    begin
        lane_v := to_integer(rr_lane);
        found_v := '0';
        for offset in 0 to INPUT_COUNT_CONST - 1 loop
            index_v := (to_integer(rr_lane) + offset) mod INPUT_COUNT_CONST;
            if (found_v = '0' and fifo_rempty(index_v) = '0') then
                lane_v := index_v;
                found_v := '1';
            end if;
        end loop;
        selected_lane <= lane_v;
        selected_lane_valid <= found_v;
    end process;

    proc_ingress_control : process (i_clk, i_rst) -- we do not mask here, we mask outside
        variable drop_count_v : unsigned(2 downto 0);
        variable drop_count_32_v : unsigned(31 downto 0);
    begin
        if (i_rst = '1') then
            ingress_overflow  <= (others => '0');
            start_run_pending <= '0';
            end_run_pulse     <= '0';
            run_state_last    <= (others => '0');
            rr_lane           <= (others => '0');
        elsif rising_edge(i_clk) then
            drop_count_v := (others => '0');
            end_run_pulse <= '0';

            for k in 0 to INPUT_COUNT_CONST - 1 loop
                if (
                    i_run_state_125 = RUN_STATE_RUNNING
                    and hit_inputs(k).valid = '1'
                    and fifo_wfull(k) = '1' -- TODO: do a uvm directed test on this condition
                ) then
                    drop_count_v := drop_count_v + 1; -- small per cycle counter
                end if;
            end loop;

            if (drop_count_v /= 0) then
                drop_count_32_v := resize(drop_count_v, drop_count_32_v'length); -- update the main counter with the incr amount
                if (ingress_overflow <= OVERFLOW_MAX_CONST - drop_count_32_v) then
                    ingress_overflow <= ingress_overflow + drop_count_32_v;
                else
                    ingress_overflow <= OVERFLOW_MAX_CONST; -- overflow protection, TODO: run uvm for this corner case
                end if;
            end if;

            if (i_run_state_125 = RUN_STATE_RUNNING and run_state_last /= RUN_STATE_RUNNING) then
                start_run_pending <= '1';
            end if;

            if (run_state_last = RUN_STATE_RUNNING and i_run_state_125 /= RUN_STATE_RUNNING) then
                end_run_pulse <= '1';
            end if;

            if (selected_lane_valid = '1' and hit_in_ready = '1') then
                rr_lane <= to_unsigned((selected_lane + 1) mod INPUT_COUNT_CONST, rr_lane'length);
                start_run_pending <= '0';
            end if;

            if (
                i_subdet_reset = '1'
                or i_run_state_125 = RUN_STATE_PREP
                or i_run_state_125 = RUN_STATE_SYNC
            ) then
                start_run_pending <= '0';
                end_run_pulse     <= '0';
                rr_lane           <= (others => '0');
            end if;

            run_state_last <= i_run_state_125;
        end if;
    end process;

    -- demux from 1 : 3 for adaptation of the hitsorter; for rbcam, we will not need this
    proc_output_demux : process (i_clk, i_rst)
    begin
        if (i_rst = '1') then
            output_lane <= (others => '0');
        elsif rising_edge(i_clk) then
            if (
                i_subdet_reset = '1'
                or i_run_state_125 = RUN_STATE_PREP
                or i_run_state_125 = RUN_STATE_SYNC
            ) then
                output_lane <= (others => '0');
            elsif (hit_out_accept = '1') then -- simple RR
                if (OUTPUT_COUNT <= 1 or to_integer(output_lane) >= OUTPUT_COUNT - 1) then
                    output_lane <= (others => '0');
                else
                    output_lane <= output_lane + 1;
                end if;
            end if;
        end if;
    end process;

    -- FEB run_state_t bits 0..8 match the MTS one-hot command order:
    -- IDLE, PREP/RUN_PREPARE, SYNC, RUNNING, TERMINATING, LINK_TEST,
    -- SYNC_TEST, RESET, OUT_OF_DAQ. The reset-link STOP_RESET command
    -- is represented upstream by the transition from RESET back to IDLE.
    mts_ctrl_data <= RUN_STATE_RESET(8 downto 0) when i_subdet_reset = '1' else i_run_state_125(8 downto 0);
    mts_ctrl_valid <= '1'; -- yifeng: from mts IP side, tie to vcc is fine

    -- below is a simple wrapper for the mu3e sc, just a clean timing thing for a 1 dword access, if we want to upgrade for burst, we can do more careful as following suggest/
    proc_csr_bootstrap : process (i_clk, i_rst) -- yifeng: this should be correct at first glance, but we shall add more random test. very likely a bug can happen for skewed read if burst is not aligned to boundary.
    begin
        if (i_rst = '1') then
            csr_state         <= WRITING_CONTROL;
            boot_csr_write     <= '0';
            boot_csr_address   <= (others => '0');
            boot_csr_writedata <= (others => '0');
        elsif rising_edge(i_clk) then
            boot_csr_write <= '0';
            case csr_state is
                when WRITING_CONTROL =>
                    boot_csr_write     <= '1';
                    boot_csr_address   <= "000";
                    boot_csr_writedata <= CSR_CONTROL_WORD_CONST;
                    csr_state         <= WRITING_LATENCY;
                when WRITING_LATENCY =>
                    boot_csr_write     <= '1';
                    boot_csr_address   <= "010";
                    boot_csr_writedata <= CSR_LATENCY_WORD_CONST;
                    csr_state         <= RUNNING;
                when RUNNING =>
                    null;
            end case;
        end if;
    end process;

    -- simple CDC stage, does not support burst yet
    e_mu3e_csr_adapter : entity work.mu3e_mts_csr_adapter
    port map (
        i_mu3e_clk             => i_sc_clk,
        i_mu3e_reset_n         => i_sc_reset_n,
        i_mu3e_reg_addr        => i_sc_reg_addr,
        i_mu3e_reg_re          => i_sc_reg_re,
        o_mu3e_reg_rdata       => o_sc_reg_rdata,
        i_mu3e_reg_we          => i_sc_reg_we,
        i_mu3e_reg_wdata       => i_sc_reg_wdata,

        i_mts_clk              => i_clk,
        i_mts_reset_n          => not i_rst,
        i_mts_csr_readdata     => mts_csr_readdata,
        o_mts_csr_read         => sc_csr_read,
        o_mts_csr_address      => sc_csr_address,
        i_mts_csr_waitrequest  => mts_csr_waitrequest,
        o_mts_csr_write        => sc_csr_write,
        o_mts_csr_writedata    => sc_csr_writedata
    );

    -- this is ok for scifi, but please check it
    proc_output_adapter : process (all)
        variable rec_v  : t_hit_presort_div;
        variable hits_v : t_v_hit_presort_div(2 downto 0);
        variable lane_v : integer;
    begin
        rec_v := t_hit_presort_div_zero;
        hits_v := (others => t_hit_presort_div_zero);
        lane_v := 0;
        if (hit_out_accept = '1') then
            rec_v.asic     := hit_out_data(38 downto 35);
            rec_v.channel  := hit_out_data(34 downto 30);
            rec_v.T_CC_div := hit_out_data(29 downto 17);
            rec_v.T_CC_rem := hit_out_data(16 downto 14);
            rec_v.T_Fine   := hit_out_data(13 downto 9);
            -- [mts-int] energy-time from MTS O_ET1n6 (phase-1): zero-extend 9-bit E-T into the legacy energy field.
            rec_v.E_CC(8 downto 0) := hit_out_data(8 downto 0);
            -- [mts-int] energy-time from MTS O_ET1n6 (phase-1): no EFlag sideband exists, so nonzero clean E-T marks valid energy.
            if (hit_out_error = '0' and hit_out_data(8 downto 0) /= "000000000") then
                rec_v.E_Flag := '1';
            end if;
            rec_v.valid := '1';
            lane_v := to_integer(output_lane); -- demux from 1:3
            if (lane_v >= OUTPUT_COUNT or lane_v >= OUTPUT_COUNT_MAX_CONST) then
                lane_v := 0;
            end if;
            hits_v(lane_v) := rec_v;
        end if;
        o_hit <= hits_v;
    end process;


    -- the main IP
    e_mts_processor : entity work.mts_processor
    generic map (
        BANK                                => BANK,
        ENABLED_CHANNEL_LO                  => 0,
        ENABLED_CHANNEL_HI                  => 3,
        LPM_DIV_PIPELINE                    => 4, -- the div by 5 is large thing for 48 bit-48 bit, not DSP, can change for timing, but it might break the internal pipeline
        MUTRIG_BUFFER_EXPECTED_LATENCY_8N   => 2000, -- this is good estimation as supported by the measurement result. note: for long format we need 1550*2
        MUTRIG_OVERFLOW_LOOKBACK_8N         => 2000, -- this should be removed or further justified
        DEBUG                               => 1
    )
    port map (
        avs_csr_readdata                    => mts_csr_readdata,
        avs_csr_read                        => mts_csr_read,
        avs_csr_address                     => mts_csr_address,
        avs_csr_waitrequest                 => mts_csr_waitrequest,
        avs_csr_write                       => mts_csr_write,
        avs_csr_writedata                   => mts_csr_writedata,
        asi_hit_type0_channel               => hit_in_channel,
        asi_hit_type0_startofpacket         => hit_in_sop,
        asi_hit_type0_endofpacket           => end_run_pulse,
        asi_hit_type0_endofrun              => end_run_pulse, -- TODO: handle this nicely
        asi_hit_type0_error                 => (others => '0'),
        asi_hit_type0_data                  => hit_in_data,
        asi_hit_type0_valid                 => hit_in_valid,
        asi_hit_type0_ready                 => hit_in_ready,
        coe_hit_type0_sidecar_data          => (others => '0'),
        coe_hit_type0_sidecar_valid         => '0',
        aso_hit_type1_channel               => hit_out_channel,
        aso_hit_type1_startofpacket         => hit_out_sop,
        aso_hit_type1_endofpacket           => hit_out_eop,
        aso_hit_type1_data                  => hit_out_data,
        aso_hit_type1_valid                 => hit_out_valid,
        aso_hit_type1_ready                 => '1',
        aso_hit_type1_empty                 => hit_out_empty, -- not used
        aso_hit_type1_error                 => hit_out_error, -- some hint on hit timestamp wrong
        aso_hit_type1_extended_0_data       => open,
        aso_hit_type1_extended_0_valid      => open,
        aso_hit_type1_extended_1_data       => open,
        aso_hit_type1_extended_1_valid      => open,
        coe_hit_type1_ts                    => hit_out_timestamp,
        coe_hit_arrival_gts_8n              => hit_out_arrival,
        asi_ctrl_data                       => mts_ctrl_data,
        asi_ctrl_valid                      => mts_ctrl_valid,
        aso_debug_ts_valid                  => open,
        aso_debug_ts_data                   => open,
        aso_debug_burst_valid               => open,
        aso_debug_burst_data                => open,
        aso_ts_delta_valid                  => open,
        aso_ts_delta_data                   => open,
        coe_debug_status_data               => open,
        coe_hit_type1_sidecar_data          => open,
        coe_hit_type1_sidecar_valid         => open,
        i_rst                               => i_rst,
        i_clk                               => i_clk
    );

end architecture;
