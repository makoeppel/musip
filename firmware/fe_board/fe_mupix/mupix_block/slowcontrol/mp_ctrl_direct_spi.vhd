----------------------------------------------------------------------------
-- Mupix direct SPI
-- M. Mueller
-- JAN 2022

-- gets the 29 bit word that needs to go into the mupix spi reg and writes it
-- input either from register (software) or rest of mp_ctrl block
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mupix.all;
use work.mudaq.all;


entity mp_ctrl_direct_spi is
generic (
    g_DIRECT_SPI_FIFO_SIZE : positive := 4;
    g_CHIPS_PER_SPI : positive := 4--;
);
port (
    i_fifo_write_mp_ctrl: in  std_logic := '0';
    i_fifo_data_mp_ctrl : in  std_logic_vector(31 downto 0);
    o_fifo_almost_full  : out std_logic;
    o_direct_spi_busy   : out std_logic;

    -- bypass the usual path and write directly to spi from midas
    i_direct_spi_enable : in  std_logic := '0';
    i_fifo_write_direct : in  std_logic;
    i_fifo_data_direct  : in  std_logic_vector(31 downto 0);

    i_spi_slow_down     : in  std_logic_vector(15 downto 0);
    i_chip_mask         : in  std_logic_vector(g_CHIPS_PER_SPI-1 downto 0);

    o_spi               : out std_logic;
    o_spi_clk           : out std_logic;
    o_cs                : out std_logic_vector(g_CHIPS_PER_SPI-1 downto 0);

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture RTL of mp_ctrl_direct_spi is

    signal fifo_write           : std_logic;
    signal fifo_wdata           : std_logic_vector(31 downto 0);
    signal fifo_empty           : std_logic;
    signal fifo_rd              : std_logic;
    signal fifo_rdata           : std_logic_vector(31 downto 0);

    type direct_spi_state_type  is (idle, rd, wr, ld);
    signal direct_spi_state     : direct_spi_state_type;

    type spi_slowdown_state_type is (beforepulse, duringpulse,afterpulse);
    signal spi_bit_state        : spi_slowdown_state_type;
    signal wait_cnt             : std_logic_vector(15 downto 0);

    signal spi_bitpos           : integer range 0 to 31;
    signal internal_chip_mask   : std_logic_vector(g_CHIPS_PER_SPI-1 downto 0);

begin

    fifo_write          <= i_fifo_write_direct when i_direct_spi_enable = '1' else i_fifo_write_mp_ctrl;
    fifo_wdata          <= i_fifo_data_direct  when i_direct_spi_enable = '1' else i_fifo_data_mp_ctrl;
    o_direct_spi_busy   <= not fifo_empty;

    direct_spi_fifo: entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => g_DIRECT_SPI_FIFO_SIZE,
        g_DATA_WIDTH => 32,
        g_SHOWAHEAD => "OFF",
        g_LPM_HINT => "RAM_BLOCK_TYPE=MLAB"--,
    )
    port map (
        i_we        => fifo_write,
        i_wdata     => fifo_wdata,
        o_almost_full => o_fifo_almost_full,

        i_rack      => fifo_rd,
        o_rdata     => fifo_rdata,
        o_rempty    => fifo_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    process(i_clk, i_reset_n) is
    begin
    if ( i_reset_n = '0' ) then
        o_spi               <= '0';
        o_spi_clk           <= '0';
        o_cs                <= (others => '0');
        fifo_rd             <= '0';
        direct_spi_state    <= idle;
        spi_bitpos          <= 0;
        wait_cnt            <= (others => '0');
        internal_chip_mask  <= (others => '0');

    elsif rising_edge(i_clk) then
        fifo_rd     <= '0';
        wait_cnt    <= wait_cnt + 1;
        o_spi       <= '0';
        o_spi_clk   <= '0';

        case direct_spi_state is
        when idle =>
            if(fifo_empty = '0') then
                fifo_rd             <= '1';
                direct_spi_state    <= rd;
                internal_chip_mask  <= i_chip_mask;
            end if;
        when rd =>
            direct_spi_state <= wr;
            wait_cnt         <= (others => '0');
        when wr =>
            o_spi <= fifo_rdata(spi_bitpos);
            case spi_bit_state is
            when beforepulse =>
                o_spi_clk <= '0';
                if(wait_cnt(14 downto 0) = i_spi_slow_down(15 downto 1)) then -- wait_cnt = slow_down/2
                    wait_cnt        <= (others => '0');
                    spi_bit_state   <= duringpulse;
                end if;
            when duringpulse =>
                o_spi_clk <= '1';
                if(wait_cnt = i_spi_slow_down) then
                    wait_cnt        <= (others => '0');
                    spi_bit_state   <= afterpulse;
                end if;
            when afterpulse =>
                o_spi_clk <= '0';
                if(wait_cnt(14 downto 0) = i_spi_slow_down(15 downto 1)) then -- wait_cnt = slow_down/2
                    wait_cnt            <= (others => '0');
                    spi_bit_state       <= beforepulse;
                    if(spi_bitpos=31) then
                        direct_spi_state <= ld;
                        spi_bitpos       <= 0;
                    else
                        spi_bitpos      <= spi_bitpos + 1;
                    end if;
                end if;
            when others =>
                spi_bit_state <= beforepulse;
            end case;
        when ld =>
            if(wait_cnt=i_spi_slow_down) then
                o_cs  <= internal_chip_mask;
            end if;
            if(wait_cnt = i_spi_slow_down + i_spi_slow_down) then
                direct_spi_state <= idle;
                o_cs  <= (others => '0');
            end if;
        when others =>
            direct_spi_state <= idle;
        end case;

    end if;
    end process;

end architecture;
