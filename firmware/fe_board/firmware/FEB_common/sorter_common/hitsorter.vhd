-- Sort hits by timestamp
-- Version Tile 125 MHz TS
-- November 2022, Niklaus Berger
-- niberger@uni-mainz.de


-- General idea: Write hits to a memory location according to their timestamp;
-- one memory per chip, 16 slots in memory per chip and timestamp
-- After a fixed delay, the counters of how many hits there are get collected and are transferred to the
-- read side via another memory.

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.mutrig_hit_types.all;
use work.mudaq.all;
use work.sorter_pkg.all;
use work.util_slv.all;

library altera_mf;


entity hitsorter is
generic (
    -- should be a multiple of 3 and not more than 15.
    NSORTERINPUTS : integer := 3;
    TIMESTAMPSIZE : integer := 13;
    HIT_WITHOUT_TS_SIZE : integer := 13;
    IS_SORTER_TWO : integer := 0;
    g_USE_TRIGGER : integer := 0;
    IS_SCIFI : integer := 0;
    IS_TILE : integer := 0;
    g_IS_OUTER : integer := 0
);
port (
    i_reset_n       : in    std_logic;                            -- async reset
    i_clk           : in    std_logic;                            -- clock for write/input side
    i_running       : in    std_logic;
    i_currentts     : in    std_logic_vector(TIMESTAMPSIZE-1 downto 0); -- 13 bit ts
    -- TODO: we should make one common record type (i_hit is mutrig)
    i_hit           : in    t_v_hit_presort_div(NSORTERINPUTS-1 downto 0) := (others => t_hit_presort_div_zero);
    i_hit_mupix     : in    hit_array(NSORTERINPUTS-1 downto 0) := (others => (others => '0'));
    i_chipID        : in    slv2_array_t(NSORTERINPUTS-1 downto 0) := (others => (others => '0'));
    i_hit_ena_mupix : in    std_logic_vector(NSORTERINPUTS-1 downto 0) := (others => '0'); -- valid hit

    data_out        : out   reg32;                        -- packaged data out
    out_ena         : out   std_logic;                    -- valid output data
    out_type        : out   std_logic_vector(3 downto 0); -- start/end of an output package, hits, end of run
    out_is_hit      : out   std_logic;                    -- same as out_ena, but only hits, no trailer header etc.

    i_ccdiff        : in    slv24_array_t(NSORTERINPUTS-1 downto 0) := (others => (others => '0')); -- not super nice to do that here, but...

    i_clk156        : in    std_logic;
    i_regs_reset_n  : in    std_logic;
    i_reg_addr      : in    std_logic_vector(15 downto 0);
    i_reg_re        : in    std_logic;
    o_reg_rdata     : out   std_logic_vector(31 downto 0);
    i_reg_we        : in    std_logic;
    i_reg_wdata     : in    std_logic_vector(31 downto 0)--;
);
end entity;

architecture rtl of hitsorter is

    -- We create the types here in order to stay generic...
    constant ISMUTRIG               : integer := IS_SCIFI + IS_TILE;
    constant COUNTERMEMADDRSIZE     : integer := 10 - 2*(1-ISMUTRIG);
    constant COUNTERMEMDATASIZE     : integer := 5;
    subtype COUNTERMEMSELRANGE      is integer range TIMESTAMPSIZE-1 downto COUNTERMEMADDRSIZE;
    subtype COUNTERMEMADDRRANGE     is integer range COUNTERMEMADDRSIZE-1 downto 0;
    constant NMEMS                  : integer := 2**(TIMESTAMPSIZE-COUNTERMEMADDRSIZE);
    constant HITSORTERBINBITS       : integer := 4;
    constant H                      : integer := HITSORTERBINBITS;
    constant HITSORTERADDRSIZE      : integer := TIMESTAMPSIZE + HITSORTERBINBITS;
    subtype TSRANGE                 is integer range TIMESTAMPSIZE-1 downto 0;
    subtype TSNONBLOCKRANGE         is integer range BITSPERTSBLOCK-1 downto 0;

    -- Bit positions in the counter fifo of the sorter
    subtype MEMCOUNTERRANGE         is integer range 2*NSORTERINPUTS*HITSORTERBINBITS-1 downto 0;
    constant MEMOVERFLOWBIT         : integer := 2*NSORTERINPUTS*HITSORTERBINBITS;
    constant HASMEMBIT              : integer := 2*NSORTERINPUTS*HITSORTERBINBITS+1;
    subtype TSINFIFORANGE           is integer range HASMEMBIT+TIMESTAMPSIZE downto HASMEMBIT+1;
    subtype TSBLOCKINFIFORANGE      is integer range TSINFIFORANGE'left downto TSINFIFORANGE'right+BITSPERTSBLOCK;
    subtype TSINBLOCKINFIFORANGE    is integer range TSINFIFORANGE'right+BITSPERTSBLOCK-1 downto TSINFIFORANGE'right;
    subtype SORTERFIFORANGE         is integer range TSINFIFORANGE'left downto 0;
    subtype TSINBLOCKRANGE          is integer range BITSPERTSBLOCK-1 downto 0;

    subtype ts_t                    is std_logic_vector(TIMESTAMPSIZE-1 downto 0);
    subtype nots_t                  is std_logic_vector(HIT_WITHOUT_TS_SIZE-1 downto 0);
    type nots_hit_array             is array (NSORTERINPUTS-1 downto 0) of nots_t;

    type ts_array                   is array (NSORTERINPUTS-1 downto 0) of ts_t;
    subtype input_bits_t            is std_logic_vector(NSORTERINPUTS-1 downto 0);

    subtype doublecounter_t         is std_logic_vector(COUNTERMEMDATASIZE-1 downto 0);
    type doublecounter_array        is array (NMEMS-1 downto 0) of doublecounter_t;
    type doublecounter_inputarray   is array (NSORTERINPUTS-1 downto 0) of doublecounter_t;
    type alldoublecounter_array     is array (NSORTERINPUTS-1 downto 0) of doublecounter_array;

    subtype addr_t                  is std_logic_vector(HITSORTERADDRSIZE-1 downto 0);
    subtype counter_t               is std_logic_vector(HITSORTERBINBITS-1 downto 0);

    type addr_array                 is array (NSORTERINPUTS-1 downto 0) of addr_t;

    subtype counteraddr_t           is std_logic_vector(COUNTERMEMADDRSIZE-1 downto 0);
    type counteraddr_array          is array (NMEMS-1 downto 0) of counteraddr_t;
    type counteraddr_chiparray      is array (NSORTERINPUTS-1 downto 0) of counteraddr_t;
    type allcounteraddr_array       is array (NSORTERINPUTS-1 downto 0) of counteraddr_array;

    type counterwren_array          is array (NMEMS-1 downto 0) of std_logic;
    type allcounterwren_array       is array (NSORTERINPUTS-1 downto 0) of counterwren_array;

    subtype sorterfifodata_t        is std_logic_vector(SORTERFIFORANGE);

    type counter_inputs             is array (NSORTERINPUTS-1 downto 0) of counter_t;
    subtype counter2_inputs         is std_logic_vector(2*NSORTERINPUTS*HITSORTERBINBITS-1 downto 0);

    type hitcounter_sum3_type is array (NSORTERINPUTS/3-1 downto 0) of integer;

    -- Commands from the sequencer
    constant COMMANDBITS            : integer := TIMESTAMPSIZE + HITSORTERBINBITS + 4 + 1;
    constant COMMANDSCIFIASICBIT    : integer := TIMESTAMPSIZE + HITSORTERBINBITS;
    subtype command_t               is std_logic_vector(COMMANDBITS-1 downto 0);
    constant COMMAND_HEADER1        : std_logic_vector(3 downto 0) := X"8";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_HEADER2        : std_logic_vector(3 downto 0) := X"9";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_SUBHEADER      : std_logic_vector(3 downto 0) := X"C";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_FOOTER         : std_logic_vector(3 downto 0) := X"E";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_DEBUGHEADER1   : std_logic_vector(3 downto 0) := X"A";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    constant COMMAND_DEBUGHEADER2   : std_logic_vector(3 downto 0) := X"B";-- & std_logic_vector(to_unsigned(0, COMMANDBITS-4));
    subtype COMMANDRANGE is integer range COMMANDBITS-1 downto COMMANDBITS-4;
    subtype COMMANDINPUTSELRANGE is integer range COMMANDBITS-2 downto COMMANDBITS-5;
    subtype COMMANDBINSELRANGE is integer range COMMANDBITS-6 downto TIMESTAMPSIZE;


    -- For run start/stop process
    signal running_last : std_logic;
    signal running_read : std_logic;
    signal running_read_last : std_logic;
    signal running_read_last2 : std_logic;
    signal running_seq : std_logic;

    signal tslow : ts_t;
    signal tshi : ts_t;
    signal tsread : ts_t;
    signal tsreadmemdelay : ts_t;

    signal runstartup : std_logic;
    signal runshutdown : std_logic;
    signal runend : std_logic;

    -- For hit writing process
    signal hit_last1 : t_v_hit_presort_div(NSORTERINPUTS-1 downto 0);
    signal hit_last2 : t_v_hit_presort_div(NSORTERINPUTS-1 downto 0);
    signal hit_last3 : t_v_hit_presort_div(NSORTERINPUTS-1 downto 0);
    signal hit_last1_mupix : hit_array(NSORTERINPUTS-1 downto 0);
    signal hit_last2_mupix : hit_array(NSORTERINPUTS-1 downto 0);
    signal hit_last3_mupix : hit_array(NSORTERINPUTS-1 downto 0);
    signal chipID_last1_mupix : slv2_array_t(NSORTERINPUTS-1 downto 0);
    signal chipID_last2_mupix : slv2_array_t(NSORTERINPUTS-1 downto 0);
    signal hit_ena_last1 : std_logic_vector(NSORTERINPUTS-1 downto 0);
    signal hit_ena_last2 : std_logic_vector(NSORTERINPUTS-1 downto 0);
    signal hit_ena_last3 : std_logic_vector(NSORTERINPUTS-1 downto 0);

    signal tshit : ts_array;

    signal sametsafternext : input_bits_t;
    signal sametsnext : input_bits_t;

    signal dcountertemp : doublecounter_inputarray;
    signal dcountertemp2 : doublecounter_inputarray;

    -- Actual sorter memory
    signal tomem : nots_hit_array;
    signal frommem : nots_hit_array;
    signal memwren : std_logic_vector(NSORTERINPUTS-1 downto 0);
    signal waddr : addr_array;
    signal raddr : addr_array;

    -- Counter memory
    signal tocmem : alldoublecounter_array;
    signal tocmem_hitwriter : alldoublecounter_array;
    signal fromcmem : alldoublecounter_array := (others => (others => (others => '0')));
    signal fromcmem_hitreader : doublecounter_inputarray := (others => (others => '0'));
    signal cmemreadaddr : allcounteraddr_array;
    signal cmemwriteaddr : allcounteraddr_array;
    signal cmemreadaddr_hitwriter : allcounteraddr_array;
    signal cmemwriteaddr_hitwriter : allcounteraddr_array;
    signal cmemreadaddr_hitreader : counteraddr_t;
    signal addrcounterreset : counteraddr_t := (others => '0');
    signal cmemwren : allcounterwren_array;
    signal cmemwren_hitwriter : allcounterwren_array;

    -- Fifo for counters to sequencer
    signal reset : std_logic;
    signal tofifo_counters : sorterfifodata_t;
    signal fromfifo_counters : sorterfifodata_t;
    signal read_counterfifo : std_logic;
    signal write_counterfifo : std_logic;
    signal counterfifo_almostfull : std_logic;
    signal counterfifo_empty : std_logic;

    signal block_nonempty_accumulate : std_logic;
    signal block_empty_del2 : std_logic;

    signal stopwrite : std_logic;
    signal stopwrite_del1 : std_logic;
    signal stopwrite_del2 : std_logic;
    signal stopwrite_del3 : std_logic;

    signal blockchange : std_logic;
    signal blockchange_del1 : std_logic;
    signal blockchange_del2 : std_logic;

    constant counter2inputszero : counter2_inputs := (others => '0');

    signal mem_nnonempty : std_logic_vector(3 downto 0); -- for sim only
    signal mem_neinputs : input_bits_t;
    signal mem_neinputs2 : input_bits_t;
    signal mem_countinputs : counter_inputs;
    signal mem_countinputs_m1 : counter2_inputs;
    signal mem_countinputs_m2 : counter2_inputs;
    signal hashits : std_logic;
    signal mem_overflow : std_logic;
    signal mem_overflow_del1 : std_logic;
    signal mem_overflow_del2 : std_logic;

    signal credits : integer range -128 to 127 := 0;
    signal credits32 : std_logic_vector(31 downto 0);
    signal credittemp : integer range -256 to 255 := 0;
    signal hitcounter_sum_m3_mem : hitcounter_sum3_type;
    signal hitcounter_sum_mem : integer;
    signal hitcounter_sum : integer; -- for sim only
    signal creditchange_reg : integer; -- for sim only

    signal readcommand : command_t;
    signal readcommand_last1 : command_t;
    signal readcommand_last2 : command_t;
    signal readcommand_last3 : command_t;
    signal readcommand_last4 : command_t;

    signal readcommand_ena : std_logic;
    signal readcommand_ena_last1 : std_logic;
    signal readcommand_ena_last2 : std_logic;
    signal readcommand_ena_last3 : std_logic;
    signal readcommand_ena_last4 : std_logic;

    signal outoverflow : std_logic_vector(15 downto 0);
    signal overflow_last1 : std_logic_vector(15 downto 0);
    signal overflow_last2 : std_logic_vector(15 downto 0);
    signal overflow_last3 : std_logic_vector(15 downto 0);
    signal overflow_last4 : std_logic_vector(15 downto 0);

    signal header_counter : std_logic_vector(15 downto 0);
    signal subheader_counter : std_logic_vector(15 downto 0);

    signal memmultiplex : nots_t;
    signal tscounter : std_logic_vector(47-11 downto 0); --timestamp in 16us when the hit arrived on the FPGA after runstart
    signal sendtscounter : std_logic_vector(47 downto 0); --timestamp when the hit is sound out of the sorter after runstart

    -- end of run sequence on output side
    signal terminate_output : std_logic;
    signal terminated_output : std_logic;

    signal debug_hitcounter : std_logic_vector(15 downto 0);

    -- diagnostics
    signal noutoftime       : reg32array(NSORTERINPUTS-1 downto 0);
    signal noverflow        : reg32array(NSORTERINPUTS-1 downto 0);
    signal nintime          : reg32array(NSORTERINPUTS-1 downto 0);
    signal nout             : reg32;
    signal delay            : ts_t;

    signal nprewindow       : reg32array(NSORTERINPUTS-1 downto 0);
    signal npastwindow      : reg32array(NSORTERINPUTS-1 downto 0);
    signal noutdiag         : reg32array(NSORTERINPUTS-1 downto 0); --TODO do we have enough registers?
    signal diagwidth        : ts_t;

    signal tshidiag         : ts_t;
    signal tslowdiag        : ts_t;

    -- NOTE: not static choice exclude others choice for GHDL
    -- one cannot use more than one choice in an array aggregate
    -- if you're using a non-static value (generic) to define the
    -- ranges or positions.
    constant TSONE : ts_t := (TIMESTAMPSIZE-1 downto 1 => '0') & "1";
    constant TSZERO : ts_t := (others => '0');
    constant WINDOWSIZE : ts_t := '1' & (TIMESTAMPSIZE - 2 downto 0 => '0');
    constant READOFFSET : ts_t := "001" & (TIMESTAMPSIZE - 4 downto 2 => '0') & "11";

    -- simulation
    signal s_counterfrommem         : doublecounter_inputarray := (others => (others => '0'));

begin

    -- Generate timestamps that define windows for writing, reading and clearing
    -- Including run start and stop logic
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        running_last <= '0';
        running_read <= '0';
        running_read_last <= '0';
        running_read_last2 <= '0';
        running_seq <= '0';

        runstartup <= '0';
        runshutdown <= '0';
        runend <= '0';

        tslow <= TSZERO;
        tshi <= TSZERO;
        tslowdiag <= TSZERO;
        tshidiag <= TSZERO;
        tsread <= TSZERO;
        tsreadmemdelay <= TSZERO;
    elsif rising_edge(i_clk) then

        tsread <= tslow - READOFFSET;
        tsreadmemdelay <= tsread;

        running_last <= i_running;
        running_read_last <= running_read;
        running_read_last2 <= running_read_last;

        if(i_running = '0') then
            runstartup <= '0';
        end if;

        if(i_running = '1' and running_last = '0') then
            runstartup <= '1';
        end if;

        if(i_running = '0' and running_last = '1') then
            runshutdown <= '1';
        end if;

        if(i_running = '1' and runstartup = '1') then
            tslow <= TSONE;
            tshi <= WINDOWSIZE;
            tslowdiag <= TSONE - diagwidth;
            tshidiag <= WINDOWSIZE + diagwidth;
            if(i_currentts = WINDOWSIZE + delay - "11") then
                runstartup <= '0';
            end if;
        elsif(i_running = '1' and running_last = '1' and runshutdown = '0') then
            tslow <= tslow + '1';
            tshi <= tshi + '1';
            tslowdiag <= tslowdiag + '1'; --could adapt this to be able to change diag window while running
            tshidiag <= tshidiag + '1';
            if(running_read = '0' and tslow >= READOFFSET) then
                running_read <= '1';
                running_seq <= '1';
            end if;
        elsif(runshutdown = '1') then-- shutdown sequence
            tshi <= tshi + '1';
            tslow <= tslow + '1';
            tslowdiag <= tslowdiag + '1';
            tshidiag <= tshidiag + '1';
            if(tshi = TSZERO) then
                tshi <= TSZERO;
                tshidiag <= TSZERO;
                if(tslow = TSZERO) then
                    tslow <= tszero;
                    tslowdiag <=tszero;
                    tsread <= tsread + '1';
                    if(tsread - "10100" = TSZERO) then
                        running_read <= '0';
                        runend <= '1';
                        running_seq <= '0';
                    end if;
                end if;
            end if;
        else
            tshi <= TSZERO;
            tslow <= TSZERO;
            tshidiag <= TSZERO;
            tslow <= TSZERO;
        end if;
    end if;
    end process;

    -- we need to run through addresses for resetteing the memory
    process(i_clk)
    begin
    if rising_edge(i_clk) then
        addrcounterreset <= addrcounterreset + '1';
    end if;
    end process;

    -- Memory for the actual sorting
    -- NOTE: -ISMUTRIG is not the best way to do this.
    --       we need this because the sorter is only designed for
    --       multiple of 3 inputs but we have 2 for Scifi
    genmem : for i in NSORTERINPUTS-IS_SCIFI-1 downto 0 generate

        hsmem : altera_mf.altera_mf_components.altsyncram
        GENERIC MAP (
            address_aclr_b => "NONE",
            address_reg_b => "CLOCK1",
            clock_enable_input_a => "BYPASS",
            clock_enable_input_b => "BYPASS",
            clock_enable_output_b => "BYPASS",
            intended_device_family => "Arria V",
            lpm_type => "altsyncram",
            numwords_a => 2**HITSORTERADDRSIZE,
            numwords_b => 2**HITSORTERADDRSIZE,
            operation_mode => "DUAL_PORT",
            outdata_aclr_b => "NONE",
            outdata_reg_b => "CLOCK1",
            power_up_uninitialized => "FALSE",
            widthad_a => HITSORTERADDRSIZE,
            widthad_b => HITSORTERADDRSIZE,
            width_a => HIT_WITHOUT_TS_SIZE,
            width_b => HIT_WITHOUT_TS_SIZE,
            width_byteena_a => 1
        )
        PORT MAP (
            address_a => waddr(i),
            address_b => raddr(i),
            clock0 => i_clk,
            clock1 => i_clk,
            data_a => tomem(i),
            wren_a => memwren(i),
            q_b => frommem(i)
        );

        -- In order to have enough ports also for clearing, we divide the memories for the counters
        -- into NMEMS memories, one address holds one TS
        gencmem : for k in NMEMS-1 downto 0 generate

            cmem : altera_mf.altera_mf_components.altsyncram
            GENERIC MAP (
                address_aclr_b => "NONE",
                address_reg_b => "CLOCK0",
                clock_enable_input_a => "BYPASS",
                clock_enable_input_b => "BYPASS",
                clock_enable_output_b => "BYPASS",
                intended_device_family => "Arria V",
                lpm_type => "altsyncram",
                numwords_a => 2**COUNTERMEMADDRSIZE,
                numwords_b => 2**COUNTERMEMADDRSIZE,
                operation_mode => "DUAL_PORT",
                outdata_aclr_b => "NONE",
                outdata_reg_b => "UNREGISTERED",
                power_up_uninitialized => "FALSE",
                read_during_write_mode_mixed_ports => "OLD_DATA",
                widthad_a => COUNTERMEMADDRSIZE,
                widthad_b => COUNTERMEMADDRSIZE,
                width_a => COUNTERMEMDATASIZE,
                width_b => COUNTERMEMDATASIZE,
                width_byteena_a => 1
            )
            PORT MAP (
                address_a => cmemwriteaddr(i)(k),
                address_b => cmemreadaddr(i)(k),
                clock0 => i_clk,
                data_a => tocmem(i)(k),
                wren_a => cmemwren(i)(k),
                q_b => fromcmem(i)(k)
            );

            -- countermemory mux:
            -- - write 0 to countermemory during reset
            --   (addrcounterreset is cycled through all addresses
            --   and reset should be held for countermemory.DEPTH cycles)
            -- - write 0 when reading (k == tsread(COUNTERMEMSELRANGE))
            -- - normal mode
            tocmem(i)(k) <=
                (others => '0') when ( i_reset_n /= '1' ) else
                (others => '0') when ( k = tsread(COUNTERMEMSELRANGE) ) else
                tocmem_hitwriter(i)(k);
            cmemreadaddr(i)(k) <=
                cmemreadaddr_hitreader when ( k = tsread(COUNTERMEMSELRANGE) ) else
                cmemreadaddr_hitwriter(i)(k);
            cmemwriteaddr(i)(k) <=
                addrcounterreset when ( i_reset_n /= '1' ) else
                cmemreadaddr_hitreader when ( k = tsread(COUNTERMEMSELRANGE) ) else
                cmemwriteaddr_hitwriter(i)(k);
            cmemwren(i)(k) <=
                '1' when ( i_reset_n /= '1' ) else
                '1' when ( k = tsread(COUNTERMEMSELRANGE) ) else
                cmemwren_hitwriter(i)(k);
        end generate;

        fromcmem_hitreader(i) <= fromcmem(i)(conv_integer(tsreadmemdelay(COUNTERMEMSELRANGE)));

        -- Write side: Put hits into memory at the right place and count them
        -- TODO: make a common rec type
        g_MUTRIG_WRITE : if ISMUTRIG = 1 generate
            process(i_reset_n, i_clk)
                variable counterfrommem : doublecounter_t := (others => '0');
            begin
            if (i_reset_n = '0') then
                memwren(i) <= '0';
                waddr(i) <= (others => '0');
                noutoftime(i) <= (others => '0');
                nintime(i) <= (others => '0');
                noverflow(i) <= (others => '0');
                nprewindow(i) <= (others => '0');
                npastwindow(i) <= (others => '0');
                noutdiag(i) <= (others => '0');
                cmemwren_hitwriter(i) <= (others => '0');
                dcountertemp(i) <= (others => '0');
                dcountertemp2(i) <= (others => '0');
                cmemreadaddr_hitwriter(i) <= (others => (others => '0'));
                cmemwriteaddr_hitwriter(i) <= (others => (others => '0'));

                hit_last1(i) <= t_hit_presort_div_zero;
                hit_last2(i) <= t_hit_presort_div_zero;
                hit_last3(i) <= t_hit_presort_div_zero;

                sametsnext(i) <= '0';
                sametsafternext(i) <= '0';

                for k in NMEMS-1 downto 0 loop
                    tocmem_hitwriter(i)(k) <= (others => '0');
                end loop;

            elsif rising_edge(i_clk) then

                memwren(i) <= '0';

                tshit(i) <= hit_last1(i).T_CC_div(TSRANGE);
                hit_last1(i) <= i_hit(i);
                hit_last2(i) <= hit_last1(i);
                hit_last3(i) <= hit_last2(i);
                if (IS_SCIFI = 1) then
                    tomem(i) <= presort_div_to_vector_no_ts(hit_last2(i));
                elsif(IS_TILE = 1) then
                    tomem(i) <= presort_div_to_vector_tile(hit_last2(i));
                end if;

                for k in NMEMS-1 downto 0 loop
                    cmemreadaddr_hitwriter(i)(k) <= i_hit(i).T_CC_div(COUNTERMEMADDRRANGE);
                    cmemwriteaddr_hitwriter(i)(k) <= hit_last2(i).T_CC_div(COUNTERMEMADDRRANGE);
                end loop;
                counterfrommem := fromcmem(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE)));
                s_counterfrommem(i) <= fromcmem(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE)));

                for k in NMEMS-1 downto 0 loop
                    cmemwren_hitwriter(i)(k) <= '0';
                end loop;

                -- Reading from the memory, incrementing the counter and storing it again takes three
                -- cycles, so we cannot rely on what was written to the memory for incrementing and have to deal
                -- with this out-of-memory
                -- TODO: Should this be hit last 2?
                if(hit_last1(i).valid = '1' and hit_last1(i).T_CC_div = hit_last2(i).T_CC_div) then
                    sametsnext(i) <= '1';
                    sametsafternext(i) <= '0';
                elsif(hit_last3(i).valid = '1' and hit_last1(i).T_CC_div = hit_last3(i).T_CC_div) then
                    sametsnext(i) <= '0';
                    sametsafternext(i) <= '1';
                else
                    sametsnext(i) <= '0';
                    sametsafternext(i) <= '0';
                end if;

                dcountertemp2(i) <= dcountertemp(i);

                if((i_running = '1' or runshutdown = '1') and hit_last2(i).valid ='1') then -- Hit coming in during run
                    if(((tshi > tslow) and (tshit(i) >= tslow and tshit(i) < tshi)) or
                        ((tslow > tshi) and (tshit(i) >= tslow or tshit(i) < tshi))) then
                        -- Hit TS in the range we can accept
                        if(sametsnext(i) = '0' and sametsafternext(i) = '0') then -- not the same memory location as the last hit
                            waddr(i) <= tshit(i) & counterfrommem(3 downto 0);
                            if(counterfrommem(3 downto 0) /= "1111") then -- no overflow yet
                                memwren(i) <= '1';
                                nintime(i) <= nintime(i) + '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '0' & counterfrommem(3 downto 0) + '1';
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '0' & counterfrommem(3 downto 0) + '1';
                            else -- overflow, mark this
                                noverflow(i) <= noverflow(i) + '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '1' & "1111";
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '1' & "1111";
                            end if;
                        elsif(sametsnext(i) = '1') then -- same memory location in last cycle
                            waddr(i) <= tshit(i) & dcountertemp(i)(3 downto 0);
                            if(dcountertemp(i)(3 downto 0) /= "1111") then -- no overflow yet
                                nintime(i) <= nintime(i) + '1';
                                memwren(i) <= '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '0' & dcountertemp(i)(3 downto 0) + '1';
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '0' & dcountertemp(i)(3 downto 0) + '1';
                            else -- overflow, mark this
                                noverflow(i) <= noverflow(i) + '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '1' & "1111";
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '1' & "1111";
                            end if;
                        else -- same memory location two cycles ago
                            waddr(i) <= tshit(i) & dcountertemp2(i)(3 downto 0);
                            if(dcountertemp2(i)(3 downto 0) /= "1111") then -- no overflow yet
                                nintime(i) <= nintime(i) + '1';
                                memwren(i) <= '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '0' & dcountertemp2(i)(3 downto 0) + '1';
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '0' & dcountertemp2(i)(3 downto 0) + '1';
                            else -- overflow, mark this
                                noverflow(i) <= noverflow(i) + '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '1' & "1111";
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2(i).T_CC_div(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '1' & "1111";
                            end if;
                        end if; -- same/ not same memory location
                    else -- in/out of time
                        -- we have an out of time hit: some diagnosis
                        noutoftime(i) <= noutoftime(i) + '1';
                        if(tshi< tshidiag) then --tshi(diag) no wrapping
                            if((tshi < tshit(i)) and (tshit(i) < (tshidiag))) then
                                npastwindow(i) <= npastwindow(i) + '1';
                            else
                                noutdiag(i) <= noutdiag(i) + '1';
                            end if;
                        elsif(tslowdiag < tslow) then --tslow(diag) no wrapping
                            if(((tslowdiag) < tshit(i)) and (tshit(i) < tslow)) then
                                nprewindow(i) <= nprewindow(i) + '1';
                            else
                                noutdiag(i) <= noutdiag(i) + '1';
                            end if;
                        elsif(tshi > tshidiag) then
                            if((tshi < tshit(i)) or (tshit(i) < (tshidiag))) then
                                npastwindow(i) <= npastwindow(i) + '1';
                            else
                                noutdiag(i) <= noutdiag(i) + '1';
                            end if;
                        elsif(tslowdiag > tslow) then
                            if((tslowdiag < tshit(i)) or (tshit(i) < (tslow))) then
                                nprewindow(i) <= nprewindow(i) + '1';
                            else
                                noutdiag(i) <= noutdiag(i) + '1';
                            end if;
                        else -- tshit is out of diag window
                            noutdiag(i) <= noutdiag(i) + '1'; --check: noutdiag + npastwindow + nprewindow = noutoftime
                        end if;
                    end if;
                end if; -- hit coming in during run;
            end if; -- clk event
            end process;
        end generate;

        g_MUPIX_WRITE : if ISMUTRIG = 0 generate
            process(i_reset_n, i_clk)
                variable counterfrommem : doublecounter_t := (others => '0');
            begin
            if ( i_reset_n = '0' ) then
                memwren(i) <= '0';
                waddr(i) <= (others => '0');
                noutoftime(i) <= (others => '0');
                nintime(i) <= (others => '0');
                noverflow(i) <= (others => '0');
                nprewindow(i) <= (others => '0');
                npastwindow(i) <= (others => '0');
                noutdiag(i) <= (others => '0');
                cmemwren_hitwriter(i) <= (others => '0');
                dcountertemp(i) <= (others => '0');
                dcountertemp2(i) <= (others => '0');
                cmemreadaddr_hitwriter(i) <= (others => (others => '0'));
                cmemwriteaddr_hitwriter(i) <= (others => (others => '0'));

                hit_last1_mupix(i) <= (others => '0');
                hit_last2_mupix(i) <= (others => '0');
                hit_last3_mupix(i) <= (others => '0');

                sametsnext(i) <= '0';
                sametsafternext(i) <= '0';

                for k in NMEMS-1 downto 0 loop
                    tocmem_hitwriter(i)(k) <= (others => '0');
                end loop;

            elsif rising_edge(i_clk) then

                nprewindow(i) <= "10011001" & i_ccdiff(i);

                memwren(i) <= '0';

                tshit(i) <= hit_last1_mupix(i)(TSRANGE);

                hit_last1_mupix(i) <= i_hit_mupix(i);
                hit_last2_mupix(i) <= hit_last1_mupix(i);
                hit_last3_mupix(i) <= hit_last2_mupix(i);

                chipID_last1_mupix(i) <= i_chipID(i);
                chipID_last2_mupix(i) <= chipID_last1_mupix(i);

                hit_ena_last1(i) <= i_hit_ena_mupix(i);
                hit_ena_last2(i) <= hit_ena_last1(i);
                hit_ena_last3(i) <= hit_ena_last2(i);

                if ( g_IS_OUTER = 0 ) then
                    tomem(i) <= hit_last2_mupix(i)(NOTSRANGE);
                else
                    tomem(i) <= chipID_last2_mupix(i) & hit_last2_mupix(i)(NOTSRANGE);
                end if;

                for k in NMEMS-1 downto 0 loop
                    cmemreadaddr_hitwriter(i)(k) <= i_hit_mupix(i)(COUNTERMEMADDRRANGE);
                    cmemwriteaddr_hitwriter(i)(k) <= hit_last2_mupix(i)(COUNTERMEMADDRRANGE);
                end loop;
                counterfrommem := fromcmem(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE)));

                for k in NMEMS-1 downto 0 loop
                    cmemwren_hitwriter(i)(k) <= '0';
                end loop;

                -- Reading from the memory, incrementing the counter and storing it again takes three
                -- cycles, so we cannot rely on what was written to the memory for incrementing and have to deal
                -- with this out-of-memory
                if(hit_ena_last2(i) = '1' and hit_last1_mupix(i)(TSRANGE) = hit_last2_mupix(i)(TSRANGE)) then
                    sametsnext(i) <= '1';
                    sametsafternext(i) <= '0';
                elsif(hit_ena_last3(i) = '1' and hit_last1_mupix(i)(TSRANGE) = hit_last3_mupix(i)(TSRANGE)) then
                    sametsnext(i) <= '0';
                    sametsafternext(i) <= '1';
                else
                    sametsnext(i) <= '0';
                    sametsafternext(i) <= '0';
                end if;

                dcountertemp2(i) <= dcountertemp(i);

                if((i_running = '1' or runshutdown = '1') and hit_ena_last2(i) ='1') then -- Hit coming in during run
                    if(((tshi > tslow) and (tshit(i) >= tslow and tshit(i) < tshi)) or
                        ((tslow > tshi) and (tshit(i) >= tslow or tshit(i) < tshi))) then
                        -- Hit TS in the range we can accept
                        if(sametsnext(i) = '0' and sametsafternext(i) = '0') then -- not the same memory location as the last hit
                            waddr(i) <= tshit(i) & counterfrommem(3 downto 0);
                            if(counterfrommem(3 downto 0) /= "1111") then -- no overflow yet
                                memwren(i) <= '1';
                                nintime(i) <= nintime(i) + '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '0' & counterfrommem(3 downto 0) + '1';
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '0' & counterfrommem(3 downto 0) + '1';
                            else -- overflow, mark this
                                noverflow(i) <= noverflow(i) + '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '1' & "1111";
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '1' & "1111";
                            end if;
                        elsif(sametsnext(i) = '1') then -- same memory location in last cycle
                            waddr(i) <= tshit(i) & dcountertemp(i)(3 downto 0);
                            if(dcountertemp(i)(3 downto 0) /= "1111") then -- no overflow yet
                                nintime(i) <= nintime(i) + '1';
                                memwren(i) <= '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '0' & dcountertemp(i)(3 downto 0) + '1';
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '0' & dcountertemp(i)(3 downto 0) + '1';
                            else -- overflow, mark this
                                noverflow(i) <= noverflow(i) + '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '1' & "1111";
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '1' & "1111";
                            end if;
                        else -- same memory location two cycles ago
                            waddr(i) <= tshit(i) & dcountertemp2(i)(3 downto 0);
                            if(dcountertemp2(i)(3 downto 0) /= "1111") then -- no overflow yet
                                nintime(i) <= nintime(i) + '1';
                                memwren(i) <= '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '0' & dcountertemp2(i)(3 downto 0) + '1';
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '0' & dcountertemp2(i)(3 downto 0) + '1';
                            else -- overflow, mark this
                                noverflow(i) <= noverflow(i) + '1';
                                for k in NMEMS-1 downto 0 loop
                                    tocmem_hitwriter(i)(k) <= '1' & "1111";
                                end loop;
                                cmemwren_hitwriter(i)(conv_integer(hit_last2_mupix(i)(COUNTERMEMSELRANGE))) <= '1';
                                dcountertemp(i) <= '1' & "1111";
                            end if;
                        end if; -- same/ not same memory location
                    else -- in/out of time
                        -- we have an out of time hit: some diagnosis
                        noutoftime(i) <= noutoftime(i) + '1';
                        noutdiag(i) <= noutdiag(i) + '1';
                        -- TODO implement diag for PIXEL
                    end if;
                end if; -- hit coming in during run;
            end if; -- clk event
            end process;
        end generate;

    end generate;

    reset <= not i_reset_n;

    scfifo_component : altera_mf.altera_mf_components.scfifo
    GENERIC MAP (
        add_ram_output_register => "ON",
        almost_full_value => 120,
        intended_device_family => "Arria V",
        lpm_numwords => 128,
        lpm_showahead => "OFF",
        lpm_type => "scfifo",
        lpm_width => SORTERFIFORANGE'left + 1,
        lpm_widthu => 7,
        overflow_checking => "ON",
        underflow_checking => "ON",
        use_eab => "ON"
    )
    PORT MAP (
        aclr => '0',
        clock => i_clk,
        data => tofifo_counters,
        rdreq => read_counterfifo,
        sclr => reset,
        wrreq => write_counterfifo,
        almost_full => counterfifo_almostfull,
        empty => counterfifo_empty,
        q => fromfifo_counters
    );



    -- collect data for transmission to read side
    -- read one line in the countermemories per cycle, condense counters and push to fifo if nonempty
    process(i_clk, i_reset_n)
        variable mem_ne : std_logic;
        variable mem_ov : std_logic;
        variable mem_nonemptycount : std_logic_vector(3 downto 0);
        variable mem_nfilled : integer;

        variable countersum_temp : integer;

        variable creditchange : integer range -2048 to 2047;
    begin
    if ( i_reset_n = '0' ) then
        cmemreadaddr_hitreader <= (others => '0');
        write_counterfifo <= '0';
        block_nonempty_accumulate <= '0';
        block_empty_del2 <= '0';

        stopwrite <= '0';
        stopwrite_del1 <= '0';
        stopwrite_del2 <= '0';

        blockchange <= '0';
        blockchange_del1 <= '0';
        blockchange_del2 <= '0';

        credits <= 127;
        credittemp <= 127;
        for i in NSORTERINPUTS/3-1 downto 0 loop
            hitcounter_sum_m3_mem(i) <= 0;
        end loop;
        hitcounter_sum_mem <= 0;
        hitcounter_sum <= 0;

    elsif rising_edge(i_clk) then
        write_counterfifo <= '0';

        mem_countinputs_m1 <= (others => '0');
        mem_countinputs_m2 <= (others => '0');


        if(running_read = '1')then
            cmemreadaddr_hitreader <= tsread(COUNTERMEMADDRRANGE)+'1';

            -- or nonempty, read counters
            mem_ov := '0';
            for i in NSORTERINPUTS-1 downto 0 loop
                mem_neinputs(i) <= or_reduce(fromcmem_hitreader(i)(3 downto 0));
                mem_countinputs(i) <= fromcmem_hitreader(i)(3 downto 0);
                mem_ov := mem_ov or fromcmem_hitreader(i)(4);
            end loop;

            mem_overflow <= mem_ov;


            mem_nonemptycount := (others => '0');
            mem_ne := '0';

            if(running_read_last2 = '1') then
                for i in NSORTERINPUTS-1 downto 0 loop
                    mem_ne := mem_ne or mem_neinputs(i);
                    mem_nonemptycount := mem_nonemptycount + mem_neinputs(i);
                end loop;
                mem_nnonempty <= mem_nonemptycount;
            end if;

            blockchange <= '0';
            if((or_reduce(tsread(TSNONBLOCKRANGE))) = '0' and running_read_last = '1') then -- no block change at startup
                blockchange <= '1';
                if(counterfifo_almostfull = '1' or credits <= 0) then
                    stopwrite <= '1';
                else
                    stopwrite <= '0';
                end if;

            end if;

            block_empty_del2 <= '0';
            if(blockchange_del1 = '1') then
                block_nonempty_accumulate <= mem_ne;
                if(block_nonempty_accumulate = '0')then
                    block_empty_del2 <= '1';
                end if;
            else
                block_nonempty_accumulate <= mem_ne or block_nonempty_accumulate;
            end if;


            -- multiplexing of counters -- here we pack groups of three towards the LSB
            -- Even
            mem_neinputs2 <= (others => '0');
            for i in NSORTERINPUTS/3-1 downto 0 loop
                hitcounter_sum_m3_mem(i) <= conv_integer(mem_countinputs(3*i))
                                          + conv_integer(mem_countinputs(3*i+1))
                                          + conv_integer(mem_countinputs(3*i+2));
                if(mem_neinputs(i*3) = '1')then
                    mem_countinputs_m1(H*2*3*i + H-1 downto H*2*3*i) <= mem_countinputs(3*i);
                    mem_countinputs_m1(H*2*3*i + 2*H-1 downto H*2*3*i + H) <= conv_std_logic_vector(3*i+0, H);
                    mem_neinputs2(i*3) <= '1';
                    if(mem_neinputs(i*3+1) = '1')then
                        mem_countinputs_m1(H*2*3*i + 3*H-1 downto H*2*3*i + 2*H) <= mem_countinputs(3*i+1);
                        mem_countinputs_m1(H*2*3*i + 4*H-1 downto H*2*3*i + 3*H) <= conv_std_logic_vector(3*i+1, H);
                        mem_neinputs2(i*3+1) <= '1';
                        if(mem_neinputs(i*3+2) = '1')then
                            mem_countinputs_m1(H*2*3*i + 5*H-1 downto H*2*3*i + 4*H) <= mem_countinputs(3*i+2);
                            mem_countinputs_m1(H*2*3*i + 6*H-1 downto H*2*3*i + 5*H) <= conv_std_logic_vector(3*i+2, H);
                            mem_neinputs2(i*3+2) <= '1';
                        end if;
                    elsif(mem_neinputs(i*3+2) = '1')then
                        mem_countinputs_m1(H*2*3*i + 3*H-1 downto H*2*3*i + 2*H) <= mem_countinputs(3*i+2);
                        mem_countinputs_m1(H*2*3*i + 4*H-1 downto H*2*3*i + 3*H) <= conv_std_logic_vector(3*i+2, H);
                        mem_neinputs2(i*3+1) <= '1';
                    end if;

                elsif(mem_neinputs(i*3+1) = '1')then
                    mem_countinputs_m1(H*2*3*i + H-1 downto H*2*3*i) <= mem_countinputs(3*i+1);
                    mem_countinputs_m1(H*2*3*i + 2*H-1 downto H*2*3*i + H) <= conv_std_logic_vector(3*i+1, H);
                    mem_neinputs2(i*3) <= '1';
                    if(mem_neinputs(i*3+2) = '1')then
                        mem_countinputs_m1(H*2*3*i + 3*H-1 downto H*2*3*i + 2*H) <= mem_countinputs(3*i+2);
                        mem_countinputs_m1(H*2*3*i + 4*H-1 downto H*2*3*i + 3*H) <= conv_std_logic_vector(3*i+2, H);
                        mem_neinputs2(i*3+1) <= '1';
                    end if;
                elsif(mem_neinputs(i*3+2) = '1')then
                    mem_countinputs_m1(H*2*3*i + H-1 downto H*2*3*i) <= mem_countinputs(3*i+2);
                    mem_countinputs_m1(H*2*3*i + 2*H-1 downto H*2*3*i + H) <= conv_std_logic_vector(3*i+2, H);
                    mem_neinputs2(i*3) <= '1';
                end if;
            end loop;

            mem_overflow_del1 <= mem_overflow;
            stopwrite_del1 <= stopwrite;
            blockchange_del1 <= blockchange;

            -- multiplexing of counters, step 2
            hashits <= or_reduce(mem_neinputs2);
            mem_nfilled := 0;
            countersum_temp := 0;
            mem_countinputs_m2 <= (others => '0');

            for i in  0 to NSORTERINPUTS/3-1 loop
                countersum_temp := countersum_temp + hitcounter_sum_m3_mem(i);
                mem_countinputs_m2(2*H*mem_nfilled + 2*3*H-1 downto 2*H*mem_nfilled)
                    <= mem_countinputs_m1(2*3*i*H + 2*3*H-1 downto 2*3*i*H);
                if(mem_neinputs2(i*3+2 downto i*3) = "001") then
                    mem_nfilled := mem_nfilled + 1;
                elsif(mem_neinputs2(i*3+2 downto i*3) = "011") then
                    mem_nfilled := mem_nfilled + 2;
                elsif(mem_neinputs2(i*3+2 downto i*3) = "111") then
                    mem_nfilled := mem_nfilled + 3;
                end if;
            end loop;
            hitcounter_sum_mem <= countersum_temp;


            mem_overflow_del2 <= mem_overflow_del1;
            stopwrite_del2 <= stopwrite_del1;
            blockchange_del2 <= blockchange_del1;

            -- one more delay cycle for stopwrite, as it supresses the NEXT block
            stopwrite_del3 <= stopwrite_del2;

            -- we substract "100" because after read the pipeline to sum up the counters is 4 cycles long
            tofifo_counters <= tsread - "100" & hashits & mem_overflow_del2 & mem_countinputs_m2;
            creditchange := 1;


            if(stopwrite_del3 = '0' and (hashits = '1' or block_empty_del2 = '1')) then
                write_counterfifo <= '1';
                if(hitcounter_sum_mem < 48) then -- limit number of hits per ts
                    creditchange := creditchange - hitcounter_sum_mem;
                else
                    tofifo_counters(HASMEMBIT) <= '1';
                    tofifo_counters(MEMOVERFLOWBIT) <= '1';
                    tofifo_counters(MEMCOUNTERRANGE) <= counter2inputszero;
                    creditchange := creditchange - 1;
                end if;

                if(blockchange_del2 = '1') then
                    creditchange := creditchange - 1;
                end if;

            elsif(stopwrite_del3 ='1' and blockchange_del2 = '1' and block_empty_del2 = '1') then -- we were overfull but just got an empty block
                write_counterfifo <= '1';
                creditchange := creditchange - 1;
            elsif(stopwrite_del3 ='1' and blockchange_del2 = '1') then -- we were overfull and have suppressed hits
                write_counterfifo <= '1';
                tofifo_counters <= tsread - "100" & "0" & "1" & counter2inputszero;
                creditchange := creditchange - 1;
            end if;
            credittemp <= credittemp + creditchange;
            creditchange_reg <= creditchange;
            if(credittemp + creditchange > 127) then
                credits <= 127;
                credittemp <= 127;
            elsif ( credittemp + creditchange < -128 ) then
                credits <= -128;
                credittemp <= -128;
            else
                credits <= credittemp;
            end if;
        end if;
    end if;
    end process;



    -- Here we generate the sequence of read commands etc.
    seq : entity work.sequencer_NG
    generic map (
        HITSORTERBINBITS => HITSORTERBINBITS,
        NSORTERINPUTS => NSORTERINPUTS,
        TIMESTAMPSIZE => TIMESTAMPSIZE,
        ISMUTRIG => ISMUTRIG
    )
    port map (
        i_runend            => runend,
        i_fifo_data         => fromfifo_counters,
        i_fifo_empty        => counterfifo_empty,
        o_fifo_read         => read_counterfifo,
        o_command           => readcommand,
        o_command_enable    => readcommand_ena,
        o_overflow          => outoverflow,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );

    -- The ouput command has the TS in the LSBs, followed by four bits hit address
    -- four bits channel/chip ID and the MSB inciating command (1) or hit (0)

    -- And the reading (use writeclk for the moment, FIFO comes after)
    process(i_clk, i_reset_n)
        variable SorterID, MUXID: std_logic_vector(5 downto 0);
    begin
    if ( i_reset_n = '0' ) then
        data_out                <= (others => '0');
        out_ena                 <= '0';
        out_type                <= (others => '0');
        readcommand_ena_last1   <= '0';
        readcommand_ena_last2   <= '0';
        readcommand_ena_last3   <= '0';
        readcommand_ena_last4   <= '0';
        tscounter               <= (others => '0');
        sendtscounter           <= (others => '0');
        nout                    <= (others => '0');
        terminate_output        <= '0';
        terminated_output       <= '0';
        header_counter          <= (others => '0');
        subheader_counter       <= (others => '0');
        debug_hitcounter        <= (others => '0');
    elsif rising_edge(i_clk) then
        out_ena <= '0';
        out_is_hit <= '0';
        for i in NSORTERINPUTS-1 downto 0 loop
            raddr(i) <= readcommand(TSRANGE) --MSBs: Timestamp
                      & readcommand(COMMANDBITS-6 downto TIMESTAMPSIZE); -- LSBs: hit address in TS
        end loop;

        readcommand_last1 <= readcommand;
        readcommand_last2 <= readcommand_last1;
        readcommand_last3 <= readcommand_last2;
        readcommand_last4 <= readcommand_last3;

        readcommand_ena_last1 <= readcommand_ena;
        readcommand_ena_last2 <= readcommand_ena_last1;
        readcommand_ena_last3 <= readcommand_ena_last2;
        readcommand_ena_last4 <= readcommand_ena_last3;

        overflow_last1 <= outoverflow;
        overflow_last2 <= overflow_last1;
        overflow_last3 <= overflow_last2;
        overflow_last4 <= overflow_last3;

        out_ena <= readcommand_ena_last4;

        if(conv_integer(readcommand_last3(COMMANDBITS-2 downto TIMESTAMPSIZE+4)) < NSORTERINPUTS) then
            memmultiplex <= frommem(conv_integer(readcommand_last3(COMMANDBITS-2 downto TIMESTAMPSIZE+4))); -- 18 downto 15
        end if;

        if(running_seq = '1') then
            sendtscounter <= sendtscounter + '1';
        end if;

        case readcommand_last4(COMMANDBITS-1 downto COMMANDBITS-4) is
        when COMMAND_HEADER1 =>
            data_out <= tscounter(47-11 downto 16-11);
            out_type <= MERGER_FIFO_PAKET_START_MARKER;
        when COMMAND_HEADER2 =>
            data_out <= tscounter(15-11 downto 0) & "000" & x"00" & header_counter;
            out_type <= "0000";
            if(readcommand_ena_last4 = '1') then
                header_counter <= header_counter + '1';
                tscounter <= tscounter + '1';
            end if;
        when COMMAND_DEBUGHEADER1 =>
            data_out <= "0" & subheader_counter(14 downto 0) & debug_hitcounter;
            out_type <= "0000";
            subheader_counter <= (others => '0');
            debug_hitcounter <= (others => '0');
        when COMMAND_DEBUGHEADER2 =>
            data_out <= "0" & sendtscounter(30 downto 0);
            out_type <= "0000";
        when COMMAND_SUBHEADER =>
            if ( ISMUTRIG = 1 ) then -- mutrig has 13 bit TS we read out here bit 11 downto 4
                data_out <= readcommand_last4(11 downto 4) & overflow_last4 & work.util.K23_7;
            else -- mupix has 11 bit TS we read out here bit 10 downto 4
                data_out <= "0" & readcommand_last4(10 downto 4) & overflow_last4 & work.util.K23_7;
            end if;
            out_type <= MERGER_FIFO_SUB_MARKER;
            if(readcommand_ena_last4 = '1') then
                subheader_counter <= subheader_counter + '1';
            end if;
        when COMMAND_FOOTER =>
            data_out <= header_counter & overflow_last4;
            out_type <= MERGER_FIFO_PAKET_END_MARKER;
            if(runshutdown = '1')then
                terminate_output <= '1';
            end if;
        when others =>
            out_type <= "0000";
            if(ISMUTRIG = 0)then
                if ( g_IS_OUTER = 0 ) then
                    -- ts(3:0) & chipID(5:0, the upper 2 bits are 0 here since we have max. 12 links for the vertex) & row(7:0) & col(7:0) & tot(4:0) & '0'
                    data_out <= readcommand_last4(3 downto 0) & "00" & readcommand_last4(COMMANDINPUTSELRANGE) & memmultiplex & "0";
                else
                    -- readcommand_last4(COMMANDINPUTSELRANGE) has 4 bits
                    -- we MUX into the sorter
                    -- CHIPID (SorterID): 0 1 2    (0) 3 4 5    (1) 6 7 8    (2) 9 10 11  (3) 12 13 14 (4)  15 16 17 (5)
                    --                    18 19 20 (6) 21 22 23 (7) 24 25 26 (8) 27 28 29 (9) 30 31 32 (10) 33 34 35 (11)
                    -- So the mapping back is: SorterID x 3 + MUXID
                    SorterID := "00" & readcommand_last4(COMMANDINPUTSELRANGE);
                    MUXID := "0000" & memmultiplex(HIT_WITHOUT_TS_SIZE - 1 downto HIT_WITHOUT_TS_SIZE - 2);
                    data_out <= readcommand_last4(3 downto 0)
                        & std_logic_vector(ieee.numeric_std.resize(ieee.numeric_std.unsigned(SorterID) * 3 + ieee.numeric_std.unsigned(MUXID), 6))
                        & memmultiplex(HIT_WITHOUT_TS_SIZE - 3 downto 0) & "0";
                end if;
                if ( g_USE_TRIGGER = 1 and readcommand_last4(COMMANDBITS-2 downto TIMESTAMPSIZE+4) = "1011" ) then
                    -- upper two bits are from trigger MUX
                    -- ts(3:0) & chipID(5:0) & "00" & trigger(18:0) & '0'
                    if ( memmultiplex(20 downto 19) = "00" ) then
                        data_out <= readcommand_last4(3 downto 0) & "001011" & "00" & memmultiplex(18 downto 0) & "0"; -- chipID 11
                    elsif ( memmultiplex(20 downto 19) = "01" ) then
                        data_out <= readcommand_last4(3 downto 0) & "001100" & "00" & memmultiplex(18 downto 0) & "0"; -- chipID 12
                    elsif ( memmultiplex(20 downto 19) = "10" ) then
                        data_out <= readcommand_last4(3 downto 0) & "001101" & "00" & memmultiplex(18 downto 0) & "0"; -- chipID 13
                    elsif ( memmultiplex(20 downto 19) = "11" ) then
                        data_out <= readcommand_last4(3 downto 0) & "001110" & "00" & memmultiplex(18 downto 0) & "0"; -- chipID 14
                    end if;
                end if;
            end if;
            -- NOTE: this is scifi here
            if(IS_SCIFI = 1)then -- ts(3:0) & ts(12:11) & asic(2:0) & channel(4:0) & CC 1.6ns (2:0) & fine (4:0) & E-Flag & E-T (10:0) = zero at the moment
                -- NOTE: this is for debugging now to check if readcommand_last4(COMMANDINPUTSELRANGE) = asic(3:0)
                -- TODO: the memmultiplex has 29 bits and we can use the readcommand_last4(COMMANDINPUTSELRANGE) for getting the ASIC
                -- TODO: also the E-flag is missing at the moment
                -- vec(17 downto 16) := rec.asic(1 downto 0);
                -- vec(15 downto 11) := rec.channel;
                -- vec(10 downto  9) := rec.T_CC_upper_div;
                -- vec( 8 downto  6) := rec.T_CC_rem;
                -- vec( 5 downto  1) := rec.T_Fine;
                -- vec(0)            := rec.E_flag
                if ( IS_SORTER_TWO = 1 ) then                   -- memmultiplex(10 downto 9) = bits 12:11 of TCC 8ns for debugging not used later
                    data_out <= readcommand_last4(3 downto 0) & "0" & memmultiplex(10 downto 9) & "1" & memmultiplex(17 downto 11) & memmultiplex(8 downto 0) & x"00";
                else
                    data_out <= readcommand_last4(3 downto 0) & "0" & memmultiplex(10 downto 9) & "0" & memmultiplex(17 downto 11) & memmultiplex(8 downto 0) & x"00";
                end if;
            end if;
            if(IS_TILE = 1)then
                data_out <= readcommand_last4(3 downto 0) & "00" & memmultiplex(25 downto 0);
            end if;
            if(readcommand_ena_last4 = '1') then
                out_is_hit <= '1';
                nout <= nout + '1';
                debug_hitcounter <= debug_hitcounter + '1';
            end if;
        end case;

        if(terminate_output = '1') then
            data_out <= (others => '0');
            out_type <= MERGER_FIFO_RUN_END_MARKER;
            out_ena <= '1';
            terminate_output <= '0';
            terminated_output <= '1';
        end if;
        if(terminated_output = '1') then
            out_ena <= '0';
        end if;
    end if;
    end process;

    credits32 <= conv_std_logic_vector(credits, 32);

    e_sorter_reg_mapping : entity work.sorter_reg_mapping
    generic map (
        NSORTERINPUTS => NSORTERINPUTS,
        TIMESTAMPSIZE => TIMESTAMPSIZE,
        IS_MUTRIG     => IS_SCIFI=1 or IS_TILE=1
    )
    port map (
        i_reg_addr      => i_reg_addr,
        i_reg_re        => i_reg_re,
        o_reg_rdata     => o_reg_rdata,
        i_reg_we        => i_reg_we,
        i_reg_wdata     => i_reg_wdata,

        i_nintime       => nintime,
        i_noutoftime    => noutoftime,
        i_noverflow     => noverflow,
        i_nout          => nout,

        i_credit        => credits32,
        o_sorter_delay  => delay,

        i_nprewindow    => nprewindow,
        i_npastwindow   => npastwindow,
        i_noutdiag      => noutdiag,
        o_diagwidth     => diagwidth,

        i_reset_n       => i_regs_reset_n,
        i_clk156        => i_clk156--,
    );

end architecture;
