library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity tb_debug_controller is
end entity;

architecture rtl of tb_debug_controller is

    signal clk                    : std_logic := '1';
    signal clk_subdetector        : std_logic := '1';
    signal reset_n                : std_logic;
    signal data_in_debug          : work.mu3e.link32_t := work.mu3e.LINK32_IDLE;
    signal data_out_debug         : work.mu3e.link32_t := work.mu3e.LINK32_IDLE;
    signal data_in_debug_write    : std_logic := '0';
    signal o_debug_frame_counter  : std_logic_vector(31 downto 0);
    signal subdetector_err_flag   : std_logic;
    signal override_granted       : std_logic := '0';
    signal normal_data_full       : std_logic := '0';
    signal normal_data_almost_full: std_logic := '0';
    signal new_packet             : std_logic := '0';
    signal running                : std_logic := '1';

begin

    clk     <= not clk after (3.2 ns);
    clk_subdetector <= not clk_subdetector after (4 ns);
    reset_n <= '0', '1' after 32 ns;

    process
    begin
        wait;
    end process;

    debug_stream_controller_inst: entity work.debug_stream_controller
    generic map (
        ADDR_WIDTH_g     => 6--,
    )
    port map (
        i_clk                     => clk,
        i_clk_subdetector         => clk_subdetector,
        i_reset_n                 => reset_n,
        i_fpga_ID_in              => x"0001",
        i_FEB_type_in             => "111010",
        i_no_of_debug_pakets      => x"0001",
        i_n_pakets_before_debug   => x"0003",
        o_debug_frame_counter     => o_debug_frame_counter,
        o_subdetector_error_flag  => subdetector_err_flag,
        i_data_debug              => data_in_debug,
        i_data_debug_write        => data_in_debug_write,
        o_override_request        => open,
        i_override_granted        => override_granted,
        i_normal_data_almost_full => normal_data_almost_full,
        i_normal_data_full        => normal_data_full,
        i_new_data_packet         => new_packet,
        i_running                 => running,
        o_debug_almost_full       => open,
        o_data                    => data_out_debug
    );

end architecture;
