-- Sequencer.vhd
-- Niklaus Berger, November 2019
-- niberger@uni-mainz.de
--
-- Take the front-stacked counters and bit arrays of busy timestamps to
-- create a sequence of memory adrreses to be read and multiplexer settings
-- for the read part of the hit sorter

-- The ouput command has the TS in the LSBs, followed by four bits hit address
-- four bits channel/chip ID and the MSB inciating command (1) or hit (0)


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.sorter_pkg.all;

entity sequencer is
port (
    i_fifo_data         : in    sorterfifodata_t;
    i_fifo_empty        : in    std_logic;
    o_fifo_read         : out   std_logic;
    o_command           : out   command_t;
    o_command_enable    : out   std_logic;
    o_verflow           : out   std_logic_vector(15 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture rtl of sequencer is

    type state_type is (idle, header1, header2, subheader, hits, footer);
    signal state : state_type;
    signal state_last : state_type;

    signal current_block : block_t;
    constant block_max : block_t := (others => '1');
    signal block_from_fifo : block_t;


    signal fifo_reg : sorterfifodata_t;
    signal counters_reg : std_logic_vector(MEMCOUNTERRANGE);
    signal domem : std_logic;
    signal subaddr : counter_t;
    signal overflowts : std_logic_vector(15 downto 0);

    signal fifo_empty_last : std_logic;
    signal fifo_reading_last : boolean;
    signal newblocknext_reg : boolean;

    signal timesinceheader : integer;

begin

    process(i_clk, i_reset_n)
        variable do_fifo_reading : boolean;
        variable newblocknext: boolean;
    begin
    if ( i_reset_n = '0' ) then
        state <= idle;
        o_fifo_read <= '0';
        o_command_enable <= '0';
        o_command <= (others => '0');
        o_verflow <= (others => '0');
        current_block <= (others => '0');
        overflowts <= (others => '0');
        domem <= '0';
        fifo_empty_last <= '1';
        timesinceheader <= 0;
    elsif rising_edge(i_clk) then

        o_fifo_read <= '0';

        fifo_empty_last <= i_fifo_empty;

        state_last <= state;

        do_fifo_reading := false;
        newblocknext := i_fifo_data(TSBLOCKINFIFORANGE) /= current_block;
        newblocknext_reg <= newblocknext;
        if(i_fifo_empty = '0') then
            block_from_fifo <= i_fifo_data(TSBLOCKINFIFORANGE);
        end if;

        if(state /= idle) then
            timesinceheader <= timesinceheader + 1;
        end if;


        -- State machine for creating commands: We want to send a HEADER once per TS overflow, a SUBHEADER for every block
        -- and ordered read commands for the hits, where the read commands contain both the memory address (corresponding to the TS)
        -- and the MUX setting (corresponding to the input channel).
        case state is
        when idle =>
            if(i_fifo_empty = '0') then -- We start when we have data in the FIFO...
                state <= header1;
            end if;
        when header1 =>
            o_command <= COMMAND_HEADER1;
            o_command_enable <= '1';
            timesinceheader <= 0;
            state <= header2;
        when header2 =>
            o_command <= COMMAND_HEADER2;
            o_command_enable <= '1';
            state <= subheader;
            do_fifo_reading := true;
        when subheader =>
            o_command <= COMMAND_SUBHEADER;
            o_command(TSRANGE) <= i_fifo_data(TSBLOCKINFIFORANGE) & std_logic_vector(to_unsigned(0, BITSPERTSBLOCK));
            o_command_enable <= '1';
            o_verflow <= overflowts;
            overflowts <= (others => '0');
            -- Look at FIFO - either it is empty or it shows a word with hits - then process them
            -- or it is one without, then we can output the next subheader, or in case of overflow, the next header
            if(i_fifo_empty = '1') then
                do_fifo_reading := true;
                current_block <= block_from_fifo;
                o_command_enable <= '0';
                current_block <= current_block;
            elsif(i_fifo_data(HASMEMBIT) = '0') then
                do_fifo_reading := true;
                subaddr <= (others => '0');
                current_block <= block_from_fifo;
                if(block_from_fifo = block_max) then
                    state <= footer;
                    o_command_enable <= '0';
                else
                    state <= subheader;
                end if;
            else
                if(i_fifo_data(3 downto 0) = "0001" and i_fifo_data(11 downto 8) = "0000") then
                    do_fifo_reading := true;
                else
                    do_fifo_reading := false;
                end if;
                state <= hits;
                subaddr <= "0000";
            end if;

        when hits =>
            -- note here that fifo_reg contains the counters we are working on and (if ready) the fifo shows the next
            -- active TS
            o_command(COMMANDBITS-1) <= '0'; -- Hits, not a command
            o_command(TSRANGE) <= fifo_reg(TSINFIFORANGE);


            if(domem = '1') then
                o_command(COMMANDBITS-2 downto TIMESTAMPSIZE+4) <= counters_reg(7 downto 4);
                o_command(COMMANDBITS-6 downto TIMESTAMPSIZE)   <= subaddr;
                o_command_enable <= '1';

                if(counters_reg(3 downto 0) = "0010" and counters_reg(11 downto 8) = "0000" and i_fifo_empty = '0' and not newblocknext) then
                    do_fifo_reading := true;
                end if;

                --if(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0000" and fifo_empty = '0' and newblocknext) then
                --    do_fifo_reading := true;
                --end if;

                if(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0001" and counters_reg(19 downto 16) = "0000" and i_fifo_empty = '0' and not newblocknext) then
                    do_fifo_reading := true;
                end if;

                if(counters_reg(3 downto 0) = "0001" and counters_reg(11 downto 8) = "0000") then
                -- this is the last hit
                    if(i_fifo_empty = '1') then -- the fifo is empty, sit here and wait
                        o_command_enable <= '0';
                    elsif(newblocknext) then -- the next block is a new one
                        current_block <= block_from_fifo;
                        if(block_from_fifo = block_max) then
                            state <= footer;
                        else
                            state <= subheader;
                            do_fifo_reading := true;
                            --if((from_fifo(3 downto 0) = "0001" and from_fifo(11 downto 8) = "0000"  and fifo_empty = '0') -- only one hit in the next packet, move ahead
                            --or from_fifo(HASMEMBIT) = '0') then -- just a header, also move ahead
                            --    do_fifo_reading := true;
                            --else
                            --    do_fifo_reading := false;
                            --end if;
                        end if;
                    else -- we stay in block
                        if((i_fifo_data(3 downto 0) = "0001" and i_fifo_data(11 downto 8) = "0000") -- only one hit in the next packet, move ahead
                            or i_fifo_data(HASMEMBIT) = '0') then
                            do_fifo_reading := true;
                        elsif((i_fifo_data(3 downto 0) > "0001") or (i_fifo_data(11 downto 8) > "0000")) then
                            do_fifo_reading := false;
                        else
                            -- should not get here, read FIFO to prevent getting stuck
                            do_fifo_reading := true;
                        end if;
                        subaddr <= "0000";
                    end if;
                elsif(counters_reg(3 downto 0) = "0001") then -- switch chip
                    counters_reg(counters_reg'left-8 downto 0) <= counters_reg(counters_reg'left downto 8);
                    counters_reg(counters_reg'left downto counters_reg'left-7) <= (others => '0');
                    subaddr <= "0000";
                else -- more hits from same chip
                    counters_reg <= counters_reg;
                    counters_reg(3 downto 0) <= counters_reg(3 downto 0) -'1';
                    subaddr <= subaddr + "1";
                end if;
            else --domem zero indicate a block skipped due to overflow
                o_command_enable <= '0';
                -- if we have skipped a block, set all overflows to 1
                -- following condition should always be true in this case
                if(fifo_reg(MEMOVERFLOWBIT) = '1') then
                    overflowts <= (others => '1');
                end if;
                if(i_fifo_empty = '1') then -- the fifo is empty, sit here and wait (unlikely as we are close to FIFO overflow)
                    o_command_enable <= '0';
                elsif(newblocknext) then -- the next block is a new one
                    do_fifo_reading := true;
                    current_block <= block_from_fifo;
                    if(block_from_fifo = block_max) then
                        state <= footer;
                    else
                        state <= subheader;
                        do_fifo_reading := true;
                    end if;
                else
                    do_fifo_reading := true;
                end if;
            end if;

            -- And we should store the overflows
            overflowts(conv_integer(fifo_reg(TSINBLOCKINFIFORANGE))) <= fifo_reg(MEMOVERFLOWBIT);
        when footer =>
            o_command      <= COMMAND_FOOTER;
            o_command_enable  <= '1';
            state           <= header1;
            current_block   <= (others => '0');
        when others =>
            state <= idle;
        end case;


        if(timesinceheader > 3000) then
            do_fifo_reading := true;

            if(i_fifo_data(TSBLOCKINFIFORANGE) = block_max and i_fifo_empty = '0') then
                state <= footer;
            end if;
        end if;


        fifo_reading_last <= do_fifo_reading;

        if(do_fifo_reading ) then --and fifo_empty='0') then
            o_fifo_read <= '1';
        end if;
        if(fifo_reading_last and i_fifo_empty='0') then
            fifo_reg        <= i_fifo_data;
            counters_reg    <= i_fifo_data(MEMCOUNTERRANGE);
            domem           <= i_fifo_data(HASMEMBIT);
        end if;
    end if; -- clk/reset
    end process;

end architecture;
