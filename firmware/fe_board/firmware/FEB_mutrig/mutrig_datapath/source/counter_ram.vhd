-- counter reg mapping
-- M. Koeppel, April 2024

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;


entity counter_ram is
generic (
    -- TODO: maybe one can do this dynamic for now we have a fixed RAM of 32 bits with 1024 addr
    g_N_CNT : integer := 64;
    g_N_TABLE : integer := 16--;
);
port (
    i_reg_addr      : in  std_logic_vector(9 downto 0);
    o_reg_rdata     : out std_logic_vector(31 downto 0);

    i_counter       : in  slv32_array_t(64*16 - 1 downto 0) := (others => ( others => '0' ));

    i_reset_we_n    : in  std_logic;
    i_clk_rd        : in  std_logic;
    i_clk_we        : in  std_logic--;
);
end entity;

architecture rtl of counter_ram is

    signal waddr     : std_logic_vector(9 downto 0)  := (others => '0');
    signal wdata     : std_logic_vector(31 downto 0) := (others => '0');
    signal waddr_int : integer range 0 to 64*16 := 0;

begin

    waddr_int  <= to_integer(unsigned(waddr + '1'));

    process(i_clk_we, i_reset_we_n)
    begin
    if ( i_reset_we_n /= '1' ) then
        waddr <= (others => '1');
        wdata <= (others => '0');
    elsif rising_edge(i_clk_we) then
        waddr <= waddr + '1';
        wdata <= i_counter(waddr_int);
    end if;
    end process;

    e_counter_ram : entity work.ram_1r1w
    generic map (
        g_DATA_WIDTH => 32,
        g_ADDR_WIDTH => 10,
        g_RAMSTYLE => "no_rw_check, MLAB"--,
    )
    port map (
        i_raddr => i_reg_addr,
        o_rdata => o_reg_rdata,
        i_rclk  => i_clk_rd,

        i_waddr => waddr,
        i_wdata => wdata,
        i_we    => '1',
        i_wclk  => i_clk_we--,
    );

end architecture;
