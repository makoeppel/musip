-------------------------------------------------------
--! @musip_mux_4_1.vhd
--! @brief the musip_mux_4_1 takes n input links and
--! stores them in FIFOs, converts the data into 64bits and 
--! mergers all hits from 16us into one package
--! Author: mkoepp@phys.ethz.ch
-------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;
use work.mudaq.all;
use work.mu3e.all;

entity musip_mux_4_1 is
generic (
    g_LINK_N : positive := 4
);
port (
    i_rx              : in  work.mu3e.link32_array_t(g_LINK_N-1 downto 0);
    i_rmask_n         : in  std_logic_vector(g_LINK_N-1 downto 0);

    i_lookup_ctrl     : in  std_logic_vector(31 downto 0);

    o_subh_cnt        : out slv64_array_t(g_LINK_N-1 downto 0) := (others => (others => '0'));
    o_hit_cnt         : out slv64_array_t(g_LINK_N-1 downto 0) := (others => (others => '0'));
    o_package_cnt     : out slv64_array_t(g_LINK_N-1 downto 0) := (others => (others => '0'));
    o_data            : out std_logic_vector(255 downto 0);
    o_valid           : out std_logic;

    i_reset_n         : in  std_logic;
    i_clk             : in  std_logic
);
end entity;

architecture arch of musip_mux_4_1 is

begin

    gen_links_to_256bit : for i in 0 to g_LINK_N-1 GENERATE

        -- in the next step we replace the local chipID to the global one, change the hit from 32bit to 64bit and store the data in another FIFO
        FEBChipID(i) <= "00" & i_rx(i).data(25 downto 22) when data_type(i) = MUPIX_HEADER_ID or data_type(i) = TILE_HEADER_ID else
                        "000" & i_rx(i).data(24 downto 22) when data_type(i) = SCIFI_HEADER_ID else
                        (others => '0');

        e_lookup : entity work.chip_lookup
        port map (
            i_fpgaID        => work.mudaq.link_36_to_std(i),
            i_FEBChipID     => FEBChipID(i),
            i_data_type     => data_type(i),

            i_lookup_ctrl   => i_lookup_ctrl,

            o_globalChipID  => globalChipID(i),

            i_reset_n       => local_resets_n(3),
            i_clk           => i_clk--,
        );

        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n /= '1' ) then
            rx_256(i) <= (others => '0');
            rx_valid(i) <= '0';
            data_type(i) <= (others => '0');
            package_stage(i) <= (others => '0');
            ts_high(i) <= (others => '0');
            ts_low(i) <= (others => '0');
            last_subheader_time(i) <= (others => '0');
            next_64bit_word(i) <= (others => '0');
            next_64bit_word_valid(i) <= '1';
            --
        elsif rising_edge(i_clk) then

            rx_valid(i) <= '0';
            next_64bit_word_valid(i) <= '1';

            if ( i_rx(i).idle = '0' and i_rmask_n(i) = '1' ) then
                if ( i_rx(i).sop = '1' ) then
                    we_write_this_package(i) <= '1';
                    -- store package type
                    data_type(i) <= i_rx(i).data(31 downto 26);
                end if;

                if ( we_write_this_package(i) = '1' ) then
                    if ( package_stage(i) = "000" ) then
                        ts_high(i) <= i_rx(i).data;
                        package_stage(i) <= "001";
                    elsif ( package_stage(i) = "001" ) then
                        ts_low(i) <= i_rx(i).data(31 downto 16);
                        package_stage(i) <= "010";
                    elsif ( package_stage(i) = "010" ) then
                        package_stage(i) <= "011";
                    elsif ( package_stage(i) = "011" ) then
                        package_stage(i) <= "100";
                    elsif ( i_rx(i).eop = '1' ) then
                        o_package_cnt(i) <= o_package_cnt(i) + '1';
                        we_write_this_package(i) <= '0';
                    elsif ( i_rx(i).sbhdr = '1' ) then
                        o_subh_cnt(i) <= o_subh_cnt(i) + '1';
                        last_subheader_time(i) <= i_rx(i).data(31 downto 24);
                    else
                        -- count hits per FEB
                        o_hit_cnt(i) <= o_hit_cnt(i) + '1';

                        next_64bit_word_valid(i) <= '1';

                        -- set 256bit data
                        if ( data_type(i) = MUPIX_HEADER_ID ) then
                            -- MuSiP-Pixel 64bit format
                            -- Bit 63           indication (0) for pixel data
                            next_64bit_word(i)(63) <= '0';
                            -- Bit 62:58        chipID (0-31)
                            next_64bit_word(i)(62 downto 58) <= globalChipID(i)(4 downto 0);
                            -- Bit 57:50        8 bit column
                            next_64bit_word(i)(57 downto 50) <= i_rx(i).data(21 downto 14);
                            -- Bit 49:42        8 bit row
                            next_64bit_word(i)(39 downto 32) <= i_rx(i).data(13 downto 6);
                            -- Bits 41:37       ToT (timestamp 2)
                            next_64bit_word(i)(41 downto 37) <= i_rx(i).data(5 downto 1);
                            -- Bits 36:0        Hit time (8ns overflow in 1000s)     21 +                       5 +                                  7 +                          4
                            next_64bit_word(i)(36 downto  0) <= ts_high(i)(20 downto 0) & ts_low(i)(15 downto 11) & last_subheader_time(i)(6 downto 0) & i_rx(i).data(31 downto 28);
                        elsif ( data_type(i) = SCIFI_HEADER_ID or data_type(i) = TILE_HEADER_ID ) then
                            -- MuSiP-MuTRiG 64bit format
                            -- Bit 63           indication (1) for mutrig data
                            next_64bit_word(i)(63) <= '1';
                            -- Bit 62:61        chipID (0-3)
                            next_64bit_word(i)(62 downto 61) <= globalChipID(i)(1 downto 0);
                            -- Bits 60:56       Channel ID
                            next_64bit_word(i)(60 downto 56) <= i_rx(i).data(21 downto 17);
                            -- Bits 55:47       E-T (0 for the short hit format and 0x1ff for the energy flag)
                            next_64bit_word(i)(55 downto 47) <= i_rx(i).data(8 downto 0);
                            -- Bits 46:44       Time in 1.6 ns reminder bit
                            next_64bit_word(i)(46 downto 44) <= i_rx(i).data(16 downto 14);
                            -- Bits 43:39        Fine time
                            next_64bit_word(i)(43 downto 39) <= i_rx(i).data(13 downto 9);
                            -- Bits 38:0         Hit time (8ns overflow in 4000s)   23 +                       4 +                      8 +                          4
                            next_64bit_word(i)(31 downto 8) <= ts_high(i)(22 downto 0) & ts_low(i)(15 downto 12) & last_subheader_time(i) & i_rx(i).data(31 downto 28);
                        end if;
                        end if;
                    end if;
                end if;
            end if;

    end generate;



    -- MUX 4 to 1
    p_mux : process(i_clk)
    begin
    if rising_edge(i_clk) then
        -- keep input data as it becomes available
        for i in i_data'range loop
            if ( s_select = i or (i_data(i).valid = '1') ) then
                s_data(i) <= i_data(i);
            end if;

            if ( i_mask(i) = '0' ) then
                s_data(i).valid <= '0';
            end if;
        end loop;

        -- select next
        if (s_select = NPORTS-1 or i_rst='1') then
            s_select <= 0;
        else
            s_select <= s_select+1;
        end if;
    end if;
    end process;

    o_data <= s_data(s_select);


    ----------------------------------------------------------------------------
    -- One 32-bit FIFO per input link
    ----------------------------------------------------------------------------
    gen_input_fifos : for i in 0 to g_LINK_N-1 generate
    begin
        e_buffer_package : entity work.link32_scfifo
        generic map (
            g_ADDR_WIDTH => 12
        )
        port map (
            i_wdata   => i_rx(i),
            i_we      => not i_rx(i).idle,
            o_wfull   => fifo_full(i),
            o_usedw   => fifo_usedw(i),

            o_rdata   => fifo_q(i),
            i_rack    => fifo_rack(i) or fifo_drop_old(i),
            o_rempty  => fifo_empty(i),

            i_reset_n => i_reset_n,
            i_clk     => i_clk
        );
    end generate;

    ----------------------------------------------------------------------------
    -- Main merger / decoder
    ----------------------------------------------------------------------------
    process(i_clk, i_reset_n)
        variable v_fifo_rack     : std_logic_vector(g_LINK_N-1 downto 0);
        variable v_fifo_drop_old : std_logic_vector(g_LINK_N-1 downto 0);
        variable v_sop_seen      : std_logic_vector(g_LINK_N-1 downto 0);

        variable v_data_out      : std_logic_vector(255 downto 0);
        variable v_slot_count    : integer range 0 to 4;
        variable lane_idx        : integer;
        variable hit64           : std_logic_vector(63 downto 0);

        variable v_hit_valid     : std_logic_vector(g_LINK_N-1 downto 0);
        variable v_hit_word      : t_data64_array(g_LINK_N-1 downto 0);
    begin
        if i_reset_n /= '1' then
            merger_state    <= ST_WAIT_SYNC;
            rr_ptr          <= (others => '0');
            data_out_r      <= (others => '0');
            wen_r           <= '0';
            dma_cnt_words_r <= (others => '0');

            fifo_rack       <= (others => '0');
            fifo_drop_old   <= (others => '0');
            sop_seen        <= (others => '0');
            hit_valid       <= (others => '0');

            for i in 0 to g_LINK_N-1 loop
                pkg_state(i)           <= PKG_WAIT_SOP;
                ts_high(i)             <= (others => '0');
                ts_low(i)              <= (others => '0');
                last_subheader_time(i) <= (others => '0');
                hit_word(i)            <= (others => '0');
            end loop;

        elsif rising_edge(i_clk) then
            v_fifo_rack     := (others => '0');
            v_fifo_drop_old := (others => '0');
            v_sop_seen      := sop_seen;
            v_hit_valid     := hit_valid;
            v_hit_word      := hit_word;

            wen_r           <= '0';
            v_data_out      := (others => '0');
            v_slot_count    := 0;

            --------------------------------------------------------------------
            -- Drop head when FIFO is full and a new input arrives
            --------------------------------------------------------------------
            for i in 0 to g_LINK_N-1 loop
                if fifo_full(i) = '1' and i_rx(i).idle = '0' then
                    v_fifo_drop_old(i) := '1';
                    o_fifo_full_cnt(i) <= std_logic_vector(unsigned(o_fifo_full_cnt(i)) + 1);
                end if;
            end loop;

            --------------------------------------------------------------------
            -- Stage 1: sync to SOP on all active links
            --------------------------------------------------------------------
            if merger_state = ST_WAIT_SYNC then
                for i in 0 to g_LINK_N-1 loop
                    if i_rmask_n(i) = '1' and fifo_empty(i) = '0' then
                        if fifo_q(i).sop = '1' then
                            v_sop_seen(i) := '1';
                        else
                            v_fifo_rack(i) := '1';
                        end if;
                    end if;
                end loop;

                if f_all_active_sop_seen(i_rmask_n, v_sop_seen) then
                    for i in 0 to g_LINK_N-1 loop
                        if i_rmask_n(i) = '1' and fifo_empty(i) = '0' and fifo_q(i).sop = '1' then
                            v_fifo_rack(i) := '1';
                            pkg_state(i)    <= PKG_TS_HIGH;
                        end if;
                    end loop;
                    merger_state <= ST_RUN;
                    v_sop_seen   := (others => '0');
                end if;
            end if;

            --------------------------------------------------------------------
            -- Stage 2: decode 32-bit packet stream into 64-bit hits
            --------------------------------------------------------------------
            if merger_state = ST_RUN then
                for i in 0 to g_LINK_N-1 loop
                    if i_rmask_n(i) = '1' and fifo_empty(i) = '0' and v_hit_valid(i) = '0' then
                        case pkg_state(i) is

                            when PKG_WAIT_SOP =>
                                if fifo_q(i).sop = '1' then
                                    v_fifo_rack(i) := '1';
                                    pkg_state(i)   <= PKG_TS_HIGH;
                                else
                                    v_fifo_rack(i) := '1';
                                end if;

                            when PKG_TS_HIGH =>
                                ts_high(i)      <= fifo_q(i).data;
                                v_fifo_rack(i)  := '1';
                                pkg_state(i)    <= PKG_TS_LOW;

                            when PKG_TS_LOW =>
                                ts_low(i)       <= fifo_q(i).data(31 downto 16);
                                v_fifo_rack(i)  := '1';
                                pkg_state(i)    <= PKG_D0;

                            when PKG_D0 =>
                                v_fifo_rack(i)  := '1';
                                pkg_state(i)    <= PKG_D1;

                            when PKG_D1 =>
                                v_fifo_rack(i)  := '1';
                                pkg_state(i)    <= PKG_PAYLOAD;

                            when PKG_PAYLOAD =>
                                if fifo_q(i).eop = '1' then
                                    v_fifo_rack(i) := '1';
                                    pkg_state(i)   <= PKG_WAIT_SOP;
                                    v_sop_seen(i)  := '0';

                                elsif fifo_q(i).sop = '1' then
                                    v_sop_seen(i)  := '1';

                                elsif fifo_q(i).sbhdr = '1' then
                                    last_subheader_time(i) <= fifo_q(i).data(31 downto 24);
                                    v_fifo_rack(i)         := '1';

                                else
                                    hit64 := (others => '0');

                                    if data_type(i) = MUPIX_HEADER_ID or data_type(i) = OUTER_HEADER_ID then
                                        -- MuPix PHIT
                                        hit64(63 downto 62) := "00";
                                        hit64(61 downto 48) := globalChipID(i);
                                        hit64(47 downto 40) := fifo_q(i).data(21 downto 14);
                                        hit64(39 downto 32) := fifo_q(i).data(13 downto 6);
                                        hit64(31 downto 27) := fifo_q(i).data(5 downto 1);
                                        hit64(26 downto 0)  :=
                                            ts_high(i)(10 downto 0) &
                                            ts_low(i)(15 downto 11) &
                                            last_subheader_time(i)(6 downto 0) &
                                            fifo_q(i).data(31 downto 28);

                                    elsif data_type(i) = SCIFI_HEADER_ID or data_type(i) = TILE_HEADER_ID then
                                        -- SciFi/Tile hit
                                        hit64(63 downto 61) := "000";
                                        hit64(60 downto 53) := globalChipID(i)(7 downto 0);
                                        hit64(52 downto 48) := fifo_q(i).data(21 downto 17);
                                        hit64(47 downto 41) := (others => '0');
                                        hit64(40 downto 32) := fifo_q(i).data(8 downto 0);
                                        hit64(31 downto 8)  :=
                                            ts_high(i)(7 downto 0) &
                                            ts_low(i)(15 downto 12) &
                                            last_subheader_time(i) &
                                            fifo_q(i).data(31 downto 28);
                                        hit64(7 downto 5)   := fifo_q(i).data(16 downto 14);
                                        hit64(4 downto 0)   := fifo_q(i).data(13 downto 9);
                                    end if;

                                    v_hit_word(i)  := hit64;
                                    v_hit_valid(i) := '1';
                                    v_fifo_rack(i) := '1';

                                    o_hit_in_cnt(i) <= std_logic_vector(unsigned(o_hit_in_cnt(i)) + 1);
                                end if;
                        end case;
                    end if;
                end loop;

                ----------------------------------------------------------------
                -- Stage 3: pack decoded 64-bit hits to 256-bit via round robin
                ----------------------------------------------------------------
                for k in 0 to g_LINK_N-1 loop
                    exit when v_slot_count = 4;

                    lane_idx := (to_integer(rr_ptr) + k) mod g_LINK_N;

                    if i_rmask_n(lane_idx) = '1' and v_hit_valid(lane_idx) = '1' then
                        case v_slot_count is
                            when 0 =>
                                v_data_out(63 downto 0) := v_hit_word(lane_idx);
                            when 1 =>
                                v_data_out(127 downto 64) := v_hit_word(lane_idx);
                            when 2 =>
                                v_data_out(191 downto 128) := v_hit_word(lane_idx);
                            when 3 =>
                                v_data_out(255 downto 192) := v_hit_word(lane_idx);
                            when others =>
                                null;
                        end case;

                        v_hit_valid(lane_idx) := '0';
                        v_slot_count := v_slot_count + 1;
                        o_hit_out_cnt(lane_idx) <= std_logic_vector(unsigned(o_hit_out_cnt(lane_idx)) + 1);
                    end if;
                end loop;

                if v_slot_count > 0 and i_dmamemhalffull = '0' and i_wen = '1' then
                    data_out_r      <= v_data_out;
                    wen_r           <= '1';
                    dma_cnt_words_r <= dma_cnt_words_r + 1;
                    rr_ptr          <= rr_ptr + 1;
                end if;

                -- optional resync: once all active links have reached next SOP
                if f_all_active_sop_seen(i_rmask_n, v_sop_seen) then
                    merger_state <= ST_WAIT_SYNC;
                end if;
            end if;

            fifo_rack     <= v_fifo_rack;
            fifo_drop_old <= v_fifo_drop_old;
            sop_seen      <= v_sop_seen;
            hit_valid     <= v_hit_valid;
            hit_word      <= v_hit_word;
        end if;
    end process;

    process(i_clk, i_reset_n)
    begin
    if i_reset_n = '0' then
        o_wen                  <= '0';
        done                   <= '0';
        o_endofevent           <= '0';
        word_counter_written   <= '0';
        o_state_out            <= x"A";
        cnt_skip_event_dma     <= (others => '0');
        serial_number          <= (others => '0');
        r_fifo_en              <= '0';
        is_error_q             <= '0';
        flush_request          <= '0';
        flush_reg              <= '0';
        r_ram_addr             <= (others => '1');
        event_last_ram_addr    <= (others => '0');
        event_counter_state    <= waiting;
        word_counter           <= (others => '0');
        o_dma_cnt_words        <= (others => '0');
        word_counter_endofevent<= (others => '0');
        cnt_4kb                <= (others => '0');

    elsif rising_edge(i_clk) then

        flush_reg <= i_flush_request;
        if (i_flush_request = '1' and flush_reg = '0') then
            flush_request <= '1';
        end if;

        r_fifo_en    <= '0';
        o_wen        <= '0';
        o_endofevent <= '0';

        if i_wen = '0' then
            word_counter         <= (others => '0');
            done                 <= '0';
            word_counter_written <= '0';
        end if;

        case event_counter_state is

            when waiting =>
                o_state_out <= x"1";

                if (i_wen = '1' and i_dmamemhalffull = '0' and flush_request = '1') then
                    flush_request       <= '0';
                    event_counter_state <= start_flushing;

                elsif (i_wen = '1' and tag_fifo_empty = '0' and unsigned(i_get_n_words) /= 0 and done = '0' and i_dmamemhalffull = '0') then
                    if word_counter_written = '0' then
                        word_counter         <= i_get_n_words;
                        serial_number        <= i_get_serial_number;
                        word_counter_written <= '1';
                    end if;

                    r_fifo_en           <= '1';
                    event_last_ram_addr <= r_fifo_data(10 downto 2);
                    is_error_q          <= r_fifo_data(11);
                    r_ram_addr          <= std_logic_vector(unsigned(r_ram_addr) + 1);
                    event_counter_state <= get_data;

                elsif tag_fifo_empty = '0' then
                    event_counter_state <= skip_event;
                    r_fifo_en           <= '1';
                    event_last_ram_addr <= r_fifo_data(10 downto 2);
                    is_error_q          <= r_fifo_data(11);
                    r_ram_addr          <= std_logic_vector(unsigned(r_ram_addr) + 1);
                    cnt_skip_event_dma  <= std_logic_vector(unsigned(cnt_skip_event_dma) + 1);
                end if;

            when get_data =>
                o_state_out <= x"2";
                o_wen <= i_wen;

                if unsigned(word_counter) /= 0 then
                    word_counter <= std_logic_vector(unsigned(word_counter) - 1);
                end if;

                word_counter_endofevent <= std_logic_vector(unsigned(word_counter_endofevent) + 1);
                event_counter_state     <= set_serial_number;
                r_ram_addr              <= std_logic_vector(unsigned(r_ram_addr) + 1);

            when set_serial_number =>
                o_state_out    <= x"3";
                serial_number  <= std_logic_vector(unsigned(serial_number) + 1);
                o_wen          <= i_wen;

                if unsigned(word_counter) /= 0 then
                    word_counter <= std_logic_vector(unsigned(word_counter) - 1);
                end if;

                word_counter_endofevent <= std_logic_vector(unsigned(word_counter_endofevent) + 1);
                event_counter_state     <= runing;

                if unsigned(r_ram_addr) = unsigned(event_last_ram_addr) - 1 then
                    if (is_error_q = '1' or unsigned(word_counter) = 0) then
                        event_counter_state <= wait_last_word;
                        cnt_4kb             <= (others => '0');
                    else
                        event_counter_state <= waiting;
                    end if;
                else
                    r_ram_addr <= std_logic_vector(unsigned(r_ram_addr) + 1);
                end if;

            when runing =>
                o_state_out <= x"4";
                o_wen       <= i_wen;

                if unsigned(word_counter) /= 0 then
                    word_counter <= std_logic_vector(unsigned(word_counter) - 1);
                end if;

                word_counter_endofevent <= std_logic_vector(unsigned(word_counter_endofevent) + 1);

                if unsigned(r_ram_addr) = unsigned(event_last_ram_addr) - 1 then
                    if (is_error_q = '1' or unsigned(word_counter) = 0) then
                        event_counter_state <= wait_last_word;
                        cnt_4kb             <= (others => '0');
                    else
                        event_counter_state <= waiting;
                    end if;
                else
                    r_ram_addr <= std_logic_vector(unsigned(r_ram_addr) + 1);
                end if;

            when start_flushing =>
                o_wen <= i_wen;
                event_counter_state <= wait_last_word;
                cnt_4kb <= (others => '0');

            when wait_last_word =>
                o_state_out         <= x"4";
                o_endofevent        <= '1';
                event_counter_state <= write_4kb_padding;

            when write_4kb_padding =>
                o_state_out <= x"5";

                if is_error_q = '1' then
                    is_error_q <= '0';
                else
                    o_wen <= i_wen;

                    if cnt_4kb = "01111111" then
                        done <= '1';
                        o_dma_cnt_words <= word_counter_endofevent;
                        event_counter_state <= waiting;
                    else
                        cnt_4kb <= std_logic_vector(unsigned(cnt_4kb) + 1);
                    end if;
                end if;

            when skip_event =>
                o_state_out <= x"6";
                if unsigned(r_ram_addr) = unsigned(event_last_ram_addr) - 1 then
                    event_counter_state <= waiting;
                else
                    r_ram_addr <= std_logic_vector(unsigned(r_ram_addr) + 1);
                end if;

            when others =>
                o_state_out <= x"7";
                event_counter_state <= waiting;

        end case;
    end if;
    end process;

    ----------------------------------------------------------------------------
    -- Outputs
    ----------------------------------------------------------------------------
    o_data          <= data_out_r;
    o_wen           <= wen_r;
    o_ren           <= '0';
    o_dma_cnt_words <= std_logic_vector(dma_cnt_words_r);
    o_serial_num    <= (others => '0');
    o_endofevent    <= '0';
    o_done          <= '0';

    with merger_state select
        o_state_out <= "0001" when ST_WAIT_SYNC,
                       "0010" when ST_RUN,
                       "0000" when others;

end architecture;