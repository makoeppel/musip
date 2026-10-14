--
-- Marius Koeppel, March 2026
--
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity musip_event_builder is
port (
    i_rx                : in  std_logic_vector(255 downto 0);
    i_valid             : in  std_logic;

    i_get_n_words       : in  std_logic_vector(31 downto 0);
    i_dmamemhalffull    : in  std_logic;
    i_wen               : in  std_logic;
    o_data              : out std_logic_vector(255 downto 0);
    o_wen               : out std_logic;
    o_endofevent        : out std_logic;
    o_done              : out std_logic;

    o_hit_cnt           : out std_logic_vector(63 downto 0);
    o_hit_drop_cnt      : out std_logic_vector(63 downto 0);
    o_full_cnt          : out std_logic_vector(63 downto 0);
    o_cnt_input         : out std_logic_vector(63 downto 0);
    o_hit_rate          : out std_logic_vector(31 downto 0);

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture arch of musip_event_builder is

    ------------------------------------------------------------------------
    -- State machine
    ------------------------------------------------------------------------
    type event_builder_state_t is (
        waiting,
        write_hits,
        write_last_hit,
        write_4kb_padding
    );

    signal event_builder_state : event_builder_state_t := waiting;

    ------------------------------------------------------------------------
    -- FIFO interface signals
    ------------------------------------------------------------------------
    signal fifo_full    : std_logic := '0';
    signal fifo_empty   : std_logic := '1';
    signal fifo_en      : std_logic := '0';
    signal fifo_data    : std_logic_vector(255 downto 0);
    signal wrusedw  : std_logic_vector(13 downto 0);  -- matches g_ADDR_WIDTH=12
    signal drop_hit : std_logic;

    ------------------------------------------------------------------------
    -- Counters
    ------------------------------------------------------------------------
    signal hit_cnt, cnt_input, hit_drop_cnt, full_cnt : std_logic_vector(63 downto 0) := (others => '0');

    -- [AK] TODO: count in units of 4 kB
    signal word_counter  : std_logic_vector(31 downto 0) := (others => '0');

    signal timeout : unsigned(25 downto 0);

begin

    --! counter
    o_hit_cnt <= hit_cnt;
    o_hit_drop_cnt <= hit_drop_cnt;
    o_full_cnt <= full_cnt;
    o_cnt_input <= cnt_input;

    e_fifo_event : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 14,
        g_DATA_WIDTH => 256--,
    )
    port map (
        i_we        => i_valid,
        i_wdata     => i_rx,
        o_wfull     => fifo_full,
        o_usedw     => wrusedw,

        i_rack      => fifo_en or wrusedw(13),
        o_rdata     => fifo_data,
        o_rempty    => fifo_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    --! data out
    fifo_en <= '1' when ( fifo_empty = '0' and i_dmamemhalffull = '0' ) and ( event_builder_state = write_hits ) else '0';
    drop_hit <= '1' when ( fifo_en = '0' and wrusedw(13) = '1' ) else '0';
    o_done <= '1' when ( i_wen = '1' and word_counter >= i_get_n_words ) else '0';

    e_hit_rate : entity work.word_rate
    generic map ( g_CLK_MHZ => 250.0 )
    port map (
        i_valid => fifo_en, o_rate => o_hit_rate,
        i_reset_n => i_reset_n, i_clk => i_clk--,
    );

    -- dma end of events, count events and write control
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        event_builder_state <= waiting;
        o_wen <= '0';
        o_data <= (others => '1');
        o_endofevent <= '0';
        hit_cnt <= (others => '0');
        hit_drop_cnt <= (others => '0');
        word_counter <= (others => '0');
        full_cnt <= (others => '0');
        cnt_input <= (others => '0');
        --
    elsif rising_edge(i_clk) then

        if ( drop_hit = '1' ) then
            hit_drop_cnt <= hit_drop_cnt + 1;
        end if;

        if ( i_wen = '0' ) then
            word_counter <= (others => '0');
        end if;

        if ( fifo_full = '1' ) then
            full_cnt <= full_cnt + 1;
        end if;

        if ( i_valid = '1' ) then
            cnt_input <= cnt_input + 1;
        end if;

        o_wen <= '0';
        o_data <= (others => '1');
        o_endofevent <= '0';

        if ( fifo_empty = '0' or word_counter(12 downto 0) = 0 ) then
            -- reset timeout when there is data or when at 4~kB boundary
            timeout <= (others => '1');
        elsif ( timeout /= 0 ) then
            timeout <= timeout - 1;
        end if;

        case event_builder_state is
            when waiting =>
                if ( i_wen = '1' and word_counter < i_get_n_words ) then
                    event_builder_state <= write_hits;
                end if;

            when write_hits =>
                if ( word_counter >= i_get_n_words and word_counter(12 downto 0) = 0 ) then
                    -- stop when we have have requested words and at 256~kB boundary
                    event_builder_state <= waiting;
                    o_endofevent <= '1';
                elsif ( fifo_empty = '1' and word_counter(12 downto 0) = 0 ) then
                    event_builder_state <= waiting;
                    o_endofevent <= '1';
                elsif ( fifo_empty = '0' or timeout = 0 ) and ( i_dmamemhalffull = '0' ) then
                    -- produce data or filler on timeout
                    o_wen <= '1';
                    o_data <= (others => '1');
                    if ( fifo_empty = '0' ) then
                        o_data <= fifo_data;
                        hit_cnt <= hit_cnt + 1;
                    end if;
                    word_counter <= word_counter + 1;
                end if;

            when others =>
                event_builder_state <= waiting;

        end case;

    end if;
    end process;

end architecture;
