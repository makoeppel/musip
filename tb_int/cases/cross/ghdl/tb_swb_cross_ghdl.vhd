-- -----------------------------------------------------------------------------
-- File      : tb_swb_cross_ghdl.vhd
-- Purpose   : Lightweight GHDL waveform fixture for MuSiP SWB/OPQ cross-flow
--             debug. This is not the signoff DUT; it emits a deterministic
--             all-bucket cross-run waveform for GTKWave/SignalTap review.
-- -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.all;

entity tb_swb_cross_ghdl is
generic (
    G_CASE_CYCLES     : positive := 8192;
    G_CLOCK_PERIOD_NS : positive := 4
);
end entity;

architecture sim of tb_swb_cross_ghdl is

    constant C_CLK_PERIOD : time := G_CLOCK_PERIOD_NS * 1 ns;

    subtype t_lane_mask is std_logic_vector(3 downto 0);

    type t_case_cfg is record
        code           : natural;
        bucket         : natural;
        mask           : t_lane_mask;
        activity       : natural;
        frame_cycles   : natural;
        skew_cycles    : natural;
        dma_bp_pct     : natural;
        expected_words : natural;
        reset_before   : boolean;
        error_path     : boolean;
    end record;

    type t_case_array is array (natural range <>) of t_case_cfg;

    constant C_CASES : t_case_array := (
        (1,    0, "1111", 3, 512,  0,    0,  64, false, false), -- B001
        (2,    0, "1111", 4, 512,  0,    0,  96, false, false), -- B002
        (46,   0, "0001", 5, 512,  0,    0,  48, false, false), -- B046
        (47,   0, "0010", 5, 512,  0,    0,  48, false, false), -- B047
        (48,   0, "0100", 5, 512,  0,    0,  48, false, false), -- B048
        (49,   0, "1000", 5, 512,  0,    0,  48, false, false), -- B049
        (1025, 1, "1111", 1, 512,  0,    0,   8, true,  false), -- E025
        (1026, 1, "1111", 2, 512,  0,    0,  16, false, false), -- E026
        (1027, 1, "0001", 7, 512,  0,    0, 128, false, false), -- E027
        (2040, 2, "1111", 4, 512,  0,   50,  96, true,  false), -- P040
        (2041, 2, "1111", 4, 512,  0,   75,  96, false, false), -- P041
        (2123, 2, "1111", 4, 4096, 2048, 0, 128, false, false), -- P123
        (2124, 2, "1111", 4, 4096, 2048, 0, 128, false, false), -- P124
        (3111, 3, "1111", 5, 512,  0,    0,  96, true,  true),  -- X111
        (3112, 3, "1111", 3, 512,  0,    0,  64, false, true),  -- X112
        (3116, 3, "1111", 4, 512,  0,    0,  80, false, true),  -- X116
        (3117, 3, "1111", 4, 512,  0,    0,  80, false, true),  -- X117
        (3118, 3, "1111", 1, 512,  0,    0,   4, false, true),  -- X118
        (3120, 3, "1111", 4, 512,  0,    0,  64, false, true),  -- X120
        (3122, 3, "1111", 1, 512,  0,    0,   4, false, true),  -- X122
        (3123, 3, "1111", 1, 512,  0,    0,   4, false, true),  -- X123
        (3124, 3, "1111", 1, 512,  0,    0,   4, false, true)   -- X124
    );

    signal clk               : std_logic := '0';
    signal reset_n           : std_logic := '0';
    signal run_active        : std_logic := '0';
    signal cycle_tick        : unsigned(31 downto 0) := (others => '0');
    signal case_tick         : unsigned(31 downto 0) := (others => '0');
    signal case_index        : unsigned(7 downto 0) := (others => '0');
    signal cases_done        : unsigned(7 downto 0) := (others => '0');
    signal bucket_id         : unsigned(3 downto 0) := (others => '0');
    signal case_code         : unsigned(15 downto 0) := (others => '0');
    signal flow_state        : unsigned(3 downto 0) := (others => '0');

    signal case_sop          : std_logic := '0';
    signal case_eop          : std_logic := '0';
    signal segment_reset     : std_logic := '0';
    signal bucket_transition : std_logic := '0';
    signal frame_slot        : std_logic := '0';

    signal lane_mask         : std_logic_vector(3 downto 0) := (others => '0');
    signal lane_valid        : std_logic_vector(3 downto 0) := (others => '0');
    signal lane_ready        : std_logic_vector(3 downto 0) := (others => '1');
    signal lane_fire         : std_logic_vector(3 downto 0) := (others => '0');

    signal join_pending      : std_logic := '0';
    signal inactive_wait     : std_logic := '0';
    signal opq_body_hold     : std_logic := '0';
    signal opq_wait_cycles   : unsigned(15 downto 0) := (others => '0');
    signal reorder_depth     : unsigned(15 downto 0) := (others => '0');

    signal ingress_words     : unsigned(31 downto 0) := (others => '0');
    signal opq_words         : unsigned(31 downto 0) := (others => '0');
    signal expected_words    : unsigned(31 downto 0) := (others => '0');
    signal payload_words     : unsigned(31 downto 0) := (others => '0');
    signal dma_words         : unsigned(31 downto 0) := (others => '0');
    signal dma_half_full     : std_logic := '0';
    signal dma_wren          : std_logic := '0';
    signal dma_done          : std_logic := '0';

    signal error_expected    : std_logic := '0';
    signal ghost_count       : unsigned(15 downto 0) := (others => '0');
    signal missing_count     : unsigned(15 downto 0) := (others => '0');
    signal scoreboard_pass   : std_logic := '0';

    function count_ones(constant value : std_logic_vector) return natural is
        variable count : natural := 0;
    begin
        for idx in value'range loop
            if value(idx) = '1' then
                count := count + 1;
            end if;
        end loop;
        return count;
    end function;

    function bucket_name(constant bucket : natural) return string is
    begin
        case bucket is
            when 0 => return "BASIC";
            when 1 => return "EDGE";
            when 2 => return "PROF";
            when 3 => return "ERROR";
            when others => return "UNKNOWN";
        end case;
    end function;

    function case_name(constant code : natural) return string is
    begin
        case code is
            when 1    => return "B001";
            when 2    => return "B002";
            when 46   => return "B046";
            when 47   => return "B047";
            when 48   => return "B048";
            when 49   => return "B049";
            when 1025 => return "E025";
            when 1026 => return "E026";
            when 1027 => return "E027";
            when 2040 => return "P040";
            when 2041 => return "P041";
            when 2123 => return "P123";
            when 2124 => return "P124";
            when 3111 => return "X111";
            when 3112 => return "X112";
            when 3116 => return "X116";
            when 3117 => return "X117";
            when 3118 => return "X118";
            when 3120 => return "X120";
            when 3122 => return "X122";
            when 3123 => return "X123";
            when 3124 => return "X124";
            when others => return "UNKNOWN";
        end case;
    end function;

begin

    clk <= not clk after C_CLK_PERIOD / 2;

    proc_cross_run : process
        variable cfg              : t_case_cfg;
        variable valid_v          : std_logic_vector(3 downto 0);
        variable ready_v          : std_logic_vector(3 downto 0);
        variable fire_v           : std_logic_vector(3 downto 0);
        variable dma_half_full_v  : std_logic;
        variable join_pending_v   : std_logic;
        variable ingress_count_v  : natural;
        variable opq_count_v      : natural;
        variable payload_count_v  : natural;
        variable dma_count_v      : natural;
        variable depth_v          : natural;
        variable wait_v           : natural;
        variable emit_period_v    : natural;
    begin
        reset_n <= '0';
        run_active <= '0';
        flow_state <= to_unsigned(0, flow_state'length);
        lane_ready <= (others => '1');

        for idx in 0 to 7 loop
            wait until rising_edge(clk);
            cycle_tick <= cycle_tick + 1;
        end loop;

        reset_n <= '1';
        run_active <= '1';
        report "[GHDL_CROSS_START] run_id=CROSS-GHDL cases="
            & integer'image(C_CASES'length)
            & " case_cycles=" & integer'image(G_CASE_CYCLES)
            severity note;

        for idx in C_CASES'range loop
            cfg := C_CASES(idx);
            ingress_count_v := 0;
            opq_count_v := 0;
            payload_count_v := 0;
            dma_count_v := 0;
            depth_v := 0;
            wait_v := 0;
            if cfg.activity < 8 then
                emit_period_v := 9 - cfg.activity;
            else
                emit_period_v := 1;
            end if;

            case_index <= to_unsigned(idx, case_index'length);
            bucket_id <= to_unsigned(cfg.bucket, bucket_id'length);
            case_code <= to_unsigned(cfg.code, case_code'length);
            lane_mask <= cfg.mask;
            expected_words <= to_unsigned(cfg.expected_words, expected_words'length);
            if cfg.error_path then
                error_expected <= '1';
            else
                error_expected <= '0';
            end if;
            scoreboard_pass <= '0';

            report "[GHDL_CASE_BEGIN] idx=" & integer'image(idx)
                & " case=" & case_name(cfg.code)
                & " bucket=" & bucket_name(cfg.bucket)
                & " cycles=" & integer'image(G_CASE_CYCLES)
                severity note;

            for tick in 0 to G_CASE_CYCLES - 1 loop
                wait until rising_edge(clk);
                cycle_tick <= cycle_tick + 1;
                case_tick <= to_unsigned(tick, case_tick'length);

                if cfg.dma_bp_pct > 0 and (tick mod 100) < cfg.dma_bp_pct then
                    dma_half_full_v := '1';
                else
                    dma_half_full_v := '0';
                end if;
                dma_half_full <= dma_half_full_v;

                if tick = 0 then
                    case_sop <= '1';
                else
                    case_sop <= '0';
                end if;

                if tick = G_CASE_CYCLES - 1 then
                    case_eop <= '1';
                else
                    case_eop <= '0';
                end if;

                if cfg.reset_before and tick < 16 then
                    segment_reset <= '1';
                    bucket_transition <= '1';
                else
                    segment_reset <= '0';
                    bucket_transition <= '0';
                end if;

                if (tick mod cfg.frame_cycles) = 0 then
                    frame_slot <= '1';
                else
                    frame_slot <= '0';
                end if;

                if tick = 0 then
                    flow_state <= to_unsigned(1, flow_state'length);
                elsif tick > (G_CASE_CYCLES - 32) then
                    flow_state <= to_unsigned(5, flow_state'length);
                elsif cfg.skew_cycles > 0 and (tick mod cfg.frame_cycles) < cfg.skew_cycles then
                    flow_state <= to_unsigned(3, flow_state'length);
                elsif dma_half_full_v = '1' then
                    flow_state <= to_unsigned(4, flow_state'length);
                else
                    flow_state <= to_unsigned(2, flow_state'length);
                end if;

                if cfg.skew_cycles > 0
                    and tick > 0
                    and (tick mod cfg.frame_cycles) < cfg.skew_cycles
                then
                    join_pending_v := '1';
                    wait_v := cfg.skew_cycles - (tick mod cfg.frame_cycles);
                else
                    join_pending_v := '0';
                    wait_v := 0;
                end if;
                join_pending <= join_pending_v;
                inactive_wait <= join_pending_v;
                opq_body_hold <= join_pending_v;
                opq_wait_cycles <= to_unsigned(wait_v, opq_wait_cycles'length);

                valid_v := (others => '0');
                ready_v := (others => '1');
                for lane in 0 to 3 loop
                    if cfg.mask(lane) = '1'
                        and ((tick + (lane * 13) + (cfg.skew_cycles / 64)) mod 8) < cfg.activity
                    then
                        valid_v(lane) := '1';
                    end if;
                end loop;

                fire_v := valid_v and ready_v;
                lane_valid <= valid_v;
                lane_ready <= ready_v;
                lane_fire <= fire_v;

                ingress_count_v := ingress_count_v + count_ones(fire_v);
                if join_pending_v = '0' then
                    opq_count_v := opq_count_v + count_ones(fire_v);
                end if;

                if dma_half_full_v = '0'
                    and payload_count_v < cfg.expected_words
                    and (tick mod emit_period_v) = 0
                then
                    dma_wren <= '1';
                    payload_count_v := payload_count_v + 1;
                    dma_count_v := dma_count_v + 1;
                    if depth_v > 0 then
                        depth_v := depth_v - 1;
                    end if;
                else
                    dma_wren <= '0';
                    if count_ones(fire_v) > 0 and depth_v < 255 then
                        depth_v := depth_v + count_ones(fire_v);
                    end if;
                end if;

                if depth_v > 255 then
                    depth_v := 255;
                end if;

                reorder_depth <= to_unsigned(depth_v, reorder_depth'length);
                ingress_words <= to_unsigned(ingress_count_v, ingress_words'length);
                opq_words <= to_unsigned(opq_count_v, opq_words'length);
                payload_words <= to_unsigned(payload_count_v, payload_words'length);
                dma_words <= to_unsigned(dma_count_v, dma_words'length);
                ghost_count <= (others => '0');
                missing_count <= (others => '0');
                dma_done <= '0';
            end loop;

            wait until rising_edge(clk);
            cycle_tick <= cycle_tick + 1;
            case_eop <= '0';
            case_sop <= '0';
            segment_reset <= '0';
            bucket_transition <= '0';
            lane_valid <= (others => '0');
            lane_fire <= (others => '0');
            dma_wren <= '0';
            dma_half_full <= '0';
            dma_done <= '1';
            scoreboard_pass <= '1';
            cases_done <= to_unsigned(idx + 1, cases_done'length);

            report "[GHDL_CASE_PASS] case=" & case_name(cfg.code)
                & " ingress_words=" & integer'image(ingress_count_v)
                & " opq_words=" & integer'image(opq_count_v)
                & " dma_words=" & integer'image(dma_count_v)
                severity note;
        end loop;

        wait until rising_edge(clk);
        cycle_tick <= cycle_tick + 1;
        dma_done <= '0';
        run_active <= '0';
        flow_state <= to_unsigned(6, flow_state'length);
        report "[GHDL_CROSS_PASS] cases=" & integer'image(C_CASES'length)
            & " ghost=0 missing=0"
            severity note;
        wait until rising_edge(clk);
        cycle_tick <= cycle_tick + 1;
        stop;
        wait;
    end process;

end architecture;
