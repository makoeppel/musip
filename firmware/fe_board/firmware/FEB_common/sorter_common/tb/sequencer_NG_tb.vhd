library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sorter_pkg.all;

entity sequencer_ng_tb is
end entity;

architecture sim of sequencer_ng_tb is

    -- Bit positions in the counter fifo of the sorter
    constant HITSORTERBINBITS : integer := 4;
    constant NSORTERINPUTS : integer := 12;
    constant TIMESTAMPSIZE : integer := 11;
    constant ISMUTRIG : integer := 0;
    subtype MEMCOUNTERRANGE         is integer range 2*NSORTERINPUTS*HITSORTERBINBITS-1 downto 0;
    constant MEMOVERFLOWBIT         : integer := 2*NSORTERINPUTS*HITSORTERBINBITS;
    constant HASMEMBIT              : integer := 2*NSORTERINPUTS*HITSORTERBINBITS+1;
    subtype TSINFIFORANGE           is integer range HASMEMBIT+TIMESTAMPSIZE downto HASMEMBIT+1;
    subtype TSBLOCKINFIFORANGE      is integer range TSINFIFORANGE'left downto TSINFIFORANGE'right+BITSPERTSBLOCK;
    subtype TSBLOCKINFIFOMUTRIGRANGE is integer range TSINFIFORANGE'left-1 downto TSINFIFORANGE'right+BITSPERTSBLOCK;
    subtype TSINBLOCKINFIFORANGE    is integer range TSINFIFORANGE'right+BITSPERTSBLOCK-1 downto TSINFIFORANGE'right;
    subtype SORTERFIFORANGE         is integer range TSINFIFORANGE'left downto 0;
    subtype TSINBLOCKRANGE          is integer range BITSPERTSBLOCK-1 downto 0;
    subtype TSBLOCKRANGE            is integer range TIMESTAMPSIZE-1 downto BITSPERTSBLOCK;
    subtype TSBLOCKMUTRIGRANGE      is integer range TIMESTAMPSIZE - 2 downto BITSPERTSBLOCK;
    subtype TSNONBLOCKRANGE         is integer range BITSPERTSBLOCK-1 downto 0;
    subtype TSRANGE                 is integer range TIMESTAMPSIZE-1 downto 0;

    constant CLK_PERIOD : time := 10 ns;

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal i_runend      : std_logic := '0';
    signal i_fifo_data   : std_logic_vector(2*NSORTERINPUTS*HITSORTERBINBITS + 2 + TIMESTAMPSIZE-1 downto 0)
                           := (others => '0');
    signal i_fifo_empty  : std_logic := '1';

    signal o_fifo_read      : std_logic;
    signal o_command        : std_logic_vector(
                                TIMESTAMPSIZE +
                                HITSORTERBINBITS +
                                4 +
                                1 - 1 downto 0);
    signal o_command_enable : std_logic;
    signal o_overflow       : std_logic_vector(15 downto 0);

    signal i_reset_n : std_logic := '0';
    signal i_clk     : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------
    i_clk <= not i_clk after CLK_PERIOD/2;

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    dut : entity work.sequencer_ng
    generic map (
        HITSORTERBINBITS => HITSORTERBINBITS,
        NSORTERINPUTS    => NSORTERINPUTS,
        TIMESTAMPSIZE    => TIMESTAMPSIZE,
        ISMUTRIG         => ISMUTRIG
    )
    port map (
        i_runend         => i_runend,
        i_fifo_data      => i_fifo_data,
        i_fifo_empty     => i_fifo_empty,
        o_fifo_read      => o_fifo_read,
        o_command        => o_command,
        o_command_enable => o_command_enable,
        o_overflow       => o_overflow,
        i_reset_n        => i_reset_n,
        i_clk            => i_clk
    );

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim_proc : process

        procedure push_fifo_entry(
            block_num : std_logic_vector(7 downto 0);
            hit_chip  : integer;
            hit_count : integer
        ) is
            variable tmp : std_logic_vector(2*NSORTERINPUTS*HITSORTERBINBITS + 2 + TIMESTAMPSIZE-1 downto 0);
            variable ts  : integer;
        begin

            tmp := (others => '0');

            ----------------------------------------------------------------
            -- timestamp field
            ----------------------------------------------------------------
            tmp(TSBLOCKINFIFORANGE) := block_num(6 downto 0);

            ----------------------------------------------------------------
            -- hasmem
            ----------------------------------------------------------------
            if hit_count > 0 then
                tmp(HASMEMBIT) := '1';
            else
                tmp(HASMEMBIT) := '0';
            end if;

            ----------------------------------------------------------------
            -- overflow
            ----------------------------------------------------------------
            tmp(MEMOVERFLOWBIT) := '0';

            ----------------------------------------------------------------
            -- first chip entry
            --
            -- bits 3:0 = nhits
            -- bits 7:4 = chip id
            ----------------------------------------------------------------
            tmp(3 downto 0) :=
                std_logic_vector(to_unsigned(hit_count,4));

            tmp(7 downto 4) :=
                std_logic_vector(to_unsigned(hit_chip,4));

            i_fifo_data  <= tmp;
            i_fifo_empty <= '0';

            ----------------------------------------------------------------
            -- Wait until DUT asks for the word
            ----------------------------------------------------------------
            wait until rising_edge(i_clk);

            while o_fifo_read = '0' loop
                wait until rising_edge(i_clk);
            end loop;
            i_fifo_empty <= '1';
        end procedure;

        
        procedure push_fifo_empty(
            cycle_count : integer
        ) is
            variable cycles  : integer;
        begin
            cycles := 0;
             while cycles < cycle_count loop
                wait until rising_edge(i_clk);
                cycles := cycles + 1;
            end loop;
        end procedure;

    begin

        ----------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------
        i_reset_n <= '0';
        wait for 100 ns;

        i_reset_n <= '1';
        wait for 100 ns;

        ----------------------------------------------------------------
        ----------------------------------------------------------------

        -- report "test the start";
        -- push_fifo_entry(block_num => x"00", hit_chip  => 0, hit_count => 3);
        -- push_fifo_entry(block_num => x"01", hit_chip  => 0, hit_count => 2);
        -- push_fifo_entry(block_num => x"02", hit_chip  => 0, hit_count => 1);

        -- report "test for diff amount of hits 1";
        -- push_fifo_entry(block_num => x"7B", hit_chip  => 0, hit_count => 3);
        -- push_fifo_entry(block_num => x"7C", hit_chip  => 0, hit_count => 2);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 0, hit_count => 0);
        -- push_fifo_entry(block_num => x"7E", hit_chip  => 0, hit_count => 0);
        -- push_fifo_entry(block_num => x"7F", hit_chip  => 0, hit_count => 3);
        -- push_fifo_entry(block_num => x"00", hit_chip  => 0, hit_count => 0);
        -- push_fifo_entry(block_num => x"01", hit_chip  => 0, hit_count => 0);
        -- push_fifo_entry(block_num => x"02", hit_chip  => 0, hit_count => 0);
        -- push_fifo_entry(block_num => x"03", hit_chip  => 0, hit_count => 0);

        -- report "test for diff amount of hits 2";
        -- push_fifo_entry(block_num => x"7B", hit_chip  => 0, hit_count => 2);
        -- push_fifo_entry(block_num => x"7C", hit_chip  => 0, hit_count => 1);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 0, hit_count => 1);
        -- push_fifo_entry(block_num => x"7E", hit_chip  => 0, hit_count => 1);
        -- push_fifo_entry(block_num => x"7F", hit_chip  => 0, hit_count => 3);
        -- push_fifo_entry(block_num => x"00", hit_chip  => 0, hit_count => 1);
        -- push_fifo_entry(block_num => x"01", hit_chip  => 0, hit_count => 1);

        -- report "multiple hits per block";
        -- push_fifo_entry(block_num => x"7B", hit_chip  => 0, hit_count => 3);
        -- push_fifo_entry(block_num => x"7C", hit_chip  => 0, hit_count => 3);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 0, hit_count => 1);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 0, hit_count => 1);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 0, hit_count => 1);
        -- push_fifo_entry(block_num => x"7E", hit_chip  => 0, hit_count => 3);
        -- push_fifo_entry(block_num => x"7F", hit_chip  => 0, hit_count => 3);
        -- push_fifo_entry(block_num => x"00", hit_chip  => 0, hit_count => 1);
        -- push_fifo_entry(block_num => x"01", hit_chip  => 0, hit_count => 1);

        -- report "FIFO running empty"
        -- push_fifo_entry(block_num => x"7B", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 1);
        -- push_fifo_entry(block_num => x"7C", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 1);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 1, hit_count => 1);
        -- push_fifo_empty(cycle_count => 1);        
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 2, hit_count => 1);
        -- push_fifo_empty(cycle_count => 1);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 3, hit_count => 1);
        -- push_fifo_empty(cycle_count => 1);
        -- push_fifo_entry(block_num => x"7E", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 1);
        -- push_fifo_entry(block_num => x"7F", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 1);
        -- push_fifo_entry(block_num => x"00", hit_chip  => 0, hit_count => 1);
        -- push_fifo_empty(cycle_count => 1);
        -- push_fifo_entry(block_num => x"01", hit_chip  => 0, hit_count => 1);

        -- report "FIFO running emptier"
        -- push_fifo_entry(block_num => x"7B", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 2);
        -- push_fifo_entry(block_num => x"7C", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 2);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 1, hit_count => 1);
        -- push_fifo_empty(cycle_count => 2);        
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 2, hit_count => 1);
        -- push_fifo_empty(cycle_count => 2);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 3, hit_count => 1);
        -- push_fifo_empty(cycle_count => 2);
        -- push_fifo_entry(block_num => x"7E", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 2);
        -- push_fifo_entry(block_num => x"7F", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 2);
        -- push_fifo_entry(block_num => x"00", hit_chip  => 0, hit_count => 1);
        -- push_fifo_empty(cycle_count => 2);
        -- push_fifo_entry(block_num => x"01", hit_chip  => 0, hit_count => 1);

        -- report "FIFO running even emptier"
        -- push_fifo_entry(block_num => x"7B", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 4);
        -- push_fifo_entry(block_num => x"7C", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 4);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 1, hit_count => 1);
        -- push_fifo_empty(cycle_count => 4);        
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 2, hit_count => 1);
        -- push_fifo_empty(cycle_count => 4);
        -- push_fifo_entry(block_num => x"7D", hit_chip  => 3, hit_count => 1);
        -- push_fifo_empty(cycle_count => 4);
        -- push_fifo_entry(block_num => x"7E", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 4);
        -- push_fifo_entry(block_num => x"7F", hit_chip  => 0, hit_count => 3);
        -- push_fifo_empty(cycle_count => 4);
        -- push_fifo_entry(block_num => x"00", hit_chip  => 0, hit_count => 1);
        -- push_fifo_empty(cycle_count => 4);
        -- push_fifo_entry(block_num => x"01", hit_chip  => 0, hit_count => 1);

        -- report "FIFO running even more emptier"
        push_fifo_entry(block_num => x"7B", hit_chip  => 0, hit_count => 3);
        push_fifo_empty(cycle_count => 5);
        push_fifo_entry(block_num => x"7C", hit_chip  => 0, hit_count => 3);
        push_fifo_empty(cycle_count => 5);
        push_fifo_entry(block_num => x"7D", hit_chip  => 1, hit_count => 1);
        push_fifo_empty(cycle_count => 5);        
        push_fifo_entry(block_num => x"7D", hit_chip  => 2, hit_count => 1);
        push_fifo_empty(cycle_count => 5);
        push_fifo_entry(block_num => x"7D", hit_chip  => 3, hit_count => 1);
        push_fifo_empty(cycle_count => 5);
        push_fifo_entry(block_num => x"7E", hit_chip  => 0, hit_count => 3);
        push_fifo_empty(cycle_count => 5);
        push_fifo_entry(block_num => x"7F", hit_chip  => 0, hit_count => 3);
        push_fifo_empty(cycle_count => 5);
        push_fifo_entry(block_num => x"00", hit_chip  => 0, hit_count => 1);
        push_fifo_empty(cycle_count => 7);
        push_fifo_entry(block_num => x"01", hit_chip  => 0, hit_count => 1);



        ----------------------------------------------------------------
        -- FIFO empty
        ----------------------------------------------------------------
        --i_fifo_empty <= '1';

        wait for 500 ns;

        ----------------------------------------------------------------
        -- End of run
        ----------------------------------------------------------------
        i_runend <= '1';

        wait for 500 ns;

        -- assert false
        --     report "Simulation completed"
        --     severity failure;

    end process;

    --------------------------------------------------------------------
    -- Monitor outputs
    --------------------------------------------------------------------
    monitor : process(i_clk)
    begin
        if rising_edge(i_clk) then

            if o_command_enable = '1' then

                report
                    "CMD = 0x" &
                    to_hstring(o_command);

            end if;

        end if;
    end process;

end architecture;