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

entity scifi_receiver_block is
generic (
    g_INPUTS : positive := 1;
    INPUT_SIGNFLIP : std_logic_vector(31 downto 0) := x"00000000"--;
);
port (
    -- serial lines
    i_rx                : in std_logic_vector(g_INPUTS-1 downto 0) := (others => '0');
    i_enablesim         : in std_logic;
    i_scifi_lvds_los_n  : in std_logic_vector(g_INPUTS-1 downto 0);

    -- ref.clocks
    i_rx_inclock        : in std_logic;

    -- slow control signals
    o_rx_status         : out lvds_status_array_t(g_INPUTS-1 downto 0);

    -- data output
    o_rx_data           : out   std_logic_vector(g_INPUTS*8-1 downto 0);
    o_rx_k              : out   std_logic_vector(g_INPUTS-1 downto 0);
    o_rx_ready          : out   std_logic_vector(g_INPUTS-1 downto 0);

    i_reset_n           : in    std_logic;
    i_clk_global        : in    std_logic--;
);
end entity;

architecture rtl of scifi_receiver_block is

    -- clock
    signal rx_inclock_ctrl : std_logic;

    -- parallel data
    signal rx_out, rx_out_order, rx_out_reg : std_logic_vector(g_INPUTS*10-1 downto 0);
    signal rx_data : std_logic_vector(g_INPUTS*8-1 downto 0);
    signal rx_k : std_logic_vector(g_INPUTS-1 downto 0);

    -- status signals
    signal rx_dpa_locked, rx_fifo_reset, rx_reset, rx_ready, disp_err, err8b10b, rx_align : std_logic_vector (g_INPUTS-1 DOWNTO 0);
    signal rx_locked, rx_clk : std_logic;
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

    -- synthesis read_comments_as_HDL on
    -- clk_ctrl : component work.cmp.clk_ctrl_single
    -- port map (
    --      inclk  => i_rx_inclock,
    --      outclk => rx_inclock_ctrl
    -- );
    -- lvds_rx : entity work.ip_altlvds_rx
    -- generic map ( g_CHANNELS => g_INPUTS, g_DESER_FACTOR => 10 )
    -- port map (
    --    rx_channel_data_align   => rx_align,
    --    rx_fifo_reset           => rx_fifo_reset,
    --    rx_in                   => i_rx,
    --    rx_inclock              => rx_inclock_ctrl,
    --    rx_reset                => rx_reset,
    --    rx_dpa_locked           => rx_dpa_locked,
    --    rx_locked               => rx_locked,
    --    rx_out                  => rx_out,
    --    rx_outclock             => rx_clk
    -- );
    -- rx_out_reg <= rx_out;
    -- synthesis read_comments_as_HDL off

    -- synthesis translate_off
    rx_locked <= '1';
    rx_dpa_locked <= (others => '1');
    -- synthesis translate_on

-----------------------------------------------------------
--------------- decode and sync----------------------------
-----------------------------------------------------------

    geninvert_n: FOR i in 0 to g_INPUTS - 1 GENERATE

        -- synthesis translate_off
        -- NOTE: this is for simulation
        process(i_clk_global, i_reset_n)
        begin
            if ( i_reset_n /= '1' ) then
                state_sim(i) <= (others => '0');
                rx_out_reg(i*10+9 downto i*10) <= "0011111010"; -- 0xBC
            elsif rising_edge(i_clk_global) then
                state_sim(i) <= state_sim(i) + '1';
                if ( state_sim(i) = "000" ) then
                    rx_out_reg(i*10+9 downto i*10) <= "0011111010"; -- 0xBC
                elsif ( state_sim(i) = "001" ) then
                    rx_out_reg(i*10+9 downto i*10) <= "0011111010"; -- 0xBC
                elsif ( state_sim(i) = "010" ) then
                    rx_out_reg(i*10+9 downto i*10) <= "0011111010"; -- 0xBC
                elsif ( state_sim(i) = "011" ) then
                    rx_out_reg(i*10+9 downto i*10) <= "0011111010"; -- 0xBC
                elsif ( state_sim(i) = "100" ) then
                    rx_out_reg(i*10+9 downto i*10) <= "0011111010"; -- 0xBC
                elsif ( state_sim(i) = "101" ) then
                    rx_out_reg(i*10+9 downto i*10) <= "0011111010"; -- 0xBC
                elsif ( state_sim(i) = "110" ) then
                    rx_out_reg(i*10+9 downto i*10) <= "0011110100"; -- 0x1C
                elsif ( state_sim(i) = "111" ) then
                    rx_out_reg(i*10+9 downto i*10) <= "0011110010"; -- 0x9C
                end if;
            end if;
        end process;
        -- synthesis translate_on

        -- invert signals
        rx_out_order(i*10+9 downto i*10) <= not rx_out_reg(i*10+9 downto i*10) when INPUT_SIGNFLIP(i) = '0' else rx_out_reg(i*10+9 downto i*10);

    end generate;

    gen_channels: for i in g_INPUTS-1 downto 0 generate
        e_data_decoder : entity work.data_decoder
        port map (
            rx_in           => rx_out_order(i*10+9 downto i*10),

            rx_reset        => rx_reset(i),
            rx_fifo_reset   => rx_fifo_reset(i),
            rx_dpa_locked   => rx_dpa_locked(i),
            rx_locked       => rx_locked,
            rx_align        => rx_align(i),

            ready           => rx_ready(i),
            data            => rx_data(i*8+7 downto i*8),
            k               => rx_k(i),
            disp_err        => disp_err(i),
            err8b10b        => err8b10b(i),

            i_reset_n       => i_reset_n,
            -- synthesis read_comments_as_HDL on
            -- i_clk          => rx_clk
            -- synthesis read_comments_as_HDL off
            -- synthesis translate_off
            i_clk           => i_clk_global
            -- synthesis translate_on
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
            -- synthesis read_comments_as_HDL on
            -- i_wclk  => rx_clk,
            -- synthesis read_comments_as_HDL off
            -- synthesis translate_off
            i_wclk     => i_clk_global,
            -- synthesis translate_on

            i_rack     => rx_sync_fifo_rd(i),
            o_rdata    => rx_data_out_buffer(i*9+8 downto i*9),
            o_rempty   => rx_sync_fifo_empty(i),
            i_rclk     => i_clk_global,

            i_reset_n  => i_reset_n--,
        );

        process(rx_clk)
        begin
        if rising_edge(rx_clk) then
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
            o_rx_status(i).pll_locked   <= rx_locked;
            o_rx_status(i).aligncnt     <= rx_aligncnt(i);
            o_rx_status(i).ready        <= rx_ready(i) and i_scifi_lvds_los_n(i);
            o_rx_status(i).dpa_locked   <= rx_dpa_locked(i);
        end if;
        end process;

        process(i_clk_global)
        begin
        if rising_edge(i_clk_global) then
            rx_sync_fifo_rd(i)  <= not rx_sync_fifo_empty(i);
            o_rx_ready(i) <= rx_ready(i) and i_scifi_lvds_los_n(i);
            o_rx_data(i*8+7 downto i*8) <= rx_data_out_buffer(i*9+7 downto i*9);
            o_rx_k(i) <= rx_data_out_buffer(i*9+8);
        end if;
        end process;

    end generate;

end architecture;
