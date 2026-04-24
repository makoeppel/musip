-- -----------------------------------------------------------------------------
-- File      : tb_swb_block_plain_replay.vhd
-- Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
-- Version   : 26.4.21
-- Date      : 20260421
-- Change    : Plain mixed-language SWB replay bench. This mirrors the
--             quartus_system-style deterministic harness: read replay vectors
--             from the basic reference flow, drive the narrow SWB wrapper,
--             capture the observed normalized DMA words, and leave semantic
--             hit comparison to the post-run checker.
-- -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use std.textio.all;
use std.env.all;

use work.util.all;

entity tb_swb_block_plain_replay is
generic (
    G_REPLAY_DIR             : string := ".";
    G_ACTUAL_OPQ_PATH        : string := "actual_opq_words.mem";
    G_ACTUAL_DMA_PATH        : string := "actual_dma_words.mem";
    G_USE_MERGE              : std_logic := '0';
    G_FEB_ENABLE_MASK_HEX    : string := "F";
    G_LOOKUP_CTRL_HEX        : string := "00000000";
    G_DMA_HALF_FULL_PERIOD_CYCLES : natural := 0;
    G_DMA_HALF_FULL_ASSERT_CYCLES : natural := 0;
    G_TIMEOUT_PADDING_CYCLES : natural := 300000;
    G_SETTLE_CYCLES          : natural := 16
);
end entity;

architecture rtl of tb_swb_block_plain_replay is

    constant C_CLK_PERIOD : time := 4 ns;
    constant C_DMA_PADDING_WORD : std_logic_vector(255 downto 0) := (others => '1');

    signal clk             : std_logic := '0';
    signal reset_n         : std_logic := '0';
    signal feb_data        : std_logic_vector(127 downto 0) := (others => '0');
    signal feb_datak       : std_logic_vector(15 downto 0) := (others => '0');
    signal feb_valid       : std_logic_vector(3 downto 0) := (others => '0');
    signal feb_err_desc    : std_logic_vector(11 downto 0) := (others => '0');
    signal feb_enable_mask : std_logic_vector(3 downto 0) := (others => '1');
    signal use_merge       : std_logic := G_USE_MERGE;
    signal enable_dma      : std_logic := '0';
    signal get_n_words     : std_logic_vector(31 downto 0) := (others => '0');
    signal lookup_ctrl     : std_logic_vector(31 downto 0) := (others => '0');
    signal dma_half_full   : std_logic := '0';
    signal opq_data        : std_logic_vector(31 downto 0);
    signal opq_datak       : std_logic_vector(3 downto 0);
    signal opq_valid       : std_logic;
    signal dma_data        : std_logic_vector(255 downto 0);
    signal dma_wren        : std_logic;
    signal end_of_event    : std_logic;
    signal dma_done        : std_logic;
    signal lane_done       : std_logic_vector(3 downto 0) := (others => '0');

    function hex_char_to_nibble(
        constant ch : character
    ) return std_logic_vector is
    begin
        case ch is
            when '0' => return "0000";
            when '1' => return "0001";
            when '2' => return "0010";
            when '3' => return "0011";
            when '4' => return "0100";
            when '5' => return "0101";
            when '6' => return "0110";
            when '7' => return "0111";
            when '8' => return "1000";
            when '9' => return "1001";
            when 'A' | 'a' => return "1010";
            when 'B' | 'b' => return "1011";
            when 'C' | 'c' => return "1100";
            when 'D' | 'd' => return "1101";
            when 'E' | 'e' => return "1110";
            when 'F' | 'f' => return "1111";
            when others =>
                report "Unsupported hex character '" & ch & "'" severity failure;
                return "0000";
        end case;
    end function;

    function hex_string_to_slv(
        constant text  : string;
        constant width : natural
    ) return std_logic_vector is
        variable result     : std_logic_vector(width - 1 downto 0) := (others => '0');
        variable nibble_idx : natural := 0;
    begin
        for idx in text'reverse_range loop
            exit when (nibble_idx * 4) >= width;
            result((nibble_idx * 4) + 3 downto nibble_idx * 4) := hex_char_to_nibble(text(idx));
            nibble_idx := nibble_idx + 1;
        end loop;
        return result;
    end function;

    constant C_FEB_ENABLE_MASK : std_logic_vector(3 downto 0) :=
        hex_string_to_slv(G_FEB_ENABLE_MASK_HEX, 4);
    constant C_LOOKUP_CTRL_WORD : std_logic_vector(31 downto 0) :=
        hex_string_to_slv(G_LOOKUP_CTRL_HEX, 32);

    function replay_path(
        constant replay_dir : string;
        constant leaf       : string
    ) return string is
    begin
        return replay_dir & "/" & leaf;
    end function;

    function lane_replay_path(
        constant replay_dir : string;
        constant lane       : natural
    ) return string is
    begin
        case lane is
            when 0 =>
                return replay_path(replay_dir, "lane0_ingress.mem");
            when 1 =>
                return replay_path(replay_dir, "lane1_ingress.mem");
            when 2 =>
                return replay_path(replay_dir, "lane2_ingress.mem");
            when 3 =>
                return replay_path(replay_dir, "lane3_ingress.mem");
            when others =>
                report "Unsupported lane index " & integer'image(lane)
                    severity failure;
                return replay_path(replay_dir, "lane0_ingress.mem");
        end case;
    end function;

    function normalize_dma_word(
        constant data_word : std_logic_vector(255 downto 0)
    ) return std_logic_vector is
        variable normalized : std_logic_vector(255 downto 0) := data_word;
    begin
        normalized(62 downto 58)    := (others => '0');
        normalized(126 downto 122)  := (others => '0');
        normalized(190 downto 186)  := (others => '0');
        normalized(254 downto 250)  := (others => '0');
        return normalized;
    end function;

    impure function count_hex_lines(
        constant fname : string
    ) return natural is
        file f          : text;
        variable fs     : file_open_status;
        variable l      : line;
        variable c      : character;
        variable ok     : boolean;
        variable count  : natural := 0;
    begin
        file_open(fs, f, fname, read_mode);
        assert fs = open_ok
            report "Unable to open replay file " & fname
            severity failure;

        while not endfile(f) loop
            readline(f, l);
            read(l, c, ok);
            if ok and c /= '#' then
                count := count + 1;
            end if;
        end loop;

        file_close(f);
        return count;
    end function;

begin

    clk <= not clk after C_CLK_PERIOD / 2;

    dut : entity work.swb_block_uvm_wrapper
    port map (
        clk             => clk,
        reset_n         => reset_n,
        feb_data        => feb_data,
        feb_datak       => feb_datak,
        feb_valid       => feb_valid,
        feb_err_desc    => feb_err_desc,
        feb_enable_mask => feb_enable_mask,
        use_merge       => use_merge,
        enable_dma      => enable_dma,
        get_n_words     => get_n_words,
        lookup_ctrl     => lookup_ctrl,
        dma_half_full   => dma_half_full,
        opq_data        => opq_data,
        opq_datak       => opq_datak,
        opq_valid       => opq_valid,
        dma_data        => dma_data,
        dma_wren        => dma_wren,
        end_of_event    => end_of_event,
        dma_done        => dma_done
    );

    proc_reset : process
    begin
        reset_n <= '0';
        feb_enable_mask <= C_FEB_ENABLE_MASK;
        lookup_ctrl <= (others => '0');
        dma_half_full <= '0';
        wait for 16 * C_CLK_PERIOD;
        wait until rising_edge(clk);
        reset_n <= '1';
        wait;
    end process;

    proc_dma_half_full : process
        variable phase_cycles  : natural := 0;
        variable active_cycles : natural := 0;
    begin
        dma_half_full <= '0';
        wait until reset_n = '1';

        if G_DMA_HALF_FULL_PERIOD_CYCLES = 0 then
            wait;
        end if;

        if G_DMA_HALF_FULL_ASSERT_CYCLES < G_DMA_HALF_FULL_PERIOD_CYCLES then
            active_cycles := G_DMA_HALF_FULL_ASSERT_CYCLES;
        else
            active_cycles := G_DMA_HALF_FULL_PERIOD_CYCLES;
        end if;

        loop
            wait until rising_edge(clk);
            if enable_dma /= '1' then
                dma_half_full <= '0';
                phase_cycles := 0;
            else
                if phase_cycles < active_cycles then
                    dma_half_full <= '1';
                else
                    dma_half_full <= '0';
                end if;

                if (phase_cycles + 1) >= G_DMA_HALF_FULL_PERIOD_CYCLES then
                    phase_cycles := 0;
                else
                    phase_cycles := phase_cycles + 1;
                end if;
            end if;
        end loop;
    end process;

    gen_lane_replay : for lane in 0 to 3 generate
    begin
        proc_lane_replay : process
            file replay_file          : text;
            variable fs               : file_open_status;
            variable l                : line;
            variable beat             : std_logic_vector(39 downto 0);
            variable good             : boolean;
            constant c_replay_path    : string := lane_replay_path(G_REPLAY_DIR, lane);
            constant c_data_hi        : natural := (lane + 1) * 32 - 1;
            constant c_data_lo        : natural := lane * 32;
            constant c_datak_hi       : natural := (lane + 1) * 4 - 1;
            constant c_datak_lo       : natural := lane * 4;
        begin
            feb_valid(lane)                    <= '0';
            feb_data(c_data_hi downto c_data_lo)   <= (others => '0');
            feb_datak(c_datak_hi downto c_datak_lo) <= (others => '0');
            feb_err_desc((lane + 1) * 3 - 1 downto lane * 3) <= (others => '0');
            lane_done(lane)                    <= '0';

            file_open(fs, replay_file, c_replay_path, read_mode);
            assert fs = open_ok
                report "Unable to open lane replay file " & c_replay_path
                severity failure;

            wait until reset_n = '1';
            -- Align replay launch to the SWB datapath reset domain, which is
            -- released one clock after the top-level wrapper reset.
            wait until rising_edge(clk);

            while not endfile(replay_file) loop
                readline(replay_file, l);
                read_hex(l, beat, good);
                next when not good;

                wait until rising_edge(clk);
                feb_valid(lane)                    <= beat(36);
                feb_datak(c_datak_hi downto c_datak_lo) <= beat(35 downto 32);
                feb_data(c_data_hi downto c_data_lo)   <= beat(31 downto 0);
                feb_err_desc((lane + 1) * 3 - 1 downto lane * 3) <= beat(39 downto 37);
            end loop;

            file_close(replay_file);

            wait until rising_edge(clk);
            feb_valid(lane)                    <= '0';
            feb_datak(c_datak_hi downto c_datak_lo) <= (others => '0');
            feb_data(c_data_hi downto c_data_lo)   <= (others => '0');
            feb_err_desc((lane + 1) * 3 - 1 downto lane * 3) <= (others => '0');
            lane_done(lane)                    <= '1';
            wait;
        end process;
    end generate;

    proc_check : process
        file opq_file                : text;
        variable opq_fs              : file_open_status;
        variable opq_line            : line;
        variable opq_word            : std_logic_vector(36 downto 0);
        file actual_file             : text;
        variable actual_fs           : file_open_status;
        variable actual_line         : line;
        variable dma_word_raw        : std_logic_vector(255 downto 0);
        variable recv_words          : natural := 0;
        variable padding_words       : natural := 0;
        variable timeout_cycles      : natural := 0;
        variable settle_cycles       : natural := 0;
        variable saw_end_of_event_v  : boolean := false;
        variable saw_dma_done_v      : boolean := false;
        variable output_complete_v   : boolean := false;
        variable expected_word_count : natural := 0;
        constant c_expected_path     : string := replay_path(G_REPLAY_DIR, "expected_dma_words.mem");
        constant c_actual_opq_path   : string := G_ACTUAL_OPQ_PATH;
        constant c_actual_path       : string := G_ACTUAL_DMA_PATH;
    begin
        expected_word_count := count_hex_lines(c_expected_path);
        get_n_words <= std_logic_vector(to_unsigned(expected_word_count, get_n_words'length));
        enable_dma  <= '0';

        file_open(actual_fs, actual_file, c_actual_path, write_mode);
        assert actual_fs = open_ok
            report "Unable to open actual DMA capture file " & c_actual_path
            severity failure;

        file_open(opq_fs, opq_file, c_actual_opq_path, write_mode);
        assert opq_fs = open_ok
            report "Unable to open actual OPQ capture file " & c_actual_opq_path
            severity failure;

        wait until reset_n = '1';
        wait until rising_edge(clk);
        if C_LOOKUP_CTRL_WORD /= x"00000000" then
            lookup_ctrl <= C_LOOKUP_CTRL_WORD;
            wait until rising_edge(clk);
            lookup_ctrl <= (others => '0');
            wait until rising_edge(clk);
        end if;
        enable_dma <= '1';

        timeout_cycles := (expected_word_count * 32) + G_TIMEOUT_PADDING_CYCLES;
        while timeout_cycles /= 0 loop
            wait until rising_edge(clk);

            if opq_valid = '1' then
                opq_word := '1' & opq_datak & opq_data;
                hwrite(opq_line, opq_word);
                writeline(opq_file, opq_line);
            end if;

            if dma_wren = '1' then
                dma_word_raw := dma_data;
                hwrite(actual_line, dma_word_raw);
                writeline(actual_file, actual_line);

                if dma_word_raw /= C_DMA_PADDING_WORD then
                    recv_words := recv_words + 1;
                else
                    padding_words := padding_words + 1;
                end if;

                if end_of_event = '1' then
                    saw_end_of_event_v := true;
                end if;
            end if;

            if dma_done = '1' then
                saw_dma_done_v := true;
                exit;
            end if;

            if expected_word_count = 0 and lane_done = "1111" then
                output_complete_v := true;
                exit;
            end if;

            if recv_words = expected_word_count and saw_end_of_event_v then
                output_complete_v := true;
                exit;
            end if;

            timeout_cycles := timeout_cycles - 1;
        end loop;

        while settle_cycles < G_SETTLE_CYCLES loop
            wait until rising_edge(clk);
            if opq_valid = '1' then
                opq_word := '1' & opq_datak & opq_data;
                hwrite(opq_line, opq_word);
                writeline(opq_file, opq_line);
            end if;
            if dma_wren = '1' then
                dma_word_raw := dma_data;
                hwrite(actual_line, dma_word_raw);
                writeline(actual_file, actual_line);

                if dma_word_raw /= C_DMA_PADDING_WORD then
                    recv_words := recv_words + 1;
                else
                    padding_words := padding_words + 1;
                end if;
                if end_of_event = '1' then
                    saw_end_of_event_v := true;
                end if;
            end if;
            if dma_done = '1' then
                saw_dma_done_v := true;
            end if;
            settle_cycles := settle_cycles + 1;
        end loop;

        if expected_word_count = 0 then
            output_complete_v := true;
        elsif recv_words = expected_word_count and saw_end_of_event_v then
            output_complete_v := true;
        end if;

        enable_dma <= '0';
        file_close(opq_file);
        file_close(actual_file);

        if output_complete_v and not saw_dma_done_v then
            report "DMA semantic completion observed without dma_done; accepting semantic close"
                severity note;
        end if;

        assert recv_words = expected_word_count
            report "Expected "
                & integer'image(expected_word_count)
                & " payload words but observed "
                & integer'image(recv_words)
            severity failure;

        if expected_word_count /= 0 then
            assert saw_end_of_event_v
                report "No end-of-event marker observed on DMA output"
                severity failure;
        else
            assert not saw_end_of_event_v
                report "Unexpected end-of-event marker observed for zero-word replay"
                severity failure;
        end if;

        report "PASS: tb_swb_block_plain_replay expected_words="
            & integer'image(expected_word_count)
            & " padding_words="
            & integer'image(padding_words)
            & " use_merge="
            & std_logic'image(use_merge)
            & " replay_dir="
            & G_REPLAY_DIR
            & " actual_dma_path="
            & c_actual_path
        severity note;

        finish;
        wait;
    end process;

end architecture;
