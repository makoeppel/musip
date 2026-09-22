--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity spi_decoder is
generic (
    g_ADC_DATA_BASE : unsigned (13 downto 0) := "11111111101100"--;
);
port (
    -- SPI secondary --
    i_SPI_inst      : in  std_logic_vector(7 downto 0);
    i_SPI_data      : in  std_logic_vector(31 downto 0);
    i_SPI_addr_o    : in  std_logic_vector(6 downto 0);
    i_SPI_rw        : in  std_logic;
    o_SPI_data      : out std_logic_vector(31 downto 0);

    -- ram interface ..
    i_ram_data      : in  std_logic_vector(31 downto 0);
    o_ram_data      : out std_logic_vector(31 downto 0);
    o_ram_addr      : out std_logic_vector(13 downto 0);
    o_ram_rw        : out std_logic;

    --ADC Nioas PIOs --
    i_adc_data_0    : in std_logic_vector(31 downto 0);
    i_adc_data_1    : in std_logic_vector(31 downto 0);
    i_adc_data_2    : in std_logic_vector(31 downto 0);
    i_adc_data_3    : in std_logic_vector(31 downto 0);
    i_adc_data_4    : in std_logic_vector(31 downto 0);

    -- fifo interface --
    i_fifo_data     : in  std_logic_vector(31 downto 0);
    o_fifo_data     : out std_logic_vector(31 downto 0);
    o_fifo_next     : out std_logic;
    o_fifo_rw       : out std_logic;

    -- command register --
    i_comm_data     : in  std_logic_vector(31 downto 0);
    o_comm_data     : out std_logic_vector(31 downto 0);
    o_comm_rw       : out std_logic;

    -- status register--
    i_stat_data     : in  std_logic_vector(31 downto 0);
    o_stat_data     : out std_logic_vector(31 downto 0);
    o_stat_rw       : out std_logic;

    -- register
    i_reg_data      : in  std_logic_vector(31 downto 0);
    o_reg_data      : out std_logic_vector(31 downto 0);
    o_reg_addr      : out std_logic_vector(7 downto 0);
    o_reg_rw        : out std_logic--;
);

end entity;

architecture rtl of spi_decoder is

    signal adc_data     : work.util_slv.slv32_array_t(0 to 4);

    signal adc_data_o   : std_logic_vector(31 downto 0);
    signal command      : std_logic_vector(7 downto 0);
    signal rw_comm      : std_logic;
    signal adc_adr      : std_logic_vector(13 downto 0);

begin

    adc_data(0) <= i_adc_data_0;
    adc_data(1) <= i_adc_data_1;
    adc_data(2) <= i_adc_data_2;
    adc_data(3) <= i_adc_data_3;
    adc_data(4) <= i_adc_data_4;
    adc_data_o  <= adc_data(to_integer(unsigned(i_SPI_addr_o)))
                    when to_integer(unsigned(i_SPI_addr_o)) < 5
                    else (others => '0');
    command(6 downto 0) <= i_SPI_inst(7 downto 1);
    command(7)          <= '0';
    rw_comm             <= i_SPI_inst(0);
    adc_adr             <= std_logic_vector(g_ADC_DATA_BASE + unsigned(i_SPI_addr_o));

    with command select
        -- more infos in the manuel
        o_SPI_data <=   i_stat_data     when X"02",
                        i_stat_data     when X"10",
                        i_reg_data      when x"11",
                        i_comm_data     when X"12",
                        i_reg_data      when x"13",
                        i_fifo_data     when x"14",
                        i_fifo_data     when x"15",
                        i_ram_data      when x"20",
                        i_ram_data      when x"21",
                        adc_data_o      when x"22",
                        (others => '0') when others;
    with command select
        o_comm_data <=  i_SPI_data      when x"12",
                        (others => '0') when others;
    with command select
        o_comm_rw   <=  i_SPI_rw        when x"12",
                        '0'             when others;
    with command select
        o_fifo_data <=  i_SPI_data      when x"14",
                        (others => '0') when others;
    with command select
        o_fifo_next <=  '1'             when (x"14" or x"15"),
                        '0'             when others;
    with command select
        o_fifo_rw   <=  rw_comm         when (x"14" or x"15"),
                        '0'             when others;
    with command select
        o_ram_addr  <=  adc_adr         when x"20",
                        adc_adr         when x"21",
                        (others => '0') when others;
    with command select
        o_ram_data  <=  i_SPI_data      when x"20",
                        i_SPI_data      when x"21",
                        (OTHERS => '0') when others;
    with command select
        o_ram_rw    <=  i_SPI_rw        when x"21",
                        '1'             when others;
    with command select
        o_reg_addr  <=  (others => '0') when others;
    with command select
        o_reg_data  <=  i_SPI_data      when x"00",
                        (others => '0') when others;
    with command select
        o_reg_rw    <=  i_SPI_rw        when x"00",
                        '1'             when others;

end architecture;
