-- Mupix 10 data path (online repo)
-- M.Mueller, Oktober 2020

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.mudaq.all;
use work.mupix.all;
use work.lvds_registers.all;
use work.mupix_registers.all;
use work.sorter_pkg.all;

entity mupix_datapath is
generic (
    g_IS_QUAD      : std_logic := '0';
    g_IS_OUTER     : integer := 0;
    g_USE_TRIGGER  : integer := 0;
    g_LINK_INVERT  : std_logic_vector(35 downto 0) := (others => '0');
    g_IS_TELESCOPE : std_logic := '0';
    g_IS_MUPIX10   : boolean   := false;
    g_LINK_ORDER   : mp_link_order_t--;
);
port (
    i_lvds_rx_inclock_A : in  std_logic;
    i_lvds_rx_inclock_B : in  std_logic;
    i_lvds_data         : in  std_logic_vector(35 downto 0);

    i_reg_addr          : in  std_logic_vector(15 downto 0);
    i_reg_re            : in  std_logic;
    o_reg_rdata         : out std_logic_vector(31 downto 0);
    i_reg_we            : in  std_logic;
    i_reg_wdata         : in  std_logic_vector(31 downto 0);

    o_fifo_wdata        : out std_logic_vector(35 downto 0);
    o_fifo_write        : out std_logic;

    o_data_bypass       : out std_logic_vector(31 downto 0) := x"000000BC";
    o_data_bypass_we    : out std_logic := '0';

    i_sync_reset_cnt    : in  std_logic;
    i_fpga_id           : in  std_logic_vector(7 downto 0);
    i_run_state_125     : in  run_state_t;
    i_run_state_156     : in  run_state_t;

    i_trigger_en        : in  std_logic := '0';
    i_trigger_timestamp : in  std_logic_vector(31 downto 0);

    i_clk_125           : in  std_logic;
    i_reset_156_n       : in  std_logic;
    i_clk_156           : in  std_logic--;
);
end entity;

architecture rtl of mupix_datapath is

    -- This is the number of inputs fed into the sorter. This should always be
    -- the number of links divided by 3, i.e. NCHIPS. For inner pixel this is
    -- the same as the number of chips, for outer pixel it is the number of
    -- chips divided by 3. So NCHIPS is not a good constant name when you're
    -- thinking about outer pixel, but the value is correct.
    --
    -- You might want to reduce `sorter_inputs` for debugging however, to
    -- create space for signal taps because the sorter takes up a lot of fabric.
    -- It should always be a multiple of 3.
    constant sorter_inputs          : integer := NCHIPS;

    signal reset_156_n              : std_logic;
    signal reset_125_n              : std_logic;
    signal sorter_reset_n           : std_logic := '0';

    -- signals after mux
    signal rx_data_raw, rx_data     : slv8_array_t(35 downto 0);
    signal rx_k_raw, rx_k, rx_bad_raw, rx_bad  : std_logic_vector(35 downto 0);
    signal lvds_status_raw, lvds_status : lvds_status_array_t(35 downto 0);
    signal lvds_invert              : std_logic_vector(35 downto 0);
    signal data_valid_raw, data_valid : std_logic_vector(35 downto 0);
    signal link_order               : mp_link_order_t := g_LINK_ORDER;

    -- hits + flag to indicate a word as a hit, after unpacker
    signal hits_ena                 : std_logic_vector(35 downto 0);
    signal ts                       : ts_array_t(35 downto 0);
    signal row                      : row_array_t(35 downto 0);
    signal col                      : col_array_t(35 downto 0);
    signal tot                      : tot_array_t(35 downto 0);
    signal chip_ID                  : ch_ID_array_t(35 downto 0);

    signal hits_ena_unpacker        : std_logic_vector(35 downto 0);
    signal ts_unpacker              : ts_array_t(35 downto 0);
    signal row_unpacker             : row_array_t(35 downto 0);
    signal col_unpacker             : col_array_t(35 downto 0);
    signal tot_unpacker             : tot_array_t(35 downto 0);
    signal chip_ID_unpacker         : ch_ID_array_t(35 downto 0);

    signal hits_ena_gen             : std_logic_vector(35 downto 0);
    signal ts_gen                   : ts_array_t(35 downto 0);
    signal row_gen                  : row_array_t(35 downto 0);
    signal col_gen                  : col_array_t(35 downto 0);
    signal tot_gen                  : tot_array_t(35 downto 0);
    signal chip_ID_gen              : ch_ID_array_t(35 downto 0);

    -- hits afer 3-1 multiplexing
    signal hits_ena_hs              : std_logic_vector(35 downto 0);
    signal ts_hs                    : ts_array_t(35 downto 0);
    signal row_hs                   : row_array_t(35 downto 0);
    signal col_hs                   : col_array_t(35 downto 0);
    signal tot_hs                   : tot_array_t(35 downto 0);
    signal chip_ID_hs               : ch_ID_array_t(35 downto 0);
    signal sel_chip                 : slv2_array_t(11 downto 0);
    signal hits_sorter_in           : hit_array(11 downto 0);
    signal chipID_sorter_in         : slv2_array_t(11 downto 0);
    signal hits_sorter_in_ena       : std_logic_vector(11 downto 0);
    signal hits_sorter_in_buf       : hit_array(11 downto 0);
    signal chipID_sorter_in_buf     : slv2_array_t(11 downto 0);
    signal hits_sorter_in_ena_buf   : std_logic_vector(11 downto 0);
    signal data_bypass              : std_logic_vector(31 downto 0);
    signal data_bypass_we           : std_logic;
    signal data_bypass_select       : std_logic_vector(31 downto 0);

    signal mp_use_arrival_time      : std_logic_vector(35 downto 0);

    signal running                  : std_logic := '0';

    signal counter125               : std_logic_vector(63 downto 0);

    signal gen_seed                 : std_logic_vector(64 downto 0);
    signal mp_datagen_control_reg   : std_logic_vector(31 downto 0);

    signal rx_state                 : std_logic_vector(36*4-1 downto 0);

    signal multichip_ro_overflow    : std_logic_vector(31 downto 0);

    signal link_enable              : std_logic_vector(35 downto 0);
    signal lvds_link_mask           : std_logic_vector(35 downto 0);
    signal lvds_link_mask_reg       : std_logic_vector(35 downto 0);

    signal coarsecounters           : slv24_array_t(35 downto 0);
    signal coarsecounter_enas       : std_logic_vector(35 downto 0);
    signal coarsecounter_diff       : slv24_array_t(35 downto 0);
    signal coarsecounter_diff_chip  : slv24_array_t(11 downto 0);
    signal delta_ts_link_select     : std_logic_vector(5 downto 0);

    --hit_ts conversion settings
    signal mp_readout_mode          : std_logic_vector(31 downto 0);

    signal fifo_wdata               : std_logic_vector(35 downto 0);
    signal fifo_write               : std_logic;
    signal sync_fifo_empty          : std_logic;
    signal sync_fifo_wdata_out      : std_logic_vector(35 downto 0);
    signal sync_fifo_write_out      : std_logic;

    signal fifo_wdata_hs            : std_logic_vector(35 downto 0);
    signal fifo_write_hs            : std_logic;

    signal fifo_wdata_gen           : std_logic_vector(35 downto 0);
    signal fifo_write_gen           : std_logic;

    signal last_sorter_hit          : std_logic_vector(31 downto 0);
    signal sorter_out_is_hit        : std_logic;
    signal sorter_inject            : std_logic_vector(31 downto 0);
    signal sorter_inject_prev       : std_logic;

    signal unpacker_counters, unpacker_counters_156_reg : slv256_array_t(35 downto 0);
    signal chip_unpacker_cnt_select : std_logic_vector( 7 downto 0);
    signal sc_cnt, sc_error_cnt, hit_error_cnt, hit_ena_cnt, error_cnt, package_cnt, reject_package_cnt, coarsecounter_error_cnt : std_logic_vector(31 downto 0);
    signal hitsorter_in_ena_counters_reg: reg32array(11 downto 0);
    signal hitsorter_in_ena_counters: reg32array(11 downto 0);
    signal hitsorter_in_ena_cnt     : std_logic_vector(31 downto 0);
    signal hitsorter_in_ena_cnt_sel : std_logic_vector( 3 downto 0);
    signal hitsorter_out_ena_cnt    : std_logic_vector(31 downto 0);
    signal hitsorter_out_ena_cnt_reg: std_logic_vector(31 downto 0);
    signal lvds_reset_n             : std_logic;

    -- sc
    signal mp_sorter_reg            : work.util.rw_t;
    signal lvds_rx_reg           : work.util.rw_t;
    signal lvds_rx_reg2          : work.util.rw_t;
    signal mp_datapath_reg          : work.util.rw_t;
    signal mp_general_datapath_reg  : work.util.rw_t;
    signal mp_readback_fifos_reg    : work.util.rw_t;
    signal mp_readback_mems_reg     : work.util.rw_t;
    signal slowctrl_readback_data   : reg32array(35 downto 0);
    signal slowctrl_readback_data_ena : std_logic_vector(35 downto 0);
    signal slowctrl_readback_data64   : reg64array(35 downto 0);
    signal slowctrl_readback_data64_ena : std_logic_vector(35 downto 0);
    signal slowctrl_empty           : std_logic_vector(35 downto 0);

    -- link order
    signal is_a, is_b, is_c : std_logic_vector(35 downto 0);
    signal one_hot_link : slv4_array_t(35 downto 0);

    -- trigger
    signal trigger0, trigger1, trigger0_reg, trigger1_reg : std_logic_vector(31 downto 0);

begin

    process(i_clk_156)
    begin
    if rising_edge(i_clk_156) then
        if ( i_run_state_156 = RUN_STATE_SYNC ) then
            reset_156_n <= '0';
        else
            reset_156_n <= '1';
        end if;
    end if;
    end process;

    process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
        if ( i_run_state_125 = RUN_STATE_SYNC ) then
            reset_125_n <= '0';
        else
            reset_125_n <=  '1';
        end if;
    end if;
    end process;

------------------------------------------------------------------------------------
---------------------- trigger------------------------------------------------------

    -- get frequency of frist two triggers
    -- TODO: make this also working for N triggers
    process(i_clk_156)
    begin
    if rising_edge(i_clk_156) then
        if ( sync_fifo_empty = '0' and sync_fifo_wdata_out(27 downto 22) = "001011" ) then
            trigger0        <= sync_fifo_wdata_out(31 downto 0);
            trigger0_reg    <= trigger0;
        end if;

        if ( sync_fifo_empty = '0' and sync_fifo_wdata_out(27 downto 22) = "001100" ) then
            trigger1        <= sync_fifo_wdata_out(31 downto 0);
            trigger1_reg    <= trigger1;
        end if;
    end if;
    end process;

------------------------------------------------------------------------------------
---------------------- sc ----------------------------------------------------------

    e_lvl2_sc_node: entity work.sc_node
    generic map (
        g_SLAVE1_ADDR_MATCH => "00010000--------",
        g_SLAVE2_ADDR_MATCH => "000100010-------",
        g_SLAVE3_ADDR_MATCH => "000100011-------",
        g_SLAVE0_DEPTH      => 2--,
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

        o_slave3_addr  => lvds_rx_reg2.addr(15 downto 0),
        o_slave3_re    => lvds_rx_reg2.re,
        i_slave3_rdata => lvds_rx_reg2.rdata,
        o_slave3_we    => lvds_rx_reg2.we,
        o_slave3_wdata => lvds_rx_reg2.wdata,

        i_reset_n      => i_reset_156_n,
        i_clk          => i_clk_156--,
    );

    lvds_rx_reg_mapping_inst: entity work.lvds_rx_status
    port map (
        i_reg_addr      => lvds_rx_reg.addr(15 downto 0),
        i_reg_re        => lvds_rx_reg.re,
        o_reg_rdata     => lvds_rx_reg.rdata,
        i_reg_we        => lvds_rx_reg.we,
        i_reg_wdata     => lvds_rx_reg.wdata,

        i_reg2_addr     => lvds_rx_reg2.addr(15 downto 0),
        i_reg2_re       => lvds_rx_reg2.re,
        o_reg2_rdata    => lvds_rx_reg2.rdata,
        i_reg2_we       => lvds_rx_reg2.we,
        i_reg2_wdata    => lvds_rx_reg2.wdata,

        i_clk_156       => i_clk_156,

        i_hit_ena       => hits_ena,
        i_counter       => counter125(31 downto 0),
        i_lvds_status   => lvds_status,

        i_reset_125_n   => reset_125_n,
        i_clk_125       => i_clk_125--,
      );

    e_lvl3_sc_node: entity work.sc_node
    generic map (
        g_SLAVE1_ADDR_MATCH => "000100----------",
        g_SLAVE2_ADDR_MATCH => "0010000000------",
        g_SLAVE3_ADDR_MATCH => "00110000--------"--,
    )
    port map (
        i_master_addr  => mp_datapath_reg.addr(15 downto 0),
        i_master_re    => mp_datapath_reg.re,
        o_master_rdata => mp_datapath_reg.rdata,
        i_master_we    => mp_datapath_reg.we,
        i_master_wdata => mp_datapath_reg.wdata,

        o_slave0_addr  => open,
        o_slave0_re    => open,
        i_slave0_rdata => (others => '0'),
        o_slave0_we    => open,
        o_slave0_wdata => open,

        o_slave1_addr  => mp_general_datapath_reg.addr(15 downto 0),
        o_slave1_re    => mp_general_datapath_reg.re,
        i_slave1_rdata => mp_general_datapath_reg.rdata,
        o_slave1_we    => mp_general_datapath_reg.we,
        o_slave1_wdata => mp_general_datapath_reg.wdata,

        o_slave2_addr  => mp_readback_fifos_reg.addr(15 downto 0),
        o_slave2_re    => mp_readback_fifos_reg.re,
        i_slave2_rdata => mp_readback_fifos_reg.rdata,
        o_slave2_we    => mp_readback_fifos_reg.we,
        o_slave2_wdata => mp_readback_fifos_reg.wdata,

        o_slave3_addr  => mp_readback_mems_reg.addr(15 downto 0),
        o_slave3_re    => mp_readback_mems_reg.re,
        i_slave3_rdata => mp_readback_mems_reg.rdata,
        o_slave3_we    => mp_readback_mems_reg.we,
        o_slave3_wdata => mp_readback_mems_reg.wdata,

        i_reset_n      => i_reset_156_n,
        i_clk          => i_clk_156--,
    );

    e_mupix_datapath_reg_mapping : entity work.mupix_datapath_reg_mapping
    generic map (
        g_LINK_ORDER => g_LINK_ORDER--,
    )
    port map (
        i_reg_addr                  => mp_general_datapath_reg.addr(15 downto 0),
        i_reg_re                    => mp_general_datapath_reg.re,
        o_reg_rdata                 => mp_general_datapath_reg.rdata,
        i_reg_we                    => mp_general_datapath_reg.we,
        i_reg_wdata                 => mp_general_datapath_reg.wdata,

        -- outputs 156--------------------------------------------
        o_mp_datagen_control        => mp_datagen_control_reg,
        o_lvds_link_mask            => lvds_link_mask,
        o_lvds_invert               => lvds_invert,
        o_mp_readout_mode           => mp_readout_mode,
        o_mp_data_bypass_select     => data_bypass_select,
        o_mp_delta_ts_link_select   => delta_ts_link_select,
        o_mp_use_arrival_time       => mp_use_arrival_time,

        i_reset_156_n               => i_reset_156_n,
        i_clk_156                   => i_clk_156,

        -- inputs  125 (how to sync)------------------------------
        --i_coarsecounter_ena         => coarsecounter_enas(g_LINK_ORDER(to_integer(unsigned(delta_ts_link_select)))),
        --i_coarsecounter             => coarsecounters(g_LINK_ORDER(to_integer(unsigned(delta_ts_link_select)))),
        i_ts_global                 => counter125(23 downto 0),
        i_last_sorter_hit           => last_sorter_hit,

        -- counter inputs
        i_mp_sc_cnt                 => sc_cnt,
        i_mp_sc_error_cnt           => sc_error_cnt,
        i_mp_hit_error_cnt          => hit_error_cnt,
        i_mp_hit_ena_cnt            => hit_ena_cnt,
        i_mp_error_cnt              => error_cnt,
        i_mp_package_cnt            => package_cnt,
        i_mp_reject_package_cnt     => reject_package_cnt,
        i_mp_coarsecounter_error_cnt => coarsecounter_error_cnt,
        i_mp_sorter_in_hit_ena_cnt  => hitsorter_in_ena_cnt,
        i_mp_sorter_out_hit_ena_cnt => hitsorter_out_ena_cnt_reg,

        i_trigger0                  => trigger0,
        i_trigger1                  => trigger1,
        i_trigger0_reg              => trigger0_reg,
        i_trigger1_reg              => trigger1_reg,
        i_is_a                      => is_a,
        i_is_b                      => is_b,
        i_is_c                      => is_c,

        -- outputs 125-------------------------------------------------
        o_sorter_inject             => sorter_inject,
        o_lvds_reset_n              => lvds_reset_n,
        o_mp_chip_unpacker_cnt_select => chip_unpacker_cnt_select,
        o_mp_hit_ena_cnt_sorter_sel => hitsorter_in_ena_cnt_sel,

        i_reset_125_n               => reset_125_n,
        i_clk_125                   => i_clk_125--,
    );

------------------------------------------------------------------------------------
---------------------- LVDS Receiver part ------------------------------------------
    lvds_block : entity work.mupix_receiver_block
    generic map (
        g_IS_TELESCOPE => g_IS_TELESCOPE--,
    )
    port map (
        rx_in               => i_lvds_data,
        rx_inclock_A        => i_lvds_rx_inclock_A,
        rx_inclock_B        => i_lvds_rx_inclock_B,

        o_rx_status         => lvds_status_raw,
        o_rx_ready          => data_valid_raw,
        i_rx_invert         => lvds_invert,
        o_rx_data           => rx_data_raw,
        o_rx_k              => rx_k_raw,
        o_rx_bad            => rx_bad_raw,

        i_reset_n           => lvds_reset_n,
        i_clk_global        => i_clk_125--,
    );

    process(i_clk_125)
        variable j : integer;
    begin
    if rising_edge(i_clk_125) then
        for i in 0 to 35 loop
            j := link_order(i);
            lvds_status(i).disperr      <= lvds_status_raw(j).disperr;
            lvds_status(i).err8b10b     <= lvds_status_raw(j).err8b10b;
            lvds_status(i).pll_locked   <= lvds_status_raw(j).pll_locked;
            lvds_status(i).ready        <= lvds_status_raw(j).ready;
            lvds_status(i).dpa_locked   <= lvds_status_raw(j).dpa_locked;
            lvds_status(i).aligncnt     <= lvds_status_raw(j).aligncnt;
            data_valid(i)               <= data_valid_raw(j);
            rx_data(i) <= rx_data_raw(j);
            rx_k(i) <= rx_k_raw(j);
            rx_bad(i) <= rx_bad_raw(j);
        end loop;
    end if;
    end process;

    -- use a link mask to disable channels from being used in the data processing

--------------------------------------------------------------------------------------
--------------------- Unpack the data ------------------------------------------------
    genunpack:
    FOR i in 0 to 35 GENERATE
        -- we currently only use link 0 of each chip (up to 8 possible)

        link_enable(I) <= data_valid(i) and lvds_link_mask_reg(i);

        g_IS_NOT_OUTER_PIXEL : if g_IS_OUTER = 0 generate
            unpacker_single : entity work.data_unpacker
            generic map (
                g_COARSECOUNTER_SIZE => COARSECOUNTERSIZE,
                g_LVDS_ID => i,
                -- TODO: remove mupix10 support
                g_IS_MUPIX10 => g_IS_MUPIX10--,
            )
            port map (
                datain              => rx_data(i),
                kin                 => rx_k(i),
                i_bad               => rx_bad(i),
                readyin             => link_enable(i),
                i_mp_readout_mode   => mp_readout_mode,
                o_ts                => ts_unpacker(i),
                o_chip_ID           => chip_ID_unpacker(i),
                o_row               => row_unpacker(i),
                o_col               => col_unpacker(i),
                o_tot               => tot_unpacker(i),
                o_hit_ena           => hits_ena_unpacker(i),
                o_coarsecounter     => coarsecounters(i),
                o_coarsecounter_ena => coarsecounter_enas(i),
                o_counters          => unpacker_counters(i),
                o_link              => one_hot_link(i),
                o_slowctrl_data     => slowctrl_readback_data(i),
                o_slowctrl_data_ena => slowctrl_readback_data_ena(i),
                o_slowctrl_data64     => slowctrl_readback_data64(i),
                o_slowctrl_data64_ena => slowctrl_readback_data64_ena(i),
                i_slowctrl_empty    => slowctrl_empty(i),

                reset_n             => reset_125_n,
                clk                 => i_clk_125--,
            );
        end generate;

        g_IS_OUTER_PIXEL : if g_IS_OUTER = 1 generate
            unpacker_outer : entity work.data_unpacker_outer
            generic map (
                g_COARSECOUNTER_SIZE => COARSECOUNTERSIZE,
                g_LVDS_ID => i,
                -- TODO: remove mupix10 support
                g_IS_MUPIX10 => g_IS_MUPIX10--,
            )
            port map (
                datain              => rx_data(i),
                kin                 => rx_k(i),
                i_bad               => rx_bad(i),
                readyin             => link_enable(i),
                i_mp_readout_mode   => mp_readout_mode,
                o_ts                => ts_unpacker(i),
                o_chip_ID           => chip_ID_unpacker(i),
                o_row               => row_unpacker(i),
                o_col               => col_unpacker(i),
                o_tot               => tot_unpacker(i),
                o_hit_ena           => hits_ena_unpacker(i),
                o_coarsecounter     => open,--coarsecounters(i),
                o_coarsecounter_ena => open,--coarsecounter_enas(i),
                o_counters          => unpacker_counters(i),
                o_link              => one_hot_link(i),
                o_slowctrl_data     => slowctrl_readback_data(i),
                o_slowctrl_data_ena => slowctrl_readback_data_ena(i),
                o_slowctrl_data64     => slowctrl_readback_data64(i),
                o_slowctrl_data64_ena => slowctrl_readback_data64_ena(i),
                i_slowctrl_empty    => slowctrl_empty(i),

                reset_n             => reset_125_n,
                clk                 => i_clk_125--,
            );
        end generate;
    END GENERATE;

    -- check link order
    process(i_clk_125, reset_125_n)
    begin
    if ( reset_125_n = '0' ) then
        is_a <= (others => '0');
        is_b <= (others => '0');
        is_c <= (others => '0');
        --
    elsif rising_edge(i_clk_125) then
        -- check link type
        for i in 0 to 35 loop
            if ( one_hot_link(i) /= 0 ) then
                -- TODO: add D link
                is_a(i) <= one_hot_link(i)(0);
                is_b(i) <= one_hot_link(i)(1);
                is_c(i) <= one_hot_link(i)(2);
            end if;
        end loop;
    end if;
    end process;

    -- put the slowcontrol into storage - FIFO version
    e_sc_readback_mem : entity work.sc_readback_mem
    generic map (
        g_CHIPS => 36--,
    )
    port map (
        -- clk_125
        i_slowctrl_data       => slowctrl_readback_data,
        i_slowctrl_data_ena   => slowctrl_readback_data_ena,
        o_slowctrl_empty      => slowctrl_empty,

        i_clk_125             => i_clk_125,

        io_readback_fifos_reg => mp_readback_fifos_reg,
        i_reset_156_n         => i_reset_156_n,
        i_clk_156             => i_clk_156--,
    );

    -- put the slowcontrol into storage - register version for adcs only
    e_sc_readback_mem_adc : entity work.sc_readback_mem_adc
    generic map (
        g_CHIPS => 36--,
    )
    port map (
        -- clk_125
        i_slowctrl_data64       => slowctrl_readback_data64,
        i_slowctrl_data64_ena   => slowctrl_readback_data64_ena,

        i_clk_125             => i_clk_125,

        io_readback_mems_reg  => mp_readback_mems_reg,
        i_reset_156_n         => i_reset_156_n,
        i_clk_156             => i_clk_156--,
    );


    --------------------------------------------
    -- 2 not so interesting processes (one in 156, one in 125 Mhz)
    -- counting stuff, delaying stuff, etc. nothing really happening here
    --------------------------------------------

    process(i_clk_156)
    begin
    if rising_edge(i_clk_156) then

        unpacker_counters_156_reg <= unpacker_counters;
        hitsorter_in_ena_counters_reg <= hitsorter_in_ena_counters;
        hitsorter_out_ena_cnt_reg <= hitsorter_out_ena_cnt;

        if ( chip_unpacker_cnt_select < 36 ) then
            sc_cnt <= unpacker_counters_156_reg(to_integer(unsigned(chip_unpacker_cnt_select)))(32*0+31 downto 32*0);
            sc_error_cnt <= unpacker_counters_156_reg(to_integer(unsigned(chip_unpacker_cnt_select)))(32*1+31 downto 32*1);
            hit_error_cnt <= unpacker_counters_156_reg(to_integer(unsigned(chip_unpacker_cnt_select)))(32*2+31 downto 32*2);
            hit_ena_cnt <= unpacker_counters_156_reg(to_integer(unsigned(chip_unpacker_cnt_select)))(32*3+31 downto 32*3);
            error_cnt <= unpacker_counters_156_reg(to_integer(unsigned(chip_unpacker_cnt_select)))(32*4+31 downto 32*4);
            package_cnt <= unpacker_counters_156_reg(to_integer(unsigned(chip_unpacker_cnt_select)))(32*5+31 downto 32*5);
            reject_package_cnt <= unpacker_counters_156_reg(to_integer(unsigned(chip_unpacker_cnt_select)))(32*6+31 downto 32*6);
            coarsecounter_error_cnt <= unpacker_counters_156_reg(to_integer(unsigned(chip_unpacker_cnt_select)))(32*7+31 downto 32*7);
        else
            sc_cnt <= (others => '0');
            sc_error_cnt <= (others => '0');
            hit_error_cnt <= (others => '0');
            hit_ena_cnt <= (others => '0');
            error_cnt <= (others => '0');
            package_cnt <= (others => '0');
            reject_package_cnt <= (others => '0');
            coarsecounter_error_cnt <= (others => '0');
        end if;

        if ( hitsorter_in_ena_cnt_sel < 12 ) then
            hitsorter_in_ena_cnt <= hitsorter_in_ena_counters_reg(to_integer(unsigned(hitsorter_in_ena_cnt_sel)));
        else
            hitsorter_in_ena_cnt <= (others => '0');
        end if;
    end if;
    end process;



    process(i_clk_125, reset_125_n)
    begin
    if ( reset_125_n = '0' ) then
        counter125                  <= (others => '0');
        last_sorter_hit             <= (others => '0');
        hitsorter_out_ena_cnt       <= (others => '0');
        hitsorter_in_ena_counters   <= (others => (others => '0'));
        hits_sorter_in_ena          <= (others => '0');

    elsif rising_edge(i_clk_125) then
        lvds_link_mask_reg  <= lvds_link_mask;

        if(i_sync_reset_cnt = '1')then
            counter125 <= (others => '0');
        else
            counter125 <= counter125 + 1;
        end if;

        if(sorter_out_is_hit='1') then
            last_sorter_hit <= fifo_wdata_hs(31 downto 0);
        end if;

        if(i_run_state_125 = RUN_STATE_RUNNING) then
            if(sorter_out_is_hit='1') then
                    hitsorter_out_ena_cnt <= hitsorter_out_ena_cnt + '1';
            end if;
        end if;

        --sorter_inject_prev <= sorter_inject(MP_SORTER_INJECT_ENABLE_BIT);
        --if(sorter_inject_prev = '0' and sorter_inject(MP_SORTER_INJECT_ENABLE_BIT) = '1' and sorter_inject(MP_SORTER_INJECT_SELECT_RANGE) < 12 ) then
        --    hits_sorter_in      <= (others => sorter_inject);
        --    hits_sorter_in_ena  <= (others => '0');
        --    hits_sorter_in_ena(to_integer(unsigned(sorter_inject(MP_SORTER_INJECT_SELECT_RANGE)))) <= '1';
        --else

            for i in 0 to 7 loop
                hits_sorter_in(i)       <= hits_sorter_in_buf(i);
                chipID_sorter_in(i)    <= chipID_sorter_in_buf(i);
                hits_sorter_in_ena(i)   <= hits_sorter_in_ena_buf(i);
            end loop;

            for i in 8 to 10 loop
                hits_sorter_in(i)       <= hits_sorter_in_buf(i);
                chipID_sorter_in(i)    <= chipID_sorter_in_buf(i);
                hits_sorter_in_ena(i)   <= hits_sorter_in_ena_buf(i);
                if ( g_IS_QUAD = '1' ) then
                    hits_sorter_in_ena(i) <= '0';
                end if;
            end loop;

            if ( g_USE_TRIGGER = 1 ) then
                hits_sorter_in(11)      <= i_trigger_timestamp(31 downto 30) & i_trigger_timestamp(18 downto 0) & counter125(10 downto 0);
                hits_sorter_in_ena(11)  <= i_trigger_en;
            else
                hits_sorter_in(11)      <= hits_sorter_in_buf(11);
                chipID_sorter_in(11)    <= chipID_sorter_in_buf(11);
                hits_sorter_in_ena(11)  <= hits_sorter_in_ena_buf(11);
                if ( g_IS_QUAD = '1' ) then
                    hits_sorter_in_ena(11) <= '0';
                end if;
            end if;

        --end if;

        for i in 0 to 11 loop
            if(i_run_state_125 = RUN_STATE_RUNNING) then
                if(hits_sorter_in_ena(i)='1') then
                    hitsorter_in_ena_counters(i) <= hitsorter_in_ena_counters(i) + '1';
                end if;
            end if;
        end loop;

        for i in 0 to 35 loop
            if(coarsecounter_enas(i) = '1') then
                coarsecounter_diff(i) <= counter125(24-1 downto 0) - coarsecounters(i);
            end if;
        end loop;

        for i in 0 to 11 loop
            coarsecounter_diff_chip(i) <= coarsecounter_diff(i/3);
        end loop;

        if(mp_datagen_control_reg(MP_DATA_GEN_SORT_IN_BIT) = '1') then
            ts      <= ts_gen;
            chip_ID <= chip_ID_gen;
            row     <= row_gen;
            col     <= col_gen;
            tot     <= tot_gen;
            hits_ena<= hits_ena_gen;
        else
            ts      <= ts_unpacker;
            chip_ID <= Chip_ID_unpacker;
            row     <= row_unpacker;
            col     <= col_unpacker;
            tot     <= tot_unpacker;
            hits_ena<= hits_ena_unpacker;
        end if;
    end if;
    end process;

    gen_hm:
    FOR i IN 11 downto 0 GENERATE
        -- 3->1 multiplexer
        multiplexer : entity work.hit_multiplexer
        port map (
            i_ts(0)         => ts(i*3),
            i_ts(1)         => ts(i*3+1),
            i_ts(2)         => ts(i*3+2),
            i_chip_ID(0)    => chip_ID(i*3),
            i_chip_ID(1)    => chip_ID(i*3+1),
            i_chip_ID(2)    => chip_ID(i*3+2),
            i_row(0)        => row(i*3),
            i_row(1)        => row(i*3+1),
            i_row(2)        => row(i*3+2),
            i_col(0)        => col(i*3),
            i_col(1)        => col(i*3+1),
            i_col(2)        => col(i*3+2),
            i_tot(0)        => tot(i*3),
            i_tot(1)        => tot(i*3+1),
            i_tot(2)        => tot(i*3+2),
            i_hit_ena       => hits_ena(i*3+2) & hits_ena(i*3+1) & hits_ena(i*3),

            o_ts(0)         => ts_hs(i),
            o_chip_ID(0)    => chip_ID_hs(i),
            o_sel_chip      => sel_chip(i),
            o_row(0)        => row_hs(i),
            o_col(0)        => col_hs(i),
            o_tot(0)        => tot_hs(i),
            o_hit_ena       => hits_sorter_in_ena_buf(i),

            i_reset_n       => sorter_reset_n,
            i_clk           => i_clk_125--,
        );
        hits_sorter_in_buf(i) <=
            col_hs(i) & row_hs(i) & tot_hs(i)(4 downto 0) & ts_hs(i) when mp_use_arrival_time(I)='0' else
            col_hs(i) & row_hs(i) & tot_hs(i)(4 downto 0) & counter125(10 downto 0);
        chipID_sorter_in_buf(i) <= sel_chip(i);
    END GENERATE;

    process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
        if(i_run_state_125 = RUN_STATE_RUNNING) then
            running <= '1';
        else
            running <= '0';
        end if;
        if(i_run_state_125 = RUN_STATE_IDLE) then
            sorter_reset_n <= '0';
        else
            sorter_reset_n <= '1';
        end if;
    end if;
    end process;

    e_sorter : entity work.hitsorter
    generic map (
        IS_SORTER_TWO => 0,
        g_IS_OUTER => g_IS_OUTER,
        g_USE_TRIGGER => g_USE_TRIGGER,
        -- TODO: at the moment this is dynamic for mutrig but for mupix we use this and some constants like NOTSHITSIZE, same for NCHIPS
        HIT_WITHOUT_TS_SIZE => 21+2*g_IS_OUTER,
        NSORTERINPUTS => sorter_inputs,
        TIMESTAMPSIZE => 11--,
    )
    port map (
        -- run control and hit data input
        i_running       => running,
        i_currentts     => counter125(MUPIX_TIMESTAMPSIZE-1 downto 0),
        i_hit_mupix     => hits_sorter_in(sorter_inputs-1 downto 0),
        i_chipID        => chipID_sorter_in(sorter_inputs-1 downto 0),
        i_hit_ena_mupix => hits_sorter_in_ena(sorter_inputs-1 downto 0),

        -- hit output
        data_out        => fifo_wdata_hs(31 downto 0),
        out_ena         => fifo_write_hs,
        out_type        => fifo_wdata_hs(35 downto 32),
        out_is_hit      => sorter_out_is_hit,

        i_ccdiff        => coarsecounter_diff_chip(sorter_inputs-1 downto 0),

        -- slow control sorter register
        i_clk156        => i_clk_156,
        i_regs_reset_n  => i_reset_156_n,
        i_reg_addr      => mp_sorter_reg.addr(15 downto 0),
        i_reg_re        => mp_sorter_reg.re,
        o_reg_rdata     => mp_sorter_reg.rdata,
        i_reg_we        => mp_sorter_reg.we,
        i_reg_wdata     => mp_sorter_reg.wdata,

        -- clk / reset
        i_reset_n       => sorter_reset_n,
        i_clk           => i_clk_125--,
    );

    process(i_clk_125) -- hitsorter, generator, unsorted ...
    begin
    if rising_edge(i_clk_125) then
        if ( mp_datagen_control_reg(MP_DATA_GEN_ENGAGE_BIT) = '1' ) then
            fifo_wdata  <= fifo_wdata_gen;
            fifo_write  <= fifo_write_gen;
        else
            fifo_wdata  <= fifo_wdata_hs;
            fifo_write  <= fifo_write_hs;
        end if;
    end if;
    end process;

    datagen : entity work.mp_sorter_datagen
    port map (
        i_running           => running,
        i_global_ts         => counter125,
        i_control_reg       => mp_datagen_control_reg,
        i_seed              => gen_seed,
        o_hit_counter       => open,
        o_fifo_wdata        => fifo_wdata_gen,
        o_fifo_write        => fifo_write_gen,

        o_ts                => ts_gen,
        o_chip_ID           => chip_ID_gen,
        o_row               => row_gen,
        o_col               => col_gen,
        o_tot               => tot_gen,
        o_hit_ena           => hits_ena_gen,

        i_generror_register => (others => '0'),
        o_error_generated   => open,

        i_reset_n           => sorter_reset_n,
        i_clk               => i_clk_125--,
    );
    gen_seed <= i_fpga_id & not i_fpga_id & i_fpga_id & not i_fpga_id & not i_fpga_id & i_fpga_id & i_fpga_id & not i_fpga_id & '0';

    -- sync some things ...
    e_sync_fifo_cnt : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => 4,
        g_DATA_WIDTH => fifo_wdata'length,
        g_LPM_HINT => "RAM_BLOCK_TYPE=MLAB"--,

    )
    port map (
        i_wdata => fifo_wdata,
        i_we => fifo_write,
        i_wclk => i_clk_125,

        i_rack => not sync_fifo_empty,
        o_rdata => sync_fifo_wdata_out,
        o_rempty => sync_fifo_empty,
        i_rclk => i_clk_156,

        i_reset_n => '1'--,
    );

    o_fifo_wdata <= sync_fifo_wdata_out;
    o_fifo_write <= not sync_fifo_empty;

    -- bypass hitsorter and put data of a single MP directly on a seperate optical link
    process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
        if ( data_bypass_select <= NCHIPS ) then
            data_bypass     <= hits_sorter_in(to_integer(unsigned(data_bypass_select)));
            data_bypass_we  <= hits_sorter_in_ena(to_integer(unsigned(data_bypass_select)));
        else
            data_bypass     <= x"000000BC";
            data_bypass_we  <= '0';
        end if;
    end if;
    end process;

    -- TODO: use sync_fifo
    e_sync_fifo_bypass : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH  => 4,
        g_DATA_WIDTH => 32,
        g_SHOWAHEAD => "OFF"--,
    )
    port map (
        i_we        => data_bypass_we,
        i_wdata     => data_bypass,
        i_wclk      => i_clk_125,

        i_rack      => '1',
        o_rdata     => o_data_bypass,
        o_rempty    => o_data_bypass_we,
        i_rclk      => i_clk_156,

        i_reset_n   => '1'--,
    );

end architecture;
