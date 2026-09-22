library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity arria_reg_tb is
generic (
    R       : std_logic -- := '1' --; -- when (r/w = R) => read || when (r/w != R) => write
);
port (
    i_adrr  : in  std_logic_vector(6 downto 0); -- Base addr = 0
    i_data  : in  std_logic_vector(31 downto 0);

    i_R     : in  std_logic;
    i_W     : in  std_logic;

    i_SPI_c : in  std_logic; -- falls der SPI über register gesteuert werden soll.
    o_SPI_c : out std_logic_vector(15 downto 0);
    o_SPI_a : out std_logic_vector(15 downto 0);

    o_data  : out std_logic_vector(31 downto 0);

    i_reset_n : in  std_logic;
    i_clk   : in  std_logic--;
);
end entity;

architecture  rtl of arria_reg_tb is

    type reg_128 is Array (natural range<>) of std_logic_vector(31 downto 0);
    signal reg     : reg_128(0 to 127);

    signal inst     : std_logic := '1';

begin

    o_data  <= reg(to_integer(unsigned(i_adrr))) when i_R = R;

    process(i_clk, i_reset_n)
    begin
    if i_reset_n = '0' then
        inst <= '1';
    elsif rising_edge(i_clk) then
        o_SPI_c <= reg(127)(15 downto 0);
        o_SPI_a <= reg(127)(31 downto 16);

        if inst = '1' then
            reg(127) <= X"55" & "0100010" & '1' & X"00" & "000100" & '1' & '1';
            for i in 0 to 62 loop
                reg(i*2)        <= X"F0570FF0";
                --reg(i*2)        <= X"55555555";
                reg((i*2)+1)   <= X"55555555";
            end loop;
            inst <= '0';

        elsif i_R = not R then
            if i_adrr /= "1111111" then
                reg(to_integer(unsigned(i_adrr))) <= i_data;
            end if;
        else
            --o_data  <= reg(to_integer(unsigned(i_adrr)));
        end if;

        if i_SPI_c = '1' then
            reg(127)(0) <= '0';
        end if;

    end if;
    end process;

end architecture;
