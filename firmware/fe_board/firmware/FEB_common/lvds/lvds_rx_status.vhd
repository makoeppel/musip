-- mupix lvds rx status
-- M. Mueller, July 2023

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;
use work.util_slv.all;

use work.mupix_registers.all;
use work.lvds_registers.all;
use work.mupix.all;
use work.mudaq.all;

entity lvds_rx_status is
generic (
    g_LVDS_LINKGS : integer := 36--;
);
port (
    i_reg_addr                  : in    std_logic_vector(15 downto 0);
    i_reg_re                    : in    std_logic := '0';
    o_reg_rdata                 : out   std_logic_vector(31 downto 0);
    i_reg_we                    : in    std_logic := '0';
    i_reg_wdata                 : in    std_logic_vector(31 downto 0) := (others => '0');

    i_reg2_addr                 : in    std_logic_vector(15 downto 0) := (others => '0');
    i_reg2_re                   : in    std_logic := '0';
    o_reg2_rdata                : out   std_logic_vector(31 downto 0);
    i_reg2_we                   : in    std_logic := '0';
    i_reg2_wdata                : in    std_logic_vector(31 downto 0) := (others => '0');

    i_clk_156                   : in    std_logic;

    i_hit_ena                   : in    std_logic_vector(g_LVDS_LINKGS - 1 downto 0);
    i_counter                   : in    std_logic_vector(31 downto 0);
    i_lvds_status               : in    lvds_status_array_t(g_LVDS_LINKGS-1 downto 0) := (others => LVDS_ZERO);

    i_reset_125_n               : in    std_logic;
    i_clk_125                   : in    std_logic--;
);
end entity;

architecture rtl of lvds_rx_status is

    signal lvds_status : lvds_status_array_t(g_LVDS_LINKGS-1 downto 0);

begin

    gen: for I in 0 to g_LVDS_LINKGS - 1 generate
        lvds_status(i).disperr       <= i_lvds_status(i).disperr;
        lvds_status(i).err8b10b      <= i_lvds_status(i).err8b10b;
        lvds_status(i).pll_locked    <= i_lvds_status(i).pll_locked;
        lvds_status(i).ready         <= i_lvds_status(i).ready;
        lvds_status(i).dpa_locked    <= i_lvds_status(i).dpa_locked;
        lvds_status(i).aligncnt      <= i_lvds_status(i).aligncnt;

        -- i_hit_ena is from the data_unpacker where we already have the correct link order
        -- Therefore signals derived from this do not need reordering
        process(i_clk_125, i_reset_125_n) is
        begin
        if ( i_reset_125_n = '0' ) then
            lvds_status(i).hitcnt           <= (others => '0');
            lvds_status(i).arrival_phase    <= (others => '0');
            lvds_status(i).out_of_phase_cnt <= (others => '0');
            --
        elsif rising_edge(i_clk_125) then
            if(i_hit_ena(i) = '1') then
                lvds_status(i).hitcnt <= lvds_status(i).hitcnt + 1;
                lvds_status(i).arrival_phase <= i_counter(1 downto 0);

                if ( lvds_status(i).arrival_phase /= i_counter(1 downto 0) ) then
                    lvds_status(i).out_of_phase_cnt <= lvds_status(i).out_of_phase_cnt + 1;
                end if;
            end if;
        end if;
        end process;
    end generate;

    lvds_rx_reg_mapping_inst: entity work.lvds_rx_reg_mapping
    generic map (
        g_LVDS_LINKGS => g_LVDS_LINKGS
    )
    port map (
        i_reg_addr      => i_reg_addr,
        i_reg_re        => i_reg_re,
        o_reg_rdata     => o_reg_rdata,
        i_reg_we        => i_reg_we,
        i_reg_wdata     => i_reg_wdata,

        i_reg2_addr     => i_reg2_addr,
        i_reg2_re       => i_reg2_re,
        o_reg2_rdata    => o_reg2_rdata,
        i_reg2_we       => i_reg2_we,
        i_reg2_wdata    => i_reg2_wdata,

        i_clk_156       => i_clk_156,

        i_lvds_status   => lvds_status,

        i_reset_125_n   => i_reset_125_n,
        i_clk_125       => i_clk_125--,
    );

end architecture;
