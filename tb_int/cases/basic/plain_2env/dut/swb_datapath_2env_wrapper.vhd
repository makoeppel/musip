-- -----------------------------------------------------------------------------
-- File      : swb_datapath_2env_wrapper.vhd
-- Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
-- Version   : 26.4.21
-- Date      : 20260421
-- Change    : Expose the post-OPQ MuSiP datapath as a VHDL-only wrapper for
--             the 2-env DPI workaround harness.
-- -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.mu3e.all;
use work.mudaq.all;
use work.util_slv.all;

entity swb_datapath_2env_wrapper is
port (
    clk                : in std_logic;
    reset_n            : in std_logic;
    opq_data           : in std_logic_vector(31 downto 0);
    opq_datak          : in std_logic_vector(3 downto 0);
    opq_valid          : in std_logic;
    enable_dma         : in std_logic;
    get_n_words        : in std_logic_vector(31 downto 0);
    lookup_ctrl        : in std_logic_vector(31 downto 0);
    dma_half_full      : in std_logic;
    dma_data           : out std_logic_vector(255 downto 0);
    dma_wren           : out std_logic;
    end_of_event       : out std_logic;
    dma_done           : out std_logic
);
end entity;

architecture rtl of swb_datapath_2env_wrapper is

    constant LINK_COUNT_CONST     : positive := 4;
    constant MASK_N_CONST         : std_logic_vector(LINK_COUNT_CONST - 1 downto 0) := (others => '1');

    signal lane_rx              : work.mu3e.link32_array_t(LINK_COUNT_CONST - 1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal hits_256             : std_logic_vector(255 downto 0);
    signal hits_256_valid       : std_logic;
    signal hit_drop_cnt         : std_logic_vector(63 downto 0);
    signal full_cnt             : std_logic_vector(63 downto 0);
    signal mux_subh_cnt         : slv64_array_t(LINK_COUNT_CONST - 1 downto 0);
    signal mux_hit_cnt          : slv64_array_t(LINK_COUNT_CONST - 1 downto 0);
    signal mux_package_cnt      : slv64_array_t(LINK_COUNT_CONST - 1 downto 0);
    signal mux_word_cnt         : std_logic_vector(63 downto 0);
    signal mux_subh_rate        : slv32_array_t(LINK_COUNT_CONST - 1 downto 0);
    signal mux_hit_rate         : slv32_array_t(LINK_COUNT_CONST - 1 downto 0);
    signal mux_package_rate     : slv32_array_t(LINK_COUNT_CONST - 1 downto 0);
    signal mux_word_rate        : std_logic_vector(31 downto 0);

begin

    lane_rx(0) <= work.mu3e.to_link(opq_data, opq_datak) when opq_valid = '1' else work.mu3e.LINK32_IDLE;

    gen_idle_lanes : for lane in 1 to LINK_COUNT_CONST - 1 generate
    begin
        lane_rx(lane) <= work.mu3e.LINK32_IDLE;
    end generate;

    dut_mux : entity work.musip_mux_4_1
    generic map (
        g_LINK_N => LINK_COUNT_CONST
    )
    port map (
        i_rx                => lane_rx,
        i_rmask_n           => MASK_N_CONST,
        i_use_direct_mux    => '1',
        i_lookup_ctrl       => lookup_ctrl,
        o_subh_cnt          => mux_subh_cnt,
        o_hit_cnt           => mux_hit_cnt,
        o_package_cnt       => mux_package_cnt,
        o_word_cnt          => mux_word_cnt,
        o_subh_rate         => mux_subh_rate,
        o_hit_rate          => mux_hit_rate,
        o_package_rate      => mux_package_rate,
        o_word_rate         => mux_word_rate,
        o_data              => hits_256,
        o_valid             => hits_256_valid,
        i_reset_n           => reset_n,
        i_clk               => clk
    );

    dut_event_builder : entity work.musip_event_builder
    port map (
        i_rx             => hits_256,
        i_valid          => hits_256_valid,
        i_get_n_words    => get_n_words,
        i_dmamemhalffull => dma_half_full,
        i_wen            => enable_dma,
        o_data           => dma_data,
        o_wen            => dma_wren,
        o_endofevent     => end_of_event,
        o_done           => dma_done,
        o_hit_cnt        => open,
        o_hit_drop_cnt => hit_drop_cnt,
        o_full_cnt       => full_cnt,
        o_hit_rate       => open,
        i_reset_n        => reset_n,
        i_clk            => clk
    );

end architecture;
