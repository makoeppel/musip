-- This file is for a simplified Outer Mupix data path that can be used to test
-- the sorter. So just enough to show from data read on the LVDS lines the sorter
-- running, which means unpacker_outer->hit_multiplexer->sorter.
-- Most of this was copied from "fe_board/fe_mupix/mupix_block/mupix_datapath.vhd"
-- and then trimmed down.
--
-- Mark Grimes Jun 2026

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.sorter_pkg.all;

use work.mupix_registers.all;
use work.mupix.all;
use work.mudaq.all;
use work.mapping_functions.all;
use work.util.K28_5;

entity top_sorter_test is
generic (
    g_NUMBER_OF_LINKS : integer := 3;
    g_IS_QUAD      : std_logic := '0';
    g_IS_OUTER     : integer := 1;
    g_USE_TRIGGER  : integer := 0;
    g_LINK_INVERT  : std_logic_vector(35 downto 0) := (others => '0');
    g_IS_TELESCOPE : std_logic := '0';
    g_IS_MUPIX10   : boolean   := false;
    g_LINK_ORDER   : mp_link_order_t--;
);
port (
    --
    -- Ports for data_unpacker_outer
    --
    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic;
    -- Ideally I'd just have one `datain : in work.util_slv.slv8_array_t(g_NUMBER_OF_LINKS - 1 downto 0);`,
    -- but cocotb doesn't seem to like setting that from python. So I need to have 3 hardcoded ones
    -- (because g_NUMBER_OF_LINKS = 3) and in a hardcoded process convert these into one `datain` signal
    -- to use with other generated stuff. So if g_NUMBER_OF_LINKS is changed from 3 these hardcoded parts
    -- need to change.
    datain_0            : in    std_logic_vector(7 downto 0); --work.util_slv.slv8_array_t(g_NUMBER_OF_LINKS - 1 downto 0);
    datain_1            : in    std_logic_vector(7 downto 0);
    datain_2            : in    std_logic_vector(7 downto 0);
    kin                 : in    std_logic_vector(g_NUMBER_OF_LINKS - 1 downto 0);
    i_bad               : in    std_logic_vector(g_NUMBER_OF_LINKS - 1 downto 0);
    readyin             : in    std_logic_vector(g_NUMBER_OF_LINKS - 1 downto 0);
    i_slowctrl_empty    : in    std_logic_vector(g_NUMBER_OF_LINKS - 1 downto 0) := (others => '0');


    --
    -- Ports for hitsorter
    --
    i_running                : in    std_logic;
    o_data_out               : out   reg32;                        -- packaged data out
    o_out_ena                : out   std_logic;                    -- valid output data
    o_out_type               : out   std_logic_vector(3 downto 0); -- start/end of an output package, hits, end of run
    o_out_is_hit             : out   std_logic;                    -- same as out_ena, but only hits, no trailer header etc.

    o_reg_rdata              : out   std_logic_vector(31 downto 0);

    i_sync_reset_cnt         : in  std_logic;

    -- Stuff to record the tests
    debug_nmultiplexer_hits  : out integer;
    debug_nsorter_out_hits   : out integer
);
end entity;

architecture rtl of top_sorter_test is

    signal datain : work.util_slv.slv8_array_t(g_NUMBER_OF_LINKS - 1 downto 0);

    signal hits_ena_unpacker        : std_logic_vector(g_NUMBER_OF_LINKS - 1 downto 0);
    signal ts_unpacker              : ts_array_t(g_NUMBER_OF_LINKS - 1 downto 0);
    signal row_unpacker             : row_array_t(g_NUMBER_OF_LINKS - 1 downto 0);
    signal col_unpacker             : col_array_t(g_NUMBER_OF_LINKS - 1 downto 0);
    signal tot_unpacker             : tot_array_t(g_NUMBER_OF_LINKS - 1 downto 0);
    signal chip_ID_unpacker         : ch_ID_array_t(g_NUMBER_OF_LINKS - 1 downto 0);

    signal ts_hs                    : ts_array_t(35 downto 0);
    signal row_hs                   : row_array_t(35 downto 0);
    signal col_hs                   : col_array_t(35 downto 0);
    signal tot_hs                   : tot_array_t(35 downto 0);
    signal chip_ID_hs               : ch_ID_array_t(35 downto 0);
    signal sel_chip                 : work.util_slv.slv2_array_t(g_NUMBER_OF_LINKS - 1 downto 0);
    signal hits_sorter_in           : hit_array(g_NUMBER_OF_LINKS - 1 downto 0) := (others => (others => '0'));
    -- Note that mupix_datapath.vhd doesn't set a default for this
    signal chipID_sorter_in         : work.util_slv.slv2_array_t(g_NUMBER_OF_LINKS - 1 downto 0) := (others => (others => '0'));
    signal hits_sorter_in_ena       : std_logic_vector(2 downto 0) := (others => '0');

    constant mp_use_arrival_time      : std_logic_vector(35 downto 0) := (others => '0');


    signal counter125               : std_logic_vector(63 downto 0);

    signal link_enable              : std_logic_vector(g_NUMBER_OF_LINKS - 1 downto 0);

    signal coarsecounters           : work.util_slv.slv24_array_t(35 downto 0) := (others => (others => '0'));
    signal coarsecounter_enas       : std_logic_vector(35 downto 0) := (others => '0');
    signal coarsecounter_diff       : work.util_slv.slv24_array_t(35 downto 0) := (others => (others => '0'));
    signal coarsecounter_diff_chip  : work.util_slv.slv24_array_t(g_NUMBER_OF_LINKS - 1 downto 0);

    --hit_ts conversion settings
    constant  mp_readout_mode          : std_logic_vector(31 downto 0) := (others => '0');

    signal last_sorter_hit          : std_logic_vector(31 downto 0);
    signal sorter_out_is_hit        : std_logic;

    signal unpacker_counters : work.util_slv.slv256_array_t(35 downto 0);

    -- sc
    signal mp_sorter_reg            : work.util.rw_t;
    signal slowctrl_readback_data   : reg32array(35 downto 0);
    signal slowctrl_readback_data_ena : std_logic_vector(35 downto 0);

    -- -- link order
    -- signal is_a, is_b, is_c : std_logic_vector(35 downto 0);
    signal one_hot_link : work.util_slv.slv4_array_t(35 downto 0);

begin

    -- Convert my hardcoded `datain_<n>`s into the generically sized `datain` signal. Ideally
    -- I'd just have a generically sized `datain` input, but cocotb can't seem to set that
    -- from python.
    datain(0) <= datain_0;
    datain(1) <= datain_1;
    datain(2) <= datain_2;

    process(i_clk, i_reset_n)
    begin
        if ( i_reset_n = '0' ) then
            counter125 <= (others => '0');
            mp_sorter_reg.addr <= (others => '0'); -- (0 => '1', others => '0');
            mp_sorter_reg.re <= '0';
            mp_sorter_reg.rdata <= (others => '0');
            mp_sorter_reg.we <= '0';
            mp_sorter_reg.wdata <= (others => '0');

            -- debug stuff. `debug_nmultiplexer_hits` is in a generate block below
            debug_nsorter_out_hits <= 0;
        elsif rising_edge(i_clk) then
            if(i_sync_reset_cnt = '1') then
                counter125 <= (others => '0');
            else
                counter125 <= counter125 + 1;
            end if;

            if(sorter_out_is_hit='1') then
                last_sorter_hit <= o_data_out; -- fifo_wdata_hs(31 downto 0);
            end if;

            for i in 0 to 35 loop
                if(coarsecounter_enas(i) = '1') then
                    coarsecounter_diff(i) <= counter125(24-1 downto 0) - coarsecounters(i);
                end if;
            end loop;

            for i in 0 to g_NUMBER_OF_LINKS-1 loop
                coarsecounter_diff_chip(i) <= coarsecounter_diff(i/3);
            end loop;

            -- debug stuff. `debug_nmultiplexer_hits` is in a generate block below
            if ( sorter_out_is_hit = '1' ) then
                debug_nsorter_out_hits <= debug_nsorter_out_hits + 1;
            end if;
        end if; -- end of `if rising_edge(i_clk)`
    end process;

    genunpack:
    FOR i in 0 to g_NUMBER_OF_LINKS - 1 GENERATE
        -- we currently only use link 0 of each chip (up to 8 possible)

        link_enable(i) <= readyin(i); -- data_valid(i) and lvds_link_mask_reg(i);

        unpacker_outer : entity work.data_unpacker_outer
        generic map (
            g_COARSECOUNTER_SIZE => COARSECOUNTERSIZE,
            g_LVDS_ID => i,
            -- TODO: remove mupix10 support
            g_IS_MUPIX10 => g_IS_MUPIX10--,
        )
        port map (
            datain              => datain(i),
            kin                 => kin(i),
            i_bad               => i_bad(i),
            readyin             => link_enable(i),
            i_mp_readout_mode   => mp_readout_mode,
            o_ts                => ts_unpacker(i),
            o_chip_ID           => chip_ID_unpacker(i),
            o_row               => row_unpacker(i),
            o_col               => col_unpacker(i),
            o_tot               => tot_unpacker(i),
            o_hit_ena           => hits_ena_unpacker(i),
            o_coarsecounter     => open, -- coarsecounters(i),     -- open,
            o_coarsecounter_ena => open, -- coarsecounter_enas(i), -- open,
            o_counters          => unpacker_counters(i),
            o_link              => one_hot_link(i),
            o_slowctrl_data     => slowctrl_readback_data(i),
            o_slowctrl_data_ena => slowctrl_readback_data_ena(i),
            -- TODO: add me
            --o_slowctrl_data64     => slowctrl_readback_data64(i),
            --o_slowctrl_data64_ena => slowctrl_readback_data64_ena(i),
            i_slowctrl_empty    => i_slowctrl_empty(i),

            reset_n             => i_reset_n, --reset_125_n,
            clk                 => i_clk --i_clk_125--,
        );
    END GENERATE;

    gen_hm:
    FOR i IN g_NUMBER_OF_LINKS / 3 - 1 downto 0 GENERATE
        -- 3->1 multiplexer
        multiplexer : entity work.hit_multiplexer
        port map (
            i_ts(0)         => ts_unpacker(i*3),
            i_ts(1)         => ts_unpacker(i*3+1),
            i_ts(2)         => ts_unpacker(i*3+2),
            i_chip_ID(0)    => chip_ID_unpacker(i*3),
            i_chip_ID(1)    => chip_ID_unpacker(i*3+1),
            i_chip_ID(2)    => chip_ID_unpacker(i*3+2),
            i_row(0)        => row_unpacker(i*3),
            i_row(1)        => row_unpacker(i*3+1),
            i_row(2)        => row_unpacker(i*3+2),
            i_col(0)        => col_unpacker(i*3),
            i_col(1)        => col_unpacker(i*3+1),
            i_col(2)        => col_unpacker(i*3+2),
            i_tot(0)        => tot_unpacker(i*3),
            i_tot(1)        => tot_unpacker(i*3+1),
            i_tot(2)        => tot_unpacker(i*3+2),
            i_hit_ena       => hits_ena_unpacker(i*3+2) & hits_ena_unpacker(i*3+1) & hits_ena_unpacker(i*3),

            o_ts(0)         => ts_hs(i),
            o_chip_ID(0)    => chip_ID_hs(i),
            o_sel_chip      => sel_chip(i),
            o_row(0)        => row_hs(i),
            o_col(0)        => col_hs(i),
            o_tot(0)        => tot_hs(i),
            o_hit_ena       => hits_sorter_in_ena(i),

            i_reset_n       => i_reset_n, -- sorter_reset_n,
            i_clk           => i_clk -- i_clk_125--,
        );
        hits_sorter_in(i) <=
            col_hs(i) & row_hs(i) & tot_hs(i)(4 downto 0) & ts_hs(i) when mp_use_arrival_time(I)='0' else
            col_hs(i) & row_hs(i) & tot_hs(i)(4 downto 0) & counter125(10 downto 0);
        chipID_sorter_in(i) <= sel_chip(i);

        process(i_clk, i_reset_n)
        begin
            if ( i_reset_n = '0' ) then
                debug_nmultiplexer_hits <= 0;
            elsif rising_edge(i_clk) then
                if ( hits_sorter_in_ena(i) = '1' ) then
                    debug_nmultiplexer_hits <= debug_nmultiplexer_hits + 1;
                end if;
            end if; -- end of `if rising_edge(i_clk)`
        end process;
    END GENERATE;

    e_sorter : entity work.hitsorter
    generic map (
        IS_SORTER_TWO => 0,
        g_IS_OUTER => g_IS_OUTER,
        g_USE_TRIGGER => g_USE_TRIGGER,
        -- TODO: at the moment this is dynamic for mutrig but for mupix we use this and some constants like NOTSHITSIZE, same for NCHIPS
        HIT_WITHOUT_TS_SIZE => 21+2*g_IS_OUTER,
        NSORTERINPUTS => 3,
        TIMESTAMPSIZE => 11--,
    )
    port map (
        -- run control and hit data input
        i_running       => i_running,
        i_currentts     => counter125(MUPIX_TIMESTAMPSIZE-1 downto 0),
        i_hit_mupix     => hits_sorter_in,
        i_chipID        => chipID_sorter_in,
        i_hit_ena_mupix => hits_sorter_in_ena,

        -- hit output
        data_out        => o_data_out, -- fifo_wdata_hs(31 downto 0),
        out_ena         => o_out_ena,
        out_type        => o_out_type, --fifo_wdata_hs(35 downto 32),
        out_is_hit      => sorter_out_is_hit,

        i_ccdiff        => coarsecounter_diff_chip,

        -- slow control sorter register
        i_clk156        => i_clk, -- i_clk_156,
        i_regs_reset_n  => i_reset_n, -- i_reset_156_n,
        i_reg_addr      => mp_sorter_reg.addr(15 downto 0),
        i_reg_re        => mp_sorter_reg.re,
        o_reg_rdata     => mp_sorter_reg.rdata,
        i_reg_we        => mp_sorter_reg.we,
        i_reg_wdata     => mp_sorter_reg.wdata,

        -- clk / reset
        i_reset_n       => i_reset_n,
        i_clk           => i_clk -- i_clk_125--,
    );

end architecture;
