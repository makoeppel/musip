--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;
use work.feb_sc_registers.all;


ENTITY resetsys is
PORT (
    i_data_125_rx       : in    std_logic_vector(7 downto 0);
    i_data_125_k        : in    std_logic;
    i_data_125_err      : in    std_logic;
    i_data_ready        : in    std_logic;
    i_reset_125_rx_n    : in    std_logic;
    i_clk_125_rx        : in    std_logic;

    o_state_125         : out   run_state_t;
    i_reset_125_n       : in    std_logic;
    i_clk_125           : in    std_logic;

    o_state_156         : out   run_state_t;
    i_reset_156_n       : in    std_logic;
    i_clk_156           : in    std_logic;

    o_resets            : out   std_logic_vector(15 downto 0); -- 16 bit reset mask, use this together with feb state .. example: nios_reset => (run_state=reset and resets(x)='1')
    i_reset_bypass      : in    std_logic_vector(11 downto 0); -- bypass of reset commands (for setups without the genesis board)
    i_reset_bypass_payload : in    std_logic_vector(31 downto 0); -- bypass of reset payloads
    o_run_number        : out   std_logic_vector(31 downto 0); -- run number from midas, updated on state run_prep
    i_fpga_id           : in    std_logic_vector(15 downto 0); -- input of fpga id, needed for addressed reset commands in setups with >1 FEBs
    i_reset_delay       : in    std_logic_vector(7 downto 0);
    i_terminated        : in    std_logic; -- changes run state from terminating to idle if set to 1  (data merger will set this if run was finished properly, signal will be synced to clk_reset_rx INSIDE this entity)
    o_test              : out   std_logic_vector(5 downto 0);

    o_phase             : out   std_logic_vector(31 downto 0);
    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
END ENTITY;

architecture rtl of resetsys is

    -- terminated signal in sync to clk_125_rx of state controller:
    signal terminated_125_rx            : std_logic;

    signal state_125_rx                 : run_state_t;
    signal state_controller_in          : std_logic_vector(7 downto 0);
    signal state_controller_kin         : std_logic;
    signal state_controller_errin       : std_logic;
    signal reset_bypass_125_rx          : std_logic_vector(11 downto 0);
    signal reset_bypass_payload_125_rx  : std_logic_vector(31 downto 0);
    signal reset_bypass_request         : std_logic;
    signal reset_bypass_state           : std_logic_vector(2 downto 0);
    signal phase_50                     : std_logic_vector(31 downto 0);
    signal run_number_125_rx            : std_logic_vector(31 downto 0);
    signal fpga_id_125_rx               : std_logic_vector(15 downto 0);

----------------begin resetsys------------------------
BEGIN

    process(i_clk_125_rx)
    begin
    if rising_edge(i_clk_125_rx) then
        case reset_bypass_state is
        when "000" =>
            -- idle, use genesis
            if(i_data_ready='1' and reset_bypass_125_rx(RESET_BYPASS_BIT_ENABLE)='0') then
                state_controller_in     <= i_data_125_rx;
                state_controller_kin    <= i_data_125_k;
                state_controller_errin  <= i_data_125_err;
            else
                state_controller_in     <= x"BC";
                state_controller_kin    <= '1';
                state_controller_errin  <= '0';
                if(reset_bypass_request = '1') then -- bypass request
                    reset_bypass_state  <= "001";
                end if;
            end if;

        when "001" =>
            state_controller_in     <= reset_bypass_125_rx(RESET_BYPASS_RANGE);
            state_controller_kin    <= '0';
            state_controller_errin  <= '0';
            reset_bypass_state      <= "010";

        when "010" =>
            state_controller_in     <= reset_bypass_payload_125_rx(31 downto 24);
            state_controller_kin    <= '0';
            state_controller_errin  <= '0';
            reset_bypass_state      <= "011";
        when "011" =>
            state_controller_in     <= reset_bypass_payload_125_rx(23 downto 16);
            state_controller_kin    <= '0';
            state_controller_errin  <= '0';
            reset_bypass_state      <= "100";
        when "100" =>
            state_controller_in     <= reset_bypass_payload_125_rx(15 downto 8);
            state_controller_kin    <= '0';
            state_controller_errin  <= '0';
            reset_bypass_state      <= "101";
        when "101" =>
            state_controller_in     <= reset_bypass_payload_125_rx(7 downto 0);
            state_controller_kin    <= '0';
            state_controller_errin  <= '0';
            reset_bypass_state      <= "000";
        when others => reset_bypass_state      <= "000";
        end case;
    end if;
    end process;

    e_edge_detector : entity work.edge_det
    generic map ( EDGE => +1 )
    port map (
        i_d(0) => reset_bypass_125_rx(RESET_BYPASS_BIT_REQUEST),
        o_q(0) => reset_bypass_request,
        i_clk => i_clk_125_rx--,
    );

    -- sync terminated to 125 clk of state controller
    i_ff_sync : entity work.ff_sync
    generic map ( W => 1, N => 5 )
    port map (
        i_d(0)      => i_terminated,
        o_q(0)      => terminated_125_rx,
        i_reset_n   => i_reset_125_rx_n,
        i_clk       => i_clk_125_rx--,
    );

    -- decode state from rx
    i_state_controller : entity work.state_controller
    generic map (
        g_FULL_VERSION => false--,
    )
    port map (
        i_reset_link_data       => state_controller_in,
        i_reset_link_k          => state_controller_kin,
        i_reset_link_err        => state_controller_errin,
        i_fpga_addr             => fpga_id_125_rx,
        i_reset_delay           => i_reset_delay,
        o_run_number            => run_number_125_rx,
        o_reset_mask            => o_resets,
        o_link_test_payload     => open,
        o_sync_test_payload     => open,
        i_terminated            => terminated_125_rx,

        o_state                 => state_125_rx,

        i_reset_n               => i_reset_125_rx_n,
        i_clk                   => i_clk_125_rx--,
    );

    -- measure phase between clk_125_rx and clk_125
    -- sync state from clk_125_rx to clk_125
    i_state_phase_box : entity work.state_phase_box
    port map (
        i_state_125_rx      => state_125_rx,
        i_clk_125_rx        => i_clk_125_rx,

        o_state_125         => o_state_125,
        i_reset_125_n       => i_reset_125_n,
        i_clk_125           => i_clk_125,

        o_phase             => phase_50,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );

------------------------------------------
-- Sync fifo's
------------------------------------------
-- M.Mueller:   connecting a reset signal to some of the sync-fifos leads to timing violations from o_rdata
--              maybe we should switch them to non-Showahead Fifos
--              i se no reason to reset them here.
--              using reset_n=1 for now ...

    e_fifo_sync : entity work.fifo_sync
    generic map (
        g_DATA_RESET => RUN_STATE_IDLE--,
    )
    port map (
        o_rdata     => o_state_156,
        i_rreset_n  => '1',
        i_rclk      => i_clk_156,

        i_wdata     => state_125_rx,
        i_wreset_n  => '1',
        i_wclk      => i_clk_125_rx--,
    );

    e_fifo_sync2 : entity work.fifo_sync
    generic map (
        g_DATA_RESET => (i_reset_bypass'range => '0')--,
    )
    port map (
        o_rdata     => reset_bypass_125_rx,
        i_rreset_n  => '1',
        i_rclk      => i_clk_125_rx,

        i_wdata     => i_reset_bypass,
        i_wreset_n  => '1',
        i_wclk      => i_clk_156--,
    );

    e_fifo_sync3 : entity work.fifo_sync
    generic map (
        g_DATA_RESET => (i_reset_bypass_payload'range => '0'),
        g_LPM_HINT => "RAM_BLOCK_TYPE=MLAB"
    )
    port map (
        o_rdata     => reset_bypass_payload_125_rx,
        i_rreset_n  => '1',
        i_rclk      => i_clk_125_rx,

        i_wdata     => i_reset_bypass_payload,
        i_wreset_n  => '1',
        i_wclk      => i_clk_156--,
    );

    e_fifo_sync4 : entity work.fifo_sync
    generic map (
        g_DATA_RESET => (phase_50'range => '0')--,
    )
    port map (
        o_rdata     => o_phase,
        i_rreset_n  => '1',
        i_rclk      => i_clk_156,

        i_wdata     => phase_50,
        i_wreset_n  => '1',
        i_wclk      => i_clk--,
    );

    e_fifo_sync5 : entity work.fifo_sync
    generic map (
        g_DATA_RESET => (run_number_125_rx'range => '0'),
        g_LPM_HINT => "RAM_BLOCK_TYPE=MLAB"
    )
    port map (
        o_rdata     => o_run_number,
        i_rreset_n  => '1',
        i_rclk      => i_clk_156,

        i_wdata     => run_number_125_rx,
        i_wreset_n  => '1',
        i_wclk      => i_clk_125_rx--,
    );

    e_fifo_sync6 : entity work.fifo_sync
    generic map (
        g_DATA_RESET => (i_fpga_id'range => '0')--,
    )
    port map (
        o_rdata     => fpga_id_125_rx,
        i_rreset_n  => '1',
        i_rclk      => i_clk_125_rx,

        i_wdata     => i_fpga_id,
        i_wreset_n  => '1',
        i_wclk      => i_clk_156--,
    );

    o_test <= state_125_rx(o_test'range);

end architecture;
