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

entity mux_4_1_256 is
generic (
    g_LINK_N    : positive := 4
);
port (
    i_data      : in    slv256_array_t(g_LINK_N-1 downto 0);
    i_valid     : in    std_logic_vector(g_LINK_N-1 downto 0);

    o_data      : out   std_logic_vector(255 downto 0);
    o_sel_link  : out   std_logic_vector(1 downto 0);
    o_valid     : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic
);
end entity;

architecture RTL of mux_4_1_256 is

    signal data_store        : slv256_array_t(g_LINK_N-1 downto 0);
    signal data_out          : std_logic_vector(255 downto 0);
    signal sel_link_out      : std_logic_vector(1 downto 0);
    signal valid_out         : std_logic;

    signal ena               : std_logic_vector(g_LINK_N-1 downto 0);
    signal ena_del1          : std_logic_vector(g_LINK_N-1 downto 0);
    signal ena_del2          : std_logic_vector(g_LINK_N-1 downto 0);
    signal ena_del3          : std_logic_vector(g_LINK_N-1 downto 0);

    signal ena_del1_nors     : std_logic_vector(g_LINK_N-1 downto 0);
    signal ena_del2_nors     : std_logic_vector(g_LINK_N-1 downto 0);
    signal ena_del3_nors     : std_logic_vector(g_LINK_N-1 downto 0);

begin

    o_data      <= data_out;
    o_sel_link  <= sel_link_out;
    o_valid     <= valid_out;

    process(i_clk, i_reset_n)
        variable v_sel_found : boolean;
    begin
    if ( i_reset_n = '0' ) then
        valid_out       <= '0';
        data_out        <= (others => '0');
        sel_link_out    <= (others => '0');

        data_store      <= (others => (others => '0'));

        ena             <= (others => '0');
        ena_del1        <= (others => '0');
        ena_del2        <= (others => '0');
        ena_del3        <= (others => '0');

        ena_del1_nors   <= (others => '0');
        ena_del2_nors   <= (others => '0');
        ena_del3_nors   <= (others => '0');

    elsif rising_edge(i_clk) then

        ena             <= (i_valid and (not ena)) and (not ena_del1_nors);
        ena_del1        <= ena;
        ena_del2        <= ena_del1;
        ena_del3        <= ena_del2;

        ena_del1_nors   <= ena;
        ena_del2_nors   <= ena_del1_nors;
        ena_del3_nors   <= ena_del2_nors;

        for i in 0 to g_LINK_N-1 loop
            if (i_valid(i) = '1' and ena(i) = '0' and ena_del1_nors(i) = '0') then
                data_store(i) <= i_data(i);
            end if;
        end loop;

        valid_out   <= '0';
        v_sel_found := false;

        for i in 0 to g_LINK_N-1 loop
            if (ena_del3(i) = '1' and not v_sel_found) then
                data_out        <= data_store(i);
                sel_link_out    <= std_logic_vector(to_unsigned(i, o_sel_link'length));
                valid_out       <= '1';
                v_sel_found     := true;
            end if;
        end loop;

        if (not v_sel_found) then
            for i in 0 to g_LINK_N-1 loop
                if (ena_del2(i) = '1' and not v_sel_found) then
                    data_out        <= data_store(i);
                    sel_link_out    <= std_logic_vector(to_unsigned(i, o_sel_link'length));
                    valid_out       <= '1';
                    ena_del3(i)     <= '0';
                    v_sel_found     := true;
                end if;
            end loop;
        end if;

        if (not v_sel_found) then
            for i in 0 to g_LINK_N-1 loop
                if (ena_del1(i) = '1' and not v_sel_found) then
                    data_out        <= data_store(i);
                    sel_link_out    <= std_logic_vector(to_unsigned(i, o_sel_link'length));
                    valid_out       <= '1';
                    ena_del2(i)     <= '0';
                    v_sel_found     := true;
                end if;
            end loop;
        end if;

        if (not v_sel_found) then
            for i in 0 to g_LINK_N-1 loop
                if (ena(i) = '1' and not v_sel_found) then
                    data_out        <= data_store(i);
                    sel_link_out    <= std_logic_vector(to_unsigned(i, o_sel_link'length));
                    valid_out       <= '1';
                    ena_del1(i)     <= '0';
                    v_sel_found     := true;
                end if;
            end loop;
        end if;

    end if;
    end process;

end architecture;