-- mupix PLL lock monitor reg mapping
-- M. Mueller, Jan 2022

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.mupix_registers.all;
use work.mupix.all;
use work.mudaq.all;

entity mp_pll_lock_reg_mapping is
port (
    i_reg_addr                  : in  std_logic_vector(15 downto 0);
    i_reg_re                    : in  std_logic;
    o_reg_rdata                 : out std_logic_vector(31 downto 0);
    i_reg_we                    : in  std_logic;
    i_reg_wdata                 : in  std_logic_vector(31 downto 0);

    i_reset_156_n               : in  std_logic := '1';
    i_clk_156                   : in  std_logic;

    i_hit_ena                   : in  std_logic_vector(35 downto 0) := (others => '0');
    i_counter                   : in  std_logic_vector(31 downto 0);

    i_reset_125_n               : in  std_logic := '1';
    i_clk_125                   : in  std_logic--;
);
end entity;

architecture rtl of mp_pll_lock_reg_mapping is

    signal arrival_time_distr           : reg32array(36*4-1 downto 0);
    signal upper_bits                   : std_logic_vector(36*4+1 downto 0);
    signal overflows                    : std_logic_vector(35 downto 0);

    signal arrival_time_distr_buffer    : reg32array(36*4-1 downto 0) := (others => (others => '0'));
    signal arrival_time_distr156        : reg32array(36*4-1 downto 0);

begin

    genupper: for I in 0 to 36*4-1 generate
        upper_bits(I) <= arrival_time_distr(I)(31);
    end generate;

    genoverflow: for I in 0 to 35 generate
        overflows(I) <= or_reduce(upper_bits(I*4+3 downto I*4));
    end generate;


    process(i_clk_125, i_reset_125_n)
    begin
    if ( i_reset_125_n = '0' ) then
        arrival_time_distr <= (others => (others => '1'));
    elsif rising_edge(i_clk_125)  then
        for I in 0 to 35 loop
            for J in 0 to 3 loop
                if(i_hit_ena(I) = '1') then
                    if ( i_counter(1 downto 0) = J ) then
                        arrival_time_distr(I*4+J) <= arrival_time_distr(I*4+J) + 1;
                    end if;
                end if;
                if(overflows(I) = '1') then
                    arrival_time_distr(I*4+J) <= '0' & arrival_time_distr(I*4+J)(31 downto 1); -- divide all 4 counters by 2 if max. is reached in one of them
                end if;
            end loop;
        end loop;

        if(i_counter(10 downto 8) = "001") then
            arrival_time_distr_buffer <= arrival_time_distr;
        end if;

    end if;
    end process;

    process(i_clk_156, i_reset_156_n)
        variable regaddr : integer;
    begin
    if ( i_reset_156_n = '0' ) then
        arrival_time_distr156 <= (others => (others => '0'));
    elsif rising_edge(i_clk_156) then
        if ( i_counter(10) = '1' ) then
            arrival_time_distr156 <= arrival_time_distr_buffer;
        end if;

        regaddr := to_integer(unsigned(i_reg_addr));

        for I in 0 to 36*4-1 loop
            if ( regaddr = I + MP_HIT_ARRIVAL_START_REGISTER_R and i_reg_re = '1' ) then
                o_reg_rdata <= arrival_time_distr156(I);
            end if;
        end loop;

    end if;
    end process;

end architecture;
