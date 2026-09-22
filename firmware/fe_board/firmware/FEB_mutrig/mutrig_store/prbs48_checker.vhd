-- module to test the mutrig data stream. If configured accordingly, the asic produces a datastream of frames where the events are prbs48-words.
--These "events" can be checked against the expected value using this module.

-- check if the PRBS-48 pattern in the data stream is correct or not
--
-- provided previous PRBS-48 pattern and check if the current PRBS pattern is correct
--
-- the check is reset at every frame and the output is error count for each frame
-- 4/2022: cleanup and went to binary counting, M.Koeppel

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity prbs48_checker is
port(
    i_new_cycle     : in std_logic; -- do not check next word, start checking after.

    i_new_word      : in std_logic;
    i_prbs_word     : in std_logic_vector(47 downto 0);

    o_err_cnt       : out std_logic_vector(31 downto 0);
    o_wrd_cnt       : out std_logic_vector(63 downto 0);

    i_rst_counter   : in std_logic; -- reset the error counter
    i_clk           : in std_logic--;
);
end entity;

architecture rtl of prbs48_checker is
    signal s_pre_prbs       : std_logic_vector(47 downto 0); -- previous prbs patten
    signal s_exp_prbs       : std_logic_vector(47 downto 0); -- expected prbs patten

    signal s_first_prbs     : std_logic;

    signal s_err_cnt        : std_logic_vector(31 downto 0);
    signal s_wrd_cnt        : std_logic_vector(63 downto 0);

begin

    o_err_cnt <= s_err_cnt;
    o_wrd_cnt <= s_wrd_cnt;

    -- calculate the expected prbs for checking
    s_exp_prbs <= s_pre_prbs(s_pre_prbs'high-1 downto 0) & (s_pre_prbs(47) xor s_pre_prbs(42));

    -- checking the prbs
    proc_check : process(i_clk, i_rst_counter)
    begin
    if ( i_rst_counter = '1' ) then
        s_first_prbs    <= '1';
        s_err_cnt   <= (others => '0');
        s_wrd_cnt   <= (others => '0');
    --
    elsif rising_edge(i_clk) then
        if(i_new_cycle = '1') then
            s_first_prbs    <= '1';
        else
            if(i_new_word = '1') then
                if(s_first_prbs = '1' ) then -- if it's the first prbs word in the frame, reset the flag
                    s_first_prbs <= '0';
                else
                    if(s_err_cnt /= X"ffffffff") then
                        s_wrd_cnt <= s_wrd_cnt + '1';
                    end if;
                    -- if it's not the first prbs in the frame, check the prbs word
                    if ( (i_prbs_word /= s_exp_prbs) and (s_err_cnt /= X"ffffffff") ) then
                        s_err_cnt <= s_err_cnt + '1';
                    end if;
                end if;

                -- latch the new prbs word for the next checking
                s_pre_prbs <= i_prbs_word;
            end if;
        end if;
    end if;
    end process;

end architecture;
