-- mupix lvds rx reg mapping
-- M. Mueller, Nov 2021

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.lvds_registers.all;
use work.mupix.all;
use work.mudaq.all;

entity lvds_rx_reg_mapping is
generic (
    g_LVDS_LINKGS : integer := 36--;
);
port (
    i_reg_addr                  : in    std_logic_vector(15 downto 0);
    i_reg_re                    : in    std_logic;
    o_reg_rdata                 : out   std_logic_vector(31 downto 0);
    i_reg_we                    : in    std_logic;
    i_reg_wdata                 : in    std_logic_vector(31 downto 0);

    i_reg2_addr                 : in    std_logic_vector(15 downto 0);
    i_reg2_re                   : in    std_logic;
    o_reg2_rdata                : out   std_logic_vector(31 downto 0);
    i_reg2_we                   : in    std_logic;
    i_reg2_wdata                : in    std_logic_vector(31 downto 0);

    i_clk_156                   : in    std_logic;

    i_lvds_status               : in    lvds_status_array_t(g_LVDS_LINKGS - 1 downto 0) := (others => LVDS_ZERO);

    i_reset_125_n               : in    std_logic;
    i_clk_125                   : in    std_logic--;
);
end entity;

architecture rtl of lvds_rx_reg_mapping is

    signal waddr     : std_logic_vector(6 downto 0)  := (others => '0');
    signal wdata     : std_logic_vector(31 downto 0) := (others => '0');
    signal waddr_int : integer range 0 to 31 := 0;
    signal waddr2    : std_logic_vector(3 downto 0) := (others => '0');
    signal wdata2    : std_logic_vector(31 downto 0) := (others => '0');
    signal waddr_int2: integer range 0 to g_LVDS_LINKGS := 0;

    -- reg_addr2 and reg_addr is the same in principle .. quartus sees that .. merges it .. fails timing because of it
    -- synthesis read_comments_as_HDL on
    -- attribute dont_merge : boolean;
    -- attribute dont_merge of o_reg_rdata     : signal is true;
    -- attribute dont_merge of o_reg2_rdata    : signal is true;
    -- attribute dont_merge of i_reg_addr      : signal is true;
    -- attribute dont_merge of i_reg2_addr     : signal is true;
    -- attribute dont_merge of i_reg_re        : signal is true;
    -- attribute dont_merge of i_reg2_re       : signal is true;
    -- attribute dont_merge of waddr           : signal is true;
    -- attribute dont_merge of waddr2          : signal is true;
    -- attribute dont_merge of waddr_int       : signal is true;
    -- attribute dont_merge of waddr_int2      : signal is true;
    -- attribute dont_merge of wdata           : signal is true;
    -- attribute dont_merge of wdata2          : signal is true;
    -- synthesis read_comments_as_HDL off

begin

    waddr_int  <= to_integer(unsigned(waddr(6 downto 2)));

    -- write and read first ram
    process(i_clk_125, i_reset_125_n)
    begin
    if ( i_reset_125_n = '0' ) then
        waddr <= (others => '0');
        wdata <= (others => '0');
    elsif rising_edge(i_clk_125) then

        -- overflow check if we have less than 31 links
        if ( to_integer(unsigned(waddr(6 downto 2))) = g_LVDS_LINKGS - 1 and waddr(1 downto 0) = "11"  ) then
            waddr <= (others => '0');
        else
            waddr <= waddr + '1';
        end if;

        if(waddr(1 downto 0) = "00") then
            wdata(LVDS_STATUS_PLL_LOCKED_BIT)      <= i_lvds_status(waddr_int).pll_locked;
            wdata(LVDS_STATUS_READY_BIT)           <= i_lvds_status(waddr_int).ready;
            wdata(LVDS_STATUS_DPA_LOCKED_BIT)      <= i_lvds_status(waddr_int).dpa_locked;
            wdata(LVDS_STATUS_ALIGN_CNT_RANGE)     <= i_lvds_status(waddr_int).aligncnt;
            wdata(LVDS_STATUS_ARRIVAL_PHASE_RANGE) <= i_lvds_status(waddr_int).arrival_phase;
            wdata(LVDS_STATUS_OUTOF_PHASE_RANGE)   <= i_lvds_status(waddr_int).out_of_phase_cnt;
        end if;
        if(waddr(1 downto 0) = "01") then
            wdata <= i_lvds_status(waddr_int).disperr;
        end if;
        if(waddr(1 downto 0) = "10") then
            wdata <= i_lvds_status(waddr_int).err8b10b;
        end if;
        if(waddr(1 downto 0) = "11") then
            wdata <= i_lvds_status(waddr_int).hitcnt;
        end if;

    end if;
    end process;

    e_counter_ram : entity work.ram_1r1w
    generic map (
        g_DATA_WIDTH => 32,
        g_ADDR_WIDTH => 7,
        g_RAMSTYLE => "no_rw_check, MLAB"
    )
    port map (
        i_raddr => i_reg_addr(6 downto 0),
        o_rdata => o_reg_rdata,
        i_rclk  => i_clk_156,

        i_waddr => waddr,
        i_wdata => wdata,
        i_we    => '1',
        i_wclk  => i_clk_125--,
    );


    -- second memory serves the links above 31; offset here is in links, as already divide by 4
    -- this is a space thing. Doing this in a single ram would need space equivalent to 64 links, here we do 32 + 4
    gen_second_ram : if ( g_LVDS_LINKGS > 31 ) generate

        waddr_int2 <= to_integer(unsigned(waddr(3 downto 2))) + 32;

        process(i_clk_125, i_reset_125_n)
        begin
        if ( i_reset_125_n = '0' ) then
            waddr2 <= (others => '0');
            wdata2 <= (others => '0');
        elsif rising_edge(i_clk_125) then
            waddr2 <= waddr2 + '1';

            if(waddr2(1 downto 0) = "00") then
                wdata2(LVDS_STATUS_PLL_LOCKED_BIT)      <= i_lvds_status(waddr_int2).pll_locked;
                wdata2(LVDS_STATUS_READY_BIT)           <= i_lvds_status(waddr_int2).ready;
                wdata2(LVDS_STATUS_DPA_LOCKED_BIT)      <= i_lvds_status(waddr_int2).dpa_locked;
                wdata2(LVDS_STATUS_ALIGN_CNT_RANGE)     <= i_lvds_status(waddr_int2).aligncnt;
                wdata2(LVDS_STATUS_ARRIVAL_PHASE_RANGE) <= i_lvds_status(waddr_int2).arrival_phase;
                wdata2(LVDS_STATUS_OUTOF_PHASE_RANGE)   <= i_lvds_status(waddr_int2).out_of_phase_cnt;
            end if;
            if(waddr2(1 downto 0) = "01") then
                wdata2 <= i_lvds_status(waddr_int2).disperr;
            end if;
            if(waddr2(1 downto 0) = "10") then
                wdata2 <= i_lvds_status(waddr_int2).err8b10b;
            end if;
            if(waddr2(1 downto 0) = "11") then
                wdata2 <= i_lvds_status(waddr_int2).hitcnt;
            end if;
        end if;
        end process;

        e_counter_ram2 : entity work.ram_1r1w
        generic map (
            g_DATA_WIDTH => 32,
            g_ADDR_WIDTH => 4,
            g_RAMSTYLE => "no_rw_check, MLAB"
        )
        port map (
            i_raddr => i_reg2_addr(3 downto 0),
            o_rdata => o_reg2_rdata,
            i_rclk  => i_clk_156,

            i_waddr => waddr2,
            i_wdata => wdata2,
            i_we    => '1',
            i_wclk  => i_clk_125--,
        );

    end generate;

end architecture;
