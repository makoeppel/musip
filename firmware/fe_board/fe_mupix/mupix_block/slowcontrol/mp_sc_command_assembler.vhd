----------------------------------------------------------------------------
-- Mupix Slowcontrol command assembler
-- M. Mueller
-- Nov 2022

-- aka "mu3e slowcontrol protocol" .. in need of a better name

-- this entity exists once for each chip of the FEB
-- connects to the 4 dpf's and assembles the next command that should be send to this specific chip
-- takes into account the dead time of this specific chip on the rdy output
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.mupix.all;
use work.mudaq.all;
use work.mupix_registers.all;
use work.util_slv.all;


entity mp_sc_command_assembler is
generic (
    g_LADDER_ADDR : std_logic_vector(3 downto 0) := "1111"--;
);
port (
    -- connections to config storage
    o_read                  : out   mp_conf_storage_interface_in;
    i_data                  : in    mp_conf_storage_interface_out;

    -- presenting the next command to (insert name once it has one)
    o_command               : out   std_logic_vector(63 downto 0);
    o_rdy                   : out   std_logic := '0';
    i_ack                   : in    std_logic := '0';
    i_tick                  : in    std_logic := '0';
    -- external command for the mupix that is send directly from the software
    -- and is not generated here
    i_ext_cmd               : in    work.mupix.mp_ctrl_external_command_t;
    i_vdac_ctrl             : in    std_logic_vector(31 downto 0);

    i_clk_dpf               : in    std_logic; -- 156.25 MHz of the config storage
    i_reset_n               : in    std_logic := '0';
    i_clk                   : in    std_logic--; -- slow clock of the mu3e control
);
end entity;

architecture RTL of mp_sc_command_assembler is

    type command_assembler_state_type is (idle, dead, ackWait);
    signal state                      : command_assembler_state_type;
    signal dpf_has_data               : std_logic_vector(3 downto 0);
    signal dpf_has_data_reg           : std_logic_vector(3 downto 0);
    signal dpf_has_data_fast_prev     : std_logic_vector(3 downto 0);
    signal dpf_empty_flag             : std_logic_vector(3 downto 0); -- flag when a dpf fifo became empty, remove once load is executed
    signal dpf_empty_flag_slow        : std_logic_vector(3 downto 0);
    signal remove_dpf_empty_flag      : std_logic_vector(3 downto 0);
    signal deadcounter                : integer range 0 to 5;
    signal read_dpf, read_dpf_prev    : std_logic_vector(3 downto 0);
    signal read_dpf_prev2             : std_logic_vector(3 downto 0);
    signal shift1                     : std_logic := '0';
    signal ext_cmd_trigger_prev       : std_logic := '0';
    signal is_first_row               : std_logic := '1';
    signal first_row_tdacs_written    : std_logic := '0';

    signal buffer_vdac_command        : slv64_array_t(7 downto 0);
    signal write_vdac_low_started     : std_logic := '0';
    signal write_vdac_high_started    : std_logic := '0';
    signal write_vdac_low_reg         : std_logic := '0';
    signal write_vdac_high_reg        : std_logic := '0';
    signal idx                        : integer range 0 to 7;

begin

    -- false path signals between 15.625 and 156.25 MHz:
    -- remove_dpf_empty_flag
    -- dpf_empty_flag
    -- read_dpf
    -- i_data

    -- 156.25 MHz process
    process(i_clk_dpf, i_reset_n) is
    begin
    if ( i_reset_n = '0' ) then
        o_read.mu3e_read        <= (others => '0');
        read_dpf_prev           <= (others => '0');
        dpf_has_data_fast_prev  <= (others => '0');
        dpf_empty_flag          <= (others => '0');
        --
    elsif rising_edge(i_clk_dpf) then
        dpf_has_data_fast_prev  <= i_data.rdy;
        o_read.spi_read         <= (others => '0');
        read_dpf_prev           <= read_dpf;
        read_dpf_prev2          <= read_dpf_prev;

        for I in 0 to 3 loop
            if (read_dpf_prev(I) = '1' and read_dpf_prev2(I) = '0') then
                o_read.mu3e_read(I) <= '1';
            else
                o_read.mu3e_read(I) <= '0';
            end if;

            if(i_data.rdy(I) = '0' and dpf_has_data_fast_prev(I) = '1') then
                dpf_empty_flag(I) <= '1';
            end if;

            if(remove_dpf_empty_flag(I) = '1') then
                dpf_empty_flag(I) <= '0';
            end if;

        end loop;

    end if;
    end process;

    -- 15.625 MHz process (a.k.a. the entrance to timing wonderland)
    process(i_clk, i_reset_n) is
    begin
    if ( i_reset_n = '0' ) then
        o_rdy                 <= '0';
        o_command             <= (others => '0');
        state                 <= idle;
        deadcounter           <= 0;
        write_vdac_low_started <= '0';
        write_vdac_high_started <= '0';
        write_vdac_low_reg    <= '0';
        write_vdac_high_reg   <= '0';
        remove_dpf_empty_flag <= (others => '0');
        read_dpf              <= (others => '0');
        dpf_empty_flag_slow   <= (others => '0');
        shift1                <= '0';
        is_first_row          <= '1';
        first_row_tdacs_written <= '0';
        idx                   <= 0;
        buffer_vdac_command   <= (others => (others => '0'));
        --
    elsif rising_edge(i_clk) then

        dpf_has_data_reg      <= i_data.rdy;
        dpf_has_data          <= dpf_has_data_reg;
        dpf_empty_flag_slow   <= dpf_empty_flag;
        remove_dpf_empty_flag <= (others => '0');

        if(i_ack = '1') then
            o_rdy       <= '0';
            state       <= dead;
            read_dpf    <= (others => '0');
        elsif (i_tick = '1') then
            write_vdac_low_reg        <= i_vdac_ctrl(WRITE_VDAC_LOW_BIT);
            write_vdac_high_reg       <= i_vdac_ctrl(WRITE_VDAC_HIGH_BIT);
            case state is
            when idle =>
                o_rdy               <= '0';

                if( or_reduce(dpf_empty_flag_slow) = '1' or
                    (i_vdac_ctrl(WRITE_VDAC_LOW_BIT) = '1' and write_vdac_low_reg = '0') or
                    (i_vdac_ctrl(WRITE_VDAC_HIGH_BIT) = '1' and write_vdac_high_reg = '0')
                ) then
                    state <= ackWait;

                    if (i_vdac_ctrl(WRITE_VDAC_LOW_BIT) = '1') then
                        idx <= 1;
                        write_vdac_low_started <= '1';
                        o_command <= buffer_vdac_command(0);
                    elsif (i_vdac_ctrl(WRITE_VDAC_HIGH_BIT) = '1') then
                        idx <= 4;
                        write_vdac_high_started <= '1';
                        o_command <= buffer_vdac_command(3);
                    elsif(dpf_empty_flag_slow(BIAS_BIT)) then
                        remove_dpf_empty_flag(BIAS_BIT)     <= '1';
                        o_command                           <= "00" & x"000000000000F" & COMMAND_LOAD_BIAS & g_LADDER_ADDR;
                    elsif(dpf_empty_flag_slow(CONF_BIT) = '1') then
                        remove_dpf_empty_flag(CONF_BIT)     <= '1';
                        o_command                           <= "00" & x"000000000000F" & COMMAND_LOAD_CONF & g_LADDER_ADDR;
                    elsif(dpf_empty_flag_slow(VDAC_BIT) = '1') then
                        remove_dpf_empty_flag(VDAC_BIT)     <= '1';
                        o_command                           <= "00" & x"000000000000F" & COMMAND_LOAD_VDAC & g_LADDER_ADDR;
                        if (i_vdac_ctrl(STORE_VDAC_LOW_BIT) = '1') then
                            idx                                 <= 1;
                            buffer_vdac_command(0)              <= "00" & x"000000000000F" & COMMAND_LOAD_VDAC & g_LADDER_ADDR;
                        end if;
                        if (i_vdac_ctrl(STORE_VDAC_HIGH_BIT) = '1') then
                            idx                                 <= 4;
                            buffer_vdac_command(3)              <= "00" & x"000000000000F" & COMMAND_LOAD_VDAC & g_LADDER_ADDR;
                        end if;
                    elsif(dpf_empty_flag_slow(TDAC_BIT) = '1') then
                        if(is_first_row = '1' and first_row_tdacs_written = '1') then
                            -- MM: we need to manually load the COL-reg for the first row since COMMAND_SHIFT1 only does this
                            -- after shifting by one bit, so for the first one this is missing otherwise
                            is_first_row                    <= '0';
                            o_command                       <= "00" & x"000000000000F" & COMMAND_LOAD_COL & g_LADDER_ADDR;

                            -- If we have done this from the correct starting postion then we don't want COMMAND_SHIFT1 here and leave immediately:
                            shift1                          <= '0';
                            remove_dpf_empty_flag(TDAC_BIT) <= '1';

                        elsif(shift1 = '1') then
                            shift1                          <= '0';
                            remove_dpf_empty_flag(TDAC_BIT) <= '1';
                            o_command                       <= "00" & x"000000000000F" & COMMAND_SHIFT1    & g_LADDER_ADDR;
                        else
                            o_command                       <= "00" & x"000000000000F" & COMMAND_LOAD_TDAC & g_LADDER_ADDR;
                            shift1                          <= '1';
                            first_row_tdacs_written         <= '1';
                        end if;
                    end if;
                elsif (write_vdac_low_started = '1') then
                    o_rdy               <= '1';
                    state               <= ackWait;
                    o_command           <= buffer_vdac_command(idx);
                    idx                 <= idx + 1;
                    if (idx = 3) then
                        write_vdac_low_started <= '0';
                    end if;
                elsif (write_vdac_high_started = '1') then
                    o_rdy               <= '1';
                    state               <= ackWait;
                    o_command           <= buffer_vdac_command(idx);
                    idx                 <= idx + 1;
                    if (idx = 6) then
                        write_vdac_high_started <= '0';
                    end if;
                elsif(dpf_has_data(BIAS_BIT) = '1') then
                    o_rdy               <= '1';
                    state               <= ackWait;
                    read_dpf(BIAS_BIT)  <= '1';
                    o_command           <= i_data.bias & COMMAND_WRITE_BIAS & g_LADDER_ADDR;
                elsif(dpf_has_data(CONF_BIT) = '1') then
                    o_rdy               <= '1';
                    state               <= ackWait;
                    read_dpf(CONF_BIT)  <= '1';
                    o_command           <= i_data.conf & COMMAND_WRITE_CONF & g_LADDER_ADDR;
                elsif(dpf_has_data(VDAC_BIT) = '1') then
                    o_rdy               <= '1';
                    state               <= ackWait;
                    read_dpf(VDAC_BIT)  <= '1';
                    o_command           <= i_data.vdac & COMMAND_WRITE_VDAC & g_LADDER_ADDR;
                    if (i_vdac_ctrl(STORE_VDAC_LOW_BIT) = '1') then
                        idx <= idx + 1;
                        buffer_vdac_command(idx) <= i_data.vdac & COMMAND_WRITE_VDAC & g_LADDER_ADDR;
                    end if;
                    if (i_vdac_ctrl(STORE_VDAC_HIGH_BIT) = '1') then
                        idx <= idx + 1;
                        buffer_vdac_command(idx) <= i_data.vdac & COMMAND_WRITE_VDAC & g_LADDER_ADDR;
                    end if;
                elsif(dpf_has_data(TDAC_BIT) = '1') then
                    o_rdy               <= '1';
                    state               <= ackWait;
                    read_dpf(TDAC_BIT)  <= '1';
                    o_command           <= i_data.TDAC & COMMAND_WRITE_TDAC & g_LADDER_ADDR;
                else -- external command from software or nothing
                    ext_cmd_trigger_prev<= i_ext_cmd.trigger;
                    if(ext_cmd_trigger_prev /= i_ext_cmd.trigger) then
                        o_rdy               <= '1';
                        state               <= ackWait;
                        o_command           <= i_ext_cmd.command(63 downto 4) & g_LADDER_ADDR; -- MM: i think we should add g_LADDER_ADDR here so that whatever generic software mapping we come up with applies directly to these commands as well
                    end if;                                                                    --     sending the address also from software would mean the software needs to track the config deadtime of 3000 chips to avoid messing up the mu3e protocol
                end if;

            when dead =>
                if (deadcounter = 5) then
                    state       <= idle;
                    deadcounter <= 0;
                else
                    deadcounter <= deadcounter + 1;
                end if;
            when ackWait =>
                o_rdy           <= '1';
            when others =>
                state <= idle;
            end case;
        end if;
    end if;
    end process;

end architecture;
