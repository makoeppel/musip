library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity tb_sc_new is
end entity;

architecture rtl of tb_sc_new is

    signal clk          : std_logic := '1';
    signal reset_n      : std_logic;
    signal data_in      : std_logic_vector(31 downto 0) := (others => '0');
    signal datak_in     : std_logic_vector( 3 downto 0) := (others => '0');

    signal data_out     : std_logic_vector(35 downto 0) := (others => '0');
    signal data_out_we  : std_logic := '0';

    signal sc_ram           : work.util.rw_t;
    signal fe_reg           : work.util.rw_t;
    signal sc_reg           : work.util.rw_t;
    signal subdet_reg       : work.util.rw_t;
    signal mp_ctrl_reg      : work.util.rw_t;
    signal mp_datapath_reg  : work.util.rw_t;
    signal mp_datapath_reg2 : work.util.rw_t;
    signal lvds_rx_reg      : work.util.rw_t;
    signal mp_sorter_reg    : work.util.rw_t;

    signal av_sc_address    : std_logic_vector(15 downto 0) := (others => '0');
    signal av_sc_read       : std_logic := '0';
    signal av_sc_readdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal av_sc_write      : std_logic := '0';
    signal av_sc_writedata  : std_logic_vector(31 downto 0) := (others => '0');
    signal av_sc_waitrequest: std_logic := '0';

    signal iram_addr    : std_logic_vector(15 downto 0) := (others => '0');
    signal iram_we      : std_logic := '0';
    signal iram_rdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal iram_wdata   : std_logic_vector(31 downto 0) := (others => '0');

begin

    clk     <= not clk after (500 ns / 50);
    reset_n <= '0', '1' after 30 ns;

    e_sc_rx : entity work.sc_rx
    port map (
        i_link_data     => data_in,
        i_link_datak    => datak_in,

        o_fifo_we       => data_out_we,
        o_fifo_wdata    => data_out,

        o_ram_addr      => sc_ram.addr,
        o_ram_re        => sc_ram.re,
        i_ram_rvalid    => sc_ram.rvalid,
        i_ram_rdata     => sc_ram.rdata,
        o_ram_we        => sc_ram.we,
        o_ram_wdata     => sc_ram.wdata,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    e_sc_ram : entity work.sc_ram
    generic map (
        g_READ_DELAY => 7--,
    )
    port map (
        i_ram_addr              => sc_ram.addr(15 downto 0),
        i_ram_re                => sc_ram.re,
        o_ram_rvalid            => sc_ram.rvalid,
        o_ram_rdata             => sc_ram.rdata,
        i_ram_we                => sc_ram.we,
        i_ram_wdata             => sc_ram.wdata,

        i_avs_address           => av_sc_address(15 downto 0),
        i_avs_read              => av_sc_read,
        o_avs_readdata          => av_sc_readdata,
        i_avs_write             => av_sc_write,
        i_avs_writedata         => av_sc_writedata,
        o_avs_waitrequest       => av_sc_waitrequest,

        o_reg_addr              => sc_reg.addr(15 downto 0),
        o_reg_re                => sc_reg.re,
        i_reg_rdata             => sc_reg.rdata,
        o_reg_we                => sc_reg.we,
        o_reg_wdata             => sc_reg.wdata,

        i_reset_n               => reset_n,
        i_clk                   => clk--,
    );

    e_lvl0_sc_node: entity work.sc_node
    generic map (
        g_SLAVE0_DEPTH      => 3,
        g_SLAVE1_ADDR_MATCH => "111111----------"
    )
    port map (
        i_master_addr   => sc_reg.addr(15 downto 0),
        i_master_re     => sc_reg.re,
        o_master_rdata  => sc_reg.rdata,
        i_master_we     => sc_reg.we,
        i_master_wdata  => sc_reg.wdata,

        o_slave0_addr   => subdet_reg.addr(15 downto 0),
        o_slave0_re     => subdet_reg.re,
        i_slave0_rdata  => subdet_reg.rdata,
        o_slave0_we     => subdet_reg.we,
        o_slave0_wdata  => subdet_reg.wdata,

        o_slave1_addr   => fe_reg.addr(15 downto 0),
        o_slave1_re     => fe_reg.re,
        i_slave1_rdata  => fe_reg.rdata,
        o_slave1_we     => fe_reg.we,
        o_slave1_wdata  => fe_reg.wdata,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    e_lvl1_sc_node: entity work.sc_node
    generic map (
        g_SLAVE1_ADDR_MATCH => "000000----------",
        g_SLAVE2_ADDR_MATCH => "0000------------",
        g_SLAVE0_DEPTH      => 2--,
    )
    port map (
        i_master_addr  => subdet_reg.addr(15 downto 0),
        i_master_re    => subdet_reg.re,
        o_master_rdata => subdet_reg.rdata,
        i_master_we    => subdet_reg.we,
        i_master_wdata => subdet_reg.wdata,

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

        i_reset_n      => reset_n,
        i_clk          => clk--,
    );

    e_reg_mapping : entity work.feb_reg_mapping
    port map (
        i_reg_addr                  => fe_reg.addr(15 downto 0),
        i_reg_re                    => fe_reg.re,
        o_reg_rdata                 => fe_reg.rdata,
        i_reg_we                    => fe_reg.we,
        i_reg_wdata                 => fe_reg.wdata,

        -- inputs  156--------------------------------------------
        -- ALL INPUTS DEFAULT TO (n*4-1 downto 0 => x"CCC..", others => '1')
        i_run_state_156             => (others => '0'),
        i_merger_rate_count         => (others => '0'),
        i_reset_phase               => (others => '0'),
        i_arriaV_temperature        => (others => '0'),
        i_fpga_type                 => (others => '0'),
        i_max10_version             => x"89ABCDEF",
        i_max10_status              => x"01234567",
        i_programming_status        => (others => '0'),

        i_ffly_pwr                  => (others => '0'),
        i_ffly_temp                 => (others => '0'),
        i_ffly_alarm                => (others => '0'),
        i_ffly_vcc                  => (others => '0'),

        i_si45_intr_n               => (others => '0'),
        i_si45_lol_n                => (others => '0'),

        i_reset_n                   => reset_n,
        i_clk                       => clk--,
    );

    e_reg_mapping_mupix_ctrl: entity work.mupix_ctrl_reg_mapping
    port map (
        i_reg_addr                  => mp_ctrl_reg.addr(15 downto 0),
        i_reg_re                   => mp_ctrl_reg.re,
        o_reg_rdata                => mp_ctrl_reg.rdata,
        i_reg_we                   => mp_ctrl_reg.we,
        i_reg_wdata                => mp_ctrl_reg.wdata,
        i_mp_spi_busy              => '1',

        i_reset_n                  => reset_n,
        i_clk                      => clk--,
    );

    e_reg_mapping_mupix_datapath: entity work.mupix_datapath_reg_mapping
    port map (
        i_reg_addr                  => mp_datapath_reg2.addr(15 downto 0),
        i_reg_re                    => mp_datapath_reg2.re,
        o_reg_rdata                 => mp_datapath_reg2.rdata,
        i_reg_we                    => mp_datapath_reg2.we,
        i_reg_wdata                 => mp_datapath_reg2.wdata,

        i_reset_156_n               => reset_n,
        i_clk_156                   => clk,

        i_clk_125                   => clk--,
    );

    e_lvl2_sc_node : entity work.sc_node
    generic map (
        g_SLAVE1_ADDR_MATCH => "00010000--------",
        g_SLAVE2_ADDR_MATCH => "00010001--------"--,
    )
    port map (
        i_master_addr  => mp_datapath_reg.addr(15 downto 0),
        i_master_re    => mp_datapath_reg.re,
        o_master_rdata => mp_datapath_reg.rdata,
        i_master_we    => mp_datapath_reg.we,
        i_master_wdata => mp_datapath_reg.wdata,

        o_slave0_addr  => mp_datapath_reg2.addr(15 downto 0),
        o_slave0_re    => mp_datapath_reg2.re,
        i_slave0_rdata => mp_datapath_reg2.rdata,
        o_slave0_we    => mp_datapath_reg2.we,
        o_slave0_wdata => mp_datapath_reg2.wdata,

        o_slave1_addr  => mp_sorter_reg.addr(15 downto 0),
        o_slave1_re    => mp_sorter_reg.re,
        i_slave1_rdata => mp_sorter_reg.rdata,
        o_slave1_we    => mp_sorter_reg.we,
        o_slave1_wdata => mp_sorter_reg.wdata,

        o_slave2_addr  => lvds_rx_reg.addr(15 downto 0),
        o_slave2_re    => lvds_rx_reg.re,
        i_slave2_rdata => lvds_rx_reg.rdata,
        o_slave2_we    => lvds_rx_reg.we,
        o_slave2_wdata => lvds_rx_reg.wdata,

        i_reset_n      => reset_n,
        i_clk          => clk--,
    );

    e_lvds_rx_reg_mapping : entity work.lvds_rx_reg_mapping
    port map (
        i_reg_addr        => lvds_rx_reg.addr(15 downto 0),
        i_reg_re          => lvds_rx_reg.re,
        o_reg_rdata       => lvds_rx_reg.rdata,
        i_reg_we          => lvds_rx_reg.we,
        i_reg_wdata       => lvds_rx_reg.wdata,

        i_lvds_status   => (0 => x"00000001",
                            1 => x"00000002",
                            2 => x"00000003",
                            3 => x"00000004",
                            4 => x"00000005",
                            5 => x"00000006",
                            6 => x"00000007",
                            7 => x"00000008",
                            8 => x"00000009",
                            others => (others => '0')),

        i_reset_125_n   => reset_n,
        i_clk_125       => clk--,
    );

    e_mp_sorter_reg_mapping : entity work.mp_sorter_reg_mapping
    port map (
        i_reg_addr     => mp_sorter_reg.addr(15 downto 0),
        i_reg_re       => mp_sorter_reg.re,
        o_reg_rdata    => mp_sorter_reg.rdata,
        i_reg_we       => mp_sorter_reg.we,
        i_reg_wdata    => mp_sorter_reg.wdata,

        i_nintime      => (others => x"AFFEAFFE"),
        i_noutoftime   => (others => x"FFFFFFFF"),
        i_noverflow    => (others => x"FFFFFFFF"),
        i_nout         => x"AB585487",
        i_credit       => x"11447788",
        o_sorter_delay => open,

        i_reset_n      => reset_n,
        i_clk          => clk--,
    );

    e_iram : entity work.ram_1r1w
    generic map (
        g_DATA_WIDTH => 32,
        g_ADDR_WIDTH => 10--,
    )
    port map (
        i_raddr => iram_addr(10-1 downto 0),
        o_rdata => iram_rdata,
        i_rclk  => clk,

        i_waddr => iram_addr(10-1 downto 0),
        i_wdata => iram_wdata,
        i_we    => iram_we,
        i_wclk  => clk--,
    );

    process
    begin
        wait;
    end process;

end architecture;
