library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

use work.util_slv.all;

use work.a10_pcie_registers.all;
use work.mudaq.all;
use work.hit_stream_pkg.all;

entity tb_time_merger is
end entity;

architecture arch of tb_time_merger is

    constant CLK_MHZ : real := 10000.0; -- MHz
    signal clk, reset_n, reset_n2 : std_logic := '0';

    signal rx, rx_in : work.mu3e.link32_array_t(7 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal rx_q : work.mu3e.link64_array_t(7 downto 0) := (others => work.mu3e.LINK64_IDLE);
    signal data : work.mu3e.link64_t;
    type my_array_t is array (7 downto 0) of integer;
    signal package_stage : my_array_t;
    signal rdempty, ren : std_logic_vector(7 downto 0);
    signal merger_empty : std_logic;

begin

    clk <= not clk after 4 ns;
    reset_n <= '0', '1' after 128 ns;
    reset_n2 <= '0', '1' after 256 ns;


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

        o_q             => rx_q,
        i_ren           => ren,
        o_rdempty       => rdempty,

        o_counter       => open,
        i_reset_n_cnt   => reset_n,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    e_time_merger : entity work.swb_time_merger
    generic map (
        g_NLINKS_DATA => 8--,
    )
    port map (
        i_rx            => rx_q,
        i_rempty        => rdempty,
        i_rmask_n       => (others => '1'),
        o_rack          => ren,

        o_counters      => open,

        -- farm data
        o_wdata         => data,
        o_rempty        => merger_empty,
        i_ren           => not merger_empty,

        -- data for debug readout
        o_wdata_debug   => open,
        o_rempty_debug  => open,
        i_ren_debug     => '0',

        o_error         => open,

        i_data_type     => (others => '0'),

        i_en            => '1',
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

    capture_proc : process
        file f_out : text open write_mode is "test_output.txt";
        variable L : line;
        variable wrote : integer := 0;
    begin
        -- start as soon as reset is deasserted
        wait until reset_n2 = '1';
        wait until rising_edge(clk);  -- one settling edge

        report work.util.SGR_FG_RED & "Start writing" & work.util.SGR_RESET;

        -- run for a bounded number of cycles (fits in 10 ns)
        while true loop
            if (wrote = (LINK0_PKG0_LEN * 8) - ((128+6) * 7)) then
                exit;
            else
                wait until rising_edge(clk);
                report work.util.SGR_FG_RED & integer'image(wrote) & work.util.SGR_RESET;
                report work.util.SGR_FG_RED & integer'image(((LINK0_PKG0_LEN * 8) - ((128+6) * 7))) & work.util.SGR_RESET;
                if merger_empty = '0' then
                    hwrite(L, data.data);
                    writeline(f_out, L);
                    wrote := wrote + 1;
                end if;
            end if;
        end loop;

        file_close(f_out);
        report "File writing done";
        report "Simulation finished";
    end process;

end architecture;
