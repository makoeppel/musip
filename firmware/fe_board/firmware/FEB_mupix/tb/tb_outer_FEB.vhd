library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;
use work.mutrig_registers.all;
use work.mupix_registers.all;
use work.sorter_registers.all;
use work.lvds_registers.all;
use work.util_slv.all;
use work.a10_pcie_registers.all;
use work.mupix.all;

entity tb_outer_FEB is
end entity;

architecture arch of tb_outer_FEB is

    constant CLK_MHZ    : real := 10000.0; -- MHz
    constant N_LINKS    : integer := 2;
    constant N_ASICS    : integer := 4;
    constant N_MODULES  : integer := 2;
    constant N_ASICS_TOTAL : natural := N_MODULES * N_ASICS;

    -- constants
    constant g_NLINKS_FEB_TOTL   : positive := 12;
    constant g_NLINKS_DATA_GENERIC  : integer := 0;
    constant g_NLINKS_FARM_TOTL  : positive := 3;
    -- Any g_NLINKS_DATA_... needs to be either zero or larger than 4. time_merger.vhd has the
    -- gen_input `for` loop running 0 to 4, which indexes into something with size `g_NLINKS_DATA`.
    -- This could probably be fixed but I don't completely understand it. Zero also works because
    -- this stops swb_block.vhd generating the work.swb_data_path at all.
    constant g_NLINKS_DATA_PIXEL_US : integer := 5;
    constant g_NLINKS_DATA_PIXEL_DS : integer := 0;
    constant g_NLINKS_DATA : integer := 8;

    signal clk, reset_n : std_logic := '0';

    signal mupix_reg        : work.util.rw_t;
    signal run_state_125    : run_state_t;
    signal delay            : std_logic_vector(1 downto 0);
    signal reset_state      : std_logic_vector(4 downto 0);

    signal i_simdata        : std_logic_vector(8*N_ASICS_TOTAL-1 downto 0) := (others => '0');
    signal i_simdatak       : std_logic_vector(N_ASICS_TOTAL-1 downto 0) := (others => '0');

    signal fifo_wdata       : std_logic_vector(36*N_LINKS-1 downto 0);
    signal fifo_write       : std_logic_vector(N_LINKS-1 downto 0);

    signal o_data           : std_logic_vector(127 downto 0);
    signal o_datak          : std_logic_vector(15 downto 0);

    --! data link signals
    signal rx : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal tx : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    signal writeregs : slv32_array_t(63 downto 0) := (others => (others => '0'));
    signal readregs : slv32_array_t(63 downto 0) := (others => (others => '0'));

    signal resets_n : std_logic_vector(31 downto 0) := (others => '0');

    signal counter : slv32_array_t(5+(g_NLINKS_DATA*5)-1 downto 0);

    signal fram_wen, dma_wren, dma_done, endofevent, dmamemhalffull : std_logic;
    signal dma_data : std_logic_vector(255 downto 0);
    signal mask_n : std_logic_vector(63 downto 0);

    signal dma_data_array : slv32_array_t(7 downto 0);

    signal writememdata : std_logic_vector(31 downto 0);
    signal writememdata_out : std_logic_vector(31 downto 0);
    signal writememdata_out_reg : std_logic_vector(31 downto 0);
    signal writememaddr : std_logic_vector(15 downto 0);
    signal memaddr : std_logic_vector(15 downto 0);
    signal memaddr_reg : std_logic_vector(15 downto 0);
    signal readmem_writedata : std_logic_vector(31 downto 0);
    signal readmem_writeaddr : std_logic_vector(15 downto 0);
    signal readmem_wren : std_logic;

    signal writememwren, toggle_read, done, fifo_we : std_logic;

    signal link_data : std_logic_vector(127 downto 0);
    signal link_datak : std_logic_vector(15 downto 0);

    type state_type is (idle, write_sc, wait_state, read_sc);
    signal state : state_type;

    signal readreg : reg32array_pcie;

begin

    clk     <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);


    --! Setup
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    process(clk, reset_n)
    begin
    if ( reset_n = '0' ) then
        run_state_125   <= RUN_STATE_IDLE;
        reset_state     <= (others => '0');
        mupix_reg.addr  <= (others => '0');
        mupix_reg.wdata <= (others => '0');
        mupix_reg.re    <= '0';
        mupix_reg.we    <= '0';
        delay           <= (others => '0');
        --
    elsif rising_edge(clk) then

        delay <= delay + '1';
        mupix_reg.addr  <= (others => '0');
        mupix_reg.wdata <= (others => '0');
        mupix_reg.re    <= '0';
        mupix_reg.we    <= '0';

        for i in 0 to N_ASICS_TOTAL-1 loop
            i_simdata((i+1)*8-1 downto i*8) <= x"BC";
            i_simdatak(i) <= '1';
        end loop;

        if (reset_state = "10010") then
            mupix_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(LVDS_STATUS_REGISTER_R, 16));
            mupix_reg.re <= '1';
        end if;

        if ( delay = "00" ) then

        case reset_state is

        -- start prep
        when "00000" =>
            reset_state                 <= "00001";
            run_state_125 <= RUN_STATE_PREP;

        when "00001" =>
            --mupix_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(SCIFI_CTRL_DUMMY_REGISTER_W, 16));
            --mupix_reg.wdata(11 downto 0)<= "000000000011";
            --mupix_reg.we                <= '1';
            reset_state                 <= "00010";
            run_state_125 <= RUN_STATE_SYNC;

        when "00010" =>
            --mupix_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(SCIFI_CTRL_DUMMY_REGISTER_W, 16));
            --mupix_reg.wdata(11 downto 0)<= "000000001011";
            --mupix_reg.we                <= '1';
            reset_state <= "00011";
            run_state_125 <= RUN_STATE_RUNNING;

        -- start datagen
        when "00011" =>
            mupix_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(MP_DATA_GEN_CONTROL_REGISTER_W, 16));
            mupix_reg.wdata(MP_DATA_GEN_HIT_P_RANGE) <= "0001";
            mupix_reg.wdata(MP_DATA_GEN_SYNC_BIT)    <= '1';
            mupix_reg.wdata(MP_DATA_GEN_SORT_IN_BIT)    <= '1';
            mupix_reg.wdata(MP_DATA_GEN_ENABLE_BIT)    <= '1';
            mupix_reg.we                <= '1';
            reset_state <= "00100";

        when "00100" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"1C";
                i_simdatak(i) <= '1';
            end loop;

            reset_state <= "00101";

        when "00101" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"32";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "00110";

        when "00110" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"8F";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "00111";

        when "00111" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"90"; -- x"50" is short mode
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01000";

        when "01000" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"01";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01001";

        when "01001" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"CC";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01010";

        when "01010" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"5F";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01011";

        when "01011" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"D0";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01100";

        when "01100" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"C7";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01101";

        when "01101" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"A5";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01110";

        when "01110" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"69";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01111";

        when "01111" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"52";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "10000";

        when "10000" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"68";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "10001";

        when "10001" =>
            for i in 0 to N_ASICS_TOTAL-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"9C";
                i_simdatak(i) <= '1';
            end loop;
            mupix_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(SORTER_COUNTER_REGISTER_R + SORTER_INDEX_NINTIME, 16));
            mupix_reg.re                <= '1';
            reset_state <= "10010";

        when "10010" =>
            --

        when "10011" =>
            --

        when others =>
            reset_state <= "00000";

        end case;
        end if;
    end if;
    end process;



    --! mupix Block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    -- mupix detector firmware
    e_mupix_block : entity work.mupix_block
    generic map (
        g_IS_OUTER => 1,
        g_SIN_INVERT => '0',
        g_USE_TRIGGER => 0,
        g_N_SPI => 4,
        g_CHIPS_PER_SPI => 9,
        g_IS_TELESCOPE => '0',
        g_MP_LADDER_ADDR_ARRAY => MP_LADDER_ADDR_ARRAY_US_OUTER,
        g_LINK_INVERT => MP_LINK_INVERT--,
    )
    port map (
        i_fpga_id               => (others => '0'),

        -- config signals to mupix
        o_clock                 => open,
        o_SIN                   => open,
        o_mosi                  => open,
        o_cs                    => open,

        -- mupix dac regs
        i_reg_addr              => mupix_reg.addr(15 downto 0),
        i_reg_re                => mupix_reg.re,
        o_reg_rdata             => mupix_reg.rdata,
        i_reg_we                => mupix_reg.we,
        i_reg_wdata             => mupix_reg.wdata,

        -- data
        o_fifo_wdata            => open,
        o_fifo_write            => open,

        o_data_bypass           => open,
        o_data_bypass_we        => open,

        i_run_state_125           => run_state_125,
        i_run_state_156           => run_state_125,
        o_ack_run_prep_permission => open,

        i_lvds_data_in          => (others => '0'),

        -- 156.25 MHz
        i_clk_156               => clk,
        i_clk_125               => clk,
        i_lvds_rx_inclock_A     => clk,
        i_lvds_rx_inclock_B     => clk,
        i_sync_reset_cnt        => '0',

        -- trigger for quad module
        i_trigger_en            => '0',
        i_trigger_timestamp     => (others => '0'),

        i_areset_n              => reset_n--,
    );

    e_merger : entity work.data_merger
    generic map (
        N_LINKS => N_LINKS,
        feb_mapping => (3,2,1,0)--,
    )
    port map (
        i_fpga_ID               => x"000A",
        i_FEB_type              => "111000",

        i_run_state             => run_state_125,
        i_run_number            => (others => '0'),

        o_data                  => o_data,
        o_datak                 => o_datak,

        i_slowcontrol_write_req =>'0',
        i_data_slowcontrol      => (others => '0'),

        i_data_write_req        => fifo_write,
        i_data                  => fifo_wdata,
        o_fifos_almost_full     => open,

        i_override_data         => (others => '0'),
        i_override_datak        => (others => '0'),
        i_override_req          => '0',
        o_override_granted      => open,

        i_can_terminate         => '0',
        o_terminated            => open,
        i_data_priority         => '0',
        o_rate_count            => open,

        i_reset_n               => reset_n,
        i_clk                   => clk--,
    );

    -- scifi data
    rx(2).data <= o_data(31 downto 0);
    rx(2).datak <= o_datak(3 downto 0);
    rx(3).data <= o_data(63 downto 32);
    rx(3).datak <= o_datak(7 downto 4);

    resets_n(RESET_BIT_DATAGEN)                             <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_SWB_STREAM_MERGER)                   <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_SWB_TIME_MERGER)                     <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_DATA_PATH)                           <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_RUN_START_ACK)                       <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_RUN_END_ACK)                         <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_SC_MAIN)                             <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_SC_SECONDARY)                        <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_EVENT_COUNTER)                       <= '0', '1' after (1.0 us / CLK_MHZ);

    writeregs(DATAGENERATOR_DIVIDER_REGISTER_W)                         <= x"00000002";
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK)           <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_TEST_DATA)          <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_TEST_ERROR)         <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_STREAM)             <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER)             <= '1';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_SUBHDR_SUPPRESS)    <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_HEAD_SUPPRESS)      <= '0';

    writeregs(SWB_LINK_MASK_PIXEL_REGISTER_W)(4 downto 0)   <= '1' & x"F";--x"00000048";
    writeregs(SWB_LINK_MASK_PIXEL_REGISTER_W)(9 downto 5)   <= '1' & x"F";--x"00000048";
    writeregs(SWB_LINK_MASK_PIXEL_REGISTER_W)(1 downto 0)   <= "11";
    writeregs(FEB_ENABLE_REGISTER_W)                        <= x"0000001F";--x"00000048";
    writeregs(SWB_READOUT_LINK_REGISTER_W)                  <= x"00000001";
    writeregs(GET_N_DMA_WORDS_REGISTER_W)                   <= (others => '1');
    writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE)               <= '1';

    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_PIXEL_US)   <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_PIXEL_DS)   <= '0';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_SCIFI)      <= '1';
    writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_ALL)        <= '0';

    e_swb_block : entity work.swb_block
    generic map (
        g_NLINKS_FEB_TOTL       => g_NLINKS_FEB_TOTL,
        g_NLINKS_DATA_GENERIC   => g_NLINKS_DATA_GENERIC,
        g_NLINKS_FARM_TOTL      => g_NLINKS_FARM_TOTL,
        g_NLINKS_DATA_PIXEL_US  => g_NLINKS_DATA_PIXEL_US,
        g_NLINKS_DATA_PIXEL_DS  => g_NLINKS_DATA_PIXEL_DS,
        g_SC_SEC_SKIP_INIT      => '1'--,
    )
    port map (
        i_feb_rx        => rx(g_NLINKS_FEB_TOTL-1 downto 0),
        o_feb_tx        => tx(g_NLINKS_FEB_TOTL-1 downto 0),

        i_writeregs     => writeregs,
        o_readregs      => readregs,
        i_resets_n      => resets_n,

        i_wmem_rdata    => writememdata_out,
        o_wmem_addr     => memaddr,

        o_rmem_wdata    => readmem_writedata,
        o_rmem_addr     => readmem_writeaddr,
        o_rmem_we       => readmem_wren,

        i_dmamemhalffull=> dmamemhalffull,
        o_dma_wren      => dma_wren,
        o_endofevent    => endofevent,
        o_dma_data      => dma_data,

        o_farm_tx       => open,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    dma_data_array(0) <= dma_data(0*32 + 31 downto 0*32);
    dma_data_array(1) <= dma_data(1*32 + 31 downto 1*32);
    dma_data_array(2) <= dma_data(2*32 + 31 downto 2*32);
    dma_data_array(3) <= dma_data(3*32 + 31 downto 3*32);
    dma_data_array(4) <= dma_data(4*32 + 31 downto 4*32);
    dma_data_array(5) <= dma_data(5*32 + 31 downto 5*32);
    dma_data_array(6) <= dma_data(6*32 + 31 downto 6*32);
    dma_data_array(7) <= dma_data(7*32 + 31 downto 7*32);

end architecture;
