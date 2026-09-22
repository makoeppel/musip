-- simple data generator (for slowcontrol and pixel data)
-- writes into pix_data_fifo and sc_data_fifo
-- only Header(sc or pix) + data
-- other headers/signals are added in data_merger.vhd

-- Martin Mueller, January 2019
-- Marius Koeppel, March 2019

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

entity data_generator is
port (
    i_enable_pix            : in    std_logic;
    --i_enable_sc             : in    std_logic;
    i_random_seed           : in    std_logic_vector(15 downto 0);
    o_data_pix_generated    : out   std_logic_vector(35 downto 0);
    --o_data_sc_generated     : out   std_logic_vector(31 downto 0);
    o_data_pix_ready        : out   std_logic;
    --o_data_sc_ready         : out   std_logic;
    i_start_global_time     : in    std_logic_vector(47 downto 0);
    -- TODO: add some rate control
    i_reset_n               : in    std_logic;
    i_clk                   : in    std_logic--;
);
end entity;

architecture rtl of data_generator is

    --signal sc_data_counter : std_logic_vector(3 downto 0);
    signal global_time : std_logic_vector(47 downto 0);
    -- state_types
    type data_header_states is (part1, part2, part3, part4, trailer, overflow);
    signal data_header_state: data_header_states;

    -- random signals
    signal lsfr_chip_id : std_logic_vector(5 downto 0);
    signal lsfr_tot : std_logic_vector(5 downto 0);
    signal lsfr_row : std_logic_vector(7 downto 0);
    signal lsfr_col : std_logic_vector(7 downto 0);
    signal lsfr_overflow : std_logic_vector(15 downto 0);
    signal wait_cnt : std_logic_vector(1 downto 0);

begin

    chip_id_shift : entity work.linear_shift
    generic map (
        g_m => 6,
        g_poly => "110000"
    )
    port map (
        i_sync_reset    => not i_reset_n,--sync_reset,
        i_seed          => i_random_seed(5 downto 0),
        i_en            => i_enable_pix,
        o_lfsr          => lsfr_chip_id,
        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    pix_tot_shift : entity work.linear_shift
    generic map (
        g_m => 6,
        g_poly => "110000"
    )
    port map (
        i_sync_reset    => not i_reset_n,--sync_reset,
        i_seed          => i_random_seed(15 downto 10),
        i_en            => i_enable_pix,
        o_lfsr          => lsfr_tot,
        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    pix_row_shift : entity work.linear_shift
    generic map (
        g_m => 8,
        g_poly => "10111000"
    )
    port map (
        i_sync_reset    => not i_reset_n,--sync_reset,
        i_seed          => i_random_seed(7 downto 0),
        i_en            => i_enable_pix,
        o_lfsr          => lsfr_row,
        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    pix_col_shift : entity work.linear_shift
    generic map (
        g_m => 8,
        g_poly => "10111000"
    )
    port map (
        i_sync_reset    => not i_reset_n,--sync_reset,
        i_seed          => i_random_seed(8 downto 1),
        i_en            => i_enable_pix,
        o_lfsr          => lsfr_col,
        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    overflow_shift : entity work.linear_shift
    generic map (
        g_m => 16,
        g_poly => "1101000000001000"
    )
    port map (
        i_sync_reset    => not i_reset_n,--sync_reset,
        i_seed          => i_random_seed,
        i_en            => i_enable_pix,
        o_lfsr          => lsfr_overflow,
        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    process(i_clk, i_reset_n)
        variable current_overflow : std_logic_vector(15 downto 0) := "0000000000000000";
        variable overflow_idx : integer range 0 to 15 := 0;
    begin
    if ( i_reset_n /= '1' ) then
        o_data_pix_ready        <= '0';
        --data_sc_ready           <= '0';
        o_data_pix_generated    <= (others => '0');
        --data_sc_generated       <= (others => '0');
        global_time             <= i_start_global_time;
        --sc_data_counter         <= (others => '1');
        data_header_state       <= part1;
        wait_cnt                <= (others => '0');
        current_overflow        := "0000000000000000";
        overflow_idx            := 0;
    elsif rising_edge(i_clk) then
        -- generate pix data
        if(i_enable_pix='1') then
            wait_cnt <= wait_cnt + '1';
            if (wait_cnt = "11") then
                o_data_pix_ready <= '1';
                case data_header_state is
                when trailer =>
                    o_data_pix_generated(35 downto 32) <= "0011";
                    o_data_pix_generated(31 downto 0) <= (others => '0');
                    data_header_state <= part1;
                when part1 =>
                    o_data_pix_generated <= "0010" & global_time(47 downto 16);
                    data_header_state <= part2;
                when part2 =>
                    o_data_pix_generated <= "0000" & global_time(15 downto 0) & x"0000";
                    data_header_state <= part3;
                when part3 =>
                    o_data_pix_generated <= "0000" & "0000" & DATA_SUB_HEADER_ID & global_time(9 downto 4) & lsfr_overflow;
                    global_time <= global_time + '1';
                    overflow_idx := 0;
                    current_overflow := lsfr_overflow;
                    data_header_state <= part4;
                when part4 =>
                    if (lsfr_chip_id = DATA_SUB_HEADER_ID) then
                        o_data_pix_generated <= "0000" & global_time(3 downto 0) & "000000" & global_time(21 downto 0);-- "101010" & lsfr_row & lsfr_col & lsfr_tot;
                    elsif (lsfr_chip_id = MUPIX_HEADER_ID) then
                        o_data_pix_generated <= "0000" & global_time(3 downto 0) & "000000" & global_time(21 downto 0); -- "010101" & lsfr_row & lsfr_col & lsfr_tot;
                    else
                        o_data_pix_generated <= "0000" & global_time(3 downto 0) & "000000" & global_time(21 downto 0); --lsfr_chip_id & lsfr_row & lsfr_col & lsfr_tot;
                    end if;

                    if (current_overflow(overflow_idx) = '1') then
                        overflow_idx := overflow_idx + 1;
                        data_header_state <= overflow;
                    else
                        overflow_idx := overflow_idx + 1;
                        global_time <= global_time + '1';
                    end if;

                    if (global_time(9 downto 0) = "1111111111") then
                        data_header_state <= trailer;
                    elsif (global_time(3 downto 0) = "1111") then
                        data_header_state <= part3;
                    end if;
                when overflow =>
                    if (lsfr_chip_id = DATA_SUB_HEADER_ID) then
                        o_data_pix_generated <= "0000" & global_time(3 downto 0) & "000000" & global_time(21 downto 0);-- "101010" & lsfr_row & lsfr_col & lsfr_tot;
                    elsif (lsfr_chip_id = MUPIX_HEADER_ID) then
                        o_data_pix_generated <= "0000" & global_time(3 downto 0) & "000000" & global_time(21 downto 0); -- "010101" & lsfr_row & lsfr_col & lsfr_tot;
                    else
                        o_data_pix_generated <= "0000" & global_time(3 downto 0) & "000000" & global_time(21 downto 0); --lsfr_chip_id & lsfr_row & lsfr_col & lsfr_tot;
                    end if;
                    global_time <= global_time + '1';
                    data_header_state <= part4;
                when others =>
                    data_header_state <= trailer;
                    ---
                end case;
            else
                o_data_pix_ready <= '0';
            end if;
        else
            o_data_pix_ready <= '0';
        end if;

        -- generate sc data
        --if(i_enable_sc='1') then
        --    if(sc_data_counter(3) = '1')then
        --        o_data_sc_generated <= "0000" & SC_HEADER_ID &"000000"& x"0000";
        --        o_data_sc_ready <= '1';
        --       sc_data_counter <= (others => '0');
        --    else
        --        o_data_sc_generated <= (8 =>'1',others => '0');
        --        sc_data_counter <= sc_data_counter + '1';
        --        o_data_sc_ready   <= '1';
        --    end if;
        --else
        --    o_data_sc_ready <= '0';
        --    sc_data_counter <= (others => '1');
        --end if;

    end if;
    end process;

end architecture;
