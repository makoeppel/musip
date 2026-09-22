-- data merger for mu3e FEB
-- Martin Mueller, May 2019

----------------------------------
-- PLEASE READ THE README !!!!!!!
----------------------------------

-- 2 states:
-- - merger state: state of this entity (idle, sending data, sending slowcontrol)
-- - FEB state: "reset" state from FEB_state_controller (idle, run_prep, sync, running, terminating, link_test, sync_test, reset, outOfDaq)
-- do not confuse them !!!

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

ENTITY data_merger is
GENERIC (
    g_FIFO_ADDR_WIDTH : positive := 10;
    N_LINKS                     : positive := 1;
    feb_mapping                 : integer_vector(3 downto 0);
    g_CLK_MHZ : real := 156.25--;
);
PORT (
    i_fpga_ID                   : in    std_logic_vector(15 downto 0); -- will be set by 15 jumpers in the end, set this to something random for now
    i_FEB_type                  : in    std_logic_vector(5  downto 0); -- Type of the frontendboard (111010: mupix, 111000: mutrig, DO NOT USE 000111 or 000000 HERE !!!!)
    i_run_state                 : in    run_state_t;
    i_run_number                : in    std_logic_vector(31 downto 0);

    -- to optical transm.
    o_data                      : out   std_logic_vector(127 downto 0) :=
                                          X"000000" & work.util.K28_5
                                        & X"000000" & work.util.K28_5
                                        & X"000000" & work.util.K28_5
                                        & X"000000" & work.util.K28_5;
    o_datak                     : out   std_logic_vector(15 downto 0) :=
                                          "0001"
                                        & "0001"
                                        & "0001"
                                        & "0001";

    i_data                      : in    std_logic_vector(N_LINKS*36-1 downto 0); -- data input from FIFO (32 bit data, 4 bit ID (0010 Header, 0011 Trail, 0000 Data))
    i_data_slowcontrol          : in    std_logic_vector(35 downto 0); -- data input slowcontrol from SCFIFO (32 bit data, 4 bit ID (0010 Header, 0011 Trail, 0000 SCData))
    i_slowcontrol_write_req     : in    std_logic;
    i_data_write_req            : in    std_logic_vector(N_LINKS-1 downto 0);
    o_fifos_almost_full         : out   std_logic_vector(N_LINKS-1 downto 0);
    i_can_terminate             : in    std_logic :='0'; -- during state terminating, wait for this signal to go high or the data stream to send a run end marker before finally terminating the run.
    o_terminated                : out   std_logic; -- to state controller (when stop run acknowledge was transmitted the state controller can go from terminating into idle, this is the signal to tell him that)
    i_ack_run_prep_permission   : in    std_logic := '1'; -- permission to send the run start ack
    i_override_data             : in    std_logic_vector(31 downto 0); -- data input for states link_test and sync_test;
    i_override_datak            : in    std_logic_vector(3 downto 0);
    i_override_req              : in    std_logic;
    o_override_granted          : out   std_logic_vector(N_LINKS-1 downto 0);
    i_data_priority             : in    std_logic; -- 0: slowcontrol packets have priority, 1: data packets have priority
    o_rate_count                : out   std_logic_vector(31 downto 0);

    i_reset_n                   : in    std_logic;
    i_clk                       : in    std_logic--;
);
END ENTITY;

architecture rtl of data_merger is

    signal terminated                   : std_logic_vector(N_LINKS-1 downto 0);
    signal data_out                     : std_logic_vector(N_LINKS*32-1 downto 0);
    signal data_is_k                    : std_logic_vector(N_LINKS*4-1 downto 0);
    signal rate_counter                 : unsigned(31 downto 0);
    signal time_counter                 : unsigned(31 downto 0);
    signal slowcontrol_write_req_vec    : std_logic_vector(N_LINKS-1 downto 0);

BEGIN

    o_terminated                <= and_reduce(terminated);
    slowcontrol_write_req_vec   <= (0 => i_slowcontrol_write_req, others => '0');

    feb_map: for j in N_LINKS-1 downto 0 generate
    begin
        o_data((feb_mapping(j)+1)*32-1 downto 32*feb_mapping(j)) <= data_out((j+1)*32-1 downto 32*j);
        o_datak((feb_mapping(j)+1)*4-1 downto 4*feb_mapping(j)) <= data_is_k((j+1)*4-1 downto 4*j);
    end generate;

    process(i_clk)
    begin
    if rising_edge(i_clk) then
        -- sample each second (156250000 cycles at 156.25 MHz)
        if ( time_counter = integer(g_CLK_MHZ*1000000.0) ) then
            o_rate_count <= std_logic_vector(rate_counter);
            rate_counter <= (others => '0');
            time_counter <= (others => '0');
        else
            -- overflow can not happen here
            -- increment rate by number of links that contain data
            -- (assume that at most one K bit can be set per link)
            rate_counter <= rate_counter + to_unsigned(N_LINKS - work.util.count_bits(data_is_k), rate_counter'length);
            time_counter <= time_counter + 1;
        end if;
    end if;
    end process;

    g_merger : for i in N_LINKS-1 downto 0 generate
        data_merger_single_inst: entity work.data_merger_single
        generic map (
            g_FIFO_ADDR_WIDTH => g_FIFO_ADDR_WIDTH--,
        )
        port map (
            i_fpga_ID                   => i_fpga_ID,
            i_FEB_type                  => i_FEB_type,
            i_run_state                 => i_run_state,
            i_run_number                => i_run_number,
            o_data                      => data_out((i+1)*32-1 downto 32*i),
            o_datak                     => data_is_k((i+1)*4-1 downto 4*i),
            i_data                      => i_data((i+1)*36-1 downto 36*i),
            i_data_slowcontrol          => i_data_slowcontrol,
            i_slowcontrol_write_req     => slowcontrol_write_req_vec(i),
            i_data_write_req            => i_data_write_req(i downto i),
            o_fifos_almost_full         => o_fifos_almost_full(i downto i),
            i_can_terminate             => i_can_terminate,
            o_terminated                => terminated(i),
            i_ack_run_prep_permission   => i_ack_run_prep_permission,
            i_override_data             => i_override_data,
            i_override_datak            => i_override_datak,
            i_override_req              => i_override_req,
            o_override_granted          => o_override_granted(i downto i),
            i_data_priority             => i_data_priority,

            i_reset_n                   => i_reset_n,
            i_clk                       => i_clk--,
        );
    end generate;

end architecture;
