-- -----------------------------------------------------------------------------
-- File      : ingress_egress_adaptor.vhd
-- Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
-- Version   : 26.3.6
-- Date      : 20260421
-- Change    : Bridge 4-lane MuSiP ingress through OPQ and expose merged lane-0
--             egress for the SWB datapath.
-- -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.mu3e.all;

entity ingress_egress_adaptor is
generic (
    N_SHD    : natural := 128
);
port (
    enable        : in std_logic;
    rx_ingress    : in work.mu3e.link32_array_t(3 downto 0);
    rx_egress     : out work.mu3e.link32_array_t(3 downto 0);
    reset_n       : in std_logic;
    clk           : in std_logic
);
end entity;

architecture rtl of ingress_egress_adaptor is

    signal aso_egress_data  : std_logic_vector(35 downto 0);
    signal aso_egress_valid : std_logic;

begin

    e_opq_monolithic_4lane_merge_opq_0 : entity work.opq_monolithic_4lane_merge_opq_0
    generic map (
        N_LANE    => 4,
        MODE      => "MERGING",
        N_SHD     => N_SHD
    )
    port map (
        asi_ingress_0_channel             => "00",
        asi_ingress_0_data                => rx_ingress(0).datak & rx_ingress(0).data,
        asi_ingress_0_valid(0)            => (not rx_ingress(0).idle) and enable,
        asi_ingress_0_startofpacket(0)    => rx_ingress(0).sop,
        asi_ingress_0_endofpacket(0)      => rx_ingress(0).eop,
        asi_ingress_0_error               => "000",

        asi_ingress_1_channel             => "01",
        asi_ingress_1_data                => rx_ingress(1).datak & rx_ingress(1).data,
        asi_ingress_1_valid(0)            => (not rx_ingress(1).idle) and enable,
        asi_ingress_1_startofpacket(0)    => rx_ingress(1).sop,
        asi_ingress_1_endofpacket(0)      => rx_ingress(1).eop,
        asi_ingress_1_error               => "000",

        asi_ingress_2_channel             => "10",
        asi_ingress_2_data                => rx_ingress(2).datak & rx_ingress(2).data,
        asi_ingress_2_valid(0)            => (not rx_ingress(2).idle) and enable,
        asi_ingress_2_startofpacket(0)    => rx_ingress(2).sop,
        asi_ingress_2_endofpacket(0)      => rx_ingress(2).eop,
        asi_ingress_2_error               => "000",

        asi_ingress_3_channel             => "11",
        asi_ingress_3_data                => rx_ingress(3).datak & rx_ingress(3).data,
        asi_ingress_3_valid(0)            => (not rx_ingress(3).idle) and enable,
        asi_ingress_3_startofpacket(0)    => rx_ingress(3).sop,
        asi_ingress_3_endofpacket(0)      => rx_ingress(3).eop,
        asi_ingress_3_error               => "000",

        aso_egress_data             => aso_egress_data,
        aso_egress_valid            => aso_egress_valid,
        aso_egress_ready            => '1',
        aso_egress_startofpacket    => open,
        aso_egress_endofpacket      => open,
        aso_egress_error            => open,

        avs_csr_address          => (others => '0'),
        avs_csr_read             => '0',
        avs_csr_write            => '0',
        avs_csr_writedata        => (others => '0'),
        avs_csr_readdata         => open,
        avs_csr_readdatavalid    => open,
        avs_csr_waitrequest      => open,
        avs_csr_burstcount       => '0',

        d_clk      => clk,
        d_reset    => not reset_n
    );

    egress_mux : process(all)
    begin
        rx_egress <= rx_ingress;

        if enable = '1' then
            rx_egress <= (others => work.mu3e.LINK32_IDLE);
            if aso_egress_valid = '1' then
                rx_egress(0) <= work.mu3e.to_link(aso_egress_data(31 downto 0), aso_egress_data(35 downto 32));
            end if;
        end if;
    end process;

end architecture;
