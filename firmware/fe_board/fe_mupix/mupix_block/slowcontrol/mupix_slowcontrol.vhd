----------------------------------------------------------------------------
-- Mupix Slowcontrol
-- M. Mueller
-- Feb 2022

-- aka "mu3e slowcontrol protocol" .. in need of a better name
-- once per ladder
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.mupix.all;
use work.mudaq.all;
use work.mupix_registers.all;
use work.util_slv.all;


entity mupix_slowcontrol is
generic (
    g_CHIPS_PER_LANE: positive := 4;
    g_MP_LADDER_ADDR_ARRAY : mp_ladder_addr_array_t := MP_LADDER_ADDR_ARRAY_US_INNER--;
);
port (
    -- connections to config storage
    o_read      : out   mp_conf_array_in(g_CHIPS_PER_LANE-1 downto 0);
    i_data      : in    mp_conf_array_out(g_CHIPS_PER_LANE-1 downto 0);
    i_enable    : in    std_logic;
    i_ext_cmd   : in    work.mupix.mp_ctrl_external_command_array_t(g_CHIPS_PER_LANE-1 downto 0);
    i_vdac_ctrl : in    std_logic_vector(31 downto 0);

    -- connections to direct spi entity
    o_SIN       : out   std_logic;

    i_clk_slow  : in    std_logic;
    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture RTL of mupix_slowcontrol is

    signal commands     : slv64_array_t(g_CHIPS_PER_LANE-1 downto 0);
    signal rdy_array    : std_logic_vector(g_CHIPS_PER_LANE-1 downto 0);
    signal ack_array    : std_logic_vector(g_CHIPS_PER_LANE-1 downto 0);
    signal tick         : std_logic := '0';

begin

    gen_chips: for I in 0 to g_CHIPS_PER_LANE-1 generate
        mp_sc_command_assembler_inst : entity work.mp_sc_command_assembler
        generic map (
            g_LADDER_ADDR => g_MP_LADDER_ADDR_ARRAY(I)
        )
        port map (
            o_read      => o_read(I),
            i_data      => i_data(I),
            o_command   => commands(I),
            o_rdy       => rdy_array(I),
            i_ack       => ack_array(I),
            i_tick      => tick,
            i_ext_cmd   => i_ext_cmd(I),
            i_vdac_ctrl => i_vdac_ctrl,

            i_clk_dpf   => i_clk,
            i_reset_n   => i_reset_n,
            i_clk       => i_clk_slow--,
        );
    end generate;

    mp_sc_lane_controller_inst : entity work.mp_sc_lane_controller
    generic map (
        g_CHIPS_PER_LANE => g_CHIPS_PER_LANE
    )
    port map (
        i_tick      => tick,
        i_commands  => commands,
        i_rdy_array => rdy_array,
        o_ack_array => ack_array,
        o_SIN       => o_SIN,
        i_reset_n   => i_reset_n,
        i_clk       => i_clk_slow--,
    );

    mp_sc_ticker_inst : entity work.mp_sc_ticker
    port map (
        o_tick      => tick,
        i_enable    => i_enable,
        i_reset_n   => i_reset_n,
        i_clk       => i_clk_slow--,
    );

end architecture;
