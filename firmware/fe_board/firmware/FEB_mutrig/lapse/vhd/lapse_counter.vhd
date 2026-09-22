library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mutrig_hit_types.all;

-- This entity should adapt the lapsing of the Mutrig 1.6 cc counter
-- MUTRIG counts from 1 to 32767
-- we want to count from 0 up to a number N where (N+1)/5 = 2^M (where M is determined by the number of bits for the timestamp that goes into the sorter)

-- assuming the Mutrig should count from 0 to 3 but it only counts from 0 to 2 and we want M=1

-- Assuming MUTRIG counts from 0 to 3
-- FPGA 2^15-1 counter:   0 1 2 0 1 2 0 1 2 0 1 2  0  1  2
-- cc_correction:         0 0 0 3 3 3 6 6 6 9 9 9  2  2  2
-- cc_true:               0 1 2 3 4 5 6 7 8 9 0 1  2  3  4

-- after divider
-- cc_div:                0 0 0 0 0 1 1 1 1 1 0 0  0  0  0
-- cc_rem:                0 1 2 3 4 0 1 2 3 4 0 1  2  3  4

-- additionally we have to watch out since there will be a latency through the system.
-- Therefore we need to make sure that we catch cases when cc_running lapsed but the FPGA counter(s_cc) did not
-- We have delay setting to make sure cc_running will always be ahead of s_cc
-- If cc_running lapsed and s_cc did not we know
-- cc_running<lower_bnd and s_cc>upper_bnd
-- boundarys are determined by the max variable latency
-- informations how to set delay and boundaries will be provided in wiki

entity lapse_counter is
generic (
    DIV_IN : positive := 32767;
    DIV_OUT: positive := 40960
);
port (
    i_enable    : in  std_logic;
    i_upper_bnd : in  std_logic_vector(14 downto 0);
    i_lower_bnd : in  std_logic_vector(14 downto 0);
    i_delay     : in  std_logic_vector(14 downto 0);    -- delay for system latency
    i_replace_lat : in  std_logic := '0';               -- replace E, T_fine with latency

    o_latency   : out std_logic_vector(16 downto 0);

    i_data      : in t_hit_presort;
    o_data      : out t_hit_presort;

    i_reset_n   : in  std_logic;
    i_clk       : in  std_logic--;
);
end entity;

architecture arch of lapse_counter is

    signal s_data, s_data_d1 : t_hit_presort;
    signal cc_correction, prev_cc_correction, cc_true, cc_true_short : unsigned(16 downto 0) := (others => '0');
    signal s_cc, cc_running, upper_bnd, lower_bnd, delay : unsigned(14 downto 0):= (others => '0');
    signal latency : unsigned(16 downto 0);

begin

    upper_bnd       <=  unsigned(i_upper_bnd);
    lower_bnd       <=  unsigned(i_lower_bnd);
    delay           <=  unsigned(i_delay);
    s_cc            <=  unsigned(i_data.T_CC);

    -- counting lapsing of coarse counter
    -- CC lapses every 2^15-1 cycles @ 625MHz.
    -- this timestamp is divided by 5 before going into the sorter; this lapsing behaviour is also taken care of here
    process(i_clk)
    begin
    if rising_edge(i_clk) then
        s_data          <= i_data;
        s_data_d1       <= s_data;

        if ( i_reset_n /= '1' ) then
            s_data.valid    <= '0';
            cc_running      <= DIV_IN - delay;
            cc_correction   <= to_unsigned(DIV_OUT-DIV_IN, 17); --cc_correction = 0 after delay
        else
            -- 5 different edge cases for ASIC counter
            if ( cc_running = 32763 ) then
                cc_running <= to_unsigned(1, 15);
            elsif ( cc_running = 32764 ) then
                cc_running <= to_unsigned(2, 15);
            elsif ( cc_running = 32765 ) then
                cc_running <= to_unsigned(3, 15);
            elsif ( cc_running = 32766 ) then
                cc_running <= to_unsigned(4, 15);
            elsif ( cc_running = 32767 ) then
                cc_running <= to_unsigned(5, 15);
            else
                cc_running <= cc_running + 5;
            end if;

            -- lapse correction term when we reach 0x2000 * 5
            -- TODO: get rid of all those constants
            if ( cc_running > 32762 ) then
                if ( (cc_correction + 32767) > 40959 ) then
                    cc_correction <= cc_correction + 32767 - 40960;
                else
                    cc_correction <= cc_correction + 32767;
                end if;
                prev_cc_correction <= cc_correction;
            end if;

            if ( (CC_running < lower_bnd) and (s_cc > upper_bnd) ) then -- edge case when cc_running lapsed but s_cc did not
                if ( (s_cc + prev_cc_correction) > 40959 ) then
                    cc_true <= s_cc + prev_cc_correction - 40960; -- lapse at  0x2000 * 5
                else
                    cc_true <= s_cc + prev_cc_correction;
                end if;
            else
                if ( (s_cc + cc_correction) > 40959 ) then
                    cc_true <= s_cc + cc_correction - 40960; -- lapse at  0x2000 * 5
                else
                    cc_true <= s_cc + cc_correction;
                end if;
            end if;

            -- sorter only needs 12 bits so we can already cut here
            if ( cc_true > 20479 ) then
                cc_true_short <= cc_true - 20480;
            else
                cc_true_short <= cc_true;
            end if;
        end if;
    end if;
    end process;

    --output assignment
    process(i_clk, i_reset_n)
    begin
        if rising_edge(i_clk) then
            o_latency <= std_logic_vector(latency);
            o_data <= s_data_d1;
            if ( i_enable = '1' ) then
                o_data.T_CC <= std_logic_vector(cc_true_short(14 downto 0));
                if ( i_replace_lat = '1' ) then
                    o_data.E_CC <= std_logic_vector("000000" & latency(11 downto 3));
                    o_data.T_fine <= std_logic_vector(latency(16 downto 12));
                end if;
                if ( i_data.valid = '1' ) then
                --shift by 50000 so we dont have to deal with signed
                    latency <= ((cc_running + to_unsigned(50000, 17)) - unsigned("00" & s_cc));
                end if;
            end if;
        end if;
    end process;

end architecture;
