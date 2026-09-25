-----------------------------------
--
-- On detector FPGA for layer 0/1
-- Receiver block for all the LVDS links
-- Niklaus Berger, May 2013
--
-- nberger@physi.uni-heidelberg.de
--
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.lvds_registers.all;

entity mupix_receiver_block is
generic (
    g_ALIGNER_MODE : integer := 0; -- 0: bit slip, 1: adaptive
    g_INPUTS : integer := 36;
    g_CHIPS : integer := 15;
    g_IS_TELESCOPE : std_logic := '0'--;
);
port (
    rx_in           : in    std_logic_vector(g_INPUTS-1 DOWNTO 0);
    rx_inclock_A    : in    std_logic;
    rx_inclock_B    : in    std_logic;

    o_rx_status     : out   lvds_status_array_t(g_INPUTS-1 downto 0);
    o_rx_ready      : out   std_logic_vector(g_INPUTS-1 downto 0);
    i_rx_invert     : in    std_logic_vector(35 downto 0) := (others => '0');
    o_rx_data       : out   slv8_array_t(g_INPUTS-1 downto 0);
    o_rx_k          : out   std_logic_vector(g_INPUTS-1 downto 0);
    o_rx_bad        : out   std_logic_vector(g_INPUTS-1 downto 0);

    i_reset_n       : in    std_logic;
    i_clk_global    : in    std_logic--;
);
end entity;

architecture rtl of mupix_receiver_block is

    signal rx_reset_n           : std_logic_vector(g_INPUTS-1 DOWNTO 0);

    signal rx_out               : std_logic_vector(g_INPUTS*10-1 downto 0);
    signal rx_out_temp          : std_logic_vector(g_INPUTS*10-1 downto 0);
    signal rx_clk               : std_logic_vector(1 downto 0);

    signal rx_sync_fifo_empty   : std_logic_vector(1 downto 0);
    signal rx_sync_fifo_rd      : std_logic_vector(1 downto 0);

    signal rx_data, rx_data_s   : std_logic_vector(g_INPUTS*8-1 downto 0);
    signal rx_k, rx_k_s         : std_logic_vector(g_INPUTS-1 downto 0);
    signal rx_bad               : std_logic_vector(g_INPUTS-1 downto 0);
    signal rx_data_out_buffer   : std_logic_vector(g_INPUTS*8-1 downto 0);
    signal rx_k_out_buffer      : std_logic_vector(g_INPUTS-1 downto 0);
    signal rx_bad_out_buffer    : std_logic_vector(g_INPUTS-1 downto 0);

    signal rx_dpa_locked        : std_logic_vector(g_INPUTS-1 DOWNTO 0);
    signal rx_align             : std_logic_vector(g_INPUTS-1 DOWNTO 0);
    signal rx_fifo_reset        : std_logic_vector(g_INPUTS-1 DOWNTO 0);
    signal rx_reset             : std_logic_vector(g_INPUTS-1 DOWNTO 0);

    signal rx_locked            : std_logic_vector(1 downto 0);


    signal rx_inclock_A_ctrl    : std_logic;

    signal rx_ready             : std_logic_vector(g_INPUTS-1 downto 0);
    signal disp_err             : std_logic_vector(g_INPUTS-1 downto 0);
    signal err8b10b             : std_logic_vector(g_INPUTS-1 downto 0);
    type   disp_err_counter_t   is array (natural range <>) of std_logic_vector(31 downto 0);
    signal disp_err_counter     : disp_err_counter_t(g_INPUTS-1 downto 0);
    signal err8b10b_counter     : disp_err_counter_t(g_INPUTS-1 downto 0);
    type   rx_aligncnt_t        is array (natural range <>) of std_logic_vector(5 downto 0);
    signal rx_aligncnt          : rx_aligncnt_t(g_INPUTS-1 downto 0);

begin

    -- a little clk stunt to make the lvds transceiver work:
    -- synthesis read_comments_as_HDL on
    -- lvds_clk_ctrl : component work.cmp.clk_ctrl_single
    -- port map (
    --     inclk  => rx_inclock_A,
    --     outclk => rx_inclock_A_ctrl
    -- );
    -- synthesis read_comments_as_HDL off

    gen2ndrec: if ( g_IS_TELESCOPE = '0' ) GENERATE
        -- synthesis read_comments_as_HDL on
        -- lvds_rec_small : entity work.ip_altlvds_rx
        -- generic map ( g_CHANNELS => 27, g_DESER_FACTOR => 10 )
        -- port map (
        --     rx_channel_data_align   => rx_align(26 downto 0),
        --     rx_fifo_reset           => rx_fifo_reset(26 downto 0),
        --     rx_in                   => rx_in(26 downto 0),
        --     rx_inclock              => rx_inclock_A_ctrl,
        --     rx_reset                => rx_reset(26 downto 0),
        --     rx_dpa_locked           => rx_dpa_locked(26 downto 0),
        --     rx_locked               => rx_locked(0),
        --     rx_out                  => rx_out_temp(269 downto 0),
        --     rx_outclock             => rx_clk(0)
        -- );
        -- synthesis read_comments_as_HDL off
    end generate;

    gen2ndrec2: if ( g_IS_TELESCOPE = '1' ) GENERATE
        -- synthesis read_comments_as_HDL on
        -- lvds_rec : entity work.ip_altlvds_rx
        -- generic map ( g_CHANNELS => 9, g_DESER_FACTOR => 10 )
        -- port map (
        --     rx_channel_data_align   => rx_align(26 downto 18),
        --     rx_fifo_reset           => rx_fifo_reset(26 downto 18),
        --     rx_in                   => rx_in(26 downto 18),
        --     rx_inclock              => rx_inclock_A_ctrl,
        --     rx_reset                => rx_reset(26 downto 18),
        --     rx_dpa_locked           => rx_dpa_locked(26 downto 18),
        --     rx_locked               => rx_locked(0),
        --     rx_out                  => rx_out_temp(269 downto 180),
        --     rx_outclock             => rx_clk(0)
        -- );
        -- synthesis read_comments_as_HDL off
    end generate;

    -- synthesis read_comments_as_HDL on
    -- lvds_rec : entity work.ip_altlvds_rx
    -- generic map ( g_CHANNELS => 9, g_DESER_FACTOR => 10 )
    -- port map (
    --     rx_channel_data_align   => rx_align(35 downto 27),
    --     rx_fifo_reset           => rx_fifo_reset(35 downto 27),
    --     rx_in                   => rx_in(35 downto 27),
    --     rx_inclock              => rx_inclock_B,
    --     rx_reset                => rx_reset(35 downto 27),
    --     rx_locked               => rx_locked(1),
    --     rx_dpa_locked           => rx_dpa_locked(35 downto 27),
    --     rx_out                  => rx_out_temp(359 downto 270),
    --     rx_outclock             => rx_clk(1)
    -- );
    -- synthesis read_comments_as_HDL off


    geninvert_n: FOR i in 0 to 35 GENERATE
        rx_out(9+10*i downto 10*i) <= not rx_out_temp(9+10*i downto 10*i) when i_rx_invert(i) = '0' else rx_out_temp(9+10*i downto 10*i);
    end generate;

    gendec:
    FOR i in g_INPUTS-1 downto 0 generate

        generate_data_decoder_bit_slip : if ( g_ALIGNER_MODE = 0 ) generate
            datadec: entity work.data_decoder
            port map (
                rx_in           => rx_out(i*10+9 downto i*10),

                rx_reset        => rx_reset(i),
                rx_fifo_reset   => rx_fifo_reset(i),
                rx_dpa_locked   => rx_dpa_locked(i),
                rx_locked       => rx_locked(i/27),
                rx_align        => rx_align(i),

                ready           => rx_ready(i),
                data            => rx_data_s(i*8+7 downto i*8),
                k               => rx_k_s(i),
                disp_err        => disp_err(i),
                err8b10b        => err8b10b(i),

                i_reset_n       => i_reset_n,--(i), -- TODO: register, no buttons at all
                i_clk           => rx_clk(i/27)--,
            );
        end generate;

        generate_data_decoder_bit_adaptive : if ( g_ALIGNER_MODE = 1 ) generate
            datadec: entity work.data_decoder_adaptive
            port map (
                rx_in           => rx_out(i*10+9 downto i*10),

                rx_reset        => rx_reset(i),
                rx_fifo_reset   => rx_fifo_reset(i),
                rx_dpa_locked   => rx_dpa_locked(i),
                rx_locked       => rx_locked(i/27),
                rx_align        => rx_align(i),

                ready           => rx_ready(i),
                data            => rx_data_s(i*8+7 downto i*8),
                k               => rx_k_s(i),
                disp_err        => disp_err(i),
                err8b10b        => err8b10b(i),

                i_reset_n       => i_reset_n,--(i), -- TODO: register, no buttons at all
                i_clk           => rx_clk(i/27)--,
            );
        end generate;

        -- indicate errors
        rx_data(i*8+7 downto i*8) <=  rx_data_s(i*8+7 downto i*8);
        rx_k(i) <= rx_k_s(i);
        rx_bad(i) <= '1' when (disp_err(i) = '1' or err8b10b(i) = '1' or rx_locked(i/27) = '0' or rx_dpa_locked(i) = '0') else '0';

        process(rx_clk(i/27))
        begin
        if rising_edge(rx_clk(i/27)) then
            if(disp_err(i)='1') then
                disp_err_counter(i) <= disp_err_counter(i) + '1';
            end if;
            if(rx_align(i)='1') then
                rx_aligncnt(i) <= rx_aligncnt(i) + '1';
            end if;
            if(err8b10b(i) = '1') then
                err8b10b_counter(i) <= err8b10b_counter(i) + '1';
            end if;
        end if;
        end process;

        process(i_clk_global)
        begin
        if rising_edge(i_clk_global) then
            o_rx_status(i)              <= LVDS_ZERO;
            o_rx_status(i).disperr      <= disp_err_counter(i);
            o_rx_status(i).err8b10b     <= err8b10b_counter(i);
            o_rx_status(i).pll_locked   <= rx_locked(i/27);
            o_rx_status(i).aligncnt     <= rx_aligncnt(i);
            o_rx_status(i).ready        <= rx_ready(i);
            o_rx_status(i).dpa_locked   <= rx_dpa_locked(i);
        end if;
        end process;

        e_reset_n : entity work.reset_sync
        port map ( i_areset_n => i_reset_n, o_reset_n => rx_reset_n(i), i_clk => rx_clk(i/27) );

    end generate;

    -- [AK] TODO: use fifo_sync
    sync_fifo_rx_data1 : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH  => 4,
        g_DATA_WIDTH  => 270--,
    )
    port map (
        i_we                        => '1',
        i_wdata                     => rx_bad(26 downto 0) & rx_k(26 downto 0) & rx_data(27*8-1 downto 0),
        i_wclk                      => rx_clk(0),

        i_rack                      => rx_sync_fifo_rd(0),
        o_rdata(8*27-1 downto 0)    => rx_data_out_buffer(27*8-1 downto 0),
        o_rdata(242 downto 8*27)    => rx_k_out_buffer(26 downto 0),
        o_rdata(269 downto 243)     => rx_bad_out_buffer(26 downto 0),
        o_rempty                    => rx_sync_fifo_empty(0),
        i_rclk                      => i_clk_global,

        i_reset_n                   => i_reset_n--,
    );

    -- TODO: use fifo_sync
    sync_fifo_rx_data2 : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH  => 4,
        g_DATA_WIDTH  => 90--,
    )
    port map (
        i_we                    => '1',
        i_wdata                 => rx_bad(35 downto 27) & rx_k(35 downto 27) & rx_data(36*8-1 downto 27*8),
        i_wclk                  => rx_clk(1),

        i_rack                  => rx_sync_fifo_rd(1),
        o_rdata(71 downto 0)    => rx_data_out_buffer(36*8-1 downto 27*8),
        o_rdata(80 downto 72)   => rx_k_out_buffer(35 downto 27),
        o_rdata(89 downto 81)   => rx_bad_out_buffer(35 downto 27),
        o_rempty                => rx_sync_fifo_empty(1),
        i_rclk                  => i_clk_global,

        i_reset_n               => i_reset_n--,
    );

    process(i_clk_global)
    begin
    if rising_edge(i_clk_global) then
        rx_sync_fifo_rd     <= not rx_sync_fifo_empty;
        o_rx_ready          <= rx_ready;
        for i in 0 to 35 loop
            o_rx_data(i)    <= rx_data_out_buffer(i*8+7 downto i*8);
            o_rx_k(i)       <= rx_k_out_buffer(i);
            o_rx_bad(i)     <= rx_bad_out_buffer(i);
        end loop;
    end if;
    end process;

end architecture;
