-------------------------------------------------------------
--
-- Place to organize storage of adc measurements, readback of config and error signals
--
-- M. Mueller, Nov 2023
--------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;
use work.mupix.all;
use work.mupix_registers.all;

entity sc_readback_mem is
generic(
    g_CHIPS : positive := 1--;
);
port (
    -- clk_125
    i_slowctrl_data         : in    reg32array(g_CHIPS-1 downto 0);
    i_slowctrl_data_ena     : in    std_logic_vector(g_CHIPS-1 downto 0);
    o_slowctrl_empty        : out   std_logic_vector(g_CHIPS-1 downto 0);
    i_clk_125               : in    std_logic;

    io_readback_fifos_reg   : inout work.util.rw_t;

    i_reset_156_n           : in    std_logic;
    i_clk_156               : in    std_logic--;
);
end entity;

architecture RTL of sc_readback_mem is

    constant BASE_ADDR : std_logic_vector := std_logic_vector(to_unsigned(work.mupix_registers.MP_READBACK_FIFOS_START_REGISTER_R, io_readback_fifos_reg.addr'length));

    -- [MM] use 64 element arrays to avoid `raddr < g_CHIPS` check
    signal fifo_rack  : std_logic_vector(63 downto 0) := (others => '0');
    signal fifo_rdata : reg32array(63 downto 0) := (others => X"CCCCCCCC");
    signal fifo_empty : std_logic_vector(63 downto 0) := (others => '1');

    signal re : std_logic;
    signal raddr : integer range 0 to 63;
    signal rdata : std_logic_vector(31 downto 0);

begin

    assert ( true
        and ( g_CHIPS <= 64 )
        -- check MP_READBACK_FIFOS_START_REGISTER_R alignment
        and ( BASE_ADDR(5 downto 0) = 0 )
    ) severity failure;

    re <= '1' when ( io_readback_fifos_reg.re = '1'
        and io_readback_fifos_reg.addr(BASE_ADDR'left downto 6) = BASE_ADDR(BASE_ADDR'left downto 6)
    ) else '0';
    raddr <= to_integer(unsigned(io_readback_fifos_reg.addr(5 downto 0)));

    g_fifos : for i in 0 to g_CHIPS-1 generate
        ip_dcfifo_v2_inst : entity work.ip_dcfifo_v2
        generic map (
            g_ADDR_WIDTH => 5,
            g_DATA_WIDTH => 32,
            g_SHOWAHEAD => "ON",
            g_LPM_HINT => "RAM_BLOCK_TYPE=MLAB"--,
        )
        port map (
            i_we       => i_slowctrl_data_ena(i),
            i_wdata    => i_slowctrl_data(i),
            i_wclk     => i_clk_125,

            i_rack     => fifo_rack(i),
            o_rdata    => fifo_rdata(i),
            o_rempty   => fifo_empty(i),
            i_rclk     => i_clk_156,

            i_reset_n  => i_reset_156_n
        );
    end generate;

    process(all)
    begin
        fifo_rack <= (others => '0');
        rdata <= X"CCCCCCCC";
        if ( re = '1' and fifo_empty(raddr) = '0' ) then
            fifo_rack(raddr) <= '1';
            rdata <= fifo_rdata(raddr);
        end if;
    end process;

    process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
        o_slowctrl_empty <= fifo_empty(o_slowctrl_empty'range);
    end if;
    end process;

    process(i_clk_156, i_reset_156_n)
    begin
    if ( i_reset_156_n = '0' ) then
        io_readback_fifos_reg.rdata <= X"CCCCCCCC";
        --
    elsif rising_edge(i_clk_156) then
        io_readback_fifos_reg.rdata <= rdata;
    end if;
    end process;


 -- TODO: Memory for TDAC values:

    -- Address Mux Value
    -- 0 ref_vssa
    -- 1 Baseline
    -- 2 blpix
    -- 3 thpix
    -- 4 blpix
    -- 5 ThLow
    -- 6 ThHigh
    -- 7 TEST OUT
    -- 8 vssa
    -- 9 thpix
    -- 10 VCAL
    -- 11 VTemp1
    -- 12 VTemp2

    -- with Address from i_slowctrl_data(14:10) here:

   -- DataOut[9:0] <= AdcVDAC;
   -- DataOut[14:10] <= MuxAddr[4:0];
   -- DataOut[24:15] <= AdcDiv;
   -- DataOut[28:25] <= AdcMode;
   -- DataOut[59:54] <= AdcMeasurementCnt;
   -- DataOut[63:60] <= ADC_FLAG;

    -- whenever 63:60 of i_slowctrl_data is the ADC_FLAG (1100)

end architecture;
