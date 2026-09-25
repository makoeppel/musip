-- mupix block of FEB firmware
-- M. Mueller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mupix_registers.all;
use work.mudaq.all;
use work.mupix.all;

entity mupix_block is
generic(
    g_IS_QUAD : std_logic := '0';
    g_IS_OUTER : integer := 0;
    g_USE_TRIGGER : integer := 0;
    g_SIN_INVERT : std_logic := '0';
    g_CHIPS_PER_SPI : positive := 3;
    g_N_SPI : positive := 4;
    g_IS_TELESCOPE : std_logic := '0';
    g_IS_MUPIX10 : boolean := false;
    g_LINK_INVERT : std_logic_vector(35 downto 0) := (others => '0');
    g_LINK_ORDER : mp_link_order_t := MP_LINK_ORDER;
    g_MP_LADDER_ADDR_ARRAY : mp_ladder_addr_array_t := MP_LADDER_ADDR_ARRAY_US_INNER--;
);
port (
    i_fpga_id               : in  std_logic_vector(7 downto 0);

    -- config signals to mupix
    o_clock                 : out std_logic_vector(g_N_SPI-1 downto 0);
    o_SIN                   : out std_logic_vector(g_N_SPI-1 downto 0);
    o_mosi                  : out std_logic_vector(g_N_SPI-1 downto 0);
    o_cs                    : out std_logic_vector(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0);

    i_run_state_125         : in  run_state_t;
    i_run_state_156         : in  run_state_t;
    o_ack_run_prep_permission : out std_logic := '1';

    -- mupix dac regs
    i_reg_addr              : in  std_logic_vector(15 downto 0);
    i_reg_re                : in  std_logic;
    o_reg_rdata             : out std_logic_vector(31 downto 0);
    i_reg_we                : in  std_logic;
    i_reg_wdata             : in  std_logic_vector(31 downto 0);

    -- data
    o_fifo_wdata            : out std_logic_vector(35 downto 0);
    o_fifo_write            : out std_logic;

    o_data_bypass           : out std_logic_vector(31 downto 0);
    o_data_bypass_we        : out std_logic;

    i_lvds_data_in          : in  std_logic_vector(35 downto 0);

    i_areset_n              : in  std_logic;
    -- 156.25 MHz
    i_clk_156               : in  std_logic;
    i_clk_125               : in  std_logic;
    i_lvds_rx_inclock_A     : in  std_logic;
    i_lvds_rx_inclock_B     : in  std_logic;
    i_sync_reset_cnt        : in  std_logic;

    i_trigger_en            : in  std_logic := '0';
    i_trigger_timestamp     : in  std_logic_vector(31 downto 0) := (others => '0');
    o_use_spi               : out std_logic := '1'--;
);
end entity;

architecture arch of mupix_block is

    signal reset_156_n : std_logic;

    signal mp_ctrl_reg      : work.util.rw_t;
    signal mp_datapath_reg  : work.util.rw_t;

    signal iram_addr    : std_logic_vector(15 downto 0) := (others => '0');
    signal iram_we      : std_logic := '0';
    signal iram_rdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal iram_wdata   : std_logic_vector(31 downto 0) := (others => '0');

begin

    e_reset_156_n : entity work.reset_sync
    port map ( i_areset_n => i_areset_n, o_reset_n => reset_156_n, i_clk => i_clk_156 );

    e_mupix_ctrl : entity work.mupix_ctrl
    generic map (
        g_SIN_INVERT => g_SIN_INVERT,
        g_CHIPS_PER_SPI => g_CHIPS_PER_SPI,
        g_N_SPI => g_N_SPI,
        g_IS_MUPIX10 => g_IS_MUPIX10,
        g_MP_LADDER_ADDR_ARRAY => g_MP_LADDER_ADDR_ARRAY
    )
    port map (
        i_reg_addr          => mp_ctrl_reg.addr(15 downto 0),
        i_reg_re            => mp_ctrl_reg.re,
        o_reg_rdata         => mp_ctrl_reg.rdata,
        i_reg_we            => mp_ctrl_reg.we,
        i_reg_wdata         => mp_ctrl_reg.wdata,

        o_clock             => o_clock,
        o_SIN               => o_sin,
        o_mosi              => o_mosi,
        o_cs                => o_cs,
        o_use_spi           => o_use_spi,

        i_clk_125           => i_clk_125,

        i_reset_n           => reset_156_n,
        i_clk               => i_clk_156--,
    );

    e_mupix_datapath : entity work.mupix_datapath
    generic map (
        g_IS_QUAD       => g_IS_QUAD,
        g_IS_OUTER      => g_IS_OUTER,
        g_USE_TRIGGER   => g_USE_TRIGGER,
        g_IS_TELESCOPE  => g_IS_TELESCOPE,
        g_LINK_INVERT   => g_LINK_INVERT,
        g_IS_MUPIX10    => g_IS_MUPIX10,
        g_LINK_ORDER    => g_LINK_ORDER--,
    )
    port map (
        i_lvds_rx_inclock_A => i_lvds_rx_inclock_A,
        i_lvds_rx_inclock_B => i_lvds_rx_inclock_B,

        i_lvds_data         => i_lvds_data_in,

        i_reg_addr          => mp_datapath_reg.addr(15 downto 0),
        i_reg_re            => mp_datapath_reg.re,
        o_reg_rdata         => mp_datapath_reg.rdata,
        i_reg_we            => mp_datapath_reg.we,
        i_reg_wdata         => mp_datapath_reg.wdata,

        o_fifo_wdata        => o_fifo_wdata,
        o_fifo_write        => o_fifo_write,

        o_data_bypass       => o_data_bypass,
        o_data_bypass_we    => o_data_bypass_we,

        i_sync_reset_cnt    => i_sync_reset_cnt,
        i_fpga_id           => i_fpga_id,
        i_run_state_125     => i_run_state_125,
        i_run_state_156     => i_run_state_156,

        i_trigger_en        => i_trigger_en,
        i_trigger_timestamp => i_trigger_timestamp,

        i_clk_125           => i_clk_125,

        i_reset_156_n       => reset_156_n,
        i_clk_156           => i_clk_156--,
    );

    e_lvl1_sc_node: entity work.sc_node
    generic map (
        g_SLAVE1_ADDR_MATCH => "000000----------",
        g_SLAVE2_ADDR_MATCH => "0000------------",
        g_SLAVE0_DEPTH      => 3--,
    )
    port map (
        i_master_addr  => i_reg_addr,
        i_master_re    => i_reg_re,
        o_master_rdata => o_reg_rdata,
        i_master_we    => i_reg_we,
        i_master_wdata => i_reg_wdata,

        o_slave0_addr  => mp_datapath_reg.addr(15 downto 0),
        o_slave0_re    => mp_datapath_reg.re,
        i_slave0_rdata => mp_datapath_reg.rdata,
        o_slave0_we    => mp_datapath_reg.we,
        o_slave0_wdata => mp_datapath_reg.wdata,

        o_slave1_addr  => iram_addr,
        o_slave1_re    => open,
        i_slave1_rdata => iram_rdata,
        o_slave1_we    => iram_we,
        o_slave1_wdata => iram_wdata,

        o_slave2_addr  => mp_ctrl_reg.addr(15 downto 0),
        o_slave2_re    => mp_ctrl_reg.re,
        i_slave2_rdata => mp_ctrl_reg.rdata,
        o_slave2_we    => mp_ctrl_reg.we,
        o_slave2_wdata => mp_ctrl_reg.wdata,

        i_reset_n      => reset_156_n,
        i_clk          => i_clk_156--,
    );

    e_iram : entity work.ram_1r1w
    generic map (
        g_DATA_WIDTH => 32,
        g_ADDR_WIDTH => 5,
        g_RAMSTYLE => "no_rw_check, MLAB"
    )
    port map (
        i_raddr => iram_addr(5-1 downto 0),
        o_rdata => iram_rdata,
        i_rclk  => i_clk_156,

        i_waddr => iram_addr(5-1 downto 0),
        i_wdata => iram_wdata,
        i_we    => iram_we,
        i_wclk  => i_clk_156--,
    );

end architecture;
