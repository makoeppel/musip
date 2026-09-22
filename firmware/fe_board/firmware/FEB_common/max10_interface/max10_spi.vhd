--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity max10_spi is
port (
    -- Max10 SPI
    o_SPI_csn       : out   std_logic;
    o_SPI_clk       : out   std_logic;
    io_SPI_mosi     : inout std_logic;
    io_SPI_miso     : inout std_logic;
    io_SPI_D1       : inout std_logic;
    io_SPI_D2       : inout std_logic;
    io_SPI_D3       : inout std_logic;

    -- Interface to Arria
    i_strobe        : in    std_logic;
    i_addr          : in    std_logic_vector(6 downto 0);
    i_rw            : in    std_logic;
    i_data_to_max   : in    std_logic_vector(31 downto 0);
    i_numbytes      : in    std_logic_vector(8 downto 0);
    o_next_data     : out   std_logic;
    o_word_from_max : out   std_logic_vector(31 downto 0);
    o_word_en       : out   std_logic;
    o_byte_from_max : out   std_logic_vector(7 downto 0);
    o_byte_en       : out   std_logic;
    o_busy          : out   std_logic;

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture RTL of max10_spi is

    type spistate_type is (idle, address, writing, waiting, reading);
    signal spistate : spistate_type;
    signal addrshiftregister : std_logic_vector(7 downto 0);
    signal datashiftregister : std_logic_vector(31 downto 0);
    signal datareadshiftregister : std_logic_vector(31 downto 0);
    signal toggle: std_logic;
    signal nibblecount : integer;
    signal strobe_last  : std_logic;
    signal haveread : std_logic;

begin

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_SPI_csn        <= '1';
        o_SPI_clk       <= '0';
        io_SPI_mosi     <= 'Z';
        io_SPI_miso     <= 'Z';
        io_SPI_D1       <= 'Z';
        io_SPI_D2       <= 'Z';
        io_SPI_D3       <= 'Z';
        spistate        <= idle;
        o_word_en         <= '0';
        o_byte_en         <= '0';
        o_next_data       <= '0';
        strobe_last     <= '0';
        o_busy            <= '0';
    elsif rising_edge(i_clk) then
        o_word_en         <= '0';
        o_byte_en         <= '0';
        o_next_data       <= '0';
        strobe_last     <= i_strobe;
        case spistate is
        when idle =>
            o_SPI_csn        <= '1';
            o_SPI_clk       <= '0';
            io_SPI_mosi     <= 'Z';
            io_SPI_miso     <= 'Z';
            io_SPI_D1       <= 'Z';
            io_SPI_D2       <= 'Z';
            io_SPI_D3       <= 'Z';
            o_busy            <= '0';
            if(i_strobe = '1' and strobe_last = '0')then
                spistate    <= address;
                o_busy        <= '1';
                o_SPI_csn    <= '0';
                addrshiftregister <= i_rw & i_addr;
                toggle <= '0';
                nibblecount <= 0;
            end if;
        when address =>
            toggle <= not toggle;
            if(toggle = '0')then
                o_SPI_clk       <= '0';
                io_SPI_mosi     <= addrshiftregister(0);
                io_SPI_D1       <= addrshiftregister(1);
                io_SPI_D2       <= addrshiftregister(2);
                io_SPI_D3       <= addrshiftregister(3);
                addrshiftregister(3 downto 0) <= addrshiftregister(7 downto 4);
                nibblecount     <= nibblecount +1;
            else
                o_SPI_clk       <= '1';
            end if;
            if(nibblecount = 2)then
                if(i_rw = '1')then
                    spistate <= writing;
                    datashiftregister   <= i_data_to_max;
                    o_next_data           <= '1';
                    nibblecount         <= 0;
                else
                    spistate <= waiting;
                    nibblecount         <= 0;
                end if;
            end if;
        when writing =>
            toggle <= not toggle;
            if(toggle = '0')then
                o_SPI_clk       <= '0';
                io_SPI_mosi     <= datashiftregister(0);
                io_SPI_D1       <= datashiftregister(1);
                io_SPI_D2       <= datashiftregister(2);
                io_SPI_D3       <= datashiftregister(3);
                datashiftregister(27 downto 0) <= datashiftregister(31 downto 4);
                nibblecount     <= nibblecount +1;
                if ( nibblecount/2 = i_numbytes ) then
                    spistate <= idle;
                end if;
            else
                o_SPI_clk       <= '1';
                if(nibblecount mod 8 = 0)then
                    datashiftregister   <= i_data_to_max;
                    if ( nibblecount/2 < i_numbytes ) then
                        o_next_data           <= '1';
                    end if;
                end if;
            end if;


            if ( nibblecount/2 = i_numbytes and toggle = '0' ) then
                spistate <= idle;
            end if;
        when waiting =>
            toggle <= not toggle;
            io_SPI_mosi     <= 'Z';
            io_SPI_D1       <= 'Z';
            io_SPI_D2       <= 'Z';
            io_SPI_D3       <= 'Z';
            if(toggle = '0')then
                o_SPI_clk       <= '0';
                nibblecount     <= nibblecount + 1;
            else
                o_SPI_clk       <= '1';
                if(nibblecount = 3) then
                    spistate        <= reading;
                    nibblecount     <= 0;
                end if;
            end if;
        when reading =>
            haveread <= '0';
            toggle <= not toggle;
            if(toggle = '0')then
                o_SPI_clk       <= '0';
                datareadshiftregister(28)   <= io_SPI_mosi;
                datareadshiftregister(29)   <= io_SPI_D1;
                datareadshiftregister(30)   <= io_SPI_D2;
                datareadshiftregister(31)   <= io_SPI_D3;
                datareadshiftregister(27 downto 0) <= datareadshiftregister(31 downto 4);
                nibblecount     <= nibblecount +1;
                haveread        <= '1';
            else
                o_SPI_clk       <= '1';
            end if;

            if(nibblecount mod 2 = 0 and nibblecount > 0 and haveread = '1')then
                o_byte_from_max   <= datareadshiftregister(31 downto 24);
                o_byte_en         <= '1';
            end if;

            if(nibblecount mod 8 = 0 and nibblecount > 0 and haveread = '1')then
                o_word_from_max   <= datareadshiftregister;
                o_word_en         <= '1';
            end if;

            if ( nibblecount/2 = i_numbytes ) then
                spistate    <= idle;
            end if;

        when others =>
            o_SPI_csn        <= '1';
            o_SPI_clk       <= '0';
            io_SPI_mosi     <= 'Z';
            io_SPI_miso     <= 'Z';
            io_SPI_D1       <= 'Z';
            io_SPI_D2       <= 'Z';
            io_SPI_D3       <= 'Z';
            spistate        <= idle;
        end case;
    end if;
    end process;

end architecture;
