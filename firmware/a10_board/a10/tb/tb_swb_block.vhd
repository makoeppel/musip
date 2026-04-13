library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.a10_pcie_registers.all;
use work.mudaq.all;

entity tb_swb_block is
end entity;

architecture arch of tb_swb_block is

    -- constants
    constant g_NLINKS_FEB_TOTL   : positive := 10;
    -- for the DEV board we have one (or two when scifi) data inputs
    constant g_NLINKS_DATAPATH_TOTL : positive := 8;
    constant g_NLINKS_DATA_GENERIC : integer := 0;
    constant g_NLINKS_FARM_TOTL  : positive := 2; -- NOTE: we have to set this to 3 always not generic for now
    constant g_NLINKS_FARM_PIXEL : positive := 2; -- NOTE: we have to set this to 2 always not generic for now
    constant g_NLINKS_DATA_PIXEL_US : integer := 5;
    constant g_NLINKS_DATA_PIXEL_DS : integer := 5;
    constant g_NLINKS_FARM_SCIFI : positive := 1; -- NOTE: we have to set this to 1 always not generic for now
    constant g_NLINKS_DATA_SCIFI : integer := 0;
    constant g_NLINKS_FARM_TILE  : positive := 1; -- NOTE: we have to set this to 1 always not generic for now
    constant g_NLINKS_DATA_TILE  : integer := 0;

    constant CLK_MHZ : real := 10000.0; -- MHz
    constant g_NLINKS_DATA : integer := 8;

    signal clk, clk_fast, reset_n : std_logic := '0';
    --! data link signals
    signal rx : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal tx : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    signal writeregs : slv32_array_t(63 downto 0) := (others => (others => '0'));
    signal readregs : slv32_array_t(63 downto 0) := (others => (others => '0'));

    signal resets_n : std_logic_vector(31 downto 0) := (others => '0');

    signal counter : slv32_array_t(5+(g_NLINKS_DATA*5)-1 downto 0);

    signal fram_wen, dma_wren, dma_done, endofevent, dmamemhalffull : std_logic;
    signal dma_data : std_logic_vector(255 downto 0);
    signal mask_n : std_logic_vector(63 downto 0);

    signal dma_data_array : slv32_array_t(7 downto 0);

    signal writememdata : std_logic_vector(31 downto 0);
    signal writememdata_out : std_logic_vector(31 downto 0);
    signal writememdata_out_reg : std_logic_vector(31 downto 0);
    signal writememaddr : std_logic_vector(15 downto 0);
    signal memaddr : std_logic_vector(15 downto 0);
    signal memaddr_reg : std_logic_vector(15 downto 0);
    signal readmem_writedata : std_logic_vector(31 downto 0);
    signal readmem_writeaddr : std_logic_vector(15 downto 0);
    signal readmem_wren : std_logic;

    signal writememwren, toggle_read, done, fifo_we : std_logic;

    signal fifo_wdata : std_logic_vector(35 downto 0);
    signal link_data : std_logic_vector(127 downto 0);
    signal link_datak : std_logic_vector(15 downto 0);

    signal farm_tx : work.mu3e.link32_array_t(g_NLINKS_FARM_TOTL-1 downto 0);

    type state_type is (idle, write_sc, wait_state, read_sc);
    signal state : state_type;

    signal readreg : reg32array_pcie;

begin

    clk     <= not clk after (0.5 us / CLK_MHZ);
    clk_fast<= not clk_fast after (0.1 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);

    --! Setup
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! USE_GEN_LINK | USE_STREAM | USE_MERGER | USE_GEN_MERGER | USE_FARM | SWB_READOUT_LINK_REGISTER_W | EFFECT                                                                         | WORKS
    --! ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    --! 1            | 0          | 0          | 0              | 0        | n                           | Generate data for all 64 links, readout link n via DAM                         | x
    --! 1            | 1          | 0          | 0              | 0        | -                           | Generate data for all 64 links, simple merging of links, readout via DAM       | x
    --! 1            | 0          | 1          | 0              | 0        | -                           | Generate data for all 64 links, time merging of links, readout via DAM         | x
    --! 0            | 0          | 0          | 1              | 1        | -                           | Generate time merged data, send to farm                                        | x
    resets_n(RESET_BIT_DATAGEN)                             <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_SWB_STREAM_MERGER)                   <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_FARM_STREAM_MERGER)                  <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_SWB_TIME_MERGER)                     <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_DATA_PATH)                           <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_RUN_START_ACK)                       <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_RUN_END_ACK)                         <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_SC_MAIN)                             <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_SC_SECONDARY)                        <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_EVENT_COUNTER)                       <= '0', '1' after (1.0 us / CLK_MHZ);

    writeregs(DATAGENERATOR_DIVIDER_REGISTER_W)                         <= x"00000002";
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK)           <= '1';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_TEST_DATA)          <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_TEST_ERROR)         <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_STREAM)             <= '1';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER)             <= '1';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_SUBHDR_SUPPRESS)    <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_HEAD_SUPPRESS)      <= '0';

    writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION)         <= '1';
    writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR)               <= '0';
    writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_STREAM)            <= '0';

    writeregs(SWB_LINK_MASK_PIXEL_REGISTER_W)(4 downto 0)   <= '1' & x"F";--x"00000048";
    writeregs(SWB_LINK_MASK_PIXEL_REGISTER_W)(9 downto 5)   <= '1' & x"F";--x"00000048";
    writeregs(SWB_LINK_MASK_SCIFI_REGISTER_W)(1 downto 0)   <= "01";
    writeregs(SWB_GENERIC_MASK_REGISTER_W)(7 downto 0)      <= x"01";
    writeregs(FARM_LINK_MASK_REGISTER_W)(3 downto 0)      <= x"F";

    writeregs(FEB_ENABLE_REGISTER_W)                        <= x"0000001F";--x"00000048";
    writeregs(SWB_READOUT_LINK_REGISTER_W)                  <= x"00000001";
    writeregs(GET_N_DMA_WORDS_REGISTER_W)                   <= (others => '1');
    writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE)               <= '1';

    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GENERIC)    <= '1';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_PIXEL_US)   <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_PIXEL_DS)   <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_SCIFI)      <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_ALL)        <= '0';

    --! SWB Block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_swb_block : entity work.swb_block
    generic map (
        g_NLINKS_FEB_TOTL       => g_NLINKS_FEB_TOTL,
        g_NLINKS_DATA_GENERIC   => g_NLINKS_DATA_GENERIC,
        g_NLINKS_FARM_TOTL      => g_NLINKS_FARM_TOTL,
        g_NLINKS_DATA_PIXEL_US  => g_NLINKS_DATA_PIXEL_US,
        g_NLINKS_DATA_PIXEL_DS  => g_NLINKS_DATA_PIXEL_DS,
        g_SC_SEC_SKIP_INIT      => '1'--,
    )
    port map (
        i_feb_rx        => rx(g_NLINKS_FEB_TOTL-1 downto 0),
        o_feb_tx        => tx(g_NLINKS_FEB_TOTL-1 downto 0),

        i_writeregs     => writeregs,
        o_readregs      => readregs,
        i_resets_n      => resets_n,

        i_wmem_rdata    => writememdata_out,
        o_wmem_addr     => memaddr,

        o_rmem_wdata    => readmem_writedata,
        o_rmem_addr     => readmem_writeaddr,
        o_rmem_we       => readmem_wren,

        i_dmamemhalffull=> dmamemhalffull,
        o_dma_wren      => dma_wren,
        o_endofevent    => endofevent,
        o_dma_data      => dma_data,

        o_farm_tx       => farm_tx,

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

end architecture;
