library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.util_slv.all;
use work.mudaq.all;
use work.mu3e.all;

entity tb_musip_mux_4_1 is
end entity;

architecture sim of tb_musip_mux_4_1 is

    constant c_LINK_N          : positive := 4;
    constant c_CLK_PERIOD      : time := 10 ns;
    constant c_MAX_CHECKED     : natural := 2000000;
    constant c_WATCHDOG_CYCLES : natural := 1000;
    constant c_EXP_DEPTH       : natural := 4096;

    signal clk             : std_logic := '0';
    signal reset_n         : std_logic := '0';

    signal rx              : link32_array_t(c_LINK_N-1 downto 0) := (others => LINK32_IDLE);
    signal rmask_n         : std_logic_vector(c_LINK_N-1 downto 0) := (others => '1');
    signal lookup_ctrl     : std_logic_vector(31 downto 0) := (others => '0');

    signal subh_cnt        : slv64_array_t(c_LINK_N-1 downto 0);
    signal hit_cnt         : slv64_array_t(c_LINK_N-1 downto 0);
    signal package_cnt     : slv64_array_t(c_LINK_N-1 downto 0);

    signal o_data          : std_logic_vector(255 downto 0);
    signal o_valid         : std_logic;

    type slv256_array_t is array (natural range <>) of std_logic_vector(255 downto 0);
    type slv64_local_array_t is array (natural range <>) of std_logic_vector(63 downto 0);
    type slv32_local_array_t is array (natural range <>) of std_logic_vector(31 downto 0);
    type slv16_local_array_t is array (natural range <>) of std_logic_vector(15 downto 0);
    type slv8_local_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
    type int_0_3_array_t is array (natural range <>) of integer range 0 to 3;
    type nat_array_t is array (natural range <>) of natural range 0 to 65535;

    type t_link_phase is (
        PH_IDLE_GAP,
        PH_SOP,
        PH_TS_HIGH,
        PH_TS_LOW,
        PH_STAGE2,
        PH_STAGE3,
        PH_SUBHDR,
        PH_HITS,
        PH_EOP,
        PH_POST_IDLE1,
        PH_POST_IDLE2
    );
    type t_link_phase_array is array (natural range <>) of t_link_phase;

    function lfsr_next(x : unsigned(15 downto 0)) return unsigned is
        variable v  : unsigned(15 downto 0) := x;
        variable fb : std_logic;
    begin
        fb := v(15) xor v(13) xor v(12) xor v(10);
        v  := v(14 downto 0) & fb;
        return v;
    end function;

    function make_expected_mupix_hit(
        ts_high             : std_logic_vector(31 downto 0);
        ts_low              : std_logic_vector(15 downto 0);
        last_subheader_time : std_logic_vector(7 downto 0);
        hit_data            : std_logic_vector(31 downto 0)
    ) return std_logic_vector is
        variable w : std_logic_vector(63 downto 0) := (others => '0');
    begin
        w(63)           := '0';
        w(62 downto 58) := (others => '0');
        w(57 downto 50) := hit_data(21 downto 14);
        w(49 downto 42) := hit_data(13 downto 6);
        w(41 downto 37) := hit_data(5 downto 1);
        w(36 downto 0)  := ts_high(20 downto 0) &
                           ts_low(15 downto 11) &
                           last_subheader_time(6 downto 0) &
                           hit_data(31 downto 28);
        return w;
    end function;

    function normalize_mupix_word256(w : std_logic_vector(255 downto 0)) return std_logic_vector is
        variable v : std_logic_vector(255 downto 0) := w;
    begin
        v(62 downto 58)   := (others => '0');
        v(126 downto 122) := (others => '0');
        v(190 downto 186) := (others => '0');
        v(254 downto 250) := (others => '0');
        return v;
    end function;

begin

    clk <= not clk after c_CLK_PERIOD/2;

    dut : entity work.musip_mux_4_1
    generic map (
        g_LINK_N => c_LINK_N
    )
    port map (
        i_rx            => rx,
        i_rmask_n       => rmask_n,
        i_lookup_ctrl   => lookup_ctrl,
        o_subh_cnt      => subh_cnt,
        o_hit_cnt       => hit_cnt,
        o_package_cnt   => package_cnt,
        o_data          => o_data,
        o_valid         => o_valid,
        i_reset_n       => reset_n,
        i_clk           => clk
    );

    master : process
        variable exp_mem         : slv256_array_t(0 to c_EXP_DEPTH-1) := (others => (others => '0'));
        variable exp_wr_ptr      : natural range 0 to c_EXP_DEPTH-1 := 0;
        variable exp_rd_ptr      : natural range 0 to c_EXP_DEPTH-1 := 0;
        variable exp_count       : natural range 0 to c_EXP_DEPTH := 0;

        variable part256         : slv256_array_t(0 to c_LINK_N-1) := (others => (others => '0'));
        variable idx256          : int_0_3_array_t(0 to c_LINK_N-1) := (others => 0);

        variable phase           : t_link_phase_array(0 to c_LINK_N-1);
        variable rand            : unsigned(15 downto 0) := x"ACE1";
        variable gap_left        : nat_array_t(0 to c_LINK_N-1) := (others => 0);
        variable hits_left       : nat_array_t(0 to c_LINK_N-1) := (others => 0);
        variable hit_index       : nat_array_t(0 to c_LINK_N-1) := (others => 0);

        variable ts_high_v       : slv32_local_array_t(0 to c_LINK_N-1);
        variable ts_low_v        : slv16_local_array_t(0 to c_LINK_N-1);
        variable subhdr_time_v   : slv8_local_array_t(0 to c_LINK_N-1);

        variable w               : link32_t;
        variable hit_word_v      : std_logic_vector(31 downto 0);
        variable hit64_v         : std_logic_vector(63 downto 0);
        variable tmp256          : std_logic_vector(255 downto 0);
        variable exp_word_v      : std_logic_vector(255 downto 0);
        variable dut_norm_v      : std_logic_vector(255 downto 0);
        variable exp_norm_v      : std_logic_vector(255 downto 0);

        variable checked_words   : natural := 0;
        variable pending_cycles  : natural := 0;

        procedure enqueue_expected_word(
            constant word256 : in std_logic_vector(255 downto 0)
        ) is
        begin
            assert exp_count < c_EXP_DEPTH
                report "Expected-output queue overflow"
                severity failure;

            exp_mem(exp_wr_ptr) := word256;

            if exp_wr_ptr = c_EXP_DEPTH - 1 then
                exp_wr_ptr := 0;
            else
                exp_wr_ptr := exp_wr_ptr + 1;
            end if;

            exp_count := exp_count + 1;
        end procedure;

        procedure queue_expected_hit(
            constant link_idx : in natural;
            constant hit64    : in std_logic_vector(63 downto 0)
        ) is
        begin
            tmp256 := part256(link_idx);
            tmp256((idx256(link_idx) + 1) * 64 - 1 downto idx256(link_idx) * 64) := hit64;

            if idx256(link_idx) = 3 then
                enqueue_expected_word(tmp256);
                part256(link_idx) := (others => '0');
                idx256(link_idx)  := 0;
            else
                part256(link_idx) := tmp256;
                idx256(link_idx)  := idx256(link_idx) + 1;
            end if;
        end procedure;

        procedure check_output is
        begin
            if o_valid = '1' then
                assert exp_count > 0
                    report "DUT produced output but expected queue is empty"
                    severity failure;

                exp_word_v := exp_mem(exp_rd_ptr);
                dut_norm_v := normalize_mupix_word256(o_data);
                exp_norm_v := normalize_mupix_word256(exp_word_v);

                assert dut_norm_v = exp_norm_v
                    report "Output mismatch. DUT=" & to_hstring(dut_norm_v) &
                           " EXP=" & to_hstring(exp_norm_v) &
                           " RAW_DUT=" & to_hstring(o_data) &
                           " RAW_EXP=" & to_hstring(exp_word_v)
                    severity failure;

                if exp_rd_ptr = c_EXP_DEPTH - 1 then
                    exp_rd_ptr := 0;
                else
                    exp_rd_ptr := exp_rd_ptr + 1;
                end if;

                exp_count := exp_count - 1;
                checked_words := checked_words + 1;
                pending_cycles := 0;

                report "Checked output word #" & integer'image(checked_words) &
                       " OK: " & to_hstring(dut_norm_v);

            elsif exp_count > 0 then
                pending_cycles := pending_cycles + 1;
                assert pending_cycles < c_WATCHDOG_CYCLES
                    report "Watchdog timeout: expected output pending too long. Queue count=" &
                           integer'image(exp_count)
                    severity failure;
            else
                pending_cycles := 0;
            end if;
        end procedure;

    begin
        rx          <= (others => LINK32_IDLE);
        rmask_n     <= (others => '1');
        lookup_ctrl <= (others => '0');

        for i in 0 to c_LINK_N-1 loop
            phase(i)         := PH_IDLE_GAP;
            gap_left(i)      := i;
            hits_left(i)     := 0;
            hit_index(i)     := 0;
            ts_high_v(i)     := (others => '0');
            ts_low_v(i)      := (others => '0');
            subhdr_time_v(i) := (others => '0');
        end loop;

        reset_n <= '0';
        wait for 5 * c_CLK_PERIOD;
        wait until rising_edge(clk);
        reset_n <= '1';

        report "Starting parallel randomized mux test";

        while checked_words < c_MAX_CHECKED loop
            wait until rising_edge(clk);

            for i in 0 to c_LINK_N-1 loop
                rx(i) <= LINK32_IDLE;
            end loop;

            for i in 0 to c_LINK_N-1 loop
                case phase(i) is
                    when PH_IDLE_GAP =>
                        if gap_left(i) = 0 then
                            rand := lfsr_next(rand);
                            hits_left(i) := to_integer(rand(7 downto 4));
                            hit_index(i) := 0;
                            ts_high_v(i) := std_logic_vector(to_unsigned(16#12000000# + i * 16#1000# + to_integer(rand(3 downto 0)), 32));
                            ts_low_v(i)  := std_logic_vector(to_unsigned(16#AB00# + i * 16#10# + to_integer(rand(11 downto 8)), 16));
                            subhdr_time_v(i) := std_logic_vector(to_unsigned(16#40# + i * 4 + to_integer(rand(15 downto 12)), 8));
                            phase(i) := PH_SOP;
                        else
                            gap_left(i) := gap_left(i) - 1;
                        end if;

                    when PH_SOP =>
                        w := LINK32_SOP;
                        w.data(31 downto 26) := MUPIX_HEADER_ID;
                        rx(i) <= w;
                        phase(i) := PH_TS_HIGH;

                    when PH_TS_HIGH =>
                        w := LINK32_ZERO;
                        w.data := ts_high_v(i);
                        rx(i) <= w;
                        phase(i) := PH_TS_LOW;

                    when PH_TS_LOW =>
                        w := LINK32_ZERO;
                        w.data := ts_low_v(i) & x"0000";
                        rx(i) <= w;
                        phase(i) := PH_STAGE2;

                    when PH_STAGE2 =>
                        w := LINK32_ZERO;
                        w.data := x"00000000";
                        rx(i) <= w;
                        phase(i) := PH_STAGE3;

                    when PH_STAGE3 =>
                        w := LINK32_ZERO;
                        w.data := x"00000000";
                        rx(i) <= w;
                        phase(i) := PH_SUBHDR;

                    when PH_SUBHDR =>
                        w := LINK_SBHDR;
                        w.data := subhdr_time_v(i) & x"000000";
                        rx(i) <= w;
                        phase(i) := PH_HITS;

                    when PH_HITS =>
                        if hits_left(i) = 0 then
                            phase(i) := PH_EOP;
                        else
                            hit_index(i) := hit_index(i) + 1;
                            hit_word_v := std_logic_vector(
                                to_unsigned(
                                    16#10000000# + (i * 16#01000000#) + (hit_index(i) * 16#1111#),
                                    32
                                )
                            );

                            w := LINK32_ZERO;
                            w.data := hit_word_v;
                            rx(i) <= w;

                            hit64_v := make_expected_mupix_hit(
                                ts_high_v(i),
                                ts_low_v(i),
                                subhdr_time_v(i),
                                hit_word_v
                            );
                            queue_expected_hit(i, hit64_v);

                            hits_left(i) := hits_left(i) - 1;
                        end if;

                    when PH_EOP =>
                        rx(i) <= LINK32_EOP;
                        phase(i) := PH_POST_IDLE1;

                    when PH_POST_IDLE1 =>
                        rx(i) <= LINK32_IDLE;
                        phase(i) := PH_POST_IDLE2;

                    when PH_POST_IDLE2 =>
                        rx(i) <= LINK32_IDLE;
                        rand := lfsr_next(rand);
                        gap_left(i) := to_integer(rand(9 downto 8));
                        phase(i) := PH_IDLE_GAP;
                end case;
            end loop;

            check_output;
        end loop;

        report "Main traffic finished, draining remaining expected queue";

        while exp_count > 0 loop
            wait until rising_edge(clk);
            for i in 0 to c_LINK_N-1 loop
                rx(i) <= LINK32_IDLE;
            end loop;
            check_output;
        end loop;

        report "TEST PASSED after " & integer'image(checked_words) & " checked words";
        stop;
        wait;
    end process;

end architecture;
