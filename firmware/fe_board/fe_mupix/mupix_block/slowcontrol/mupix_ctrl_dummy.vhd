----------------------------------------------------------------------------
-- Mupix control dummy
-- M. Mueller
-- JAN 2021
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.mupix_registers.all;
use work.mupix.all;
use work.mudaq.all;

entity mupix_ctrl_dummy is
port (
    o_spi_clock         : out std_logic;
    o_spi_mosi          : out std_logic;
    o_spi_csn           : out std_logic;

    i_start             : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture RTL of mupix_ctrl_dummy is

    signal sc_addr      : std_logic_vector(7 downto 0);
    signal sc_re        : std_logic;
    signal sc_rdata     : std_logic_vector(31 downto 0);
    signal sc_we        : std_logic;
    signal sc_wdata     : std_logic_vector(31 downto 0);

    signal clock        : std_logic_vector( 3 downto 0);
    signal mosi         : std_logic_vector( 3 downto 0);
    signal csn          : std_logic_vector(11 downto 0);
    signal reset_n      : std_logic;

    signal step         : integer;
    signal start_prev   : std_logic;

    type default_config_type    is array (6 downto 0) of std_logic_vector(31 downto 0);
    constant MP_BIAS_DEFAULT  : default_config_type := (x"028A0000",x"1400C20A", x"40280000", x"041E9A51", x"1E041041", x"FA3F002F", x"2A000A03");
    constant MP_CONF_DEFAULT  : default_config_type := (x"00000000",x"00000000", x"00000000", x"00000000", x"FC05F000", x"08380000", x"001F0002");
    constant MP_VDAC_DEFAULT  : default_config_type := (x"00000000",x"00000000", x"00000000", x"00000000", x"00000000", x"4C000047", x"00720000");

begin

    o_spi_clock <= clock(0);
    o_spi_mosi  <= mosi(0);
    o_spi_csn   <= csn(0);
    --e_mupix_ctrl : entity work.mupix_ctrl
    --port map (

    --    i_reg_addr                  => sc_addr,
    --    i_reg_re                    => sc_re,
    --    o_reg_rdata                 => open,
    --    i_reg_we                    => sc_we,
    --    i_reg_wdata                 => sc_wdata,

    --    o_clock                     => clock,
    --    o_SIN                       => open,
    --    o_mosi                      => mosi,
    --    o_csn                       => csn,

    --    i_reset_n                   => reset_n,
    --    i_clk                       => i_clk--,
    --);



    process(i_clk, i_start)
    begin
    if rising_edge(i_clk) then
        reset_n     <= '1';
        start_prev  <= i_start;
        if(step /= 0) then
            step        <= step + 1;
        end if;

        if(i_start = '1' and start_prev = '0') then
            step    <= 1;
        end if;

        sc_we       <= '0';
        sc_addr     <= (others => '0');

        case step is
        when 0 =>
            reset_n     <= '0';
        when 1 to 50  =>
            sc_addr     <= (others => '0');
            sc_wdata    <= (others => '0');
            sc_re       <= '0';
            sc_we       <= '0';
        when 51 =>
            sc_addr     <= x"40";
            sc_wdata    <= x"00000FC0";
            sc_we       <= '1';
        when 52 to 58 =>

        when 59 =>
            sc_addr     <= x"48";
            sc_wdata    <= x"00000000";
            sc_we       <= '1';
        when 60 =>
            sc_addr     <= x"47";
            sc_wdata    <= x"00000008";
            sc_we       <= '1';
        when 61 =>
            sc_addr     <= x"49";
            sc_wdata    <= x"00000002";
            sc_we       <= '1';
        when 62 =>
            sc_addr     <= x"40";
            sc_wdata    <= x"00000000";
            sc_we       <= '1';
        when 63 to 65 =>

        when 66 to 68 =>
            sc_addr     <= x"43";
            sc_wdata    <= MP_VDAC_DEFAULT(step-66);
            sc_we       <= '1';
        when 69 to 71 =>
            sc_addr     <= x"42";
            sc_wdata    <= MP_CONF_DEFAULT(step-69);
            sc_we       <= '1';
        when 72 to 78 =>
            sc_addr     <= x"41";
            sc_wdata    <= MP_BIAS_DEFAULT(step-72);
            sc_we       <= '1';
        when 79 to 108 =>
            sc_addr     <= x"44";
            sc_wdata    <= x"00000000";
            sc_we       <= '1';
        when 109 to 138 =>
            sc_addr     <= x"45";
            sc_wdata    <= x"00000000";
            sc_we       <= '1';
        when 139 to 168 =>
            sc_addr     <= x"46";
            sc_wdata    <= x"00000000";
            sc_we       <= '1';
        when 169 =>
            sc_addr     <= x"40";
            sc_wdata    <= x"0000003F";
            sc_we       <= '1';
        when 170 to 180 =>

        when 181 =>
            sc_addr     <= x"40";
            sc_wdata    <= x"00000000";
            sc_we       <= '1';
        when 182 to 1000000000 =>
        when others =>
            step <= 0;
        end case;
    end if;
    end process;

end architecture;
