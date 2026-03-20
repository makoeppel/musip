library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.a10_pcie_registers.all;
use work.mudaq.all;
use work.hit_stream_pkg.all;

entity tb_links_to_fifos is
end entity;

architecture arch of tb_links_to_fifos is

    constant CLK_MHZ : real := 10000.0; -- MHz
    signal clk, reset_n, reset_n2 : std_logic := '0';

    signal rx, rx_in : work.mu3e.link32_array_t(7 downto 0) := (others => work.mu3e.LINK32_IDLE);
    type my_array_t is array (7 downto 0) of integer;
    signal package_stage : my_array_t;
    signal rdempty : std_logic_vector(7 downto 0);

begin

    clk     <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);
    reset_n2 <= '0', '1' after (2.0 us / CLK_MHZ);


    --! links to fifos
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_links_to_fifos : entity work.links_to_fifos
    generic map (
        g_LINK_N => 8--,
    )
    port map (
        i_rx            => rx_in,
        i_rmask_n       => (others => '1'),

        i_lookup_ctrl   => (others => '1'),
        i_sync_enable   => '1',

        o_q             => open,
        i_ren           => open,
        o_rdempty       => rdempty,

        o_counter       => open,
        i_reset_n_cnt   => reset_n,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    gen_chip_lookup_and_fifos : for i in 0 to 7 GENERATE

        stim_proc : process
        begin
        if ( reset_n2 = '0' ) then
            rx(i).data <= x"000000BC";
            rx(i).datak <= "0001";
        else
            for j in 0 to LINK0_PKG0_LEN-1 loop
                rx(i).data <= LINK0_PKG0_WORDS(j);
                rx(i).datak <= "000" & LINK0_PKG0_K(j);
                wait until rising_edge(clk);
            end loop;
        end if;
        wait until rising_edge(clk);
        end process;

        rx_in(i) <= work.mu3e.to_link(rx(i).data, rx(i).datak);

    end generate;

end architecture;
