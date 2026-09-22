--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

entity data_decoder_adaptive is
generic (
    -- this has to be tuned for the applicaton
    g_SCORE_MIN : integer := 400;
    g_SCORE_MAX : integer := 511--;
);
port (
    rx_in           : in    std_logic_vector(9 downto 0);

    rx_reset        : out   std_logic;
    rx_fifo_reset   : out   std_logic;
    rx_dpa_locked   : in    std_logic;
    rx_locked       : in    std_logic;
    -- NOTE: this is not used since we decode all in parallel
    rx_align        : out   std_logic;

    ready           : out   std_logic;
    data            : out   std_logic_vector(7 downto 0);
    k               : out   std_logic;
    disp_err        : out   std_logic;
    err8b10b        : out   std_logic;

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture rtl of data_decoder_adaptive is

    type sync_state_type is ( reset, waitforplllock, waitfordpalock, align );
    signal sync_state : sync_state_type := reset;

    signal rx_reversed : work.util_slv.slv10_array_t(9 downto 0) := (others => (others => '0'));

    signal current_disparity, new_disparity : std_logic_vector(9 downto 0);
    signal new_data : work.util_slv.slv9_array_t(9 downto 0);
    signal disp_error, data_error : std_logic_vector(9 downto 0);

    -- aligner
    type adaptive_aligner_t is (IDLE,DECIDING,LOCKING,LOCKED,RESET);
    signal adaptive_aligner : adaptive_aligner_t;
    type word_aligner_score_t is array (0 to 9) of integer range 0 to g_SCORE_MAX;
    signal word_aligner_score : word_aligner_score_t;
    signal adaptive_aligner_score : integer range 0 to g_SCORE_MAX;
    signal word_aligner_chosen : integer range 0 to 11;
    signal word_aligner_dout : work.util_slv.slv10_array_t(9 downto 0);
    signal word_aligner_din : std_logic_vector(19 downto 0);
    signal adative_aligner_good_lanes_map, adaptive_aligner_priority, word_aligner_next_grant_comb, adaptive_aligner_chosen : std_logic_vector(9 downto 0);
    signal align_ena : std_logic := '0';

    -- --------------------------------
    -- next decision calculation
    -- --------------------------------
    -- +------------------------------------------------------------------------------------+
    -- | Concept borrowed from 'altera_merlin_std_arbitrator_core.sv`                       |
    -- |                                                                                    |
    -- | Example:                                                                           |
    -- |                                                                                    |
    -- | top_priority                        =        010000                                |
    -- | {request, request}                  = 001001 001001  (result0)                     |
    -- | {~request, ~request} + top_priority = 110111 000110  (result1)                     |
    -- | result of & operation               = 000001 000000  (result2)                     |
    -- | next_grant                          =        000001  (grant_comb)                  |
    -- +------------------------------------------------------------------------------------+
    function word_aligner_next_grant(
        imap        : std_logic_vector(9 downto 0);
        ipriority   : std_logic_vector(9 downto 0)
    ) return std_logic_vector is 
        variable result0        : std_logic_vector(19 downto 0);
        variable result0p5      : std_logic_vector(19 downto 0);
        variable result1        : std_logic_vector(19 downto 0);
        variable result2        : std_logic_vector(19 downto 0);
        variable next_grant     : std_logic_vector(9 downto 0);      
    begin
        result0     := imap & imap;
        result0p5   := not imap & not imap;
        result1     := std_logic_vector(unsigned(result0p5) + unsigned(ipriority));
        result2     := result0 and result1;
        if (or_reduce(result2(9 downto 0)) = '0') then 
            next_grant  := result2(19 downto 10);
        else
            next_grant  := result2(9 downto 0);
        end if;
        return next_grant;
    end function;

begin

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        sync_state <= reset;
        align_ena <= '0';
        rx_reset <= '0';
        rx_fifo_reset <= '0';
        --
    elsif rising_edge(i_clk) then
        align_ena <= '0';

        -- to be adapted!
        rx_reset <= '0';
        rx_fifo_reset <= '0';

        case sync_state is

        when reset =>
            sync_state <= waitforplllock;
            rx_reset <= '1';
            rx_fifo_reset <= '0';

        when waitforplllock =>
            rx_reset <= '1';
            rx_fifo_reset <= '0';
            if(rx_locked = '1') then
                sync_state <= waitfordpalock;
            end if;

        when waitfordpalock =>
            rx_reset <= '0';
            rx_fifo_reset <= '0';
            if(rx_locked = '0') then
                sync_state <= reset;
            elsif (rx_dpa_locked = '1') then
                rx_fifo_reset <= '1';
                sync_state <= align;
            end if;

        when align =>
            align_ena <= '1';
            if(rx_locked = '0') then
                sync_state <= reset;
            end if;

        when others =>
            sync_state <= reset;
        end case;
    end if;
    end process;

    word_aligner_next_grant_comb <= word_aligner_next_grant(adative_aligner_good_lanes_map, adaptive_aligner_priority);

    -- aligner
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        adaptive_aligner <= RESET;
        --
    elsif rising_edge(i_clk) then

        word_aligner_chosen <= 10;

        -- We shift here 10 times to decode all of them:
        -- rx_in(19 downto 10), rx_in(18 downto 9), ...
        -- We take all the shifted 10b words and send them to the
        -- 8b10b decoder to monitor the errors.
        -- If they are in a range, which needs to be tuned,
        -- we take the best out of the 10 possibilites.
        word_aligner_din(9 downto 0) <= rx_in;
        word_aligner_din(19 downto 10) <= word_aligner_din(9 downto 0);
        for i in 0 to 9 loop
            -- word_aligner_dout -> [ 8b10b-decoder ] -> errors -> scores (we examine this)
            word_aligner_dout(i) <= word_aligner_din(19-i downto 10-i);
        end loop;

        -- reverse the order and send it to the 8b10b decoder
        for i in 0 to 9 loop -- per choice
            for j in 0 to 9 loop -- per bit (reversal)
                rx_reversed(i)(9-j) <= word_aligner_dout(i)(j);
            end loop;
        end loop;

        -- tracking quality score of each choice
        for i in 0 to 9 loop
            if (disp_error(i) = '1' or data_error(i) = '1') then 
                if (word_aligner_score(i) /= 0) then -- prevent underflow 
                    word_aligner_score(i) <= word_aligner_score(i) - 1;
                end if;
            else
                if (word_aligner_score(i) /= g_SCORE_MAX) then
                    word_aligner_score(i) <= word_aligner_score(i) + 1;
                end if;
            end if;
        end loop;

        -- TODO: use a sorter to find the max score
        -- select the lane with score larger than a threshold.
        -- good score from lsb to msb
        for i in 0 to 9 loop
            if (word_aligner_score(i) > g_SCORE_MIN) then
                word_aligner_chosen <= i;
            end if;
        end loop;

        case adaptive_aligner is

            when IDLE => -- find good choice(s) and iterate through all good choices
                for i in 0 to 9 loop
                    if (word_aligner_score(i) > g_SCORE_MIN) then
                        adative_aligner_good_lanes_map(i) <= '1';
                        -- if there is any good choice, goto deciding 
                        adaptive_aligner <= DECIDING;
                    else 
                        adative_aligner_good_lanes_map(i) <= '0';
                    end if;
                end loop;

            when DECIDING => -- choose the next choice 
                -- update priority (<=====) (for the sake of next time you visit this)
                adaptive_aligner_priority <= word_aligner_next_grant_comb(8 downto 0) & word_aligner_next_grant_comb(9);
                -- latch grant 
                adaptive_aligner_chosen <= word_aligner_next_grant_comb;
                -- jump to normal op state
                adaptive_aligner <= LOCKING;

            when LOCKING => 
                -- get the score 
                for i in 0 to 9 loop 
                    if (adaptive_aligner_chosen(i) = '1') then 
                        adaptive_aligner_score <= word_aligner_score(i);
                    end if;
                end loop;
                adaptive_aligner <= LOCKED;

            when LOCKED => -- monitor the score
                -- get the score 
                for i in 0 to 9 loop 
                    if (adaptive_aligner_chosen(i) = '1') then 
                        adaptive_aligner_score <= word_aligner_score(i);
                    end if;
                end loop;

                -- escape condition: error due to not enough score -> choose another choice and do it again
                if (adaptive_aligner_score < g_SCORE_MIN) then
                    adaptive_aligner <= IDLE;
                end if;

            when RESET =>
                if (align_ena = '1') then 
                    adaptive_aligner <= IDLE;
                end if;
                adaptive_aligner_priority <= (0 => '1', others => '0');
                adaptive_aligner_score <= 0;
                adaptive_aligner_chosen <= (others => '0');
                adative_aligner_good_lanes_map <= (others => '0');

            when others =>  
                --

        end case;

        if (adaptive_aligner = LOCKED) then
            for i in 0 to 9 loop -- chosen_cnt >= 1
                -- connect the data and errors to the chosen decoder out of 10 possibilities
                if (word_aligner_chosen = i) then
                    data <= new_data(i)(7 downto 0);
                    k <= new_data(i)(8);
                    disp_err <= disp_error(i);
                    err8b10b <= data_error(i);
                end if;
            end loop;
            ready <= '1';
        else
            ready <= '0';
        end if;

        -- handle the reset request from csr
        if (align_ena /= '1' or or_reduce(adaptive_aligner_priority) = '0') then -- bad signal from control plane
            word_aligner_din <= (others => '0'); -- this should be enough
            adaptive_aligner <= RESET; -- need for priority all zeros. TODO: debug this?
        end if;

    end if;
    end process;

    gen_decoder_per_choice : for i in 0 to 9 generate
        e_8b10b_dec : entity work.dec_8b10b
        port map (
            i_data => rx_reversed(i),
            i_disp => current_disparity(i),
            o_data => new_data(i),
            o_disp => new_disparity(i),
            o_disperr => disp_error(i),
            o_err => data_error(i)--,
        );
    end generate;

    process(i_clk)
    begin
    if rising_edge(i_clk) then
        for i in 0 to 9 loop -- per choice
            if (align_ena = '1') then -- unblock the decoder parity input if the dpa is locked 
                current_disparity(i) <= new_disparity(i);
            else
                current_disparity(i) <= '0';
            end if;
        end loop;
    end if;
    end process;

end architecture;
