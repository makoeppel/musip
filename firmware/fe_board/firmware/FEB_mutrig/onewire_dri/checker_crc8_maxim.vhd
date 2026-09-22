library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- entity of CRC check
entity checker_crc8_maxim is
port (
    i_CRC_en    : in    std_logic;
    i_din       : in    std_logic;

    o_lfsr      : out   std_logic_vector(7 downto 0);

    i_rst_n     : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture rtl of checker_crc8_maxim is

    signal shift_reg : std_logic_vector(7 downto 0);

    --type schpad_DS18B20 is array (0 to 8) of std_logic_vector(7 downto 0);
    --signal rd_data : schpad_DS18B20;

begin

    o_lfsr <= shift_reg;
    process(i_clk,i_rst_n) begin
    if (i_rst_n /= '1') then
        shift_reg <= (others => '0');
    elsif rising_edge(i_clk) then
        if (i_CRC_en = '1') then
            shift_reg(0) <= i_din xor shift_reg(7);
            shift_reg(1) <= shift_reg(0);
            shift_reg(2) <= shift_reg(1);
            shift_reg(3) <= shift_reg(2);
            shift_reg(4) <= shift_reg(3) xor (i_din xor shift_reg(7));
            shift_reg(5) <= shift_reg(4) xor (i_din xor shift_reg(7));
            shift_reg(6) <= shift_reg(5);
            shift_reg(7) <= shift_reg(6);
        else
            shift_reg(0) <= i_din;
            shift_reg(1) <= shift_reg(0);
            shift_reg(2) <= shift_reg(1);
            shift_reg(3) <= shift_reg(2);
            shift_reg(4) <= shift_reg(3);
            shift_reg(5) <= shift_reg(4);
            shift_reg(6) <= shift_reg(5);
            shift_reg(7) <= shift_reg(6);
        end if;
    end if;
    end process;

end architecture;
