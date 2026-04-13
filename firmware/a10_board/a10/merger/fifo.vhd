library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
    generic (
        DATA_WIDTH : positive := 40;
        ADDR_WIDTH : positive := 9
    );
    port (
        data       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        read_addr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        write_addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        we         : in  std_logic;
        clk        : in  std_logic;
        q          : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity fifo;

architecture rtl of fifo is
    type ram_t is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram   : ram_t := (others => (others => '0'));
    signal q_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
begin
    q <= q_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            -- Write
            if we = '1' then
                ram(to_integer(unsigned(write_addr))) <= data;
            end if;

            -- Read (bypass on same-address read/write)
            if (we = '1') and (read_addr = write_addr) then
                q_reg <= data;
            else
                q_reg <= ram(to_integer(unsigned(read_addr)));
            end if;
        end if;
    end process;

end architecture rtl;