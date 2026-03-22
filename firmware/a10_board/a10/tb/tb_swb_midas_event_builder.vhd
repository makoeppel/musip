library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use std.textio.all;
use ieee.std_logic_textio.all;

use work.util_slv.all;
use work.mudaq.all;


entity tb_swb_midas_event_builder is
end entity;

architecture TB of tb_swb_midas_event_builder is

    -- Input from merging (first board) or links (subsequent boards)
    signal clk, clk_fast, reset_n : std_logic;

    -- links and datageneration
    constant ckTime : time := 10 ns;
    constant ckTime_fast : time := 8 ns;
    file file_RESULTS : text;
    constant g_NLINKS_TOTL : integer := 1;
    constant g_NLINKS_DATA : integer := 12;
    constant W : integer := 8*32 + 8*6;
    signal slow_down_0, slow_down_1 : std_logic_vector(31 downto 0);
    signal gen_link, gen_link_reg : slv32_array_t(1 downto 0);
    signal gen_link_k : slv4_array_t(1 downto 0);
    signal gen_data, data : work.mu3e.link32_t;
    signal fifo_data : work.mu3e.link64_t;

    -- signals
    signal rx_q : slv38_array_t(g_NLINKS_TOTL-1 downto 0) := (others => (others => '0'));
    signal rx_ren, rx_rdempty, flush_request : std_logic;
    signal rempty, dma_wen : std_logic;
    signal dma_data : std_logic_vector(255 downto 0);
    signal dma_data_array : slv32_array_t(7 downto 0);

begin

    -- generate the clock
    process
    begin
        clk <= '0';
        wait for ckTime/2;
        clk <= '1';
        wait for ckTime/2;
    end process;

    process
    begin
        flush_request <= '0';
        wait for 10000 ns;
        flush_request <= '1';
        wait;
    end process;

    process
    begin
        reset_n <= '0';
        file_open(file_RESULTS, "memory_content.txt", write_mode);
        file_close(file_RESULTS);
        wait for 8 ns;
        reset_n <= '1';
        wait;
    end process;

    -- data generation and ts counter_ddr3
    slow_down_0 <= x"00000002";
    slow_down_1 <= x"00000003";

    --! we generate different sequences for the hit time:
    --! gen0: 3, 44, 55, 6, 77, 8, 9, AA, B, CC, DD, E, F
    --! gen1-63: 3, 4, 55, 66, 77, 88, 9, A, BB, CC, D, E, F
        --! data_generator_a10
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_data_gen_0 : entity work.data_generator_a10
    generic map (
        DATA_TYPE => MUPIX_HEADER_ID, -- SCIFI_HEADER_ID 
        go_to_sh => 3,
        go_to_trailer => 4--,
    )
    port map (
        i_enable    => '1',
        i_seed      => (others => '1'),
        o_data      => gen_data,
        i_slow_down => slow_down_0,
        o_state     => open,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );
    data(0) <= work.mu3e.to_link(gen_data.data, gen_data.datak);
    --! generate link_to_fifo_32
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------

    -- TODO: We should also use links_to_fifos here
    e_links_to_fifos : entity work.links_to_fifos
    generic map (
        g_LINK_N => 1--,
    )
    port map (
        i_rx            => data,
        i_rmask_n       => (others => '1'),

        i_lookup_ctrl   => (others => '1'),
        i_sync_enable   => '1',

        o_q             => fifo_data,
        i_ren           => rx_ren,
        o_rdempty       => rx_rdempty,

        o_counter       => o_link_to_fifo_cnt(g_NLINKS_DATA*13-1 downto 0),
        i_reset_n_cnt   => i_resets_n(RESET_BIT_SWB_COUNTERS),

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    e_swb_midas_event_builder : entity work.swb_midas_event_builder
    port map (
        i_rx            => fifo_data(0),
        i_rempty        => rx_rdempty,

        i_get_n_words   => (others => '1'),
        i_event_id      => (others => '1'),
        i_get_serial_number => (others => '1'),
        i_dmamemhalffull=> '0',
        i_wen           => '1',
        i_flush_request => flush_request,
        i_flush_test    => x"BCBCBBCBC",
        o_data          => dma_data,
        o_wen           => dma_wen,
        o_ren           => rx_ren,
        o_endofevent    => open,
        o_done          => open,
        o_state_out     => open,

        --! status counters
        --! 0: bank_builder_idle_not_header
        --! 1: bank_builder_skip_event_dma
        --! 2: bank_builder_ram_full
        --! 3: bank_builder_tag_fifo_full
        o_counters      => open,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    dma_data_array(0) <= dma_data(0*32 + 31 downto 0*32);
    dma_data_array(1) <= dma_data(1*32 + 31 downto 1*32);
    dma_data_array(2) <= dma_data(2*32 + 31 downto 2*32);
    dma_data_array(3) <= dma_data(3*32 + 31 downto 3*32);
    dma_data_array(4) <= dma_data(4*32 + 31 downto 4*32);
    dma_data_array(5) <= dma_data(5*32 + 31 downto 5*32);
    dma_data_array(6) <= dma_data(6*32 + 31 downto 6*32);
    dma_data_array(7) <= dma_data(7*32 + 31 downto 7*32);

    process
        variable v_OLINE : line;
    begin
        wait until rising_edge(clk);
            if ( dma_wen = '1' ) then
                file_open(file_RESULTS, "memory_content.txt", append_mode);
                for i in 0 to 7 loop
                    write(v_OLINE, work.util.to_hstring(dma_data_array(i)));
                    writeline(file_RESULTS, v_OLINE);
                end loop;
                file_close(file_RESULTS);
            end if;
    end process;

end architecture;
