library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;
use work.mutrig_registers.all;
use work.sorter_registers.all;
use work.lvds_registers.all;

entity tb_tile_data_path is
end entity;

architecture arch of tb_tile_data_path is

    constant CLK_MHZ    : real := 10000.0; -- MHz
    constant N_LINKS    : integer := 1;
    constant N_INPUTSRX : integer := 13;
    constant N_MODULES  : integer := 1;

    signal clk, reset_n : std_logic := '0';

    signal scifi_reg        : work.util.rw_t;
    signal run_state_125    : run_state_t;
    signal delay            : std_logic_vector(1 downto 0);
    signal reset_state      : std_logic_vector(4 downto 0);

    signal i_simdata        : std_logic_vector(8*N_INPUTSRX-1 downto 0) := (others => '0');
    signal i_simdatak       : std_logic_vector(N_INPUTSRX-1 downto 0) := (others => '0');

    signal fifo_wdata       : std_logic_vector(36*N_LINKS-1 downto 0);
    signal fifo_write       : std_logic_vector(N_LINKS-1 downto 0);

begin

    clk     <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);


    --! Setup
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    process(reset_n, clk)
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

        for i in 0 to N_INPUTSRX-1 loop
            i_simdata((i+1)*8-1 downto i*8) <= x"BC";
            i_simdatak(i) <= '1';
        end loop;

        if (reset_state = "10010") then
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(LVDS_STATUS_REGISTER_R, 16));
            scifi_reg.re <= '1';
        end if;

        if ( delay = "00" ) then

        case reset_state is

        -- first we enable the data generator config
        when "00000" =>
            --scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(MUTRIG_CTRL_DUMMY_REGISTER_W, 16));
            --scifi_reg.wdata(11 downto 0)<= "000000000001";
            --scifi_reg.we                <= '1';
            reset_state                 <= "00001";
            run_state_125 <= RUN_STATE_PREP;

        when "00001" =>
            --scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(MUTRIG_CTRL_DUMMY_REGISTER_W, 16));
            --scifi_reg.wdata(11 downto 0)<= "000000000011";
            --scifi_reg.we                <= '1';
            reset_state                 <= "00010";
            run_state_125 <= RUN_STATE_SYNC;

        when "00010" =>
            --scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(MUTRIG_CTRL_DUMMY_REGISTER_W, 16));
            --scifi_reg.wdata(11 downto 0)<= "000000001011";
            --scifi_reg.we                <= '1';
            reset_state <= "00011";
            run_state_125 <= RUN_STATE_RUNNING;

        -- disable the PRBS decoder
        when "00011" =>
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(MUTRIG_CTRL_DP_REGISTER_W, 16));
            scifi_reg.wdata(31)         <= '1';      -- i_SC_disable_dec PRBS
            scifi_reg.wdata(3 downto 0) <= "0100";   -- mask inputs
            scifi_reg.we                <= '1';
            reset_state <= "00100";

        when "00100" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"1C";
                i_simdatak(i) <= '1';
            end loop;

            reset_state <= "00101";

        when "00101" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"32";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "00110";

        when "00110" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"8F";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "00111";

        when "00111" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"90"; -- x"50" is short mode
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01000";

        when "01000" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"01";
                i_simdatak(i) <= '0';
            end loop;
            run_state_125 <= RUN_STATE_PREP;
            reset_state <= "01001";

        when "01001" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"CC";
                i_simdatak(i) <= '0';
            end loop;
            run_state_125 <= RUN_STATE_SYNC;
            reset_state <= "01010";

        when "01010" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"5F";
                i_simdatak(i) <= '0';
            end loop;
            run_state_125 <= RUN_STATE_RUNNING;
            reset_state <= "01011";

        when "01011" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"D0";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01100";

        when "01100" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"C7";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01101";

        when "01101" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"A5";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01110";

        when "01110" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"69";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "01111";

        when "01111" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"52";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "10000";

        when "10000" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"68";
                i_simdatak(i) <= '0';
            end loop;
            reset_state <= "10001";

        when "10001" =>
            for i in 0 to N_INPUTSRX-1 loop
                i_simdata((i+1)*8-1 downto i*8) <= x"9C";
                i_simdatak(i) <= '1';
            end loop;
            scifi_reg.addr(15 downto 0) <= std_logic_vector(to_unsigned(SORTER_NINTIME_REGISTER_R, 16));
            scifi_reg.re                <= '1';
            reset_state <= "10010";

        when "10010" =>
            --

        when others =>
            reset_state <= "00000";

        end case;
        end if;
    end if;
    end process;



    --! tile Block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    -- tile detector firmware
    e_tile_path : entity work.tile_path
    generic map (
        N_INPUTSRX      => N_INPUTSRX,
        N_MODULES       => N_MODULES,
        INPUT_SIGNFLIP  => x"FFFFFFFF", -- swap input 0 of con2 and 0 of con3 x"FFFFFFEE"
        LVDS_PLL_FREQ   => 125.0,
        LVDS_DATA_RATE  => 1250.0--,
    )
    port map (
        -- read latency - 1
        i_reg_addr                  => scifi_reg.addr(15 downto 0),
        i_reg_re                    => scifi_reg.re,
        o_reg_rdata                 => scifi_reg.rdata,
        i_reg_we                    => scifi_reg.we,
        i_reg_wdata                 => scifi_reg.wdata,

        -- to detector module
        o_module_reset  => open,
        o_testpulse     => open,
        i_data          => (others => '0'),

        -- data out to common firmware
        o_fifo_write                => fifo_write,
        o_fifo_wdata                => fifo_wdata,

        i_common_fifos_almost_full  => (others => '0'),
        i_debug_almost_full => (others => '0'),

        -- simulation input
        i_enablesim                 => '1',
        i_simdata                   => i_simdata,
        i_simdatak                  => i_simdatak,

        -- reset system
        i_run_state                 => run_state_125,
        o_run_state_all_done        => open,

        -- 125 MHz
        i_clk_ref_A                 => clk,
        i_clk_ref_B                 => clk,

        -- test output
        o_test_led                  => open,

        -- clk / reset
        i_reset_156_n               => reset_n,
        i_clk_156                   => clk,
        i_reset_125_n               => reset_n,
        i_clk_125                   => clk--,
    );

    e_merger : entity work.data_merger
    generic map (
        N_LINKS => 1,
        feb_mapping => (3,2,1,0)--,
    )
    port map (
        i_fpga_ID               => x"000A",
        i_FEB_type              => "111000",

        i_run_state             => run_state_125,
        i_run_number            => (others => '0'),

        o_data                  => open,
        o_datak                 => open,

        i_slowcontrol_write_req =>'0',
        i_data_slowcontrol      => (others => '0'),

        i_data_write_req(0)     => fifo_write(0),
        i_data                  => fifo_wdata(35 downto 0),
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

end architecture;
