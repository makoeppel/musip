library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;
use work.mu3e.all;

entity data_generator_a10 is
generic (
    DATA_TYPE : std_logic_vector(5 downto 0) := MUPIX_HEADER_ID
);
port (
    i_enable    : in  std_logic;
    o_data      : out work.mu3e.link32_t;
    i_n_hits    : in  std_logic_vector(31 downto 0);

    o_cnt_hits  : out std_logic_vector(63 downto 0);

    i_reset_n   : in  std_logic;
    i_clk       : in  std_logic
);
end entity;

architecture rtl of data_generator_a10 is

    signal global_time : std_logic_vector(47 downto 0);
    signal next_subheader, next_package, toggle, enable_reg : std_logic;

    type data_header_states is (sop, t0, t1, d0, d1, sbhdr, dthdr, send_last_hits, trailer);
    signal data_header_state : data_header_states;

    signal nEvent, hit_counter : std_logic_vector(31 downto 0);
    signal n_packages : std_logic_vector(15 downto 0);
    signal n_hits, n_subheaders : std_logic_vector(7 downto 0);
    signal cnt_hits : std_logic_vector(63 downto 0);

begin

    o_cnt_hits <= cnt_hits;

    process(i_clk, i_reset_n)
        variable next_hit_count_v : unsigned(31 downto 0);
    begin
    if ( i_reset_n /= '1' ) then
        o_data            <= work.mu3e.LINK32_IDLE;
        hit_counter       <= (others => '0');
        n_hits            <= (others => '0');
        n_subheaders      <= (others => '0');
        n_packages        <= (others => '0');
        enable_reg        <= '0';
        cnt_hits          <= (others => '0');
        data_header_state <= sop;
        nEvent            <= (others => '0');
        global_time       <= (others => '0');
        next_subheader    <= '0';
        next_package      <= '0';
        toggle            <= '0';
        --
    elsif rising_edge(i_clk) then

        -- need to run at 125 MHz
        toggle <= not toggle;
        o_data <= work.mu3e.LINK32_IDLE;
        enable_reg <= i_enable;

        if ( enable_reg = '0' and i_enable = '1' ) then
            n_packages <= i_n_hits(31 downto 16);
        end if;

        if ( toggle = '1' ) then
            global_time    <= global_time + 1;
            next_subheader <= '0';
            next_package   <= '0';

            if (global_time(3 downto 0) = "1110") then
                next_subheader <= '1';
            end if;

            if (global_time(10 downto 0) = "11111111110") then
                next_package <= '1';
            end if;

            if ( i_enable = '1' ) then

                case data_header_state is

                    when sop =>
                        if ( n_packages > 0 ) then
                            hit_counter         <= (others => '0');
                            n_hits              <= i_n_hits(15 downto  8);
                            n_subheaders        <= i_n_hits( 7 downto  0);
                            o_data.data(31 downto 26) <= DATA_TYPE;
                            o_data.data(25 downto 24) <= (others => '0');
                            o_data.data(23 downto 8)  <= (others => '0');
                            o_data.data(7 downto 0)   <= x"BC";
                            o_data.datak              <= "0001";
                            if ( n_packages = x"FFFF" ) then
                                n_packages <= n_packages - 1;
                            end if;
                            data_header_state <= t0;
                        end if;

                    when t0 =>
                        o_data.data  <= global_time(47 downto 16);
                        o_data.datak <= "0000";
                        data_header_state <= t1;

                    when t1 =>
                        o_data.data  <= global_time(15 downto 0) & nEvent(15 downto 0);
                        o_data.datak <= "0000";
                        data_header_state <= d0;

                    when d0 =>
                        o_data.data  <= x"AFFED1D1";
                        o_data.datak <= "0000";
                        data_header_state <= d1;

                    when d1 =>
                        o_data.data  <= x"AFFED2D2";
                        o_data.datak <= "0000";
                        data_header_state <= sbhdr;

                    when sbhdr =>
                        o_data.data <= (others => '0');

                        if ( DATA_TYPE = MUPIX_HEADER_ID ) then
                            o_data.data(31 downto 24) <= '0' & global_time(10 downto 4);
                        elsif ( DATA_TYPE = SCIFI_HEADER_ID ) then
                            o_data.data(31 downto 24) <= global_time(11 downto 4);
                        else
                            o_data.data(31 downto 24) <= (others => '0');
                        end if;

                        if ( n_subheaders > 0) then
                            n_subheaders <= n_subheaders - 1;
                            n_hits <= i_n_hits(15 downto 8);
                        else
                            n_hits <= (others => '0');
                        end if;

                        o_data.data(7 downto 0) <= work.util.K23_7;
                        o_data.datak <= "0001";
                        data_header_state <= dthdr;
                        hit_counter <= (others => '0');

                    when dthdr =>
                        if ( n_hits > 0 ) then
                            -- o_data.data  <= (others => '0');
                            -- o_data.data(31 downto 28) <= global_time(3 downto 0);
                            o_data.data <= cnt_hits(31 downto 0);
                            o_data.datak <= "0000";

                            cnt_hits <= cnt_hits + '1';

                            n_hits <= n_hits - 1;
                        end if;

                        if ( next_package = '1' ) then
                            data_header_state <= trailer;
                        elsif ( next_subheader = '1' ) then
                            data_header_state <= sbhdr;
                        end if;

                    when trailer =>
                        o_data.data(31 downto 8) <= (others => '0');
                        o_data.data(7 downto 0)  <= x"9C";
                        o_data.datak             <= "0001";

                        nEvent <= nEvent + 1;
                        data_header_state <= sop;

                    when others =>
                        data_header_state <= sop;

                end case;
            end if;
        end if;
    end if;
    end process;

end architecture;