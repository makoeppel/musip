--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all; -- for UNIFORM, TRUNC
use ieee.numeric_std.all; -- for TO_UNSIGNED
use ieee.std_logic_textio.all; -- for write std_logic_vector to line
library std;
use std.textio.all; --FOR LOGFILE WRITING
library mutrig_sim;
use mutrig_sim.txt_util.all;
library modelsim_lib;
use modelsim_lib.util.all;

library mutrig_sim;
use mutrig_sim.txt_util.all;
use mutrig_sim.datapath_types.all;
use mutrig_sim.datapath_helpers.all;

entity spi_assem_tb is
end entity;

architecture RTL of spi_assem_tb is

    signal config : stic3_spi_config;
    signal SPI_data : STD_LOGIC_VECTOR(0 to N_CONF_BITS-1):=(others=>'0');         --THE DATA VECTOR TO BE SENT TO THE SPI SLAVE

begin

    ------------------------------------------------------------------------
    -- ===SIMULATION PROCESS FOR SPI=== --{{{

    -- convert config to SPI data
    SPI_data <= config_to_vector(config);

    sim_spi : process --{{{
        variable seed1, seed2: positive;
        -- Random real-number value in range 0 to 1.0
        variable rand: real;
        -- Random integer value in range 0=> 4095
        variable int_rand : integer;
    begin

        seed1:=1483;
        seed2:=2356;

        --========Generate and transmit new values============= --{{{
        -- generate random config data for channels
        -- gen_idle_signal
        config.gen_idle_signal <= '1';
        config.en_sync_ch_rst <= '1';
        config.recv_rec_all <= (others =>'0');

        -- generate configurations for L1_fifo external trigger
        config.fifo_trig_mode <= '0';
        config.fifo_trig_back_time <= (others => '0');
        config.fifo_trig_sign_forw_time <= '0';
        config.fifo_trig_forw_time <= (others => '0');

        --The configuration for the master slave select
        config.ms_limits <= "00000";
        config.ms_switch_sel <= '0';
        config.ms_debug <= '0';

        -- frame_generator configurations
        config.prbs_debug <= '1';
        config.single_prbs <= '0';
        config.fast_trans_mode <= '0';

        -- pll configurations
        config.pll_SetCoarse <= '0';
        config.pll_EnVCOMonitor <= '0';
        config.disable_coarse <= '0';

        config.en_pll_lol_debug <= '0';
        config.en_ch_event_cnt <= '0';


        -- configurations for analog channels --{{{
        for i in 0 to N_CHANNELS-1 loop

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.Anode_flag(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.Cathode_flag(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.S_switch(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.SorD(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.SorD_not(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.edge(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.edge_cml(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.DAC_cmlscale(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*4.0));
            config.comp_spi(i) <=  std_logic_vector(to_unsigned(int_rand,2));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*128.0));
            config.DAC_SiPM(i) <=  std_logic_vector(to_unsigned(int_rand,7));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*512.0));
            config.DAC_Tthresh(i) <=  std_logic_vector(to_unsigned(int_rand,9));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*256.0));
            config.DAC_ampcom(i) <=  std_logic_vector(to_unsigned(int_rand,8));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*128.0));
            config.DAC_inputbias(i) <=  std_logic_vector(to_unsigned(int_rand,7));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*256.0));
            config.DAC_Ethresh(i) <=  std_logic_vector(to_unsigned(int_rand,8));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*256.0));
            config.DAC_Ebias(i) <=  std_logic_vector(to_unsigned(int_rand,3));


            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*128.0));
            config.DAC_pole(i) <=  std_logic_vector(to_unsigned(int_rand,7));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*16.0));
            config.DAC_cml(i) <=  std_logic_vector(to_unsigned(int_rand,4));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*4.0));
            config.DAC_delay(i) <=  std_logic_vector(to_unsigned(int_rand,2));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*8.0));
            config.amon_ctrl(i) <=  std_logic_vector(to_unsigned(int_rand,3));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.dmon_ena(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.dmon_sw(i) <=  std_logic(to_unsigned(int_rand,1)(0));

            UNIFORM(seed1, seed2, rand);
            int_rand := INTEGER(TRUNC(rand*1.0));
            config.tdctest(i) <=  std_logic(to_unsigned(int_rand,1)(0));
        end loop;
        --}}}

        -- channel mask
        config.channel_mask <= (others => '0');

        -- TDC bias DAC and monitor DACs --{{{
        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*65536.0));
        config.dac_tdc_bias(0 to 15) <=  std_logic_vector(to_unsigned(int_rand,16));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*65536.0));
        config.dac_tdc_bias(16 to 31) <=  std_logic_vector(to_unsigned(int_rand,16));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*65536.0));
        config.dac_tdc_bias(32 to 47) <=  std_logic_vector(to_unsigned(int_rand,16));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*65536.0));
        config.dac_tdc_bias(48 to 63) <=  std_logic_vector(to_unsigned(int_rand,16));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*256.0));
        config.dac_tdc_bias(64 to 71) <=  std_logic_vector(to_unsigned(int_rand,8));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*4096.0));
        config.dac_tdc_latchbias <=  std_logic_vector(to_unsigned(int_rand,12));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*1.0));
        config.amon_en <=  std_logic(to_unsigned(int_rand,1)(0));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*256.0));
        config.amon_DAC <=  std_logic_vector(to_unsigned(int_rand,8));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*1.0));
        config.dig_mon1_en <=  std_logic(to_unsigned(int_rand,1)(0));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*256.0));
        config.dig_mon1_DAC <=  std_logic_vector(to_unsigned(int_rand,8));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*1.0));
        config.dig_mon2_en <=  std_logic(to_unsigned(int_rand,1)(0));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*256.0));
        config.dig_mon2_DAC <=  std_logic_vector(to_unsigned(int_rand,8));

        UNIFORM(seed1, seed2, rand);
        int_rand := INTEGER(TRUNC(rand*16384.0));
        config.txd_lvds_tx_dac <= std_logic_vector(to_unsigned(int_rand,14));
        --}}}

        config.coincidence_config <= (others => '0');
        config.coincidence_window_config <= '0';


        --}}}

        wait;
    end process;
    --}}}

    --}}}

end architecture;
