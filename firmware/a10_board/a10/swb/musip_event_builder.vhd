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
        write_last_hit
    );

    signal event_builder_state : event_builder_state_t := waiting;


    ------------------------------------------------------------------------
    -- FIFO interface signals
    ------------------------------------------------------------------------
    signal fifo_full    : std_logic := '0';
    signal fifo_empty   : std_logic := '1';
    signal fifo_en      : std_logic := '0';

    signal tag_wrusedw  : std_logic_vector(11 downto 0);  -- matches g_ADDR_WIDTH=12


    ------------------------------------------------------------------------
    -- Counters
    ------------------------------------------------------------------------
    signal hit_cnt       : std_logic_vector(63 downto 0) := (others => '0');
    signal hit_drop_cnt  : std_logic_vector(63 downto 0) := (others => '0');

    signal word_counter  : std_logic_vector(31 downto 0) := (others => '0');


    ------------------------------------------------------------------------
    -- Control signals
    ------------------------------------------------------------------------
    signal done          : std_logic := '0';

begin

    --! counter
    o_hit_cnt <= hit_cnt;
    o_hit_drop_cnt <= hit_drop_cnt;

    e_fifo_event : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => 256--,
    )
    port map (
        i_we        => i_valid,
        i_wdata     => i_rx,
        o_wfull     => fifo_full,

        i_rack      => fifo_en or fifo_full,
        o_rdata     => o_data,
        o_rempty    => fifo_empty,

        o_usedw     => tag_wrusedw,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    --! data out
    fifo_en <= '1' when (fifo_empty = '0' and i_dmamemhalffull = '0') and (event_builder_state = write_hits or event_builder_state = write_last_hit) else '0';
    o_wen <= fifo_en;
    o_endofevent <= '1' when (fifo_empty = '0' and i_dmamemhalffull = '0') and event_builder_state = write_last_hit else '0';
    o_done <= done;

    -- dma end of events, count events and write control
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        done <= '0';
        event_builder_state <= waiting;
        hit_cnt <= (others => '0');
        hit_drop_cnt <= (others => '0');
        word_counter <= (others => '0');
        --
    elsif rising_edge(i_clk) then

        if ( i_wen = '0' ) then
            done <= '0';
            word_counter <= (others => '0');
        end if;

        if ( fifo_full = '1' ) then
            hit_drop_cnt <= std_logic_vector(unsigned(hit_drop_cnt) + 1);
        end if;

        case event_builder_state is
            when waiting =>
                if ( i_wen = '1' and i_get_n_words /= 0 and done = '0' ) then
                    word_counter <= i_get_n_words;
                    event_builder_state <= write_hits;
                end if;

            when write_hits =>
                if ( word_counter = 2 and fifo_empty = '0' and i_dmamemhalffull = '0' ) then
                    event_builder_state <= write_last_hit;
                    word_counter <= std_logic_vector(unsigned(word_counter) - 1);
                    hit_cnt <= std_logic_vector(unsigned(hit_cnt) + 1);
                elsif ( fifo_empty = '0' and i_dmamemhalffull = '0' ) then
                    word_counter <= std_logic_vector(unsigned(word_counter) - 1);
                    hit_cnt <= std_logic_vector(unsigned(hit_cnt) + 1);
                end if;

            when write_last_hit =>
                if ( fifo_empty = '0' and i_dmamemhalffull = '0' ) then
                    word_counter <= (others => '0');
                    event_builder_state <= waiting;
                    hit_cnt <= std_logic_vector(unsigned(hit_cnt) + 1);
                    done <= '1';
                end if;

            when others =>
                event_builder_state <= waiting;

        end case;

    end if;
    end process;

end architecture;
