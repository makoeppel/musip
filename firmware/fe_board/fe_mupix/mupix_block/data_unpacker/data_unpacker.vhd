-------------------------------------------------------------
-- New version of the data unpacker
--
-- Martin Mueller, Nov 2023
--------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mupix_registers.all;
use work.mupix.all;
use work.mudaq.all;

use work.mapping_functions.all;

use work.util.K28_5;

entity data_unpacker is
generic (
    g_COARSECOUNTER_SIZE : integer := 32;
    g_LVDS_ID : integer := 0;
    g_IS_MUPIX10 : boolean := false--;
);
port (
    reset_n             : in    std_logic;
    clk                 : in    std_logic;
    datain              : in    std_logic_vector(7 downto 0);
    kin                 : in    std_logic;
    i_bad               : in    std_logic; 
    readyin             : in    std_logic;
    i_mp_readout_mode   : in    std_logic_vector(31 downto 0);
    o_ts                : out   std_logic_vector(10 downto 0);
    o_chip_ID           : out   std_logic_vector(5 downto 0);
    o_row               : out   std_logic_vector(7 downto 0);
    o_col               : out   std_logic_vector(7 downto 0);
    o_tot               : out   std_logic_vector(5 downto 0);
    o_hit_ena           : out   std_logic;
    o_coarsecounter     : out   std_logic_vector(23 downto 0);
    o_coarsecounter_ena : out   std_logic;
    o_counters          : out   std_logic_vector(255 downto 0);
    o_link              : out   std_logic_vector(3 downto 0); -- one-hot link encoding
    o_slowctrl_data     : out   std_logic_vector(31 downto 0);
    o_slowctrl_data_ena : out   std_logic := '0';
    o_slowctrl_data64   : out   std_logic_vector(63 downto 0);
    o_slowctrl_data64_ena : out   std_logic := '0';
    i_slowctrl_empty    : in    std_logic := '0'
);
end entity;

architecture RTL of data_unpacker is

    type state_type is (INVALID, LINK, HITS, COUNTER, SC1, SC2, WAIT1, WAIT2, WAIT3);
    signal state                : state_type;
    signal next_state           : state_type;
    signal data_i               : std_logic_vector(31 downto 0) := (others => '0');
    signal datak_i              : std_logic_vector(3  downto 0) := (others => '0');
    signal bad                  : std_logic_vector(3  downto 0) := (others => '0');
    signal dataWithoutSC        : std_logic_vector(31 downto 0);
    signal sc_cnt_reg           : std_logic_vector(31 downto 0);
    signal errorcounter_reg     : std_logic_vector(31 downto 0);
    signal sc_error_cnt_reg     : std_logic_vector(31 downto 0);
    signal package_cnt_reg      : std_logic_vector(31 downto 0);
    signal hit_error_cnt_reg    : std_logic_vector(31 downto 0);
    signal reject_package_cnt_reg : std_logic_vector(31 downto 0);
    signal coarsecounter_error_cnt_reg : std_logic_vector(31 downto 0);
    signal ts                   : std_logic_vector(10 downto 0);
    signal ts2                  : std_logic_vector(4 downto 0);
    signal ts_buf               : std_logic_vector(10 downto 0);
    signal ts2_buf              : std_logic_vector(4 downto 0);
    signal row                  : std_logic_vector(7 downto 0);
    signal col                  : std_logic_vector(7 downto 0);
    signal tot                  : std_logic_vector(5 downto 0);
    signal hit_ena              : std_logic;
    signal chip_ID_mode         : std_logic_vector(1 downto 0);
    signal tot_mode             : std_logic_vector(2 downto 0);
    signal invert_TS            : std_logic;
    signal invert_TS2           : std_logic;
    signal reject_package_with_error : std_logic;
    signal hit_ena_counter      : std_logic_vector(31 downto 0);
    signal coarsecounter        : std_logic_vector(g_COARSECOUNTER_SIZE-1 downto 0); -- Gray Counter[7:0] & Binary Counter [23:0]
    signal coarsecounter_ena    : std_logic;
    signal prev_upper_sc_bits   : std_logic_vector(9 downto 0);
    signal sc_buffer            : std_logic_vector(31 downto 0);
    signal send_one_more_sc     : std_logic;


begin

    o_ts    <= ts_buf;
    o_tot   <= calc_tot(ts2_buf,ts_buf,tot_mode);

    o_coarsecounter     <= coarsecounter(23 downto 0);
    o_coarsecounter_ena <= coarsecounter_ena;

    chip_ID_mode    <= i_mp_readout_mode(CHIP_ID_MODE_RANGE);
    tot_mode        <= i_mp_readout_mode(TOT_MODE_RANGE);
    invert_TS       <= i_mp_readout_mode(INVERT_TS_BIT);
    invert_TS2      <= i_mp_readout_mode(INVERT_TS2_BIT);
    reject_package_with_error <= i_mp_readout_mode(REJECT_PACKAGE_WITH_ERROR_BIT);

    -- counter output
    o_counters(32*0+31 downto 32*0) <= sc_cnt_reg;
    o_counters(32*1+31 downto 32*1) <= sc_error_cnt_reg;
    o_counters(32*2+31 downto 32*2) <= hit_error_cnt_reg;
    o_counters(32*3+31 downto 32*3) <= hit_ena_counter;
    o_counters(32*4+31 downto 32*4) <= errorcounter_reg;
    o_counters(32*5+31 downto 32*5) <= package_cnt_reg;
    o_counters(32*6+31 downto 32*6) <= reject_package_cnt_reg;
    o_counters(32*7+31 downto 32*7) <= coarsecounter_error_cnt_reg;

    fsmProc: process(clk, reset_n)
    begin
    if ( reset_n = '0' ) then
        state                       <= INVALID;
        coarsecounter               <= (others => '0');
        o_link                      <= (others => '0');
        coarsecounter_ena           <= '0';
        sc_cnt_reg                  <= (others => '0');
        sc_error_cnt_reg            <= (others => '0');
        hit_error_cnt_reg           <= (others => '0');
        errorcounter_reg            <= (others => '0');
        package_cnt_reg             <= (others => '0');
        reject_package_cnt_reg      <= (others => '0');
        coarsecounter_error_cnt_reg <= (others => '0');
        hit_ena_counter             <= (others => '0');
        prev_upper_sc_bits          <= (others => '0');
        --
    elsif rising_edge(clk) then

        hit_ena             <= '0';
        o_slowctrl_data_ena <= '0';
        o_slowctrl_data64_ena <= '0';
        send_one_more_sc    <= '0';

        coarsecounter       <= data_i(7 downto 0) & data_i(31 downto 8); -- gray counter & binary counter
        coarsecounter_ena   <= '0';

        if(readyin = '0')then
            state <= INVALID;
        else
            data_i <= data_i(23 downto 0) & datain;
            datak_i <= datak_i(2 downto 0) & kin;
            bad     <= bad(2 downto 0) & i_bad;

            case state is
            when INVALID =>
                errorcounter_reg <= errorcounter_reg + '1';
                if(datak_i = "1010" and bad = "0000") then
                    if to_stdulogicvector(data_i) ?= X"1C--1C--" then -- (vhdl-2008 Matching Relationals ?= and ?/= understand don't care '-' bits)
                        package_cnt_reg <= package_cnt_reg + '1';
                        next_state      <= COUNTER;
                        state           <= WAIT1;
                        -- check which link we have
                        if ( data_i(7 downto 0) = x"AA" ) then
                            o_link <= "0001";
                        elsif ( data_i(7 downto 0) = x"BB" ) then
                            o_link <= "0010";
                        elsif ( data_i(7 downto 0) = x"CC" ) then
                            o_link <= "0100";
                        elsif ( data_i(7 downto 0) = x"DD" ) then
                            o_link <= "1000";
                        else
                            o_link <= "1111"; -- ERROR
                        end if;
                    end if;
                end if;
            when LINK =>
                if(datak_i = "1010" and bad = "0000") then
                    if to_stdulogicvector(data_i) ?= X"1C--1C--" then
                        package_cnt_reg     <= package_cnt_reg + '1';
                        next_state          <= COUNTER;
                        state               <= WAIT1;
                        -- check which link we have
                        if ( data_i(7 downto 0) = x"AA" ) then
                            o_link <= "0001";
                        elsif ( data_i(7 downto 0) = x"BB" ) then
                            o_link <= "0010";
                        elsif ( data_i(7 downto 0) = x"CC" ) then
                            o_link <= "0100";
                        elsif ( data_i(7 downto 0) = x"DD" ) then
                            o_link <= "1000";
                        else
                            o_link <= "1111"; -- ERROR
                        end if;
                    end if;
                end if;
                if(send_one_more_sc = '1') then -- we are just coming out of SC2 state and need to ship the last sc word
                    o_slowctrl_data_ena <= '1';
                    o_slowctrl_data     <= sc_buffer;
                    o_slowctrl_data64_ena <= '1';
                    o_slowctrl_data64(63 downto 32) <= sc_buffer;
                end if;
            when COUNTER =>
                if(datak_i = "0000" and bad = "0000") then
                    next_state          <= HITS;
                    state               <= WAIT1;
                    coarsecounter_ena <= '1';
                elsif(bad /= "0000") then
                    reject_package_cnt_reg <= reject_package_cnt_reg + '1';
                    next_state  <= LINK;
                    state       <= WAIT1;
                end if;
            when HITS =>
                if(datak_i = "1010" and bad = "0000") then
                    if to_stdulogicvector(data_i) ?= X"1C--1C--" then
                        package_cnt_reg     <= package_cnt_reg + '1';
                        next_state          <= COUNTER;
                        state               <= WAIT1;
                        -- check which link we have
                        if ( data_i(7 downto 0) = x"AA" ) then
                            o_link <= "0001";
                        elsif ( data_i(7 downto 0) = x"BB" ) then
                            o_link <= "0010";
                        elsif ( data_i(7 downto 0) = x"CC" ) then
                            o_link <= "0100";
                        elsif ( data_i(7 downto 0) = x"DD" ) then
                            o_link <= "1000";
                        else
                            o_link <= "1111"; -- ERROR
                        end if;
                    end if;
                end if;
                if((data_i = work.util.K28_2 & work.util.K28_5 & work.util.K28_2 & work.util.K28_5) and (datak_i = "1111") and bad = "0000") then
                    state <= SC1;
                end if;
                if(datak_i = "0000" and bad = "0000") then
                    hit_ena_counter <= hit_ena_counter + '1';
                    dataWithoutSC   <= data_i;
                    hit_ena         <= '1';
                    next_state      <= HITS;
                    state           <= WAIT1;
                end if;
                if(bad /= "0000")then
                    reject_package_cnt_reg <= reject_package_cnt_reg + '1';
                    next_state  <= LINK;
                    state       <= WAIT1;
                end if;
            when SC1 =>
                if(datak_i = "0000" and bad = "0000") then
                    sc_cnt_reg          <= sc_cnt_reg + '1';
                    sc_buffer           <= data_i;
                    next_state          <= SC2;
                    state               <= WAIT1;
                end if;
                if(bad /= "0000")then
                    reject_package_cnt_reg <= reject_package_cnt_reg + '1';
                    next_state  <= LINK;
                    state       <= WAIT1;
                end if;
            when SC2 =>
                if(datak_i = "0000" and bad = "0000") then
                    prev_upper_sc_bits  <= data_i(31 downto 22);
                    state               <= LINK;
                    o_slowctrl_data     <= sc_buffer;
                    o_slowctrl_data64(31 downto 0) <= sc_buffer;
                    if(prev_upper_sc_bits /= data_i(31 downto 22) or i_slowctrl_empty = '1') then -- see Table 9 in https://www.physi.uni-heidelberg.de/Forschung/he/mu3e/restricted/notes/Mu3e-Note-0052-MuPix10_Documentation.pdf
                        o_slowctrl_data_ena <= '1';
                        sc_buffer           <= data_i;
                        send_one_more_sc    <= '1';
                    end if;
                end if;
                if(bad /= "0000")then
                    reject_package_cnt_reg <= reject_package_cnt_reg + '1';
                    next_state  <= LINK;
                    state       <= WAIT1;
                end if;
            when WAIT1 =>
                state <= WAIT2;
            when WAIT2 =>
                state <= WAIT3;
            when WAIT3 =>
                state <= next_state;
            when others =>
                state <= INVALID;
            end case;

        end if; -- readyin

        -- reset counters
        if ( i_mp_readout_mode(RESET_COUNTERS_BIT) = '1' ) then
            sc_cnt_reg <= (others => '0');
            sc_error_cnt_reg <= (others => '0');
            hit_error_cnt_reg <= (others => '0');
            hit_ena_counter <= (others => '0');
            errorcounter_reg <= (others => '0');
            package_cnt_reg <= (others => '0');
            reject_package_cnt_reg <= (others => '0');
            coarsecounter_error_cnt_reg <= (others => '0');
        end if;

    end if;
    end process;

    -- The data arrives from MuPix10: TS2[4:0] TS1[10:0] Col[6:0] Row[8:0]
                -- TS2 = data_i(31 downto 27)
                -- TS1 = data_i(26 downto 16)
                -- Col = data_i(15 downto 9)
                -- Row = data_i(8 downto 0)
            -- We remove sc and coarsecounters and present to the hitsorter:
    ts              <= dataWithoutSC(26 downto 16);
    --TODO: Fix this
    o_chip_ID       <= convert_lvds_to_chip_id(g_LVDS_ID,chip_ID_mode,g_LVDS_ID);
    ts2             <= dataWithoutSC(31 downto 27);

    genconvert10: if (g_IS_MUPIX10 = true) generate
        row             <= convert_row_mp10(dataWithoutSC(8 downto 0));
        col             <= convert_col_mp10(dataWithoutSC(15 downto 9),dataWithoutSC(8 downto 0));
    end generate;
    genconvert11: if (g_IS_MUPIX10 = false) generate
        row             <= convert_row(dataWithoutSC(8 downto 0));
        col             <= convert_col(dataWithoutSC(15 downto 9),dataWithoutSC(8 downto 0));
    end generate;

    degray_single : entity work.hit_ts_conversion
    port map (
        i_invert_TS => invert_TS,
        i_invert_TS2 => invert_TS2,
        i_gray_TS   => '1',
        i_gray_TS2  => '1',

        o_ts        => ts_buf,
        o_row       => o_row,
        o_col       => o_col,
        o_ts2       => ts2_buf,
        o_hit_ena   => o_hit_ena,

        i_ts        => ts,
        i_row       => row,
        i_col       => col,
        i_ts2       => ts2,
        i_hit_ena   => hit_ena,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

end architecture;
