library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;
use work.mutrig_registers.all;
use work.sorter_registers.all;
use work.lvds_registers.all;
use work.util_slv.all;
use work.a10_pcie_registers.all;
use work.mudaq.all;

entity tb_scifi_data_path is
end entity;

architecture arch of tb_scifi_data_path is

    constant CLK_MHZ    : real := 10000.0; -- MHz
    constant N_LINKS    : integer := 2;
    constant N_ASICS    : integer := 4;
    constant N_MODULES  : integer := 2;
    constant N_ASICS_TOTAL : natural := N_MODULES * N_ASICS;

    -- constants
    constant g_NLINKS_FEB_TOTL   : integer := 16;
    constant g_NLINKS_DATA_GENERIC : integer := 8;
    constant g_NLINKS_FARM_TOTL  : integer := 1;
    constant g_NLINKS_DATA_PIXEL_US : integer := 0;
    constant g_NLINKS_DATA_PIXEL_DS : integer := 0;

    signal clk, reset_n : std_logic := '0';

    signal scifi_reg        : work.util.rw_t;
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

    signal counter : slv32_array_t(5+(g_NLINKS_DATA_GENERIC*5)-1 downto 0);

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
        scifi_reg.addr  <= (others => '0');
        scifi_reg.wdata <= (others => '0');
        scifi_reg.re    <= '0';
        scifi_reg.we    <= '0';
        delay           <= (others => '0');
        --
    elsif rising_edge(clk) then

        delay <= delay + '1';
        scifi_reg.addr  <= (others => '0');
        scifi_reg.wdata <= (others => '0');
        scifi_reg.re    <= '0';
        scifi_reg.we    <= '0';

        for i in 0 to N_ASICS_TOTAL-1 loop
            i_simdata((i+1)*8-1 downto i*8) <= x"BC";
            i_simdatak(i) <= '1';
        end loop;

        if (reset_state = "10010") then
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(MUTRIG_CNT_ADDR_REGISTER_R, 16));
            scifi_reg.re <= '1';
        end if;

        if (reset_state = "00101") then
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(LVDS_STATUS_REGISTER_R, 16));
            scifi_reg.re                <= '1';
        end if;

        if ( delay = "00" ) then

        case reset_state is

        -- first we enable the data generator config
        when "00000" =>
            --scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(SCIFI_CTRL_DUMMY_REGISTER_W, 16));
            --scifi_reg.wdata(11 downto 0)<= "000000000001";
            --scifi_reg.we                <= '1';
            -- enable direct link readout
            --scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(SCIFI_LINK_DATA_REGISTER_W, 16));
            --scifi_reg.wdata(31)         <= '1';
            --scifi_reg.wdata(3 downto 0) <= x"1";
            --scifi_reg.we                <= '1';
            reset_state                 <= "00001";
            run_state_125 <= RUN_STATE_PREP;

        when "00001" =>
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(MUTRIG_CNT_CTRL_REGISTER_W, 16));
            scifi_reg.wdata(31) <= '0';
            scifi_reg.we                <= '1';
            reset_state                 <= "00010";
            run_state_125 <= RUN_STATE_SYNC;

        -- enable lapse counter
        when "00010" =>
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W, 16));
            scifi_reg.wdata(31)<= '0';
            scifi_reg.we                <= '1';
            reset_state <= "00011";
            run_state_125 <= RUN_STATE_RUNNING;

        -- disable the PRBS decoder
        when "00011" =>
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(MUTRIG_CTRL_DP_REGISTER_W, 16));
            scifi_reg.wdata(31)         <= '1';      -- i_SC_disable_dec PRBS
            scifi_reg.wdata(7 downto 0) <= "11111111";   -- mask inputs
            scifi_reg.we                <= '1';
            reset_state <= "00100";

        when "00100" =>
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(SORTER_COUNTER_REGISTER_R, 16));
            scifi_reg.re                <= '1';
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
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(SORTER_COUNTER_REGISTER_R + SORTER_INDEX_NINTIME, 16));
            scifi_reg.re                <= '1';
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



    --! Scifi Block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    -- scifi detector firmware
    e_scifi_path : entity work.scifi_path
    generic map (
        N_MODULES       => N_MODULES,
        N_ASICS         => N_ASICS,
        N_LINKS         => N_LINKS,
        INPUT_SIGNFLIP  => x"FFFFFFFF", -- swap input 0 of con2 and 0 of con3 x"FFFFFFEE"
        LVDS_PLL_FREQ   => 125.0,
        LVDS_DATA_RATE  => 1250.0--,
    )
    port map (
        i_reg_addr                  => scifi_reg.addr(15 downto 0),
        i_reg_re                    => scifi_reg.re,
        o_reg_rdata                 => scifi_reg.rdata,
        i_reg_we                    => scifi_reg.we,
        i_reg_wdata                 => scifi_reg.wdata,

        o_chip_reset                => open,

        i_scifi_lvds_los_n          => (others => '0'),
        i_debug_almost_full          => (others => '0'),

        o_pll_test                  => open,
        o_ainj_test                 => open,
        i_data                      => (others => '0'),

        o_fifo_write                => fifo_write,
        o_fifo_wdata                => fifo_wdata,

        i_common_fifos_almost_full  => (others => '0'),

        i_run_state                 => run_state_125,
        o_run_state_all_done        => open,

        o_MON_rxrdy                 => open,

        i_clk_ref_A                 => clk,
        i_clk_ref_B                 => clk,

        o_fast_pll_clk              => open,

        i_scifi_temp_mutrig_reading        => (others => (others => '1')),
        i_scifi_temp_sipm_reading        => (others => (others => '1')),
        i_scifi_temp_dab_reading        => (others => (others => '1')),

        -- simulation input
        i_enablesim                 => '1',
        i_simdata                   => i_simdata,
        i_simdatak                  => i_simdatak,

        i_reset_156_n               => reset_n,
        i_clk_156                   => clk,
        i_reset_125_n               => reset_n,
        i_clk_125                   => clk--,
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
    writeregs(SWB_LINK_MASK_SCIFI_REGISTER_W)(1 downto 0)   <= "11";
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
        g_NLINKS_DATA_PIXEL_DS  => g_NLINKS_DATA_PIXEL_DS--,
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
