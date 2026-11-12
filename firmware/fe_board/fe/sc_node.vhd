----------------------------------------------------------------------------
--
-- Slow Control Node
-- Oktober 2021, M.Mueller
--
-- This entity is supposed to be used to split a standard memory interface
-- with read and write enable signals, address and read and write data into
-- up to 4 interfaces where each one represents a address-subspace of the
-- original interface. The latency of the original master interface is increased
-- by 2 clock cycles in this process (one for the request and one for reply).
--
-- The reason to do that is to decrease the Fan-In and Fan-Out situation of
-- the original memory interface when to many components or registers are
-- connected to it. It is trading between fan-in/out and latency to improve
-- timing. This has a huge impact on timing in the Feb firmware where it is
-- currently used.
--
-- The general idea is that these sc_nodes can be chained. Whenever the timing
-- situation of one of the 4 splitted interfaces here becomes critical again
-- one can just add another sc_node and split the critical interface again into
-- a maximum of 4 interfaces. After two levels of splitting a single memory
-- interface can therefore be splitted into 4x4=16 interfaces with an additional
-- latency of 2 cycles per level of splitting (2+2=4 in this example), effectiveley
-- building something like a "Tree" of sc_nodes where the leaves are standard
-- 1-cycle latency memory interfaces that can be connected to user defined
-- register mappings, FiFo's or standard RAM.
--
-- The latency is known at compile time from the amount of levels of chained sc_nodes
-- connected to the original master interface. The original master interface
-- therefore preserves the ability to read and write every cycle which therefore
-- also does not compromise on bandwidth of the interface. The only thing the
-- master needs to know is the latency .. the amount of cycles where to expect
-- the reply for a read.
--
-- Until here the idea and also the implementation is very simple. It becomes
-- slightly more complicated when NOT EVERY level splits ALL interfaces into
-- 4 new ones. Lets say the first splitting splits into 4 memory interfaces
-- and then just one of them is further chained with another sc_node. The other
-- 3 end there in a ram, fifo or user reg_mapping. This is a problem because
-- it introduces an imbalance of latencies between the first port and the other 3.
--
-- This can be resolved in two ways:
-- A: Pretend that all levels DO delay by 2 cycles and introduce this delay
--    wherever it is missing (adding 2 cycle delay to the other 3 ports in the
--    example above to make it the same as the first one where that delay
--    is introduced by the 2nd level chained sc_node )
--
-- B: Drop the idea of a constant latency at the memory master.
--    Once we do that we have 2 possibilities how to continue:
--    B.1: The Memory master has to know the latency based on the address that
--         was read from and needs to keep track of that for each read which is
--         currently in the pipeline. This also immideatly means that we have
--         to compromise on bandwith since a read from a address with higher
--         latency followed by a read from a address with lower latency can lead
--         to a situation where the reply from both is expected in the same
--         cycle, which needs to be avoided.
--         Avoiding that either means the memory master needs to have exact
--         knowledge of the structure of the tree in order to predict where the
--         first collision of this type will happen based on all requests currently
--         in flight and their delays at each level and the request that needs
--         to be send out now or it needs to limit itself to 1 request in flight
--         which cuts down the bandwith by a facor of 2 x number of chained sc_nodes
--    B.2: introduce a read valid signal for each connection in the tree to
--         detect the collisions mentioned above. In case of such a detection
--         one could try to buffer one of the colliding words. This comes then with
--         the complication that the memory master in the end needs to be able
--         to assign the incoming replies to the requests that where send out.
--         Therefore it also requires knowledge of the tree structure and delays
--         of each request in flight and of the buffering strategy in order to
--         reconstruct the exact order of replies to expect.
--         If we do not buffer we can also throw away one or all of the colliding
--         replies and introduce a "readerror" signal in addition at each level.
--         That introduces the concept of a failed read which needs to be dealt
--         with upstream, potentially by software. In addition the "readerror" also
--         needs to be assigned to a specific request at the memory master. If the
--         latency is not previously known we again have the same problem as above,
--         need to limit the bandwith, knowlege of the exact tree structure, eventually
--         just assign "error" to all the recent reads since we cannot
--         know which one failed and so on. In the case of reading from a FiFo
--         just "repeating the read" might also not be possible since the
--         word in question was lost at the collision
--
-- In conclusion all of the "B" ideas lead to problems that are difficult to solve
-- and will likeley end in bandwith limitation or at least introduce the possibility
-- of failure into the system. We therefore go with the simple option A
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mudaq.all;

entity sc_node is
generic (
    -- put here the depth of the part of the tree connecting to port 0-3
    -- sc_nodes count as 1 depth, reg_mappings count as 1 depth, ram's and fifo's count as 1 depth
    -- always count the deepest path from that output
    -- (For example: slave0 connects to 1 more sc_node which then connects only to the standard 1 cycle latency reg_mapping.vhd entities ---> g_SLAVE0_DEPTH = 2 )
    -- This is needed so the delays between the differnt ports can be adjusted to each other
    -- (as explained above)
    g_SLAVE0_DEPTH          : positive := 1;
    g_SLAVE1_DEPTH          : positive := 1;
    g_SLAVE2_DEPTH          : positive := 1;
    g_SLAVE3_DEPTH          : positive := 1;

    -- These generics are used to define the address subspaces to split into (see explaination above)
    -- The incoming address will be compared against these vectors and the read/write
    -- will connect to the corresponding sub-interface when they match
    -- one can use the "-" value for don't care
    -- if no match is found it will connect the read/write to slave1 interface
    g_SLAVE1_ADDR_MATCH     : std_ulogic_vector(15 downto 0) := "1111111111111111";
    g_SLAVE2_ADDR_MATCH     : std_ulogic_vector(15 downto 0) := "1111111111111111";
    g_SLAVE3_ADDR_MATCH     : std_ulogic_vector(15 downto 0) := "1111111111111111"--;
);
port (
    -- the interface that should connect towards the master of the tree
    -- (naming is up for debate since it in principle is a slave of that master)
    i_master_addr   : in    std_logic_vector(15 downto 0);
    i_master_re     : in    std_logic;
    o_master_rdata  : out   reg32;
    i_master_we     : in    std_logic;
    i_master_wdata  : in    reg32;

    -- the interfaces that should connect towards the leaves (slaves) of the tree
    -- (naming is up for debate since they are in principle masters of those slaves)
    o_slave0_addr   : out   std_logic_vector(15 downto 0);
    o_slave0_re     : out   std_logic;
    i_slave0_rdata  : in    reg32;
    o_slave0_we     : out   std_logic;
    o_slave0_wdata  : out   reg32;

    o_slave1_addr   : out   std_logic_vector(15 downto 0);
    o_slave1_re     : out   std_logic;
    i_slave1_rdata  : in    reg32 := x"CCCCCCCC";
    o_slave1_we     : out   std_logic;
    o_slave1_wdata  : out   reg32;

    o_slave2_addr   : out   std_logic_vector(15 downto 0);
    o_slave2_re     : out   std_logic;
    i_slave2_rdata  : in    reg32 := x"CCCCCCCC";
    o_slave2_we     : out   std_logic;
    o_slave2_wdata  : out   reg32;

    o_slave3_addr   : out   std_logic_vector(15 downto 0);
    o_slave3_re     : out   std_logic;
    i_slave3_rdata  : in    reg32 := x"CCCCCCCC";
    o_slave3_we     : out   std_logic;
    o_slave3_wdata  : out   reg32;

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture arch of sc_node is

    -- Calculate the amount of latency at this node and the minimal amound of added delay needed for each sub-interface to equalize them
    constant c_REPLY_CYCLES        : positive := work.util.max(g_SLAVE0_DEPTH*2,work.util.max(g_SLAVE1_DEPTH*2, work.util.max(g_SLAVE2_DEPTH*2, g_SLAVE3_DEPTH*2))); -- overall delay of this node, depends on deepest downwards connection of the tree from here
    constant c_SLAVE0_ADD_DELAY      : positive := 1 + c_REPLY_CYCLES - g_SLAVE0_DEPTH*2; -- Delay to introduce for i_slave0_rdata
    constant c_SLAVE1_ADD_DELAY      : positive := 1 + c_REPLY_CYCLES - g_SLAVE1_DEPTH*2; -- Delay to introduce for i_slave1_rdata
    constant c_SLAVE2_ADD_DELAY      : positive := 1 + c_REPLY_CYCLES - g_SLAVE2_DEPTH*2; -- Delay to introduce for i_slave2_rdata
    constant c_SLAVE3_ADD_DELAY      : positive := 1 + c_REPLY_CYCLES - g_SLAVE3_DEPTH*2; -- Delay to introduce for i_slave3_rdata

    -- We will introduce the delay on the return only. No delay introduces for writes
    -- these signals are the buffers to implement the delay if we need one
    signal s0_return_queue      : reg32array(c_SLAVE0_ADD_DELAY downto 0);
    signal s1_return_queue      : reg32array(c_SLAVE1_ADD_DELAY downto 0);
    signal s2_return_queue      : reg32array(c_SLAVE2_ADD_DELAY downto 0);
    signal s3_return_queue      : reg32array(c_SLAVE3_ADD_DELAY downto 0);
    signal slave0_re            : std_logic;
    signal slave1_re            : std_logic;
    signal slave2_re            : std_logic;
    signal slave3_re            : std_logic;

    -- c_REPLY_CYCLES after a read we expect a reply.
    -- This signal stores from which slave we exepct the reply
    -- Signal is shifted by 1 each cycle so we know which of the
    -- 4 i_slave_rdata to connect to o_master_rdata in each cycle
    type slave_type is ( slave0, slave1, slave2, slave3 );
    type return_queue_S0123_switch_type is array (natural range <>) of slave_type;
    signal return_queue_S0123_switch : return_queue_S0123_switch_type(c_REPLY_CYCLES downto 0);

begin
    assert ( c_SLAVE0_ADD_DELAY <= c_REPLY_CYCLES ) report "sc_node Delay mismatch, c_REPLY_CYCLES is not allowed to be smaller than c_SLAVE0_ADD_DELAY" severity error;
    assert ( c_SLAVE1_ADD_DELAY <= c_REPLY_CYCLES ) report "sc_node Delay mismatch, c_REPLY_CYCLES is not allowed to be smaller than c_SLAVE1_ADD_DELAY" severity error;
    assert ( c_SLAVE2_ADD_DELAY <= c_REPLY_CYCLES ) report "sc_node Delay mismatch, c_REPLY_CYCLES is not allowed to be smaller than c_SLAVE2_ADD_DELAY" severity error;
    assert ( c_SLAVE3_ADD_DELAY <= c_REPLY_CYCLES ) report "sc_node Delay mismatch, c_REPLY_CYCLES is not allowed to be smaller than c_SLAVE3_ADD_DELAY" severity error;

    -- return part ------------------------------------
    o_slave0_re <= slave0_re;
    o_slave1_re <= slave1_re;
    o_slave2_re <= slave2_re;
    o_slave3_re <= slave3_re;

    -- put the slave that we request a read from into the start of the shift register
    -- end of the shift register will be used to make the i_slave_rdata selection after
    -- c_REPLY_CYCLES cycles
    return_queue_S0123_switch(c_REPLY_CYCLES) <=
        slave3 when slave3_re = '1' else
        slave2 when slave2_re = '1' else
        slave1 when slave1_re = '1' else
        slave0;

    -- save the reply data in case that we have to introduce delay
    s0_return_queue(c_SLAVE0_ADD_DELAY) <= i_slave0_rdata; -- moving the delay to the request part and only delay the 16 bit addr instead of the 32 bit rdata does not save registers since one also has to deal with writes & wdata in this case
    s1_return_queue(c_SLAVE1_ADD_DELAY) <= i_slave1_rdata;
    s2_return_queue(c_SLAVE2_ADD_DELAY) <= i_slave2_rdata;
    s3_return_queue(c_SLAVE3_ADD_DELAY) <= i_slave3_rdata;

    -- after c_REPLY_CYCLES make the selection menttioned above
    -- the delay equalisation is done by the different length's of s*_return_queue's
    with return_queue_S0123_switch(0) select o_master_rdata <=
        s3_return_queue(0) when slave3,
        s2_return_queue(0) when slave2,
        s1_return_queue(0) when slave1,
        s0_return_queue(0) when slave0;

    -- process to shift all the shift registers
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        return_queue_S0123_switch(c_REPLY_CYCLES-1 downto 0) <= (others => slave0);
    elsif rising_edge(i_clk) then
        s0_return_queue(c_SLAVE0_ADD_DELAY-1 downto 0) <= s0_return_queue(c_SLAVE0_ADD_DELAY downto 1);
        s1_return_queue(c_SLAVE1_ADD_DELAY-1 downto 0) <= s1_return_queue(c_SLAVE1_ADD_DELAY downto 1);
        s2_return_queue(c_SLAVE2_ADD_DELAY-1 downto 0) <= s2_return_queue(c_SLAVE2_ADD_DELAY downto 1);
        s3_return_queue(c_SLAVE3_ADD_DELAY-1 downto 0) <= s3_return_queue(c_SLAVE3_ADD_DELAY downto 1);
        return_queue_S0123_switch(c_REPLY_CYCLES-1 downto 0) <= return_queue_S0123_switch(c_REPLY_CYCLES downto 1);
    end if;
    end process;

    -- request part -----------------------------------
    -- process to send the request, just comparing i_master_addr with the SLAVE_ADDR_MATCH generics
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        slave0_re   <= '0';
        slave1_re   <= '0';
        slave2_re   <= '0';
        slave3_re   <= '0';
        o_slave0_we <= '0';
        o_slave1_we <= '0';
        o_slave2_we <= '0';
        o_slave3_we <= '0';

    elsif rising_edge(i_clk) then

        slave0_re   <= '0';
        slave1_re   <= '0';
        slave2_re   <= '0';
        slave3_re   <= '0';
        o_slave0_we <= '0';
        o_slave1_we <= '0';
        o_slave2_we <= '0';
        o_slave3_we <= '0';

        -- Quartus merges these into single registers and fails timing because the fanout is so large if one does this here
        --o_slave0_addr   <= i_master_addr;
        --o_slave1_addr   <= i_master_addr;
        --o_slave2_addr   <= i_master_addr;
        --o_slave3_addr   <= i_master_addr;

        --o_slave0_wdata  <= i_master_wdata;
        --o_slave1_wdata  <= i_master_wdata;
        --o_slave2_wdata  <= i_master_wdata;
        --o_slave3_wdata  <= i_master_wdata;

        if( to_stdulogicvector(i_master_addr) ?= g_SLAVE1_ADDR_MATCH) then
            slave1_re       <= i_master_re;
            o_slave1_we     <= i_master_we;
            o_slave1_addr   <= i_master_addr;
            o_slave1_wdata  <= i_master_wdata;
        elsif( to_stdulogicvector(i_master_addr) ?= g_SLAVE2_ADDR_MATCH) then
            slave2_re       <= i_master_re;
            o_slave2_we     <= i_master_we;
            o_slave2_addr   <= i_master_addr;
            o_slave2_wdata  <= i_master_wdata;
        elsif( to_stdulogicvector(i_master_addr) ?= g_SLAVE3_ADDR_MATCH) then
            slave3_re       <= i_master_re;
            o_slave3_we     <= i_master_we;
            o_slave3_addr   <= i_master_addr;
            o_slave3_wdata  <= i_master_wdata;
        else
            slave0_re       <= i_master_re;
            o_slave0_we     <= i_master_we;
            o_slave0_addr   <= i_master_addr;
            o_slave0_wdata  <= i_master_wdata;
        end if;
    end if;
    end process;

end architecture;
