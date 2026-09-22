
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity data_generator_mupix is
port (
    i_enable_pix    : in    std_logic;
    i_dma_half_full : in    std_logic;
    i_skip_hits     : in    std_logic_vector(3 downto 0);
    i_fpga_id       : in    std_logic_vector(15 downto 0);
    i_slow_down     : in    std_logic_vector(31 downto 0);
    o_data          : out   std_logic_vector(31 downto 0);
    o_datak         : out   std_logic_vector(3 downto 0);
    o_data_ready    : out   std_logic;
    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture rtl of data_generator_mupix is

    signal global_time : std_logic_vector(47 downto 0);
    -- state_types
    type data_header_states is (preamble, ts1, ts2, sheader, hit, trailer);
    signal data_header_state : data_header_states;

    -- random signals
    signal lsfr_overflow : std_logic_vector(15 downto 0);

    -- slow down signals
    signal waiting       : std_logic;
    signal wait_counter  : std_logic_vector(31 downto 0);

begin

    -- slow down process
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        waiting <= '0';
        wait_counter <= (others => '0');
    elsif rising_edge(i_clk) then
        if(wait_counter >= i_slow_down) then
            wait_counter <= (others => '0');
            waiting <= '0';
        else
            wait_counter <= wait_counter + '1';
            waiting <= '1';
        end if;
    end if;
    end process;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_data_ready     <= '0';
        data_header_state  <= preamble;
        global_time        <= (others => '0');
        o_data             <= (others => '0');
        o_datak <= (others => '1');
    elsif rising_edge(i_clk) then
        if(i_enable_pix = '1' and waiting = '0' and i_dma_half_full = '0') then

            o_data_ready <= '1';

                case data_header_state is
                when preamble =>
                    o_data(31 downto 26) <= "111010";
                    o_data(25 downto 24) <= (others => '0');
                    o_data(23 downto 8) <= i_fpga_id;
                    o_data(7 downto 0) <= x"bc";
                    o_datak <= "0001";
                    data_header_state <= ts1;

                when ts1 =>
                    o_data(31 downto 0) <= global_time(47 downto 16);
                    o_datak <= "0000";
                    data_header_state <= ts2;

                when ts2 =>
                    o_data(31 downto 16) <= global_time(15 downto 0);
                    o_data(15 downto 0) <= (others => '0');
                    o_datak <= "0000";
                    data_header_state <= sheader;

                when sheader =>
                    o_data(31 downto 28) <= "0000";
                    o_data(27 downto 22) <= "111111";
                    o_data(21 downto 16) <= global_time(9 downto 4);
                    -- TODO better overflow values
                    o_data(15 downto 0) <= x"0000";
                    o_datak <= "0000";
                    data_header_state <= hit;

                when hit =>

                    global_time <= global_time + '1';
                    o_data(31 downto 28) <= global_time(3 downto 0);
                    -- TODO better chip id, row, col and tot
                    o_data(27 downto 0) <= (others => '0');
                    o_datak <= "0000";

                    if ( global_time(3 downto 0) + '1' = i_skip_hits ) then
                        global_time <= global_time + "10";
                    end if;

                    if (global_time(9 downto 0) = "1111111111") then
                        data_header_state <= trailer;
                    elsif (global_time(3 downto 0) = "1111") then
                        data_header_state <= sheader;
                    end if;

                when trailer =>
                    global_time <= global_time + '1';
                    o_data(31 downto 8) <= (others => '0');
                    o_data(7 downto 0) <= x"9c";
                    o_datak <= "0001";
                    data_header_state <= data_header_state;

                when others =>
                    data_header_state <= data_header_state;

                end case;
        else
            o_data <= x"000000BC";
            o_datak <= "0001";
            o_data_ready <= '0';
        end if;
    end if;
    end process;

end architecture;
