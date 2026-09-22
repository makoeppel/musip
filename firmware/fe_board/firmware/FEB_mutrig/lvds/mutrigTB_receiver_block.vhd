-----------------------------------
--
-- On detector FPGA for layer 0/1
-- Receiver block for all the LVDS links
-- Niklaus Berger, May 2013
--
-- nberger@physi.uni-heidelberg.de
--
-- Adaptions for MuPix8 Telescope
-- Sebastian Dittmeier, April 2016
-- dittmeier@physi.uni-heidelberg.de
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.lvds_registers.all;

entity mutrigTB_receiver_block is
generic (
    g_INPUTS            : positive := 13;
    g_INPUTS_USED       : positive := 13;
    INPUT_SIGNFLIP      : std_logic_vector(31 downto 0) := x"00000000"--;
);
port (
    -- serial lines
    i_rx                : in std_logic_vector(g_INPUTS_USED-1 downto 0) := (others => '0');

    -- ref.clocks
    i_rx_inclock_A      : in std_logic;
    i_rx_inclock_B      : in std_logic;

    -- slow control signals
    o_rx_status         : out lvds_status_array_t(g_INPUTS-1 downto 0);

    -- data output
    o_rx_data           : out std_logic_vector(g_INPUTS*8-1 downto 0);
    o_rx_k              : out std_logic_vector(g_INPUTS-1 downto 0);
    o_rx_ready          : out std_logic_vector(g_INPUTS-1 downto 0);

    -- reset / clk
    i_reset_n           : in  std_logic;
    i_clk_global        : in  std_logic--;
);
end entity;

architecture rtl of mutrigTB_receiver_block is

    -- clock
    signal rx_inclock_A_ctrl, rx_inclock_B_ctrl : std_logic;

    -- parallel data
    signal rx_out, rx_out_reg, rx_out_order : std_logic_vector(g_INPUTS*10-1 downto 0);
    signal rx_data : std_logic_vector(g_INPUTS*8-1 downto 0);
    signal rx_k : std_logic_vector(g_INPUTS-1 downto 0);

    -- status signals
    signal rx_dpa_locked, rx_fifo_reset, rx_reset, rx_ready, disp_err, err8b10b, rx_align : std_logic_vector (g_INPUTS-1 DOWNTO 0);
    signal rx_locked, rx_clk, rx_clk_reg : std_logic_vector(1 downto 0);
    type   disp_err_counter_t is array (natural range <>) of std_logic_vector(31 downto 0);
    type   rx_aligncnt_t is array (natural range <>) of std_logic_vector(5 downto 0);
    signal disp_err_counter : disp_err_counter_t(g_INPUTS-1 downto 0);
    signal err8b10b_counter : disp_err_counter_t(g_INPUTS-1 downto 0);
    signal rx_aligncnt : rx_aligncnt_t(g_INPUTS-1 downto 0);

    -- sync fifo
    signal rx_sync_fifo_empty, rx_sync_fifo_rd : std_logic_vector(g_INPUTS-1 downto 0);
    signal rx_data_out_buffer : std_logic_vector(g_INPUTS*9-1 downto 0);

    -- simulation
    signal state_sim : work.util_slv.slv10_array_t(g_INPUTS-1 downto 0);

begin

    -- for simulation we need another clk
    -- synthesis read_comments_as_HDL on
    -- rx_clk_reg <= rx_clk;
    -- synthesis read_comments_as_HDL off
    -- synthesis translate_off
    rx_clk_reg <= i_clk_global & i_clk_global;
    rx_locked <= (others => '1');
    rx_dpa_locked <= (others => '1');
    -- synthesis translate_on

-----------------------------------------------------------
---------------SciTile lvds rx-----------------------------
-----------------------------------------------------------

    -- synthesis read_comments_as_HDL on
    -- clk_ctrl_A : component work.cmp.clk_ctrl_single
    --     port map (
    --         inclk  => i_rx_inclock_A,
    --         outclk => rx_inclock_A_ctrl
    -- );

    -- clk_ctrl_B : component work.cmp.clk_ctrl_single
    -- port map (
    --     inclk  => i_rx_inclock_B,
    --     outclk => rx_inclock_B_ctrl
    -- );
    -- synthesis read_comments_as_HDL off

    -----------------------------------------------------------
    ---------------SciTile lvds rx A---------------------------
    -----------------------------------------------------------
    --gen_scitile_A: if (IS_TILE_B=false) generate

    lvds_rec_small_B : entity work.ip_altlvds_rx
    generic map ( g_CHANNELS => 2, g_DESER_FACTOR => 10 )
    port map (
        rx_channel_data_align   => rx_align(1 downto 0),
        rx_fifo_reset           => rx_fifo_reset(1 downto 0),
        rx_in                   => i_rx(1 downto 0),
        rx_inclock              => rx_inclock_B_ctrl,
        rx_reset                => rx_reset(1 downto 0),
        rx_dpa_locked(1 downto 0) => rx_dpa_locked(1 downto 0),
        rx_locked               => rx_locked(1),
        rx_out(19 downto  0)    => rx_out( 19 downto   0),
        rx_outclock             => rx_clk(1)--
    );
    rx_out_reg <= rx_out;

    --end generate;

-----------------------------------------------------------
--------------- SciTile 8b10b decode and sync -------------
-----------------------------------------------------------

    -- flip bit order of received data (msb-lsb)
    geninvert_n: FOR i in 0 to g_INPUTS_USED - 1 GENERATE
            -- invert signals
            rx_out_order(10*i+9 downto 10*i) <= not rx_out_reg(10*i+9 downto 10*i) when INPUT_SIGNFLIP(i) = '0' else rx_out_reg(10*i+9 downto 10* i);
    end generate geninvert_n;
    gen_nochannels : for i in g_INPUTS-1 downto g_INPUTS_USED generate
    -- assigned unused outputs
        o_rx_status(i).hitcnt         <= (others => '0');
        o_rx_status(i).arrival_phase  <= (others => '0');
        o_rx_status(i).out_of_phase_cnt  <= (others => '0');
        o_rx_status(i).disperr      <= (others => '0');
        o_rx_status(i).err8b10b     <= (others => '0');
        o_rx_status(i).pll_locked   <= '0';
        o_rx_status(i).aligncnt     <= (others => '0');
        o_rx_status(i).ready        <= '1';
        o_rx_status(i).dpa_locked   <= '1';

        rx_ready(i) <= '1';
        rx_data_out_buffer(i*9+7 downto i*9)   <= x"bc";
        rx_data_out_buffer(i*9+8)              <= '1'; --k
    end generate gen_nochannels;


    gen_channels : for i in g_INPUTS_USED-1 downto 0 generate
        -- assigned unused outputs
        o_rx_status(i).hitcnt         <= (others => '0');
        o_rx_status(i).arrival_phase  <= (others => '0');
        o_rx_status(i).out_of_phase_cnt  <= (others => '0');

        --gen_scitile_A : if (IS_TILE_B=false) generate

            gen_a_part : if ( i = 12 or i = 10 or i = 7 or i = 6 or i = 5 or i = 4 or i = 3 or i = 2 ) generate

                datadec_A : entity work.data_decoder
                port map (
                    rx_in           => rx_out_order(i*10+9 downto i*10),

                    rx_reset        => rx_reset(i),
                    rx_fifo_reset   => rx_fifo_reset(i),
                    rx_dpa_locked   => rx_dpa_locked(i),
                    rx_locked       => rx_locked(0),
                    rx_align        => rx_align(i),

                    ready           => rx_ready(i),
                    data            => rx_data(i*8+7 downto i*8),
                    k               => rx_k(i),
                    disp_err        => disp_err(i),
                    err8b10b        => err8b10b(i),

                    i_reset_n       => i_reset_n,
                    i_clk           => rx_clk_reg(0)--,
                );

                -- [AK] TODO: use fifo_sync
                sync_fifo_rx_data_A : entity work.ip_dcfifo_v2
                generic map (
                    g_ADDR_WIDTH  => 4,
                    g_DATA_WIDTH  => 9--,
                )
                port map (
                    i_we       => '1',
                    i_wdata    => rx_k(i) & rx_data(i*8+7 downto i*8),
                    i_wclk     => rx_clk_reg(0),

                    i_rack     => rx_sync_fifo_rd(i),
                    o_rdata    => rx_data_out_buffer(i*9+8 downto i*9),
                    o_rempty   => rx_sync_fifo_empty(i),
                    i_rclk     => i_clk_global,

                    i_reset_n  => i_reset_n--,
                );

                process(rx_clk_reg(0))
                begin
                if rising_edge(rx_clk_reg(0)) then
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
                    o_rx_status(i).disperr      <= disp_err_counter(i);
                    o_rx_status(i).err8b10b     <= err8b10b_counter(i);
                    o_rx_status(i).pll_locked   <= rx_locked(0);
                    o_rx_status(i).aligncnt     <= rx_aligncnt(i);
                    o_rx_status(i).ready        <= rx_ready(i);
                    o_rx_status(i).dpa_locked   <= rx_dpa_locked(i);
                end if;
                end process;

            end generate gen_a_part;

            gen_b_part : if ( i = 11 or i = 9 or i = 8 or i = 1 or i = 0 ) generate

                datadec_B : entity work.data_decoder
                port map (
                    rx_in           => rx_out_order(i*10+9 downto i*10),

                    rx_reset        => rx_reset(i),
                    rx_fifo_reset   => rx_fifo_reset(i),
                    rx_dpa_locked   => rx_dpa_locked(i),
                    rx_locked       => rx_locked(1),
                    rx_align        => rx_align(i),

                    ready           => rx_ready(i),
                    data            => rx_data(i*8+7 downto i*8),
                    k               => rx_k(i),
                    disp_err        => disp_err(i),
                    err8b10b        => err8b10b(i),

                    i_reset_n       => i_reset_n,
                    i_clk           => rx_clk_reg(1)--,
                );

                -- [AK] TODO: use fifo_sync
                sync_fifo_rx_data_B : entity work.ip_dcfifo_v2
                generic map (
                    g_ADDR_WIDTH  => 4,
                    g_DATA_WIDTH  => 9--,
                )
                port map (
                    i_we       => '1',
                    i_wdata    => rx_k(i) & rx_data(i*8+7 downto i*8),
                    i_wclk     => rx_clk_reg(1),

                    i_rack     => rx_sync_fifo_rd(i),
                    o_rdata    => rx_data_out_buffer(i*9+8 downto i*9),
                    o_rempty   => rx_sync_fifo_empty(i),
                    i_rclk     => i_clk_global,

                    i_reset_n  => i_reset_n--,
                );

                process(rx_clk_reg(1))
                begin
                if rising_edge(rx_clk_reg(1)) then
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
                    o_rx_status(i).disperr      <= disp_err_counter(i);
                    o_rx_status(i).err8b10b     <= err8b10b_counter(i);
                    o_rx_status(i).pll_locked   <= rx_locked(1);
                    o_rx_status(i).aligncnt     <= rx_aligncnt(i);
                    o_rx_status(i).ready        <= rx_ready(i);
                    o_rx_status(i).dpa_locked   <= rx_dpa_locked(i);
                end if;
                end process;

            end generate gen_b_part;

        --end generate;

        process(i_clk_global)
        begin
        if rising_edge(i_clk_global) then
            rx_sync_fifo_rd(i)  <= not rx_sync_fifo_empty(i);
            o_rx_ready(i) <= rx_ready(i);
            o_rx_data(i*8+7 downto i*8) <= rx_data_out_buffer(i*9+7 downto i*9);
            o_rx_k(i) <= rx_data_out_buffer(i*9+8);
        end if;
        end process;

    end generate;

end architecture;
