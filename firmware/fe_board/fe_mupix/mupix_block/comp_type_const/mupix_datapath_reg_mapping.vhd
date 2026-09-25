-- Last Change: M.Mueller, November 2020 (muellem@uni-mainz.de)
-- there are TWO instances of this entity: one in mp_block, one in mp_datapath
-- TODO: check if things are compiled away correctly in 2nd instance_name .. if not --> new file mupix_reg_mapping_datapath.vhd

-- At some point we might want to generate this file automatically from mupix_registers.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mupix_registers.all;
use work.mupix.all;
use work.lvds_registers.all;

entity mupix_datapath_reg_mapping is
generic (
    g_LINK_ORDER : mp_link_order_t--;
);
port (
    i_reg_addr                  : in  std_logic_vector(15 downto 0);
    i_reg_re                    : in  std_logic;
    o_reg_rdata                 : out std_logic_vector(31 downto 0);
    i_reg_we                    : in  std_logic;
    i_reg_wdata                 : in  std_logic_vector(31 downto 0);

    -- outputs 156--------------------------------------------
    o_lvds_link_mask            : out std_logic_vector(35 downto 0); -- lvds link mask
    o_mp_use_arrival_time       : out std_logic_vector(35 downto 0);
    o_lvds_invert               : out std_logic_vector(35 downto 0);
    o_mp_datagen_control        : out std_logic_vector(31 downto 0); -- control register for the mupix data gen
    o_mp_readout_mode           : out std_logic_vector(31 downto 0); -- Invert ts, degray, chip ID numbering, tot mode, ..
    o_mp_data_bypass_select     : out std_logic_vector(31 downto 0);
    o_mp_delta_ts_link_select   : out std_logic_vector(5 downto 0);

    -- inputs  156--------------------------------------------
    -- ALL INPUTS DEFAULT TO (n*4-1 downto 0 => x"CCC..", others => '1')

    i_reset_156_n               : in  std_logic;
    i_clk_156                   : in  std_logic;

    -- inputs  125 (how to sync)------------------------------
    i_coarsecounter_ena         : in std_logic := '0';
    i_coarsecounter             : in std_logic_vector(23 downto 0) := (others => '0');
    i_ts_global                 : in std_logic_vector(23 downto 0) := (others => '0');
    i_last_sorter_hit           : in std_logic_vector(31 downto 0) := (others => '0');

    -- counter inputs
    i_mp_sc_cnt                 : in std_logic_vector(31 downto 0) := (others => '0');
    i_mp_sc_error_cnt           : in std_logic_vector(31 downto 0) := (others => '0');
    i_mp_hit_error_cnt          : in std_logic_vector(31 downto 0) := (others => '0');
    i_mp_hit_ena_cnt            : in std_logic_vector(31 downto 0) := (others => '0');
    i_mp_error_cnt              : in std_logic_vector(31 downto 0) := (others => '0');
    i_mp_package_cnt            : in std_logic_vector(31 downto 0) := (others => '0');
    i_mp_reject_package_cnt     : in std_logic_vector(31 downto 0) := (others => '0');
    i_mp_coarsecounter_error_cnt: in std_logic_vector(31 downto 0) := (others => '0');
    i_mp_sorter_in_hit_ena_cnt  : in std_logic_vector(31 downto 0) := (others => '0');
    i_mp_sorter_out_hit_ena_cnt : in std_logic_vector(31 downto 0) := (others => '0');

    i_trigger0                  : in std_logic_vector(31 downto 0) := (others => '0');
    i_trigger0_reg              : in std_logic_vector(31 downto 0) := (others => '0');
    i_trigger1                  : in std_logic_vector(31 downto 0) := (others => '0');
    i_trigger1_reg              : in std_logic_vector(31 downto 0) := (others => '0');
    i_is_a                      : in std_logic_vector(35 downto 0) := (others => '0');
    i_is_b                      : in std_logic_vector(35 downto 0) := (others => '0');
    i_is_c                      : in std_logic_vector(35 downto 0) := (others => '0');

    -- outputs 125-------------------------------------------------
    o_sorter_inject             : out std_logic_vector(31 downto 0) := (others => '0');
    o_lvds_reset_n              : out std_logic;
    o_mp_chip_unpacker_cnt_select : out std_logic_vector( 7 downto 0) := (others => '0');
    o_mp_hit_ena_cnt_sorter_sel : out std_logic_vector( 3 downto 0) := (others => '0');

    i_reset_125_n               : in  std_logic;
    i_clk_125                   : in  std_logic := '0'--;
);
end entity;

architecture rtl of mupix_datapath_reg_mapping is

    signal mp_datagen_control       : std_logic_vector(31 downto 0);
    signal mp_readout_mode          : std_logic_vector(31 downto 0);
    signal lvds_link_mask           : std_logic_vector(35 downto 0);
    signal mp_use_arrival_time      : std_logic_vector(35 downto 0);
    signal lvds_invert              : std_logic_vector(35 downto 0);
    signal is_a, is_b, is_c         : std_logic_vector(35 downto 0);
    signal mp_data_bypass_select    : std_logic_vector(31 downto 0);
    signal mp_sorter_inject         : std_logic_vector(31 downto 0);
    signal mp_chip_unpacker_cnt_select  : std_logic_vector( 7 downto 0);
    signal mp_counter_unpacker_select   : std_logic_vector( 2 downto 0);
    signal mp_hit_ena_cnt_sorter_sel: std_logic_vector( 3 downto 0);
    signal lvds_reset_n             : std_logic := '1';
    signal reg_delay                : std_logic;
    signal trigger0_reg, trigger1_reg : std_logic_vector(31 downto 0);

begin

    process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
        if(reg_delay = '1') then
            o_sorter_inject <= mp_sorter_inject;
        end if;
    end if;
    end process;

    e_is_a : entity work.ff_sync
    generic map ( W => i_is_a'length )
    port map (
        i_d => i_is_a, o_q => is_a,
        i_reset_n => i_reset_156_n, i_clk => i_clk_156--,
    );
    e_is_b : entity work.ff_sync
    generic map ( W => i_is_b'length )
    port map (
        i_d => i_is_b, o_q => is_b,
        i_reset_n => i_reset_156_n, i_clk => i_clk_156--,
    );
    e_is_c : entity work.ff_sync
    generic map ( W => i_is_c'length )
    port map (
        i_d => i_is_c, o_q => is_c,
        i_reset_n => i_reset_156_n, i_clk => i_clk_156--,
    );

    process(i_clk_156, i_reset_156_n)
        variable regaddr : integer;
    begin
    if ( i_reset_156_n = '0' ) then
        mp_datagen_control        <= (others => '0');
        lvds_link_mask            <= (others => '0');
        mp_sorter_inject          <= (others => '0');
        mp_use_arrival_time       <= (others => '0');
        trigger0_reg              <= (others => '0');
        trigger1_reg              <= (others => '0');

    elsif rising_edge(i_clk_156) then

        --regs for long paths
        o_lvds_link_mask            <= lvds_link_mask;
        o_lvds_invert               <= lvds_invert;
        o_mp_datagen_control        <= mp_datagen_control;
        o_mp_readout_mode           <= mp_readout_mode;
        o_mp_data_bypass_select     <= mp_data_bypass_select;
        o_mp_chip_unpacker_cnt_select <= mp_chip_unpacker_cnt_select;
        o_mp_hit_ena_cnt_sorter_sel <= mp_hit_ena_cnt_sorter_sel;
        o_lvds_reset_n              <= lvds_reset_n;
        o_mp_use_arrival_time       <= mp_use_arrival_time;

        regaddr             := to_integer(unsigned(i_reg_addr));
        o_reg_rdata         <= x"CCCCCCCC";

        if(i_reg_we = '1') then
            reg_delay <= '0';
        else
            reg_delay <= '1';
        end if;

        -----------------------------------------------------------------
        ---- datapath ---------------------------------------------------
        -----------------------------------------------------------------

        if ( regaddr = MP_READOUT_MODE_REGISTER_W and i_reg_we = '1' ) then
            mp_readout_mode <= i_reg_wdata;
        end if;
        if ( regaddr = MP_READOUT_MODE_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= mp_readout_mode;
        end if;

        if ( regaddr = MP_LVDS_LINK_MASK_REGISTER_W and i_reg_we = '1' ) then
            lvds_link_mask(31 downto 0) <= i_reg_wdata;
        end if;
        if ( regaddr = MP_LVDS_LINK_MASK_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= lvds_link_mask(31 downto 0);
        end if;
        if ( regaddr = MP_LVDS_LINK_MASK2_REGISTER_W and i_reg_we = '1' ) then
            lvds_link_mask(35 downto 32) <= i_reg_wdata(3 downto 0);
        end if;
        if ( regaddr = MP_LVDS_LINK_MASK2_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata(3 downto 0) <= lvds_link_mask(35 downto 32);
            o_reg_rdata(31 downto 4)<= (others => '0');
        end if;

        if ( regaddr = MP_DATA_GEN_CONTROL_REGISTER_W and i_reg_we = '1' ) then
            mp_datagen_control <= i_reg_wdata;
        end if;
        if ( regaddr = MP_DATA_GEN_CONTROL_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= mp_datagen_control;
        end if;

        if ( regaddr = MP_LVDS_INVERT_0_REGISTER_W and i_reg_we = '1' ) then
            lvds_invert(31 downto 0) <= i_reg_wdata;
        end if;
        if ( regaddr = MP_LVDS_INVERT_0_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= lvds_invert(31 downto 0);
        end if;
        if ( regaddr = MP_LVDS_INVERT_1_REGISTER_W and i_reg_we = '1' ) then
            lvds_invert(35 downto 32) <= i_reg_wdata(3 downto 0);
        end if;
        if ( regaddr = MP_LVDS_INVERT_1_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata(3 downto 0) <= lvds_invert(35 downto 32);
        end if;

        if ( regaddr = MP_DATA_BYPASS_SELECT_REGISTER_W and i_reg_we = '1' ) then
            mp_data_bypass_select <= i_reg_wdata;
        end if;
        if ( regaddr = MP_DATA_BYPASS_SELECT_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= mp_data_bypass_select;
        end if;

        if ( regaddr = MP_LAST_SORTER_HIT_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_last_sorter_hit;
        end if;

        if ( regaddr = MP_TRIGGER0_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata     <= i_trigger0;
            trigger0_reg    <= i_trigger0_reg;
        end if;

        if ( regaddr = MP_TRIGGER1_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata     <= i_trigger1;
            trigger1_reg    <= i_trigger1_reg;
        end if;

        if ( regaddr = MP_TRIGGER0_REG_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata     <= i_trigger0_reg;
        end if;

        if ( regaddr = MP_TRIGGER1_REG_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata     <= i_trigger1_reg;
        end if;

        if ( regaddr = MP_IS_A_0_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= is_a(31 downto 0);
        end if;
        if ( regaddr = MP_IS_A_1_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(3 downto 0) <= is_a(35 downto 32);
        end if;
        if ( regaddr = MP_IS_B_0_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= is_b(31 downto 0);
        end if;
        if ( regaddr = MP_IS_B_1_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(3 downto 0) <= is_b(35 downto 32);
        end if;
        if ( regaddr = MP_IS_C_0_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= is_c(31 downto 0);
        end if;
        if ( regaddr = MP_IS_C_1_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(3 downto 0) <= is_c(35 downto 32);
        end if;

        if ( regaddr = MP_SORTER_INJECT_REGISTER_W and i_reg_we = '1' ) then
            mp_sorter_inject <= i_reg_wdata;
        end if;
        if ( regaddr = MP_SORTER_INJECT_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= mp_sorter_inject;
        end if;

        if ( regaddr = MP_CHIP_UNPACKER_CNT_REGISTER_W and i_reg_we = '1' ) then
            mp_chip_unpacker_cnt_select <= i_reg_wdata(MP_CHIP_UNPACKER_CNT_SELECT_RANGE);
            mp_counter_unpacker_select <= i_reg_wdata(MP_CNT_UNPACKER_SELECT_RANGE);
        end if;
        if ( regaddr = MP_CHIP_UNPACKER_CNT_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata( 7 downto 0) <= mp_chip_unpacker_cnt_select;
            o_reg_rdata(31 downto 8) <= (others => '0');
        end if;

        if ( regaddr = MP_CHIP_UNPACKER_CNT_REGISTER_R and i_reg_re = '1' ) then
            -- TODO: not the best but for now we go with this
            if ( mp_counter_unpacker_select = "000" ) then
                o_reg_rdata <= i_mp_sc_cnt;
            elsif ( mp_counter_unpacker_select = "001" ) then
                o_reg_rdata <= i_mp_sc_error_cnt;
            elsif ( mp_counter_unpacker_select = "010" ) then
                o_reg_rdata <= i_mp_hit_error_cnt;
            elsif ( mp_counter_unpacker_select = "011" ) then
                o_reg_rdata <= i_mp_hit_ena_cnt;
            elsif ( mp_counter_unpacker_select = "100" ) then
                o_reg_rdata <= i_mp_error_cnt;
            elsif ( mp_counter_unpacker_select = "101" ) then
                o_reg_rdata <= i_mp_package_cnt;
            elsif ( mp_counter_unpacker_select = "110" ) then
                o_reg_rdata <= i_mp_reject_package_cnt;
            elsif ( mp_counter_unpacker_select = "111" ) then
                o_reg_rdata <= i_mp_coarsecounter_error_cnt;
            end if;
        end if;

        if ( regaddr = MP_HIT_ENA_CNT_SORTER_SELECT_REGISTER_W and i_reg_we = '1' ) then
            mp_hit_ena_cnt_sorter_sel <= i_reg_wdata(3 downto 0);
        end if;
        if ( regaddr = MP_HIT_ENA_CNT_SORTER_SELECT_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata( 3 downto 0) <= mp_hit_ena_cnt_sorter_sel;
            o_reg_rdata(31 downto 4) <= (others => '0');
        end if;

        if ( regaddr = MP_HIT_ENA_CNT_SORTER_IN_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata                 <= i_mp_sorter_in_hit_ena_cnt;
            mp_hit_ena_cnt_sorter_sel   <= std_logic_vector(to_unsigned(to_integer(unsigned(mp_hit_ena_cnt_sorter_sel)) + 1,4));
        end if;

        if ( regaddr = MP_HIT_ENA_CNT_SORTER_OUT_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata                 <= i_mp_sorter_out_hit_ena_cnt;
        end if;

        if ( regaddr = MP_RESET_LVDS_N_REGISTER_W and i_reg_we = '1' ) then
            lvds_reset_n <= i_reg_wdata(0);
        end if;
        if ( regaddr = MP_RESET_LVDS_N_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata(0) <= lvds_reset_n;
            o_reg_rdata(31 downto 1) <= (others => '0');
        end if;

        if ( regaddr = MP_USE_ARRIVAL_TIME1_REGISTER_W and i_reg_we = '1' ) then
            mp_use_arrival_time(31 downto 0) <= i_reg_wdata;
        end if;
        if ( regaddr = MP_USE_ARRIVAL_TIME1_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= mp_use_arrival_time(31 downto 0);
        end if;
        if ( regaddr = MP_USE_ARRIVAL_TIME2_REGISTER_W and i_reg_we = '1' ) then
            mp_use_arrival_time(35 downto 32) <= i_reg_wdata(3 downto 0);
        end if;
        if ( regaddr = MP_USE_ARRIVAL_TIME2_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata( 3 downto 0)  <= mp_use_arrival_time(35 downto 32);
            o_reg_rdata(31 downto 4)  <= (others => '0');
        end if;

    end if;
    end process;


    -- histogram of delta ts between mp timestamp and fpga timestamp
--    delta_ts_histo : work.histogram_generic
--    generic map (
--    )
--    port map (
--    );

end architecture;
