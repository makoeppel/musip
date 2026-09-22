--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_bp is
port (
    ------ SPI
    i_boardselect   : in    std_logic;
    i_SPI_csn       : in    std_logic;
    i_SPI_clk       : in    std_logic;
    i_SPI_mosi      : in    std_logic;
    o_SPI_miso      : out   std_logic;
    o_SPI_miso_en   : out   std_logic;

    o_addr          : out   std_logic_vector(7 downto 0);
    o_addroffset    : out   std_logic_vector(7 downto 0);
    o_rw            : out   std_logic;
    i_data_to_bp    : in    std_logic_vector(31 downto 0);
    o_next_data     : out   std_logic;
    o_word_from_bp  : out   std_logic_vector(31 downto 0);
    o_word_en       : out   std_logic;
    o_byte_from_bp  : out   std_logic_vector(7 downto 0);
    o_byte_en       : out   std_logic;

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture RTL of spi_bp is

    type spistate_type is (
        command, address, writing, waiting, reading, unsupported,
        idle
    );
    signal spistate : spistate_type;
    signal commandshiftregister : std_logic_vector(7 downto 0);
    signal addrshiftregister : std_logic_vector(7 downto 0);
    signal datashiftregister : std_logic_vector(31 downto 0);
    signal datareadshiftregister : std_logic_vector(31 downto 0);
    signal spicommand : std_logic_vector(7 downto 0);
    signal clklast : std_logic;
    signal bitcount : integer;
    signal addroffset_int : integer;
    signal haveread :std_logic;

    signal boardselect_reg : std_logic;
    signal csn_reg : std_logic;
    signal clk_reg : std_logic;
    signal mosi_reg : std_logic;

    constant BP_CMD_RW_BIT : integer := 5;
    constant BP_CMD_WRITE8 : std_logic_vector(7 downto 0) := X"11";
    constant BP_CMD_READ8  : std_logic_vector(7 downto 0) := X"21";

begin

    o_addroffset <= std_logic_vector(to_unsigned(addroffset_int, o_addroffset'length));

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_SPI_miso      <= '0';
        spistate        <= idle;
        o_word_en         <= '0';
        o_byte_en         <= '0';
        o_next_data       <= '0';
        clklast         <= '0';
        clk_reg         <= '0';
        csn_reg         <= '1';
        boardselect_reg <= '1';
        o_SPI_miso_en   <= '0';
    elsif rising_edge(i_clk) then
        o_word_en         <= '0';
        o_byte_en         <= '0';
        o_next_data       <= '0';
        o_SPI_miso_en   <= '0';

        boardselect_reg <= i_boardselect;
        csn_reg         <= i_SPI_csn;
        clk_reg         <= i_SPI_clk;
        mosi_reg        <= i_SPI_mosi;
        clklast         <= clk_reg;

        case spistate is
        when idle =>
            o_SPI_miso      <= '0';
            if(boardselect_reg = '0') then
                spistate    <= command;
                bitcount    <= 0;
                addroffset_int  <= 0;
            end if;
        when command =>
            if(clklast = '0' and clk_reg = '1') then
                commandshiftregister(0) <= mosi_reg;
                commandshiftregister(7 downto 1)    <= commandshiftregister(6 downto 0);
                bitcount <= bitcount + 1;
            end if;
            if(bitcount > 7)then
                spicommand  <= commandshiftregister;
                spistate    <= address;
                bitcount    <= 0;
            end if;

        when address =>
            if(clklast = '0' and clk_reg = '1') then
                addrshiftregister(0) <= mosi_reg;
                addrshiftregister(7 downto 1)    <= addrshiftregister(6 downto 0);
                bitcount <= bitcount + 1;
            end if;
            if(bitcount > 7)then
                o_addr <=    addrshiftregister(7 downto 0);
                o_rw   <= not commandshiftregister(BP_CMD_RW_BIT);
                bitcount    <= 0;
                if(commandshiftregister = BP_CMD_WRITE8) then
                    spistate <= writing;
                elsif(commandshiftregister = BP_CMD_READ8) then
                    spistate <= waiting;
                else
                    spistate <= unsupported;
                end if;
            end if;

        when writing =>
            haveread <= '0';
            if(clklast = '0' and clk_reg = '1') then
                datashiftregister(0)  <=  mosi_reg;
                datashiftregister(31 downto 1) <= datashiftregister(30 downto 0);
                bitcount     <= bitcount +1;
                haveread     <= '1';
            end if;
            if(haveread = '1' and bitcount mod 8 = 0 and bitcount > 0)then
                o_byte_from_bp        <= datashiftregister(7 downto 0);
                o_byte_en             <= '1';
            end if;
            if(haveread = '1' and bitcount mod 32 = 1 and bitcount > 1)then
                addroffset_int          <= addroffset_int + 1;
            end if;
            if(haveread = '1' and bitcount mod 32 = 0 and bitcount > 0)then
                o_word_from_bp   <= datashiftregister;
                o_word_en        <= '1';
            end if;

        when waiting =>
            if(clklast = '0' and clk_reg = '1') then
                bitcount     <= bitcount +1;
            end if;
            if(bitcount > 7) then
                spistate    <= reading;
                bitcount    <= 1;
                datareadshiftregister   <= i_data_to_bp;
                o_SPI_miso              <= i_data_to_bp(31);
                o_SPI_miso_en           <= '1';
                o_next_data               <= '1';
            end if;

        when reading =>
            haveread <= '0';
            o_SPI_miso_en <= '1';
            if(clklast = '1' and clk_reg = '0') then
                o_SPI_miso <= datareadshiftregister(30);
                datareadshiftregister(31 downto 1) <= datareadshiftregister(30 downto 0);
                bitcount     <= bitcount +1;
                haveread        <= '1';
            end if;

            if(haveread = '1' and bitcount mod 32 = 0 and bitcount > 0)then
                datareadshiftregister <= i_data_to_bp;
                o_next_data         <= '1';
            end if;
            if(haveread = '1' and bitcount mod 32 = 1 and bitcount > 32) then
                addroffset_int    <= addroffset_int + 1;
            end if;

        when unsupported =>


        when others =>

            spistate        <= idle;
        end case;

        if(boardselect_reg = '1') then
            spistate    <= idle;
        end if;

    end if;
    end process;

end architecture;
