library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mutrig_hit_types.all;

entity sorter_in_out_tb is
end entity;

architecture arch of sorter_in_out_tb is

    constant CLK_MHZ : real := 10000.0;
    signal clk, reset_n, running, out_ena, out_is_hit : std_logic := '0';
    signal s_counter125 : std_logic_vector(15 downto 0);
    signal hit : work.mutrig_hit_types.t_hit_presort_div;
    signal state : std_logic_vector(4 downto 0);
    signal out_type : std_logic_vector(3 downto 0);
    signal out_counter, out_data : std_logic_vector(31 downto 0);

begin

    clk <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);

    process(clk, reset_n)
    begin
    if ( reset_n = '0' ) then
        s_counter125 <= (others => '0');
        state <= (others => '0');
        hit.asic <= (others => '0');
        hit.channel <= (others => '0');
        hit.T_CC_div <= (others => '0');
        hit.T_CC_rem <= (others => '0');
        hit.T_Fine <= (others => '0');
        hit.E_Flag <= '0';
        hit.E_CC <= (others => '0');
        hit.valid <= '0';
        running <= '0';
        out_counter <= (others => '0');
        --
    elsif rising_edge(clk) then

        hit.valid <= '0';
        s_counter125 <= s_counter125 + '1';

        if ( out_ena = '1' and out_is_hit = '1' ) then
            out_counter <= out_counter + '1';
        end if;

        if ( s_counter125 > 3 ) then
            running <= '1';
        end if;

        if ( s_counter125 > x"0B2C" ) then
        
            state <= state + '1';

            case state is

                when "00000" =>
                    --

                when "00001" =>
                    --

                when "00010" =>
                    hit.valid <= '1';
                    hit.T_CC_div <= "1011000100000";

                when "00100" =>
                    hit.valid <= '1';
                    hit.T_CC_div <= "1011101000101";

            when "01000" =>
                    hit.valid <= '1';
                    hit.T_CC_div <= "1010001110000"; -- 1100001110000

                when "10000" =>
                    hit.valid <= '1';
                    hit.T_CC_div <= "1010110010101"; -- 1100110010101

                when "10001" =>
                    state <= "10001";

                when others =>
                    --

            end case;
        end if;
    end if;
    end process;

    scifi_sorter : entity work.hitsorter
    generic map(
        IS_SORTER_TWO => 0,
        USE_TRIGGER_g => 0,
        NSORTERINPUTS => 3,
        -- NOTE: minus ISMUTRIG is not the best way to do this.
        --       we need this because the sorter is only designed for
        --       multiple of 3 inputs but we have 2 for Scifi
        --       at the moment this is not working for tile
        TIMESTAMPSIZE => 12,
        HIT_WITHOUT_TS_SIZE => len_hit_presort_div_no_ts,
        IS_SCIFI => 1,
        IS_TILE => 0
    )
    port map(
        -- run control and hit data input
        i_running       => running,
        i_currentts     => s_counter125(11 downto 0),
        i_hit           => work.mutrig_hit_types.t_hit_presort_div_zero & work.mutrig_hit_types.t_hit_presort_div_zero & hit,

        -- hit output
        data_out        => out_data,
        out_ena         => out_ena,
        out_type        => out_type,
        out_is_hit      => out_is_hit,

        -- slow control sorter register
        i_clk156        => '0',
        i_regs_reset_n  => '0',
        i_reg_addr      => (others => '0'),
        i_reg_re        => '0',
        o_reg_rdata     => open,
        i_reg_we        => '0',
        i_reg_wdata     => (others => '0'),

        -- clk / reset
        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

end architecture;
