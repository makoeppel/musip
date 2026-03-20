-------------------------------------------------------
--! @swb_block.vhd
--! @brief the swb_block can be used
--! for the LCHb Board and the development board
--! mainly it includes the datapath which includes
--! merging hits from multiple FEBs. There will be
--! four types of SWB which differe accordingly to
--! the detector data they receive (inner pixel,
--! scifi, down and up stream pixel/tiles)
--! Author: mkoeppel@uni-mainz.de
-------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;
use work.a10_counters.all;

entity swb_block is
generic (
    g_NLINKS_FEB_TOTL       : integer := 12;
    g_NLINKS_DATA_GENERIC   : integer := 8;
    g_NLINKS_FARM_TOTL      : integer := 3;
    g_NLINKS_DATA_PIXEL_US  : integer := 5;
    g_NLINKS_DATA_PIXEL_DS  : integer := 5;
    -- needed for simulation
    g_SC_SEC_SKIP_INIT      : std_logic := '0'--;
);
port (
    --! links to/from FEBs
    i_feb_rx            : in  work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    o_feb_tx            : out work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    --! PCIe registers / memory
    i_writeregs         : in  slv32_array_t(63 downto 0) := (others => (others => '0'));
    i_regwritten        : in  std_logic_vector(63 downto 0) := (others => '0');
    o_readregs          : out slv32_array_t(63 downto 0) := (others => (others => '0'));
    i_resets_n          : in  std_logic_vector(31 downto 0) := (others => '0');

    i_wmem_rdata        : in  std_logic_vector(31 downto 0) := (others => '0');
    o_wmem_addr         : out std_logic_vector(15 downto 0) := (others => '0');

    o_rmem_wdata        : out std_logic_vector(31 downto 0) := (others => '0');
    o_rmem_addr         : out std_logic_vector(15 downto 0) := (others => '0');
    o_rmem_we           : out std_logic := '0';

    i_dmamemhalffull    : in  std_logic := '0';
    o_dma_wren          : out std_logic := '0';
    o_endofevent        : out std_logic := '0';
    o_dma_data          : out std_logic_vector(255 downto 0) := (others => '0');

    --! links to farm
    o_farm_tx           : out work.mu3e.link32_array_t(g_NLINKS_FARM_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    --! clock / reset_n
    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;

);
end entity;

--! @brief arch definition of the swb_block
--! @details The arch of the swb_block can be used
--! for the LCHb Board and the development board
--! mainly it includes the datapath which includes
--! merging hits from multiple FEBs. There will be
--! four types of SWB which differe accordingly to
--! the detector data they receive (inner pixel,
--! scifi, down and up stream pixel/tiles)
architecture arch of swb_block is

    --! masking signals
    signal mask_n : std_logic_vector(63 downto 0);

    --! feb links
    signal feb_rx : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    --! debug path
    signal farm_data_debug : work.mu3e.link64_array_t(g_NLINKS_FARM_TOTL-1 downto 0)  := (others => work.mu3e.LINK64_IDLE);
    signal data_debug : work.mu3e.link64_t;
    signal rempty_debug, builder_rack : std_logic := '1';
    signal farm_rack_debug, farm_empty_debug : std_logic_vector(g_NLINKS_FARM_TOTL-1 downto 0);

    --! demerged FEB links
    signal rx_data         : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0)   := (others => work.mu3e.LINK32_IDLE);
    signal rx_sc           : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0)   := (others => work.mu3e.LINK32_IDLE);
    signal rx_rc           : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0)   := (others => work.mu3e.LINK32_IDLE);

    --! counters
    signal counter_swb : slv32_array_t(96 * 4 - 1 downto 0) := (others => (others => '0'));
    signal counter_link_to_fifo : slv32_array_t(8*13*2-1 downto 0);

    --! histograms
    signal histo_selected_link : integer range 0 to g_NLINKS_FEB_TOTL-1;
    signal histo_select_chip   : integer range 0 to 127;
    signal histo_rx_selected   : work.mu3e.link32_t;

    signal data_path_reset_n : std_logic;

begin

    --! @brief data path of the SWB board
    --! @details the data path of the SWB board is first splitting the
    --! data from the FEBs into data, slow control and run control packages.
    --! The different paths are than assigned to the corresponding entities.
    --! The data is merged in time over all incoming FEBs. After this packages
    --! are build and the data is send of to the farm boars. The slow control
    --! data is saved in the PCIe memory and can be further used in the MIDAS
    --! system. The run control packages are used to control the run and give
    --! feedback to MIDAS if all FEBs started the run.

    --! counter readout
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    o_readregs(SWB_COUNTER_REGISTER_R) <= counter_swb(to_integer(unsigned(i_writeregs(SWB_COUNTER_REGISTER_W))));
    o_readregs(SWB_LINK_COUNTER_REGISTER_R) <= counter_link_to_fifo(to_integer(unsigned(i_writeregs(SWB_COUNTER_REGISTER_W))));


    --! demerge data
    --! three types of data will be extracted from the links
    --! data => detector data
    --! sc => slow control packages
    --! rc => runcontrol packages
    g_demerge: FOR i in g_NLINKS_FEB_TOTL-1 downto 0 GENERATE
        feb_rx(i) <= work.mu3e.to_link(i_feb_rx(i).data, i_feb_rx(i).datak);
        e_data_demerge : entity work.swb_data_demerger
        port map (
            i_aligned           => '1',
            i_data              => feb_rx(i),

            o_data              => rx_data(i),
            o_sc                => rx_sc(i),
            o_rc                => rx_rc(i),
            o_fpga_id           => open,

            i_reset_n           => i_resets_n(RESET_BIT_EVENT_COUNTER),
            i_clk               => i_clk--,
        );
    end generate;


    --! run control used by MIDAS
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_run_control : entity work.run_control
    generic map (
        g_LINKS              => g_NLINKS_FEB_TOTL--,
    )
    port map (
        i_reset_ack_seen_n     => i_resets_n(RESET_BIT_RUN_START_ACK),
        i_reset_run_end_n      => i_resets_n(RESET_BIT_RUN_END_ACK),
        -- TODO: Write out padding 4kB at MIDAS Bank Builder if run end is done
        -- TODO: connect buffers emtpy from dma here
        -- o_all_run_end_seen => MIDAS Builder => i_buffer_empty
        i_buffers_empty        => (others => '1'),
        o_feb_merger_timeout   => o_readregs(CNT_FEB_MERGE_TIMEOUT_R),
        i_aligned              => (others => '1'),
        i_data                 => rx_rc,
        i_link_enable          => i_writeregs(FEB_ENABLE_REGISTER_W),
        i_addr                 => i_writeregs(RUN_NR_ADDR_REGISTER_W), -- ask for run number of FEB with this addr.
        i_run_number           => i_writeregs(RUN_NR_REGISTER_W)(23 downto 0),
        o_run_number           => o_readregs(RUN_NR_REGISTER_R), -- run number of i_addr
        o_runNr_ack            => o_readregs(RUN_NR_ACK_REGISTER_R), -- which FEBs have responded with run number in i_run_number
        o_run_stop_ack         => o_readregs(RUN_STOP_ACK_REGISTER_R),
        o_time_counter(31 downto 0)  => o_readregs(GLOBAL_TS_LOW_REGISTER_R),
        o_time_counter(63 downto 32) => o_readregs(GLOBAL_TS_HIGH_REGISTER_R),

        i_reset_n              => i_resets_n(RESET_BIT_GLOBAL_TS),
        i_clk                  => i_clk--,
    );


    --! SWB slow control
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_sc_main : entity work.swb_sc_main
    generic map (
        NLINKS => g_NLINKS_FEB_TOTL--,
    )
    port map (
        i_length_we     => i_writeregs(SC_MAIN_ENABLE_REGISTER_W)(0),
        i_length        => i_writeregs(SC_MAIN_LENGTH_REGISTER_W)(15 downto 0),
        i_mem_data      => i_wmem_rdata,
        o_mem_addr      => o_wmem_addr,
        o_mem_data      => o_feb_tx,
        o_done          => o_readregs(SC_MAIN_STATUS_REGISTER_R)(SC_MAIN_DONE),
        o_state         => o_readregs(SC_STATE_REGISTER_R)(27 downto 0),

        i_reset_n       => i_resets_n(RESET_BIT_SC_MAIN),
        i_clk           => i_clk--,
    );

    e_sc_secondary : entity work.swb_sc_secondary
    generic map (
        NLINKS      => g_NLINKS_FEB_TOTL,
        skip_init   => g_SC_SEC_SKIP_INIT--,
    )
    port map (
        i_link_enable           => i_writeregs(FEB_ENABLE_REGISTER_W)(g_NLINKS_FEB_TOTL-1 downto 0),
        i_link_data             => rx_sc,

        o_mem_addr              => o_rmem_addr,
        o_mem_addr_finished     => o_readregs(MEM_WRITEADDR_LOW_REGISTER_R)(15 downto 0),
        o_mem_data              => o_rmem_wdata,
        o_mem_we                => o_rmem_we,

        o_state                 => o_readregs(SC_STATE_REGISTER_R)(31 downto 28),

        i_reset_n               => i_resets_n(RESET_BIT_SC_SECONDARY),
        i_clk                   => i_clk--,
    );


    --------------------------------------------------
    -- histogramming for QC
    --------------------------------------------------
    process(i_clk, i_reset_n) is
    begin
    if ( i_reset_n = '0' ) then
        histo_rx_selected <= work.mu3e.LINK32_IDLE;
    elsif rising_edge(i_clk) then
        histo_rx_selected <= rx_data(histo_selected_link);
    end if;
    end process;

    histo_selected_link <= to_integer(unsigned(i_writeregs(SWB_HISTO_LINK_SELECT_REGISTER_W)));
    histo_select_chip   <= to_integer(unsigned(i_writeregs(SWB_HISTO_CHIP_SELECT_REGISTER_W)));

    qc_histos_inst: entity work.qc_histos
    port map (
        i_data    => histo_rx_selected,
        i_chip_sel=> histo_select_chip,
        i_raddr   => i_writeregs(SWB_HISTO_ADDR_REGISTER_W),
        o_rdata   => o_readregs(SWB_HISTOS_DATA_REGISTER_R),
        i_zeromem => i_writeregs(SWB_ZERO_HISTOS_REGISTER_W)(1),
        i_ena     => i_writeregs(SWB_ZERO_HISTOS_REGISTER_W)(0),
        i_reset_n => i_reset_n,
        i_clk     => i_clk--,
    );


    --! Mapping Signals
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    -- mask_n
    mask_n <= x"00000000" & i_writeregs(SWB_GENERIC_MASK_REGISTER_W);

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        data_path_reset_n <= '0';
    elsif rising_edge(i_clk) then
        data_path_reset_n <= i_resets_n(RESET_BIT_DATA_PATH);
    end if;
    end process;

    --! SWB data path generic for dev board only
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    generate_generic_path :
    if ( g_NLINKS_DATA_GENERIC > 0 ) generate
    e_swb_data_path_generic : entity work.swb_data_path
    generic map (
        g_ADDR_WIDTH => 12,
        g_NLINKS_DATA => g_NLINKS_DATA_GENERIC,
        g_LINK_SWB => "0000",
        g_gen_time_merger => true--,
    )
    port map (
        -- link inputs
        i_rx                => rx_data(g_NLINKS_DATA_GENERIC-1 downto 0),
        i_rmask_n           => mask_n(g_NLINKS_DATA_GENERIC-1 downto 0),

        i_writeregs         => i_writeregs,

        i_lookup_ctrl       => i_writeregs(SWB_LOOKUP_CTRL_REGISTER_W),

        o_counter           => counter_swb(96*1-1 downto 0),
        o_link_to_fifo_cnt  => counter_link_to_fifo(8*13*1-1 downto 0),

        o_farm_data         => o_farm_tx(0),

        i_rack_debug        => farm_rack_debug(0),
        o_data_debug        => farm_data_debug(0),
        o_rempty_debug      => farm_empty_debug(0),

        i_data_type         => i_writeregs(SWB_DATA_TYPE_REGISTER_W)(5 downto 0),

        i_resets_n          => i_resets_n,

        i_reset_n           => data_path_reset_n,
        i_clk               => i_clk--,
    );
    end generate;

    --! SWB data path Pixel
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
   generate_us_path : if ( g_NLINKS_DATA_PIXEL_US > 0 ) generate
   e_swb_data_path_pixel_us : entity work.swb_data_path
   generic map (
        g_ADDR_WIDTH => 12,
        g_NLINKS_DATA => g_NLINKS_DATA_PIXEL_US,
        g_LINK_SWB => "0000",
        g_gen_time_merger => true--,
   )
   port map (
        -- link inputs
        i_rx                => rx_data(g_NLINKS_DATA_PIXEL_US-1 downto 0),
        i_rmask_n           => mask_n(g_NLINKS_DATA_PIXEL_US-1 downto 0),

        i_writeregs         => i_writeregs,

        i_lookup_ctrl       => i_writeregs(SWB_LOOKUP_CTRL_REGISTER_W),

        o_counter           => counter_swb(96*1-1 downto 0),
        o_link_to_fifo_cnt  => counter_link_to_fifo(8*13*1-1 downto 0),

        o_farm_data         => o_farm_tx(0),

        i_rack_debug        => farm_rack_debug(0),
        o_data_debug        => farm_data_debug(0),
        o_rempty_debug      => farm_empty_debug(0),

        i_data_type         => i_writeregs(SWB_DATA_TYPE_REGISTER_W)(11 downto 6),

        i_resets_n          => i_resets_n,

        i_reset_n           => data_path_reset_n,
        i_clk               => i_clk--,
   );
   end generate;

   generate_ds_path : if ( g_NLINKS_DATA_PIXEL_DS > 0 ) generate
   e_swb_data_path_pixel_ds : entity work.swb_data_path
   generic map (
        g_ADDR_WIDTH => 12,
        g_NLINKS_DATA => g_NLINKS_DATA_PIXEL_DS,
        g_LINK_SWB => "0001",
        g_gen_time_merger => true--,
   )
   port map (
        -- link inputs
        i_rx                => rx_data(g_NLINKS_DATA_PIXEL_US+g_NLINKS_DATA_PIXEL_DS-1 downto g_NLINKS_DATA_PIXEL_US),
        i_rmask_n           => mask_n(g_NLINKS_DATA_PIXEL_US+g_NLINKS_DATA_PIXEL_DS-1 downto g_NLINKS_DATA_PIXEL_US),

        i_writeregs         => i_writeregs,

        i_lookup_ctrl       => i_writeregs(SWB_LOOKUP_DS_CTRL_REGISTER_W),

        o_counter           => counter_swb(96*2-1 downto 96*1),
        o_link_to_fifo_cnt  => counter_link_to_fifo(8*13*2-1 downto 8*13*1),

        o_farm_data         => o_farm_tx(1),

        i_rack_debug        => farm_rack_debug(1),
        o_data_debug        => farm_data_debug(1),
        o_rempty_debug      => farm_empty_debug(1),

        i_data_type         => i_writeregs(SWB_DATA_TYPE_REGISTER_W)(17 downto 12),

        i_resets_n          => i_resets_n,

        i_reset_n           => data_path_reset_n,
        i_clk               => i_clk--,
   );
   end generate;

    --! stream merger used for the debug readout on the SWB
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_stream_debug_all : entity work.swb_stream_merger
    generic map (
        g_ADDR_WIDTH => 11,
        N => g_NLINKS_FARM_TOTL--,
    )
    port map (
        -- debug data in
        i_rdata     => farm_data_debug,
        i_rempty    => farm_empty_debug,
        i_rmask_n   => (others => '1'),
        o_rack      => farm_rack_debug,

        -- debug data out
        o_wdata     => data_debug,
        o_rempty    => rempty_debug,
        i_ren       => builder_rack,

        -- data for debug readout
        o_wdata_debug   => open,
        o_rempty_debug  => open,
        i_ren_debug     => '0',

        o_counters  => open,

        i_en        => '1',
        i_reset_n   => i_resets_n(RESET_BIT_SWB_STREAM_MERGER),
        i_clk       => i_clk--,
    );


    --! event builder used for the debug readout on the SWB
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_event_builder : entity work.swb_midas_event_builder
    port map (
        i_rx                => data_debug,
        i_rempty            => rempty_debug,

        i_get_n_words       => i_writeregs(GET_N_DMA_WORDS_REGISTER_W),
        i_dmamemhalffull    => i_dmamemhalffull,
        i_wen               => i_writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE),
        i_use_sop_type      => i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_ALL),
        i_event_id          => i_writeregs(FARM_EVENT_ID_REGISTER_W),
        i_get_serial_number => i_writeregs(FARM_SERIAL_NUMBER_W),
        i_flush_request     => i_writeregs(DMA_REGISTER_W)(FLUSH_BIT_ENABLE),
        i_flush_test(FLUSH_TEST_RANGE) => i_writeregs(DMA_REGISTER_W)(FLUSH_TEST_RANGE),

        o_data              => o_dma_data,
        o_wen               => o_dma_wren,
        o_ren               => builder_rack,
        o_endofevent        => o_endofevent,
        o_dma_cnt_words     => o_readregs(DMA_CNT_WORDS_REGISTER_R),
        o_serial_num        => o_readregs(SERIAL_NUM_REGISTER_R),
        o_done              => o_readregs(EVENT_BUILD_STATUS_REGISTER_R)(EVENT_BUILD_DONE),

        o_counters(0)       => o_readregs(EVENT_BUILD_IDLE_NOT_HEADER_R),
        o_counters(1)       => o_readregs(EVENT_BUILD_SKIP_EVENT_DMA_R),
        o_counters(2)       => o_readregs(EVENT_BUILD_CNT_EVENT_DMA_R),
        o_counters(3)       => o_readregs(EVENT_BUILD_TAG_FIFO_FULL_R),

        i_reset_n           => data_path_reset_n,
        i_clk               => i_clk--,
    );

end architecture;
