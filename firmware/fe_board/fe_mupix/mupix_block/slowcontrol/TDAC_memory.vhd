----------------------------------------------------------------------------
-- storage for Mupix TDACs
-- M. Mueller, Feb 2022
-----------------------------------------------------------------------------

library ieee;
use ieee.math_real.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.mupix.all;
use work.mudaq.all;

entity tdac_memory is
generic (
    g_CHIPS             : positive := 4;
    g_COLS_PER_PAGE     : integer := 8; -- size of a page measured in double Mupix cols
    g_PAGES             : integer := 16--; -- number of pages (memsize = N_Pages*N_COLS_PER_PAGE* size of a col)
);
port (
    o_tdac_dpf_we       : out   std_logic_vector(g_CHIPS-1 downto 0);
    o_tdac_dpf_wdata    : out   std_logic_vector(3 downto 0);
    i_tdac_dpf_empty    : in    std_logic_vector(g_CHIPS-1 downto 0);

    o_testram_rdata     : out   reg32;
    i_testram_raddr     : in    reg32;
    i_testram_waddr     : in    reg32;
    i_testram_wdata     : in    reg32;

    i_data              : in    std_logic_vector(31 downto 0);
    i_we                : in    std_logic;
    i_chip              : in    integer range 0 to g_CHIPS-1;
    o_n_free_pages      : out   std_logic_vector(31 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture RTL of tdac_memory is

    constant c_PAGE_ADDR_WIDTH  : positive := integer(ceil(log2(real(g_PAGES)))); -- width of number of pages
    constant c_ADDR_WIDTH       : positive := c_PAGE_ADDR_WIDTH + integer(ceil(log2(real(128*g_COLS_PER_PAGE)))); -- size of memory (number of pages * size of page)
    constant c_COL_ADDR_WIDTH   : integer  := integer(ceil(log2(real(g_COLS_PER_PAGE)))); -- width of number of cols in a page
    constant c_COLS_PER_CHIP    : integer  := 128;
    constant c_PAGES_PER_CHIP   : integer  := c_COLS_PER_CHIP/g_COLS_PER_PAGE; -- divide tune dacs of 1 Chip into N_PAGES_PER_CHIP blocks
    constant c_PAGE_SIZE        : integer  := 128 * g_COLS_PER_PAGE;

    type TDAC_page_type is record
        addr        :   std_logic_vector(c_ADDR_WIDTH-c_PAGE_ADDR_WIDTH-c_COL_ADDR_WIDTH-1 downto 0);    -- current read pointer in this page
        page_id     :   integer range 0 to c_PAGES_PER_CHIP-1; -- when used for tune dacs of chip X .. which page of chip X is stored here ?
        bit_in_tdac :   integer range 0 to 6;                  -- read side only: when running around to fill the dpf, which bit of the tdac are we collecting ? (see genwdata)
        col_in_page :   integer range 0 to g_COLS_PER_PAGE-1;  -- read side only: when running around to fill the dpf, which col of this page are we collecting ?
        in_use      :   boolean;                               -- is this page in use right now ?
        full        :   boolean;                               -- is this page full ? (bit is "sticky" .. will only be removed once page is completely empty again)
        chip        :   integer range 0 to g_CHIPS-1;          -- if in use .. a page of which chip is stored here ?
    end record;
    constant TDAC_PAGE_ZERO : TDAC_page_type := (
        addr => (others => '0'),
        in_use => false, full => false,
        others => 0
    );

    type TDAC_page_array_type   is array( natural range <> ) of TDAC_page_type;
    signal TDAC_page_array      : TDAC_page_array_type(g_PAGES-1 downto 0);
    signal TDAC_page            : TDAC_page_type;

    signal next_free_page       : std_logic_vector(c_PAGE_ADDR_WIDTH-1 downto 0);
    signal next_free_page_int   : integer range 0 to g_PAGES-1;
    signal current_write_page   : integer range 0 to g_PAGES-1;

    signal current_page_addr    : std_logic_vector(c_PAGE_ADDR_WIDTH-1 downto 0);
    signal addr_in_current_page : std_logic_vector(c_ADDR_WIDTH-c_PAGE_ADDR_WIDTH-1 downto 0);

    signal ram_we               : std_logic;
    signal ram_wdata            : reg32;
    signal ram_waddr            : std_logic_vector(c_ADDR_WIDTH-1 downto 0);
    signal ram_raddr            : std_logic_vector(c_ADDR_WIDTH-1 downto 0);
    signal ram_rdata            : reg32;

    subtype page_id_type        is integer range 0 to c_PAGES_PER_CHIP-1;
    type page_id_array_type     is array( natural range <>) of page_id_type;

    signal current_write_page_id : page_id_array_type(g_CHIPS-1 downto 0); -- current TDAC page (number between 0 and N_PAGES_PER_CHIP-1) for each mupix chip, read and write side of memory
    signal current_read_page_id : page_id_array_type(g_CHIPS-1 downto 0);

    type read_state_type        is ( searching_match, wait1, reading, S_READ_DONE );
    signal read_state           : read_state_type;

    signal page_cycler          : integer range 0 to g_PAGES-1;
    signal last_page_cycler     : integer range 0 to g_PAGES-1;
    signal cycler_last_full     : boolean;
    signal cycler_last_chip     : integer range 0 to g_CHIPS-1;
    signal cycler_last_ID       : integer range 0 to c_PAGES_PER_CHIP-1;

    signal read_chip            : integer range 0 to g_CHIPS-1;

    signal read_page            : integer range 0 to g_PAGES-1;
    signal read_page_reg2       : integer range 0 to g_PAGES-1;

    signal page_finished        : boolean;
    signal col_finished         : boolean;

    signal n_free_pages         : reg32;
    signal n_free_pages_prev    : reg32;
    signal testram_we           : std_logic;
    signal testram_wdata_prev   : reg32;

begin

    ram_we                  <= i_we;
    ram_waddr               <= current_page_addr & addr_in_current_page;
    ram_wdata               <= i_data;

    process(i_clk, i_reset_n) is
        variable n_free : integer range 0 to g_PAGES;
    begin
    if ( i_reset_n /= '1' ) then
        addr_in_current_page    <= (others => '0');
        current_page_addr       <= (others => '0');
        current_write_page      <= 0;
        next_free_page          <= (others => '0');
        TDAC_page_array         <= (others => TDAC_PAGE_ZERO);
        TDAC_page               <= TDAC_PAGE_ZERO;
        current_read_page_id    <= (others => 0);
        current_write_page_id   <= (others => 0);
        read_state              <= searching_match;
        page_cycler             <= 0;
        last_page_cycler        <= g_PAGES-1;
        cycler_last_full        <= false;
        cycler_last_chip        <= 0;
        o_tdac_dpf_we           <= (others => '0');
        page_finished           <= false;
        col_finished            <= false;

    elsif rising_edge(i_clk) then

        testram_wdata_prev <= i_testram_wdata;

        testram_we <= '0';
        if ( i_testram_wdata /= testram_wdata_prev ) then
            testram_we <= '1';
        end if;

        ---------------------------------------------
        -- write process
        ---------------------------------------------

        -- count how many pages are free to read that from the software (--> software can send that many pages without asking again)
        -- find and store next_free page addr in a reg
        n_free := 0;
        for I in 0 to g_PAGES-1 loop
            if(TDAC_page_array(I).in_use = false) then
                n_free := n_free + 1;
                next_free_page <= std_logic_vector(to_unsigned(I, next_free_page'length));
                next_free_page_int <= I;
            end if;
        end loop;

        n_free_pages        <= std_logic_vector(to_unsigned(n_free, n_free_pages'length));
        o_n_free_pages      <= n_free_pages;
        n_free_pages_prev   <= n_free_pages;

        if ( i_we = '1' ) then
            -- we reached the end of the page that we are currently writing --> set page to full
            if ( addr_in_current_page = c_PAGE_SIZE-1 ) then
                TDAC_page_array(current_write_page).full     <= true;
                addr_in_current_page                         <= (others => '0');
                current_write_page                           <= next_free_page_int;

                current_page_addr                            <= next_free_page;

                -- each chip has N_PAGES_PER_CHIP. We expect them to be written in order
                -- save which page of chip i_chip was written now so we can also read them in order again
                TDAC_page_array(current_write_page).page_id  <= current_write_page_id(i_chip);

                -- if we received all pages of a chip we expect page 0 of that chip again
                -- if we did not yet receive all pages, we expect the current_page+1 next
                if(current_write_page_id(i_chip) = c_PAGES_PER_CHIP-1) then
                    current_write_page_id(i_chip) <= 0;
                else
                    current_write_page_id(i_chip) <= current_write_page_id(i_chip) + 1;
                end if;

            else
                -- if we are not yet at the end of the page we incr the address by one
                addr_in_current_page <= addr_in_current_page + 1;
                -- saving chip and in_use of that page here and not above for reasons on the read side
                TDAC_page_array(current_write_page).chip    <= i_chip;
                TDAC_page_array(current_write_page).in_use  <= true;
            end if;
        end if;

        -- comment to write side:
        -- notice that the write side does not care at all in which order chips / pages are written
        -- one can write all pages of Chip X, 5 pages of chip Y, 0 pages of chip Z, etc.
        -- one can write a part of page N of chip X, then a part of page M of chip Y, etc.
        -- The only thing that matters is that for a given chip the tdacs arrive in order ([col0,row0],[col0,row1],[col0,row2].. [col1,row0]..) and that one finishes to write a started page at some point
        -- i_chip comes from the slowcontrol addr that we write to, each chip has its own addr.

        -- fix for the tdac upload speed bug:
            -- if this is the last free page in the mem then next_free_page is without meaning in the part above
            -- once a page becomes free again current_write_page will still have the same value without meaning and then something will be overwritten
            -- fix for this problem:
        if ( n_free_pages_prev = 0 and n_free_pages /= n_free_pages_prev and addr_in_current_page = 0 and i_we = '0') then
            current_write_page <= next_free_page_int;
            current_page_addr <= next_free_page;
        end if;

        -----------------------------------------------
        -- read process
        -----------------------------------------------

        -- in this part we want to "refill" the tdac dpfs for the spi / "mu3e slowcontrol" entities
        -- we have one tdac dpf for each chip with the size of 512 bits.
        -- spi / "mu3e slowcontrol" entities decide what is the quickest order to actually write from the dpfs to the mupix then
        -- we just make sure here that we "feed" them with bits in the correct order
        -- --> spi / "mu3e slowcontrol" entities do not care about "bit-order" anymore, just how to ship the bits to the mupix in the order they get them (+ shift col shenanigans, but read mp_ctrl_spi for that)

        o_tdac_dpf_we <= (others => '0');

        -- what we want to do next is a bit problematic timing wise so we need to register a bunch of things
        if(page_cycler = g_PAGES-1) then
            page_cycler <= 0;
        else
            page_cycler <= page_cycler + 1;
        end if;

        last_page_cycler <= page_cycler;
        cycler_last_chip <= TDAC_page_array(page_cycler).chip;
        cycler_last_full <= TDAC_page_array(page_cycler).full;
        cycler_last_ID   <= TDAC_page_array(page_cycler).page_id;

        case read_state is
        when searching_match =>
            -- we cycle through all pages refill the dpf whenever we find a match
            for I in 0 to g_CHIPS-1 loop
                if(cycler_last_full= true and cycler_last_chip = I and i_tdac_dpf_empty(I) = '1' and cycler_last_ID = current_read_page_id(I)) then
                    read_state <= wait1;
                    read_chip <= I;
                    read_page_reg2 <= last_page_cycler;
                end if;
            end loop;

            -- need to reset the bitpos of the prev. page if it reached the end .. needs to be done here to time the bit selection from ram correctly
            if(page_finished = true) then
                TDAC_page_array(read_page_reg2).bit_in_tdac <= 0;
                TDAC_page_array(read_page_reg2).col_in_page <= 0;
                page_finished <= false;
            end if;

            if(col_finished = true) then
                TDAC_page_array(read_page_reg2).bit_in_tdac <= 0;
                TDAC_page_array(read_page_reg2).col_in_page <= TDAC_page.col_in_page + 1;
                col_finished <= false;
            end if;

        -- it's all the same thing but we need to relax the timing situation of read_page
        when wait1 =>
            read_page <= read_page_reg2;
            TDAC_page <= TDAC_page_array(read_page_reg2);
            read_state <= reading;

        when reading =>
            -- read a col for bit_in_tdac, incr. bit_in_tdac, read the col again, incr. bit_in_tdac, ... if bit_in_tdac = 6 --> incr. col, read col, incr. bit_in_tdac, ..  if col reached N_COLS_PER_PAGE --> in_use=0

            -- when we are in reading then we write to one dpf
            o_tdac_dpf_we(read_chip) <= '1';

            -- reaching the end of the col in this page in 2 cycles
            if ( TDAC_page.addr = c_COLS_PER_CHIP-2 ) then
                -- if this was the last time we want to read in this col we need to do a few things to avoid the cycler selecting the same (now empty) TDAC_page again
                if(TDAC_page.bit_in_tdac = 6) then
                    if(TDAC_page.col_in_page = g_COLS_PER_PAGE-1) then -- page completely read
                        TDAC_page.full <= false;
                        TDAC_page.in_use <= false;
                        page_finished <= true;

                        -- if this is the last time we want to read in this page and it is also the last page of the chip we start from 0 again, otherwise we want to read page + 1 next once the dpf becomes empty again
                        if(current_read_page_id(read_chip) = c_PAGES_PER_CHIP-1) then
                            current_read_page_id(read_chip) <= 0;
                        else
                            current_read_page_id(read_chip) <= current_read_page_id(read_chip) + 1;
                        end if;
                    else
                        col_finished <= true;
                    end if;
                else
                    -- if it was not the last time we want to read in this page and col we add a bit_in_tdac and start searching new match in 2 cycles
                    TDAC_page.bit_in_tdac <= TDAC_page.bit_in_tdac + 1;
                end if;
                TDAC_page.addr <= TDAC_page.addr + 1;

            -- end of col --> search new match
            elsif ( TDAC_page.addr = c_COLS_PER_CHIP-1 ) then
                read_state <= S_READ_DONE;
                TDAC_page.addr <= (others => '0');
            else
                TDAC_page.addr <= TDAC_page.addr + 1;
            end if;

        when S_READ_DONE =>
            TDAC_page_array(read_page) <= TDAC_page;
            read_state <= searching_match;

        when others =>
            read_state <= searching_match;
        end case;

    end if;
    end process;

    -- select the bits that we currently need
    genwdata : for I in 0 to 3 generate
        o_tdac_dpf_wdata(I) <= ram_rdata(I*8 + TDAC_page.bit_in_tdac);
    end generate;

    ram_raddr <= std_logic_vector(to_unsigned(read_page, c_PAGE_ADDR_WIDTH))
        & std_logic_vector(to_unsigned(TDAC_page.col_in_page, c_COL_ADDR_WIDTH))
        & TDAC_page.addr;

    ram_1r1w_inst : entity work.ram_1r1w
    generic map (
        g_DATA_WIDTH => 32,
        g_ADDR_WIDTH => c_ADDR_WIDTH--,
        --g_RAMSTYLE => "no_rw_check, MLAB"--,
    )
    port map (
        i_raddr => ram_raddr,--i_testram_raddr(c_ADDR_WIDTH-1 downto 0), -- ram_raddr
        o_rdata => ram_rdata,--o_testram_rdata, -- ram_rdata
        i_rclk  => i_clk,
        i_waddr => ram_waddr,-- i_testram_waddr(c_ADDR_WIDTH-1 downto 0)
        i_wdata => ram_wdata,--i_testram_wdata,
        i_we    => ram_we,
        i_wclk  => i_clk
    );

end architecture;
