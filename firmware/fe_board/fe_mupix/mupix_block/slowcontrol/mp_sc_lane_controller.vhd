----------------------------------------------------------------------------
-- Mupix Slowcontrol Lane Controller
-- M. Mueller, Nov 2022

-- gets the rdy and command signals from all the mp_sc_command_assemblers of
-- one mupix ladder, decides which one to take, serializes and acknowledge the
-- command and sends it. Does this in distances of pulses on i_tick to account
-- for the config dead time distance (in case that we need to avoid the points
-- where a chip comes out of it's deadtime also for the writing to other chips,
-- not sure if that's needed but now it is there)
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;
use work.mupix.all;

entity mp_sc_lane_controller is
generic (
    g_CHIPS_PER_LANE: positive := 4--;
);
port (
    i_tick                  : in  std_logic;

    i_commands              : in  slv64_array_t(g_CHIPS_PER_LANE-1 downto 0) := (others => (others => '0'));
    i_rdy_array             : in  std_logic_vector(g_CHIPS_PER_LANE-1 downto 0) := (others => '0');
    o_ack_array             : out std_logic_vector(g_CHIPS_PER_LANE-1 downto 0) := (others => '0');
    o_SIN                   : out std_logic;

    i_reset_n               : in  std_logic;
    i_clk                   : in  std_logic--; -- slow clock of the mu3e control
);
end entity;

architecture RTL of mp_sc_lane_controller is

    type lane_controller_state_t is (searching_for_rdy, init, awaiting_tick, tick_delay0, tick_delay1);
    type sending_state_t         is (idle, start_bit, sending);
    signal sending_state        : sending_state_t := idle;
    signal state                : lane_controller_state_t := init;
    signal next_command         : std_logic_vector(63 downto 0) := (others => '0');
    signal target_chip          : integer range 0 to g_CHIPS_PER_LANE-1;
    signal bitpos_counter       : integer range 0 to 63 := 0;

    type init_state_t           is (idle,write0,waiting,write1,waiting2,load,done);
    signal init_state           : init_state_t := idle;
    signal write_0_counter      : integer range 0 to 20;
    signal init_wait_count      : integer range 0 to 7;
    signal init_bitpos_cnt      : integer range 0 to 63 := 0;
    constant COMMAND_64_WRITE_0_COL : std_logic_vector(63 downto 0) := "00" & x"0000000000000" & COMMAND_WRITE_COL & "1111";
    constant COMMAND_64_WRITE_1_COL : std_logic_vector(63 downto 0) := "10" & x"0000000000000" & COMMAND_WRITE_COL & "1111";
    constant COMMAND_64_LOAD_COL    : std_logic_vector(63 downto 0) := "10" & x"000000000000F" & COMMAND_LOAD_COL  & "1111";

begin

    process(i_clk, i_reset_n) is
    begin
    if ( i_reset_n = '0' ) then
        o_SIN           <= '1';
        o_ack_array     <= (others => '0');
        state           <= init;
        sending_state   <= idle;
        next_command    <= (others => '0');
        bitpos_counter  <= 0;
        init_state      <= idle;
        write_0_counter <= 0;
        init_wait_count <= 0;
        init_bitpos_cnt <= 0;

    elsif rising_edge(i_clk) then
        o_ack_array <= (others => '0');
        o_SIN <= '0';

        case state is
          when init =>

            case init_state is
              when idle =>
                if(i_tick = '1') then -- idk why, writing in a hurry and need something that works
                  init_wait_count <= init_wait_count + 1;
                end if;
                if(init_wait_count = 7) then
                  init_wait_count <= 0;
                  init_state      <= write0;
                  o_SIN           <= '1';
                  init_bitpos_cnt <= 0;
                  write_0_counter <= 0;
                end if;

              when write0 =>
                o_SIN             <= COMMAND_64_WRITE_0_COL(init_bitpos_cnt);
                if(init_bitpos_cnt = 63) then
                    init_bitpos_cnt<= 0;
                    write_0_counter <= write_0_counter+1;
                    init_state <= waiting;
                else
                    init_bitpos_cnt<= init_bitpos_cnt + 1;
                end if;

              when waiting =>
                if(i_tick = '1') then
                  init_wait_count <= init_wait_count + 1; -- we have to wait for the deadtime to pass (TODO: can be done shorter, writing this in a hurry and want to be safe)
                end if;
                if(init_wait_count = 7) then
                  init_wait_count <= 0;
                  o_SIN           <= '1';
                  init_bitpos_cnt <= 0;
                  if(write_0_counter = 20) then -- we have for sure written enough 0's now, put in the 1 instead
                    init_state      <= write1;
                    write_0_counter <= 0;
                  else
                    init_state      <= write0;
                  end if;
                end if;

              when write1 => -- same as write0 state, but writing a single 1 instead
                o_SIN               <= COMMAND_64_WRITE_1_COL(init_bitpos_cnt);
                if(init_bitpos_cnt = 63) then
                    init_bitpos_cnt <= 0;
                    init_state      <= waiting2; -- we are done now, move into searching for rdy state and wait for data
                    init_wait_count <= 0;
                else
                    init_bitpos_cnt <= init_bitpos_cnt + 1;
                end if;

              when waiting2 =>
                if(i_tick = '1') then
                  init_wait_count <= init_wait_count + 1;
                end if;
                if(init_wait_count = 7) then
                  init_wait_count <= 0;
                  o_SIN           <= '1';
                  init_bitpos_cnt <= 0;
                  init_state      <= load;
                end if;

              when load =>
                o_SIN               <= COMMAND_64_LOAD_COL(init_bitpos_cnt);
                if(init_bitpos_cnt = 63) then
                    init_bitpos_cnt<= 0;
                    init_state <= done; -- we are done now, move into searching for rdy state and wait for data
                else
                    init_bitpos_cnt<= init_bitpos_cnt + 1;
                end if;

              when done =>
                state <= searching_for_rdy;
                init_state <= idle;

              when others =>
                init_state <= idle;
            end case;

          when searching_for_rdy =>
            for I in 0 to g_CHIPS_PER_LANE-1 loop
                if(i_rdy_array(I) = '1') then
                    target_chip <= I;
                    state       <= awaiting_tick;
                end if;
            end loop;
          when awaiting_tick =>
            if(i_tick = '1') then
                state <= tick_delay0;
            end if;
          when tick_delay0 =>
            state <= tick_delay1;
          when tick_delay1 =>
            state <= searching_for_rdy;
          when others =>
            state <= searching_for_rdy;
        end case;

        case sending_state is
          when idle =>
            if(state = awaiting_tick and i_tick = '1') then
                sending_state <= start_bit;
                next_command  <= i_commands(target_chip);
                o_ack_array(target_chip) <= '1';
            end if;
          when start_bit =>
            o_SIN         <= '1';
            sending_state <= sending;
          when sending =>
            o_SIN             <= next_command(bitpos_counter);
            if(bitpos_counter = 63) then
                bitpos_counter<= 0;
                sending_state <= idle;
            else
                bitpos_counter<= bitpos_counter + 1;
            end if;
          when others =>
            sending_state <= idle;
        end case;

    end if;
    end process;

end architecture;
