-----------------------------------
--
-- On detector FPGA for layer 0/1
-- Setup and data alignment for one FPGA link
-- Includes 8b/10b decoding
-- Niklaus Berger, Feb 2014
--
-- nberger@physi.uni-heidelberg.de
--
----------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

entity data_decoder is
port (
    rx_in           : in    std_logic_vector(9 downto 0);

    rx_reset        : out   std_logic;
    rx_fifo_reset   : out   std_logic;
    rx_dpa_locked   : in    std_logic;
    rx_locked       : in    std_logic;
    rx_align        : out   std_logic;

    ready           : out   std_logic;
    data            : out   std_logic_vector(7 downto 0);
    k               : out   std_logic;
    disp_err        : out   std_logic;
    err8b10b        : out   std_logic;

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture rtl of data_decoder is

    type sync_state_type is ( reset, waitforplllock, waitfordpalock, align );
    signal sync_state : sync_state_type := reset;

    signal rx_decoded : std_logic_vector(7 downto 0);
    signal rx_k : std_logic;

    signal rx_reversed : std_logic_vector(9 downto 0) := (others => '0');

    signal current_disparity, new_disparity : std_logic :='0';
    signal new_datak : std_logic;
    signal new_data : std_logic_vector(7 downto 0);
    signal disp_error, data_error : std_logic;

    signal align_ena : std_logic := '0';
    signal disp_err_s : std_logic;

begin

    disp_err <= disp_err_s;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        sync_state <= reset;
        align_ena <= '0';
        rx_reset <= '0';
        rx_fifo_reset <= '0';
        --
    elsif rising_edge(i_clk) then
        align_ena <= '0';
        for I in 0 to 9 loop
            rx_reversed(9-I) <= rx_in(I);
        end loop;

        -- to be adapted!
        rx_reset <= '0';
        rx_fifo_reset <= '0';

        case sync_state is

        when reset =>
            sync_state <= waitforplllock;
            rx_reset <= '1';
            rx_fifo_reset <= '0';

        when waitforplllock =>
            rx_reset <= '1';
            rx_fifo_reset <= '0';
            if(rx_locked = '1') then
                sync_state <= waitfordpalock;
            end if;

        when waitfordpalock =>
            rx_reset <= '0';
            rx_fifo_reset <= '0';
            if(rx_locked = '0') then
                sync_state <= reset;
            elsif (rx_dpa_locked = '1') then
                rx_fifo_reset <= '1';
                sync_state <= align;
            end if;

        when align =>
            align_ena <= '1';
            if(rx_locked = '0') then
                sync_state <= reset;
            end if;

        when others =>
            sync_state <= reset;
        end case;
    end if;
    end process;

    e_rx_align : entity work.rx_align
    generic map (
        g_BYTES => 1,
        g_K => ( 0 => work.util.K28_5 )--,
    )
    port map (
        o_data    => data,
        o_datak(0)=> k,
        o_locked  => ready,
        o_bitslip => rx_align,
        i_data    => rx_decoded,
        i_datak(0)=> rx_k,
        i_error   => disp_err_s or err8b10b,
        i_reset_n => align_ena,
        i_clk     => i_clk--,
    );

    e_8b10b_dec : entity work.dec_8b10b
    port map (
        i_data => rx_reversed,
        i_disp => current_disparity,
        o_data(7 downto 0) => new_data,
        o_data(8) => new_datak,
        o_disp => new_disparity,
        o_disperr => disp_error,
        o_err => data_error--,
    );

    process(i_clk)
    begin
    if rising_edge(i_clk) then
        rx_decoded <= new_data;
        rx_k <= new_datak;
        current_disparity <= new_disparity;
        disp_err_s <= disp_error;
        err8b10b <= data_error;
    end if;
    end process;

end architecture;
