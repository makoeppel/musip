-- Sequencer_v3.vhd
-- Niklaus Berger, June 2026
-- niberger@uni-mainz.de
--
-- Take the front-stacked counters and bit arrays of busy timestamps to
-- create a sequence of memory adrreses to be read and multiplexer settings
-- for the read part of the hit sorter

-- The ouput command has the TS in the LSBs, followed by four bits hit address
-- four bits channel/chip ID and the MSB inciating command (1) or hit (0)

-- In a bit more detail: For every TS which is either containg hits or marking the
-- change of (16 TS) block, the main sorter file writes to a FIFO in the format

-- Timestamp | non-empty flag (hasmem)| Overflow bit|...|...|Chip Nr y | Nhits Chip y | Chip Nr x | Nhits Chip x
-- Note that the counters are right-stacked, i.e. the rightmost counter is from the first chip with hits and so on
-- If there are no more hits, the counter is 0

-- The FIFO is of the conventional (non show-ahead) type
-- It is almost equally tricky to make sure the FIFO is read whenever possible in showahead and non-showahead mode
-- After the integration run I decided that this way is easier to reason about

-- This input is then turned into a series of commands corresponding directly to the output of the sorter, i.e.
-- Header 1
-- Header 2
-- Subheader
-- Hit
-- Hit
-- ...
-- Subheader
-- ...
-- ...
-- Footer
--
-- For the hits we output in which memory (i.e. chip) they are at which position (TS plus hit number)
--
-- Has to be reset between runs


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

use work.sorter_pkg.all;
-- TODO: move all things to sorter_pkg
use work.mupix.all;

entity sequencer_ng is
generic (
    HITSORTERBINBITS : integer := 4;
    NSORTERINPUTS : integer := 12;
    TIMESTAMPSIZE : integer := 11;
    ISMUTRIG : integer := 0
);
port (
    i_runend            : in    std_logic;
    i_fifo_data         : in    std_logic_vector(2*NSORTERINPUTS*HITSORTERBINBITS + 2 + TIMESTAMPSIZE-1 downto 0);
    i_fifo_empty        : in    std_logic;
    o_fifo_read         : out   std_logic;
    o_command           : out   std_logic_vector(TIMESTAMPSIZE + HITSORTERBINBITS + 4 + 1-1 downto 0);
    o_command_enable    : out   std_logic;
    o_overflow          : out   std_logic_vector(15 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture rtl of sequencer_ng is

    -- Bit positions in the counter fifo of the sorter
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

    subtype block_t                 is std_logic_vector(TSBLOCKRANGE);
    subtype counter_t               is std_logic_vector(HITSORTERBINBITS-1 downto 0);
    subtype ts_t is                 std_logic_vector(TIMESTAMPSIZE-1 downto 0);

    -- Commands from the sequencer
    constant COMMANDBITS            : integer := TIMESTAMPSIZE + HITSORTERBINBITS + 4 + 1;
    subtype command_t               is std_logic_vector(COMMANDBITS-1 downto 0);
    constant COMMAND_HEADER1        : command_t := X"8" & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_HEADER2        : command_t := X"9" & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_SUBHEADER      : command_t := X"C" & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_FOOTER         : command_t := X"E" & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_DEBUGHEADER1   : command_t := X"A" & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_DEBUGHEADER2   : command_t := X"B" & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    subtype COMMANDRANGE is integer range COMMANDBITS-1 downto COMMANDBITS-4;
    subtype COMMANDINPUTSELRANGE is integer range COMMANDBITS-2 downto COMMANDBITS-5;
    subtype COMMANDBINSELRANGE is integer range COMMANDBITS-6 downto TIMESTAMPSIZE;



    signal running              : std_logic;
    signal running_last         : std_logic;
    signal stopped              : std_logic;
    signal inhibit_read_last    : std_logic;
    type output_type is (
        header1, header2,
        debugheader1, debugheader2,
        subheader, hits, footer,
        none
    );
    signal output               : output_type;
    signal current_block        : block_t;
    constant block_max          : block_t := (others => '1');
    constant block_zero         : block_t := (others => '0');
    signal current_ts           : ts_t;
    signal ts_to_out            : ts_t;
    signal counters_reg         : std_logic_vector(MEMCOUNTERRANGE);
    signal subaddr              : counter_t;
    signal subaddr_to_out       : counter_t;
    signal chip_to_out          : counter_t;
    signal hasmem               : std_logic;
    signal hasoverflow          : std_logic;
    signal fifo_empty_last      : std_logic;
    signal fifo_new             : std_logic;
    signal read_fifo_int        : std_logic;
    signal make_header          : std_logic_vector(2 downto 0);
    signal blockchange          : std_logic;
    signal no_copy_next         : std_logic;
    signal force_copy_next      : std_logic;

    signal overflowts           : std_logic_vector(15 downto 0);
    signal overflow_to_out      : std_logic_vector(15 downto 0);

begin

    o_fifo_read <= read_fifo_int;

    pseq: process(i_clk, i_reset_n)
        variable inhibit_read : std_logic;
    begin
    if ( i_reset_n = '0' ) then
        running         <= '0';
        running_last    <= '0';
        stopped         <= '0';
        read_fifo_int   <= '0';
        inhibit_read_last <= '0';
        fifo_empty_last <= '1';
        output          <= none;
        fifo_new        <= '0';
        current_block   <= block_max;
        no_copy_next    <= '0';
        force_copy_next <= '0';
        overflowts      <= (others => '0');
        make_header     <= "000";
    elsif rising_edge(i_clk) then

        running_last <= running;
        if (running = '0')then
            if (i_fifo_empty = '0') then
                running <= '1';
            end if;
        end if;

        -- defaults
        fifo_empty_last <= i_fifo_empty;
        ts_to_out <= current_ts;
        read_fifo_int <= '0';
        inhibit_read := '0';

        -- how to decide if read the FIFO is the big trick in this whole entity
        -- The decision depends on the current value of the registers (counters_reg, hasmem, blockchange)
        -- if we have a multicycle operation in progress. In this case we trigger the read when whe still
        -- need to generate two cycles of output, when we know we have more than two, we inhibt the read.
        -- If there are less than two cycles of output left, the decision is NOT taken depending on the
        -- register content, but depending on the current FIFO output, which is the block just following
        -- here.        

        -- current fifo output indicates a single-cycle operation, we can read and copy in the next cycle
        -- with a block change
        if(i_fifo_empty = '0') then
            if(i_fifo_data(TSBLOCKINFIFORANGE) /= current_block) then -- new block
                if(i_fifo_data(3 downto 0) = "0000") then --either block change with no hits or block change with 48 hit overflow
                    read_fifo_int   <= '1';
                else
                    read_fifo_int   <= '0';
                    inhibit_read    := '1';
                end if;
                if(i_fifo_data(TSBLOCKINFIFORANGE) = block_zero and ISMUTRIG = 0)then
                    read_fifo_int   <= '0';
                    inhibit_read    := '1';
                end if;
                if(i_fifo_data(TSBLOCKINFIFOMUTRIGRANGE) = block_zero(TSBLOCKMUTRIGRANGE) and ISMUTRIG = 1)then
                    read_fifo_int   <= '0';
                    inhibit_read    := '1';
                end if;

            else -- we stay in block
                if(i_fifo_data(HASMEMBIT)='1' and i_fifo_data(3 downto 0) = "0001" and i_fifo_data(11 downto 8) = "0000") then -- single hit
                    read_fifo_int <= '1';
                elsif(i_fifo_data(HASMEMBIT)='1' and i_fifo_data(3 downto 0) = "0000") then -- single TS overflow
                    read_fifo_int <= '1';
                else -- many hits, no read
                    read_fifo_int <= '0';
                    inhibit_read := '1';
                end if;    
            end if;
        end if;

        -- output computation
        if(make_header = "011")then
            output      <= footer;
            make_header <= "010";
            read_fifo_int <= '0';
        elsif(make_header = "010")then
            output      <= header1;
            make_header <= "100";
            read_fifo_int <= '0';
        elsif(make_header = "100")then
            output      <= header2;
            make_header <= "110";
            read_fifo_int <= '0';
        elsif(make_header = "110")then
            output      <= debugheader1;
            make_header <= "111";
            read_fifo_int <= '0';
        elsif(make_header = "111") then
            output      <= debugheader2;
            make_header <= "000";
            if (counters_reg(3 downto 0) /= "0000") then
                read_fifo_int <= '0';
            else
                read_fifo_int <= '1';
            end if;
        else
            if(blockchange = '1') then
                output <= subheader;
                blockchange <= '0';
                overflow_to_out <= overflowts;
                overflowts <= (others => '0');
                if(hasmem = '0' and hasoverflow = '1') then
                    overflowts <= (others => '1'); -- Note that overflow gets sent with the next subheader!
                end if;
                if(hasmem = '1' and hasoverflow = '1' and counters_reg(3 downto 0) = "0000")then -- This is the case for more than 48 hits per TS
                    overflowts(conv_integer(current_ts(TSINBLOCKRANGE))) <= hasoverflow;
                end if;
                -- subheader plus one hit - read next cycle
                if(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0000")then
                    read_fifo_int <= '1';
                elsif(counters_reg(3 downto 0) /= "0000")then
                    read_fifo_int <= '0';
                end if;
            elsif(hasmem = '1')then
                output <= hits;
                overflowts(conv_integer(current_ts(TSINBLOCKRANGE))) <= hasoverflow;
                if(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0000")then
                    hasmem <= '0';
                end if;
                if(hasmem = '1' and hasoverflow = '1' and counters_reg(3 downto 0) = "0000")then -- This is the case for more than 48 hits per TS
                    overflowts(conv_integer(current_ts(TSINBLOCKRANGE))) <= hasoverflow;
                    output <= none;
                end if;

                if(counters_reg(3 downto 0) = "0001") then -- switch chip
                    counters_reg(counters_reg'left-8 downto 0) <= counters_reg(counters_reg'left downto 8);
                    counters_reg(counters_reg'left downto counters_reg'left-7) <= (others => '0');
                    subaddr <= "0000";
                    subaddr_to_out <= subaddr;
                    chip_to_out <= counters_reg(7 downto 4);
                else -- more hits from same chip
                    counters_reg(3 downto 0) <= counters_reg(3 downto 0) -'1';
                    subaddr <= subaddr + "1";
                    subaddr_to_out <= subaddr;
                    chip_to_out <= counters_reg(7 downto 4);
                end if;

                -- and a bit of logic for the next read, we need to think ahead a bit...
                -- two hits still in the pipeline - we read:
                -- can be two hits from the last chip and no more
                if(counters_reg(3 downto 0) = "0010" and counters_reg(11 downto 8) = "0000")then
                    read_fifo_int <= '1';
                -- or one from the last and one from the second to last chip
                elsif(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0001" and counters_reg(19 downto 16) = "0000")then
                    read_fifo_int <= '1';
                -- more than two hits left -- do not read
                elsif(not(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0000"))then
                    read_fifo_int <= '0';
                end if;
                -- if there is one or zero hits, the decision is taken based on the FIFO content and not here

            else
                output <= none;
                if(inhibit_read = '0') then
                    read_fifo_int <= '1';
                end if;
                if(hasmem = '0' and hasoverflow = '1')then
                    overflowts(conv_integer(current_ts(TSINBLOCKRANGE))) <= hasoverflow;
                end if;
            end if;
        end if;

        -- if we sent a fifo_read in this cycle and the fifo was empty, 
        -- we are allowed to read again, no matter what
        if(read_fifo_int = '1' and i_fifo_empty = '1') then
            read_fifo_int <= '1';
        end if; 

        -- we acknowledge the fifo output and copy
        if(read_fifo_int = '1' and i_fifo_empty = '0')then
            current_block <= i_fifo_data(TSBLOCKINFIFORANGE);
            current_ts <= i_fifo_data(TSINFIFORANGE);
            counters_reg <= i_fifo_data(MEMCOUNTERRANGE);
            hasmem <= i_fifo_data(HASMEMBIT);
            hasoverflow <= i_fifo_data(MEMOVERFLOWBIT);
            subaddr <= "0000";

            if(i_fifo_data(HASMEMBIT)='1' and i_fifo_data(3 downto 0) = "0000")then --there was an overflow, no hits for this TS
                hasmem <= '0';
                hasoverflow <= '1';
            end if;

            if(i_fifo_data(TSBLOCKINFIFORANGE) /= current_block)then
                blockchange <= '1';
                if(i_fifo_data(TSBLOCKINFIFORANGE) = block_zero and ISMUTRIG = 0)then
                    make_header <= "01" & running_last; -- this ensures that we do not output a footer at run start
                end if;
                if(i_fifo_data(TSBLOCKINFIFOMUTRIGRANGE) = block_zero(TSBLOCKMUTRIGRANGE) and ISMUTRIG = 1)then
                    make_header <= "01" & running_last; -- this ensures that we do not output a footer at run start
                end if;
            else
                blockchange <= '0';
            end if;

        end if;

        -- run end
        if(stopped = '1') then
            output <= none;
        elsif(i_runend = '1' and current_block = block_max and i_fifo_empty = '1' and fifo_empty_last = '1' and stopped = '0') then
            output <= footer;
            stopped <= '1';
        end if;

        inhibit_read_last <= inhibit_read;

    end if;
    end process;

    -- assemble final output
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_command_enable <= '0';
        o_command <= (others => '0');
        o_overflow <= (others => '0');
    elsif rising_edge(i_clk) then
        case output is
        when none =>
            o_command_enable <= '0';
            o_command     <= (others => '0');
        when header1 =>
            o_command     <= COMMAND_HEADER1;
            o_command_enable <= '1';
        when header2 =>
            o_command     <= COMMAND_HEADER2;
            o_command_enable <= '1';
        when debugheader1 =>
            o_command     <= COMMAND_DEBUGHEADER1;
            o_command_enable <= '1';
        when debugheader2 =>
            o_command     <= COMMAND_DEBUGHEADER2;
            -- TODO: this is for debugging remove me later
            o_overflow(0) <= inhibit_read_last;
            o_command_enable <= '1';
        when subheader =>
            o_command <= COMMAND_SUBHEADER;
            o_command(TSBLOCKRANGE) <= ts_to_out(TSBLOCKRANGE);
            o_command(TSNONBLOCKRANGE) <= (others => '0');
            o_overflow <= overflow_to_out;
            o_command_enable <= '1';
        when hits =>
            o_command_enable <= '1';
            o_command(COMMANDBITS-1) <= '0'; -- Hits, not a command
            o_command(TSRANGE) <= ts_to_out;
            o_command(COMMANDINPUTSELRANGE) <= chip_to_out;
            o_command(COMMANDBINSELRANGE) <= subaddr_to_out;
        when footer =>
            o_command <= COMMAND_FOOTER;
            o_command_enable <= '1';
        end case;
    end if;
    end process;

end architecture;
