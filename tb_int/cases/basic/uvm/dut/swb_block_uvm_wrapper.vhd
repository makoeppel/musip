-- -----------------------------------------------------------------------------
-- File      : swb_block_uvm_wrapper.vhd
-- Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
-- Version   : 26.3.6
-- Date      : 20260421
-- Change    : Expose a narrow UVM-facing seam for the SWB OPQ datapath: 4 FEB
--             ingress lanes, merged OPQ egress debug, DMA egress, and the
--             minimal readout controls.
-- -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.util_slv.all;
use work.mudaq.all;
use work.mu3e.all;
use work.a10_pcie_registers.all;

entity swb_block_uvm_wrapper is
port (
    clk                : in std_logic;
    reset_n            : in std_logic;
    feb_data           : in std_logic_vector(127 downto 0);
    feb_datak          : in std_logic_vector(15 downto 0);
    feb_valid          : in std_logic_vector(3 downto 0);
    feb_err_desc       : in std_logic_vector(11 downto 0);
    feb_enable_mask    : in std_logic_vector(3 downto 0);
    use_merge          : in std_logic;
    enable_dma         : in std_logic;
    get_n_words        : in std_logic_vector(31 downto 0);
    lookup_ctrl        : in std_logic_vector(31 downto 0);
    dma_half_full      : in std_logic;
    opq_data           : out std_logic_vector(31 downto 0);
    opq_datak          : out std_logic_vector(3 downto 0);
    opq_valid          : out std_logic;
    dma_data           : out std_logic_vector(255 downto 0);
    dma_wren           : out std_logic;
    end_of_event       : out std_logic;
    dma_done           : out std_logic
);
end entity;

architecture rtl of swb_block_uvm_wrapper is

    signal feb_rx         : work.mu3e.link32_array_t(11 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal feb_tx         : work.mu3e.link32_array_t(11 downto 0);
    signal farm_tx        : work.mu3e.link32_array_t(2 downto 0);
    signal writeregs      : slv32_array_t(63 downto 0) := (others => (others => '0'));
    signal readregs       : slv32_array_t(63 downto 0);
    signal resets_n       : std_logic_vector(31 downto 0);
    signal regwritten     : std_logic_vector(63 downto 0) := (others => '0');

    function to_ingress_link(
        constant data_v     : std_logic_vector(31 downto 0);
        constant datak_v    : std_logic_vector(3 downto 0);
        constant err_desc_v : std_logic_vector(2 downto 0)
    ) return work.mu3e.link32_t is
        variable link_v : work.mu3e.link32_t;
    begin
        link_v := work.mu3e.to_link(data_v, datak_v);
        link_v.err := err_desc_v(0);
        link_v.t0  := err_desc_v(1);
        link_v.t1  := err_desc_v(2);
        return link_v;
    end function;

begin

    resets_n <= (others => reset_n);

    feb_map : for lane in 0 to 3 generate
        feb_rx(lane) <= to_ingress_link(
            feb_data((lane + 1) * 32 - 1 downto lane * 32),
            feb_datak((lane + 1) * 4 - 1 downto lane * 4),
            feb_err_desc((lane + 1) * 3 - 1 downto lane * 3)
        ) when feb_valid(lane) = '1' else work.mu3e.LINK32_IDLE;
    end generate;

    writeregs(FEB_ENABLE_REGISTER_W)(3 downto 0)                <= feb_enable_mask;
    writeregs(SWB_GENERIC_MASK_REGISTER_W)(3 downto 0)          <= feb_enable_mask;
    writeregs(SWB_LOOKUP_CTRL_REGISTER_W)                       <= lookup_ctrl;
    writeregs(GET_N_DMA_WORDS_REGISTER_W)                       <= get_n_words;
    writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE)                   <= enable_dma;
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_STREAM)     <= '1';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER)     <= use_merge;
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GENERIC)    <= '1';

    dma_done <= readregs(EVENT_BUILD_STATUS_REGISTER_R)(EVENT_BUILD_DONE);

    dut : entity work.swb_block
    generic map (
        g_NLINKS_FEB_TOTL         => 12,
        g_NLINKS_DATA_GENERIC     => 8,
        g_NLINKS_FARM_TOTL        => 3,
        g_NLINKS_DATA_PIXEL_US    => 5,
        g_NLINKS_DATA_PIXEL_DS    => 5,
        g_SC_SEC_SKIP_INIT        => '1'
    )
    port map (
        i_feb_rx    => feb_rx,
        o_feb_tx    => feb_tx,

        i_writeregs     => writeregs,
        i_regwritten    => regwritten,
        o_readregs      => readregs,
        i_resets_n      => resets_n,

        i_wmem_rdata    => (others => '0'),
        o_wmem_addr     => open,

        o_rmem_wdata    => open,
        o_rmem_addr     => open,
        o_rmem_we       => open,

        i_dmamemhalffull    => dma_half_full,
        o_opq_data          => opq_data,
        o_opq_datak         => opq_datak,
        o_opq_valid         => opq_valid,
        o_dma_wren          => dma_wren,
        o_endofevent        => end_of_event,
        o_dma_data          => dma_data,

        o_farm_tx    => farm_tx,

        i_reset_n    => reset_n,
        i_clk        => clk
    );

end architecture;
