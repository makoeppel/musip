library ieee;
use ieee.std_logic_1164.all;

package sorter_pkg is

    -----------------------------------------------------------------
    -- Things to clean up with the generics
    -----------------------------------------------------------------
    constant NINPUTS                :  integer := 36;
    constant NSORTERINPUTS          :  integer :=  1;
    constant NCHIPS                 :  integer := 12;

    -----------------------------------------------------------------
    -- conflicts between detectorfpga_constants and mupix_constants (to be checked & tested)
    -----------------------------------------------------------------

    constant HITSIZE                :  integer := 32;

    constant TIMESTAMPSIZE          :  integer := 11;

    subtype TSRANGE                 is integer range TIMESTAMPSIZE-1 downto 0;

    constant MHITSIZE               :  integer := HITSIZE+2;

    constant COARSECOUNTERSIZE      :  integer := 32;

    constant CHIPRANGE              :  integer := 3;

    -----------------------------------------------------------
    -----------------------------------------------------------

    constant BINCOUNTERSIZE         :  integer := 24;

    constant NOTSHITSIZE            :  integer := HITSIZE - TIMESTAMPSIZE;
    subtype NOTSRANGE               is integer range HITSIZE-1 downto TIMESTAMPSIZE;

    constant HITSORTERBINBITS       :  integer := 4;
    constant H                      :  integer := HITSORTERBINBITS;
    constant HITSORTERADDRSIZE      :  integer := TIMESTAMPSIZE + HITSORTERBINBITS;

    -- Subheader every 16 cycles
    constant BITSPERTSBLOCK         :  integer := 4;
    subtype TSBLOCKRANGE            is integer range TIMESTAMPSIZE-1 downto BITSPERTSBLOCK;
    subtype TSNONBLOCKRANGE         is integer range BITSPERTSBLOCK-1 downto 0;

    constant COMMANDBITS            :  integer := 20;

    constant COUNTERMEMADDRSIZE     :  integer := 8;
    constant NMEMS                  :  integer := 2**(TIMESTAMPSIZE-COUNTERMEMADDRSIZE);
    constant COUNTERMEMDATASIZE     :  integer := 5;
    subtype COUNTERMEMSELRANGE      is integer range TIMESTAMPSIZE-1 downto COUNTERMEMADDRSIZE;
    subtype COUNTERMEMADDRRANGE     is integer range COUNTERMEMADDRSIZE-1 downto 0;

    -- Bit positions in the counter fifo of the sorter
    subtype MEMCOUNTERRANGE        is integer range 2*NCHIPS*HITSORTERBINBITS-1 downto 0;
    constant MEMOVERFLOWBIT        :  integer := 2*NCHIPS*HITSORTERBINBITS;
    constant HASMEMBIT             :  integer := 2*NCHIPS*HITSORTERBINBITS+1;
    subtype TSINFIFORANGE           is integer range HASMEMBIT+TIMESTAMPSIZE downto HASMEMBIT+1;
    subtype TSBLOCKINFIFORANGE      is integer range TSINFIFORANGE'left downto TSINFIFORANGE'right+BITSPERTSBLOCK;
    subtype TSINBLOCKINFIFORANGE    is integer range TSINFIFORANGE'right+BITSPERTSBLOCK-1  downto TSINFIFORANGE'right;
    subtype SORTERFIFORANGE         is integer range TSINFIFORANGE'left downto 0;
    subtype TSINBLOCKRANGE          is integer range BITSPERTSBLOCK-1 downto 0;

    constant NSORTERCOUNTERS        : integer := 40;

    subtype hit_t is                std_logic_vector(HITSIZE-1 downto 0);
    subtype cnt_t is                std_logic_vector(COARSECOUNTERSIZE-1  downto 0);
    subtype ts_t is                 std_logic_vector(TSRANGE);
    subtype nots_t                  is std_logic_vector(NOTSHITSIZE-1 downto 0);
    subtype addr_t                  is std_logic_vector(HITSORTERADDRSIZE-1 downto 0);
    subtype counter_t               is std_logic_vector(HITSORTERBINBITS-1 downto 0);

    constant counter1               :  counter_t := (others => '1');

    type wide_hit_array             is array (NINPUTS-1 downto 0) of hit_t;
    type hit_array                  is array (natural range <>) of hit_t;

    type wide_cnt_array             is array (NINPUTS-1 downto 0) of cnt_t;
    type cnt_array                  is array (NCHIPS-1 downto 0) of cnt_t;

    type ts_array                   is array (NCHIPS-1 downto 0) of ts_t;

    type nots_hit_array             is array (NCHIPS-1 downto 0) of nots_t;
    type addr_array                 is array (NCHIPS-1 downto 0) of addr_t;

    type counter_chips              is array (NCHIPS-1 downto 0) of counter_t;
    subtype counter2_chips          is std_logic_vector(2*NCHIPS*HITSORTERBINBITS-1 downto 0);

    subtype sorterfifodata_t        is std_logic_vector(SORTERFIFORANGE);

    type hitcounter_sum3_type is array (NCHIPS/3-1 downto 0) of integer;

    subtype chip_bits_t             is std_logic_vector(NCHIPS-1 downto 0);

    subtype muxhit_t                is std_logic_vector(HITSIZE+1 downto 0);
    type muxhit_array               is array ((NINPUTS/4) downto 0) of muxhit_t;

    subtype byte_t                  is std_logic_vector(7 downto 0);
    type inbyte_array               is array (NINPUTS-1 downto 0) of byte_t;

    type state_type                 is (INIT, START, PRECOUNT, COUNT);

    subtype block_t                 is std_logic_vector(TSBLOCKRANGE);

    subtype command_t               is std_logic_vector(COMMANDBITS-1 downto 0);
    constant COMMAND_HEADER0        :  command_t := X"B0000";
    constant COMMAND_HEADER1        :  command_t := X"80000";
    constant COMMAND_HEADER2        :  command_t := X"90000";
    constant COMMAND_SUBHEADER      :  command_t := X"C0000";
    constant COMMAND_FOOTER         :  command_t := X"E0000";
    constant COMMAND_DEBUGHEADER1   :  command_t := X"A0000";
    constant COMMAND_DEBUGHEADER2   :  command_t := X"D0000";

    subtype doublecounter_t         is std_logic_vector(COUNTERMEMDATASIZE-1 downto 0);
    type doublecounter_array        is array (NMEMS-1 downto 0) of doublecounter_t;
    type doublecounter_chiparray    is array (NCHIPS-1 downto 0) of doublecounter_t;
    type alldoublecounter_array     is array (NCHIPS-1 downto 0) of doublecounter_array;

    subtype counteraddr_t           is std_logic_vector(COUNTERMEMADDRSIZE-1 downto 0);
    type counteraddr_array          is array (NMEMS-1 downto 0) of counteraddr_t;
    type counteraddr_chiparray      is array (NCHIPS-1 downto 0) of counteraddr_t;
    type allcounteraddr_array       is array (NCHIPS-1 downto 0) of counteraddr_array;

    type counterwren_array          is array (NMEMS-1 downto 0) of std_logic;
    type allcounterwren_array       is array (NCHIPS-1 downto 0) of counterwren_array;
    subtype countermemsel_t         is std_logic_vector(COUNTERMEMADDRRANGE);
    type reg_array                  is array (NCHIPS-1 downto 0) of work.mudaq.reg32;
    type sorter_reg_array           is array (NSORTERCOUNTERS-1 downto 0) of work.mudaq.reg32;

end package;