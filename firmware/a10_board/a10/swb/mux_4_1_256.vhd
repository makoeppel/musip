----------------------------------
--
-- 4 to 1 256bit hit multiplexer
-- Assume hits at maximum every fourth cycle
--
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_slv.all;

entity mux_4_1_256 is
generic (
    N : integer := 4--;
);
port (
    i_data      : in    slv256_array_t(N - 1 downto 0);
    i_valid     : in    std_logic_vector(N - 1 downto 0);

    o_data      : out   std_logic_vector(255 downto 0);
    o_sel_link  : out   std_logic_vector(1 downto 0);
    o_valid     : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture rtl of mux_4_1_256 is

    signal data_out : std_logic_vector(255 downto 0);
    signal data_in_buffer : slv256_array_t(N - 1 downto 0);
    signal data_valid_buffer : std_logic_vector(N - 1 downto 0);
    signal data_taken : std_logic_vector(N - 1 downto 0);

begin

    o_data <= data_out;

    process(i_clk, i_reset_n) is
        variable position : integer range 0 to N;
    begin
    if ( i_reset_n = '0' ) then
        data_valid_buffer <= (others => '0');
        data_taken <= (others => '0');
        o_valid <= '0';
    elsif rising_edge(i_clk) then
        data_taken <= (others => '0');
        o_valid <= '0';
        data_valid_buffer <= i_valid or (data_valid_buffer and (not data_taken));

        for i in 0 to N - 1 loop
            if(i_valid(i) = '1') then
                data_in_buffer(i)  <= i_data(i);
            end if;
        end loop;

        position := work.util.count_leading_zeroes((data_valid_buffer and (not data_taken)));
        if ( position /= N ) then
            data_out <= data_in_buffer(position);
            -- NOTE: this is for debugging
            data_out(3 downto 0) <= (position => '1', others => '0');
            o_valid <= '1';
            data_taken <= (position => '1', others => '0');
        end if;
    end if;
    end process;

end architecture;
