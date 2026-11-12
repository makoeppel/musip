----------------------------------------------------------------------------
-- Mupix control
-- M. Mueller
-- Feb 2022
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mupix_registers.all;
use work.mupix.all;
use work.mudaq.all;

entity mupix_ctrl is
generic (
    g_SIN_INVERT            : std_logic := '0';
    g_DIRECT_SPI_FIFO_SIZE  : positive := 5;
    g_CHIPS_PER_SPI         : positive := 3;
    g_IS_MUPIX10            : boolean  := false;
    g_N_SPI                 : positive := 4;
    g_MP_LADDER_ADDR_ARRAY  : mp_ladder_addr_array_t := MP_LADDER_ADDR_ARRAY_US_INNER--;
);
port (
    i_reg_addr          : in  std_logic_vector(15 downto 0);
    i_reg_re            : in  std_logic;
    o_reg_rdata         : out std_logic_vector(31 downto 0) := (others => '0');
    i_reg_we            : in  std_logic;
    i_reg_wdata         : in  std_logic_vector(31 downto 0);

    o_SIN               : out std_logic_vector(g_N_SPI-1 downto 0) := (others => '0');

    o_clock             : out std_logic_vector(g_N_SPI-1 downto 0) := (others => '0');
    o_mosi              : out std_logic_vector(g_N_SPI-1 downto 0) := (others => '0');
    o_cs                : out std_logic_vector(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0) := (others => '0');
    o_use_spi           : out std_logic := '1';

    -- used to produce slow clock for Slow Control
    i_clk_125           : in  std_logic := '0';

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture RTL of mupix_ctrl is

    signal to_regmap_reset_n, from_regmap_reset_n : std_logic;
    signal reset_n                      : std_logic;

    signal slow_down                    : std_logic_vector(15 downto 0) := (others => '0');
    signal slow_down_buf                : std_logic_vector(31 downto 0) := (others => '0');
    signal spi_chip_select_mask         : std_logic_vector(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0) := (others => '0'); -- SPI chip select mask
    signal spi_chip_select_mask_sc      : std_logic_vector(35 downto 0) := (others => '0');
    signal spi_chip_select_mask_mp_ctrl : std_logic_vector(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0) := (others => '0');
    signal direct_spi_fifo_full         : std_logic_vector(g_N_SPI-1 downto 0) := (others => '0');
    signal mp_ctrl_to_direct_spi        : reg32array(g_N_SPI-1 downto 0); -- Write data to direct spi from rest of ctrl firmware
    signal mp_ctrl_to_direct_spi_wr     : std_logic_vector(g_N_SPI-1 downto 0) := (others => '0');
    signal sc_to_direct_spi             : reg32array(g_N_SPI-1 downto 0); -- Write data to direct spi from slowcontrol (needs to be enabled using mp_ctrl_direct_spi_ena first)
    signal sc_to_direct_spi_wr          : std_logic_vector(g_N_SPI-1 downto 0) := (others => '0');
    signal mp_direct_spi_busy           : std_logic_vector(g_N_SPI-1 downto 0) := (others => '0');
    signal mp_direct_spi_busy_n         : std_logic_vector(g_N_SPI-1 downto 0) := (others => '0');
    signal mp_ctrl_direct_spi_ena       : std_logic := '0';
    signal mp_ctrl_spi_ena              : std_logic;
    signal mp_ctrl_spi_ena_n            : std_logic;
    signal vdac_ctrl                    : std_logic_vector(31 downto 0);

    signal signals_from_storage         : mp_conf_array_out(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0) := (others => (rdy => (others => '0'), spi_data => (others => '0'), conf => (others => '0'), bias => (others => '0'), vdac => (others => '0'), tdac => (others => '0')));
    signal signals_to_storage           : mp_conf_array_in(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0);
    signal read_mu3e_slowcontrol        : mp_conf_array_in(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0);
    signal read_spi                     : mp_conf_array_in(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0);

    signal direct_conf_reg_data         : reg32 := (others => '0');
    signal direct_bias_reg_data         : reg32 := (others => '0');
    signal direct_vdac_reg_data         : reg32 := (others => '0');
    signal direct_conf_reg_we           : std_logic := '0';
    signal direct_bias_reg_we           : std_logic := '0';
    signal direct_vdac_reg_we           : std_logic := '0';

    signal chip_select_cvb              : std_logic_vector(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0) := (others => '0');
    signal chip_select_tdac             : integer range 0 to g_CHIPS_PER_SPI*g_N_SPI-1 := 0;

    signal combined_data                : reg32 := (others => '0');
    signal combined_data_we             : std_logic := '0';

    signal tdac_data                    : reg32 := (others => '0');
    signal tdac_we                      : std_logic := '0';

    signal run_test                     : std_logic;
    signal n_free_pages                 : reg32;
    signal clk_slow                     : std_logic;

    signal testram_raddr, testram_rdata, testram_waddr, testram_wdata : reg32;

    signal clk_slow_shift               : integer range 0 to 7 := 0;
    signal clk_slow_reset_n             : std_logic_vector(7 downto 0) := (others => '1');
    signal clk_slow_shift_slv           : std_logic_vector(2 downto 0) := (others => '0');
    signal clk_div_reset_n              : std_logic := '1';
    signal clk_div_reset_125_n          : std_logic := '1';
    signal mp_ctrl_sin_invert           : std_logic := '0';
    signal mp_ctrl_external_cmd         : work.mupix.mp_ctrl_external_command_array_t(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0);
    signal s_SIN                        : std_logic_vector(g_N_SPI-1 downto 0);

begin

    -- regenerate reset
    e_regmap_reset_n : entity work.ff_sync
    generic map ( W => 1 )
    port map (
        o_q(0) => to_regmap_reset_n,
        i_d => (others => '1'), i_reset_n => i_reset_n, i_clk => i_clk--,
    );

    slow_down                   <= slow_down_buf(15 downto 0);
    spi_chip_select_mask        <= spi_chip_select_mask_sc(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0) when mp_ctrl_direct_spi_ena = '1' else spi_chip_select_mask_mp_ctrl;
    mp_direct_spi_busy_n        <= not mp_direct_spi_busy;
    mp_ctrl_spi_ena_n           <= not mp_ctrl_spi_ena;
    o_use_spi                   <= mp_ctrl_spi_ena;

    ------------------------------------------------------
    -- SC regs
    ------------------------------------------------------
    e_mupix_ctrl_reg_mapping : entity work.mupix_ctrl_reg_mapping
    generic map (
        g_CHIPS_PER_SPI => g_CHIPS_PER_SPI,
        g_N_SPI => g_N_SPI--,
    )
    port map (
        i_reg_addr                  => i_reg_addr,
        i_reg_re                    => i_reg_re,
        o_reg_rdata                 => o_reg_rdata,
        i_reg_we                    => i_reg_we,
        i_reg_wdata                 => i_reg_wdata,

        i_mp_spi_busy               => '0',

        o_chip_cvb                  => chip_select_cvb,
        o_chip_tdac                 => chip_select_tdac,

        o_conf_reg_data             => direct_conf_reg_data,
        o_conf_reg_we               => direct_conf_reg_we,
        o_vdac_reg_data             => direct_vdac_reg_data,
        o_vdac_reg_we               => direct_vdac_reg_we,
        o_bias_reg_data             => direct_bias_reg_data,
        o_bias_reg_we               => direct_bias_reg_we,

        o_vdac_ctrl                 => vdac_ctrl,

        o_combined_data             => combined_data,
        o_combined_data_we          => combined_data_we,

        o_tdac_data                 => tdac_data,
        o_tdac_we                   => tdac_we,
        o_run_tdac_test             => run_test,

        o_mp_ctrl_slow_down         => slow_down_buf,
        o_mp_direct_spi_data        => sc_to_direct_spi,
        o_mp_direct_spi_data_wr     => sc_to_direct_spi_wr,
        i_mp_direct_spi_busy        => mp_direct_spi_busy,
        o_mp_ctrl_direct_spi_enable => mp_ctrl_direct_spi_ena,
        o_mp_ctrl_direct_spi_chip_m => spi_chip_select_mask_sc,
        o_mp_ctrl_spi_enable        => mp_ctrl_spi_ena,
        o_mp_ctrl_clk_slow_shift    => clk_slow_shift_slv,
        o_mp_ctrl_sin_invert        => mp_ctrl_sin_invert,
        o_mp_ctrl_external_cmd      => mp_ctrl_external_cmd,


        i_testram_rdata             => testram_rdata,
        o_testram_raddr             => testram_raddr,
        o_testram_waddr             => testram_waddr,
        o_testram_wdata             => testram_wdata,

        i_n_free_pages              => n_free_pages,

        o_reset_n                   => from_regmap_reset_n,

        i_reset_n                   => to_regmap_reset_n,
        i_clk                       => i_clk--,
    );

    e_map_reset_n : entity work.ff_sync
    generic map ( W => 1 )
    port map (
        o_q(0) => reset_n,
        i_d => (others => '1'), i_reset_n => from_regmap_reset_n, i_clk => i_clk--,
    );

    ------------------------------------------------------
    -- config storage
    ------------------------------------------------------

    mupix_ctrl_config_storage_inst: entity work.mupix_ctrl_config_storage
    generic map (
        g_CHIPS => g_CHIPS_PER_SPI * g_N_SPI,
        g_IS_MUPIX10 => g_IS_MUPIX10--,
    )
    port map (
        --inputs to write storage data
        i_chip_cvb         => chip_select_cvb,
        i_chip_tdac        => chip_select_tdac,

        i_conf_reg_data    => direct_conf_reg_data,
        i_conf_reg_we      => direct_conf_reg_we,
        i_vdac_reg_data    => direct_vdac_reg_data,
        i_vdac_reg_we      => direct_vdac_reg_we,
        i_bias_reg_data    => direct_bias_reg_data,
        i_bias_reg_we      => direct_bias_reg_we,

        i_combined_data    => combined_data,
        i_combined_data_we => combined_data_we,
        i_tdac_data        => tdac_data,
        i_tdac_we          => tdac_we,

        --connections to SPI and custom protocol writing
        o_data             => signals_from_storage,
        i_read             => signals_to_storage,

        o_testram_rdata    => testram_rdata,
        i_testram_raddr    => testram_raddr,
        i_testram_waddr    => testram_waddr,
        i_testram_wdata    => testram_wdata,

        o_n_free_pages     => n_free_pages,

        i_reset_n          => reset_n,
        i_clk              => i_clk--,
    );

    signals_to_storage <= read_spi when mp_ctrl_spi_ena = '1' else read_mu3e_slowcontrol;

    ------------------------------------------------------
    -- custom protocol (aka "mu3e slowcontrol") writing
    ------------------------------------------------------

    process(i_clk, reset_n)
    begin
    if rising_edge(i_clk) then
        for i in 1 to 7 loop
            clk_slow_reset_n(I) <= clk_slow_reset_n(I-1);
        end loop;
        clk_slow_reset_n(0) <= reset_n;
        clk_div_reset_n <= clk_slow_reset_n(clk_slow_shift);
        clk_slow_shift <= to_integer(unsigned(clk_slow_shift_slv));
    end if;
    end process;

    -- [AK] TODO: use reset_sync (and remove false_path)
    process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
        clk_div_reset_125_n <= clk_div_reset_n;
    end if;
    end process;

    e_clkdiv : entity work.clkdiv
    generic map (
        g_N => 8--,
    )
    port map (
        o_clk => clk_slow,
        i_reset_n => clk_div_reset_125_n,
        i_clk => i_clk_125--,
    );

    gen_spi: for I in 0 to g_N_SPI-1 generate
        mupix_slowcontrol_inst: entity work.mupix_slowcontrol
        generic map (
            g_CHIPS_PER_LANE => g_CHIPS_PER_SPI,
            g_MP_LADDER_ADDR_ARRAY => g_MP_LADDER_ADDR_ARRAY
        )
        port map (
            o_read    => read_mu3e_slowcontrol(I*g_CHIPS_PER_SPI+g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*I),
            i_data    => signals_from_storage(I*g_CHIPS_PER_SPI+g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*I),
            i_enable  => mp_ctrl_spi_ena_n,
            i_ext_cmd => mp_ctrl_external_cmd(I*g_CHIPS_PER_SPI+g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*I),
            o_SIN     => s_SIN(I),
            i_vdac_ctrl => vdac_ctrl,

            i_clk_slow => clk_slow,

            i_reset_n => reset_n,
            i_clk     => i_clk--,
        );

        o_SIN(I) <= s_SIN(I) when (mp_ctrl_sin_invert xor g_SIN_INVERT) = '0' else (not s_SIN(I));
        ------------------------------------------------------
        -- SPI writing
        ------------------------------------------------------

        mp_ctrl_spi_inst: entity work.mp_ctrl_spi
        generic map (
            g_CHIPS_PER_SPI => g_CHIPS_PER_SPI
        )
        port map (
            o_read                  => read_spi(I*g_CHIPS_PER_SPI+g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*I),
            i_data                  => signals_from_storage(I*g_CHIPS_PER_SPI+g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*I),
            o_data_to_direct_spi    => mp_ctrl_to_direct_spi(I),
            o_data_to_direct_spi_we => mp_ctrl_to_direct_spi_wr(I),
            i_direct_spi_fifo_full  => direct_spi_fifo_full(I),
            i_direct_spi_fifo_empty => mp_direct_spi_busy_n(I),
            o_spi_chip_selct_mask   => spi_chip_select_mask_mp_ctrl(I*g_CHIPS_PER_SPI+g_CHIPS_PER_SPI-1 downto g_CHIPS_PER_SPI*I),
            i_run_test              => run_test,

            i_reset_n               => reset_n,
            i_clk                   => i_clk--,
        );

        mp_ctrl_direct_spi_inst: entity work.mp_ctrl_direct_spi
        generic map (
            g_DIRECT_SPI_FIFO_SIZE => g_DIRECT_SPI_FIFO_SIZE,
            g_CHIPS_PER_SPI => g_CHIPS_PER_SPI--,
        )
        port map (
            i_fifo_write_mp_ctrl => mp_ctrl_to_direct_spi_wr(I),
            i_fifo_data_mp_ctrl  => mp_ctrl_to_direct_spi(I),
            o_fifo_almost_full   => direct_spi_fifo_full(I),

            i_direct_spi_enable  => mp_ctrl_direct_spi_ena,
            i_fifo_write_direct  => sc_to_direct_spi_wr(I),
            i_fifo_data_direct   => sc_to_direct_spi(I),
            o_direct_spi_busy    => mp_direct_spi_busy(I),

            i_spi_slow_down      => slow_down,
            i_chip_mask          => spi_chip_select_mask(I*g_CHIPS_PER_SPI+g_CHIPS_PER_SPI-1 downto I*g_CHIPS_PER_SPI),

            o_spi                => o_mosi(I),
            o_spi_clk            => o_clock(I),
            o_cs                 => o_cs(I*g_CHIPS_PER_SPI+g_CHIPS_PER_SPI-1 downto I*g_CHIPS_PER_SPI),

            i_reset_n            => reset_n,
            i_clk                => i_clk--,
        );
    end generate;

end architecture;
