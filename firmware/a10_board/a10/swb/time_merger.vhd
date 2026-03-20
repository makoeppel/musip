library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.util_slv.all;

use work.mudaq.all;

-- merge packets delimited by SOP and EOP from N input streams
entity time_merger is
generic (
    g_ADDR_WIDTH : positive := 11;
    g_LINK_SWB : std_logic_vector(3 downto 0) := "0000";
    g_NLINKS_DATA : positive := 8--;
);
port (
    -- input streams
    i_data          : in    work.mu3e.link64_array_t(g_NLINKS_DATA-1 downto 0);
    i_empty         : in    std_logic_vector(g_NLINKS_DATA-1 downto 0);
    i_mask_n        : in    std_logic_vector(g_NLINKS_DATA-1 downto 0);
    o_rack          : out   std_logic_vector(g_NLINKS_DATA-1 downto 0); -- read ACK

    -- output stream
    o_rdata         : out   work.mu3e.link64_t; -- output is hit
    i_rack          : in    std_logic;
    o_empty         : out   std_logic;

    -- counters
    o_counters      : out   slv32_array_t(3 * (N_LINKS_TREE(3) + N_LINKS_TREE(2) + N_LINKS_TREE(1)) - 1 downto 0);

    i_data_type     : in    std_logic_vector(5 downto 0) := MUPIX_HEADER_ID;

    i_en            : in    std_logic;
    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture arch of time_merger is

    -- input signals
    signal data : work.mu3e.link64_array_t(N_LINKS_TREE(0) - 1 downto 0);
    signal countersL0 : slv32_array_t(3 * N_LINKS_TREE(1) - 1 downto 0);
    signal empty, mask_n, rack : std_logic_vector(N_LINKS_TREE(0) - 1 downto 0) := (others => '0');

    -- layer0
    signal data0 : work.mu3e.link64_array_t(N_LINKS_TREE(1) - 1 downto 0);
    signal countersL1 : slv32_array_t(3 * N_LINKS_TREE(2) - 1 downto 0);
    signal empty0, mask0_n, rack0 : std_logic_vector(N_LINKS_TREE(1) - 1 downto 0);

    -- layer1
    signal data1 : work.mu3e.link64_array_t(N_LINKS_TREE(2) - 1 downto 0);
    signal countersL2 : slv32_array_t(3 * N_LINKS_TREE(3) - 1 downto 0);
    signal empty1, mask1_n, rack1 : std_logic_vector(N_LINKS_TREE(2) - 1 downto 0);

    -- merger signals
    signal sop, eop, t0, t1, d0, d1, sbhdr, dthdr, rack_idx : std_logic_vector(g_NLINKS_DATA-1 downto 0);
    type merger_state_type is (idle_state,d0_state,d1_state,t0_state,t1_state,merge_state,waiting,eop_state,sbhdr_state);
    signal merger_state, last_state : merger_state_type;
    signal almost_full, we : std_logic;
    signal w_data : work.mu3e.link64_t;
    signal cnt_t1_error, cnt_sub_error : std_logic_vector(31 downto 0);

begin

    gen_input: FOR i in 0 to g_NLINKS_DATA - 1 GENERATE
        sop(i) <= (i_data(i).sop and not i_empty(i)) or not i_mask_n(i);
        eop(i) <= (i_data(i).eop and not i_empty(i)) or not i_mask_n(i);
        t0(i) <= (i_data(i).t0 and not i_empty(i)) or not i_mask_n(i);
        t1(i) <= (i_data(i).t1 and not i_empty(i)) or not i_mask_n(i);
        d0(i) <= (i_data(i).d0 and not i_empty(i)) or not i_mask_n(i);
        d1(i) <= (i_data(i).d1 and not i_empty(i)) or not i_mask_n(i);
        sbhdr(i) <= (i_data(i).sbhdr and not i_empty(i)) or not i_mask_n(i);
        dthdr(i) <= i_data(i).dthdr and not i_empty(i);
    END GENERATE;

    merger_state <= idle_state when and_reduce(sop) = '1' else
                    t0_state when and_reduce(t0) = '1' and last_state = idle_state else
                    t1_state when and_reduce(t1) = '1' and last_state = t0_state else
                    d0_state when and_reduce(d0) = '1' and last_state = t1_state else
                    d1_state when and_reduce(d1) = '1' and last_state = d0_state else
                    sbhdr_state when and_reduce(sbhdr) = '1' else
                    eop_state when and_reduce(eop) = '1' else
                    merge_state;

    o_rack <= (others => '1') when merger_state /= merge_state else rack_idx;

    process(all)
        variable tmp_idx : std_logic_vector(dthdr'range);
        variable tmp_data : work.mu3e.link64_t;
    begin
        tmp_idx := (others => '0');
        tmp_data := work.mu3e.LINK64_ZERO;
 
        if (merger_state = merge_state) then
            for i in dthdr'low to dthdr'high loop  -- LSB has priority
                -- NOTE: we dont care if we are sorted here
                -- its better to sorter later or never
                if (dthdr(i) = '1' and i_empty(i) = '0') then
                    tmp_idx(i) := '1';
                    tmp_data := i_data(i);
                    exit;
                end if;
            end loop;
        end if;

        if (tmp_idx = 0) then -- set value when we are not in a merger state
            for i in dthdr'low to dthdr'high loop  -- LSB has priority
                if (i_mask_n(i) = '1') then
                    tmp_data := i_data(i);
                    exit;
                end if;
            end loop;
        end if;

        rack_idx <= tmp_idx;
        w_data <= tmp_data;
    end process;

    we <= '1' when merger_state /= merge_state else or_reduce(rack_idx) and not almost_full;

    -- set last layer state
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        last_state <= idle_state;
        cnt_t1_error <= (others => '0');
        cnt_sub_error <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        if ( merger_state /= merge_state ) then
            last_state <= merger_state;
        end if;
        -- TODO: check if one is masked, make it dynamic to check for any mismatch
        if ( merger_state = t1_state and i_data(0).data(31 downto 16) /= i_data(1).data(31 downto 16) ) then
            cnt_t1_error <= cnt_t1_error + 1;
        end if;
        if ( merger_state = sbhdr_state and i_data(0).data(31 downto 24) /= i_data(1).data(31 downto 24) ) then
            cnt_sub_error <= cnt_sub_error + 1;
        end if;
    end if;
    end process;

    e_fifo_out : entity work.link64_scfifo
    generic map (
        g_ADDR_WIDTH => 14,
        g_WREG_N => 2,
        g_RREG_N => 2--,
    )
    port map (
        i_wdata => w_data,
        i_we => we,
        o_almost_full => almost_full,

        o_rdata => o_rdata,
        i_rack => i_rack,
        o_rempty => o_empty,

        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

end architecture;
