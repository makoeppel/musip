-- Stic/Mutrig event storing
-- Simon Corrodi, July 2017
-- corrodis@phys.ethz.ch
-- Konrad Briggl, April 2019: Stripped off pcie writer part, moved to separate file

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity mutrig_store is
port (
    i_clk_deser      : in  std_logic;
    i_clk_rd         : in  std_logic;   -- fast PCIe memory clk
    i_reset          : in  std_logic;   -- reset, active high
    i_aclear         : in  std_logic;   -- asyncronous reset for buffer clear
    i_event_data     : in  std_logic_vector(47 downto 0);   -- event data from deserelizer
    i_event_ready    : in  std_logic;
    i_new_frame      : in  std_logic;   -- start of frame
    i_frame_info_rdy : in  std_logic;   -- frame info ready (2 cycles after new_frame)
    i_end_of_frame   : in  std_logic;   -- end of frame
    i_frame_info     : in  std_logic_vector(15 downto 0);
    i_frame_number   : in  std_logic_vector(15 downto 0);
    i_crc_error      : in  std_logic;
    --event data output inteface
    o_fifo_data      : out std_logic_vector(55 downto 0);   -- event data output
    o_fifo_empty     : out std_logic;
    i_fifo_rd        : in  std_logic;

    --monitoring
    o_fifo_full      : out std_logic;   -- sync to i_clk_deser. Write-when-fill is prevented internally
    i_reset_counters : in  std_logic;
    o_eventcounter   : out std_logic_vector(31 downto 0);
    o_timecounter    : out std_logic_vector(63 downto 0);
    o_framecounter   : out std_logic_vector(63 downto 0);
    o_crcerrorcounter: out std_logic_vector(31 downto 0);

    o_prbs_err_cnt   : out std_logic_vector(31 downto 0);
    o_prbs_wrd_cnt   : out std_logic_vector(63 downto 0);

    --configuration
    i_SC_mask        : in  std_logic -- '1':  block any data from being written to the fifo
);
end entity;

architecture rtl of mutrig_store is

    signal crcerror             : std_logic;
    signal s_full_event_data    : std_logic_vector(55 downto 0);
    signal s_event_ready        : std_logic;

    -- fifo clear from core, synced to rxclk
    signal s_clear_rxclk_n      : std_logic;

    -- fifo
    signal s_fifofull : std_logic;
    signal s_fifoused : std_logic_vector(7 downto 0);

    signal s_fifofull_almost : std_logic;
    -- save data loss implementation
    signal s_have_dropped    : std_logic;

    -- simulation signals
    signal hit_type : std_logic;
    signal channel : std_logic_vector(4 downto 0);

begin

    u_prbs_checker : entity work.prbs48_checker
    port map (
        i_new_cycle     => i_new_frame,
        i_rst_counter   => i_reset_counters,

        i_new_word      => i_event_ready,
        i_prbs_word     => i_event_data,

        o_err_cnt       => o_prbs_err_cnt,
        o_wrd_cnt       => o_prbs_wrd_cnt,

        i_clk           => i_clk_deser--,
    );

    e_cnt_eventcounter : entity work.counter
    generic map (
        WRAP => true,
        W => o_eventcounter'length--,
    )
    port map (
        o_cnt => o_eventcounter,
        i_ena => i_event_ready,
        i_reset_n => not i_reset_counters,
        i_clk => i_clk_deser--,
    );

    e_cnt_timecounter : entity work.counter
    generic map (
        WRAP => true,
        W => o_timecounter'length--,
    )
    port map (
        o_cnt => o_timecounter,
        i_ena => '1',
        i_reset_n => not i_reset_counters,
        i_clk => i_clk_deser--,
    );

    e_cnt_framecounter : entity work.counter
    generic map (
        WRAP => true,
        W => o_framecounter'length--,
    )
    port map (
        o_cnt => o_framecounter,
        i_ena => i_end_of_frame,
        i_reset_n => not i_reset_counters,
        i_clk => i_clk_deser--,
    );

    crcerror <= '1' when i_end_of_frame = '1' and i_crc_error='1' else '0';
    e_cnt_crcerror : entity work.counter
    generic map (
        WRAP => true,
        W => o_crcerrorcounter'length--,
    )
    port map (
        o_cnt => o_crcerrorcounter,
        i_ena => crcerror,
        i_reset_n => not i_reset_counters,
        i_clk => i_clk_deser--,
    );

    pro_mux_event_data : process(i_clk_deser, i_reset)
    begin
    if ( i_reset = '1' ) then
        s_fifofull_almost   <= '0';
        s_have_dropped      <='0';
        s_event_ready       <= '0';
        s_full_event_data   <= (others => '0');
        --
    elsif rising_edge(i_clk_deser) then
        if( s_fifoused(7) = '1' ) then
            s_fifofull_almost <= '1';
        else
            s_fifofull_almost <= '0';
        end if;

        if ( (i_event_ready = '1' or i_end_of_frame = '1' or i_frame_info_rdy = '1') and s_fifofull = '0' and i_SC_mask = '0') then
            s_event_ready <= '1';
        else
            s_event_ready <= '0';
        end if;

        --want to write hit data and fifo almost full, drop it (keeping flag)
        if ( s_fifofull_almost = '1' and i_end_of_frame = '0' and i_frame_info_rdy = '0' ) then
            s_event_ready <= '0';
            s_have_dropped<= '1';
        end if;

        --release have-dropped flag when seeing trailer
        if ( i_end_of_frame = '1' ) then
            s_have_dropped <= '0';
        end if;

        --channel masked, drop any data
        if ( i_SC_mask='1' ) then
            s_event_ready <= '0';
        end if;

        --selection of output data
        if ( i_end_of_frame = '1' ) then -- the MSB of the event data is '0' for frame info data
            ----------- TRAILER -----------
            --                   4bit - & 2bit identifier   & filler            & had bad trailer  & hit-dropped-flag & 1bit l2 overflow & 1bit crc_error   & frame id
            s_full_event_data <= "0000" & "11"              & X"0000000" & "00" & i_frame_info(10) & s_have_dropped   & i_frame_info(11) & i_crc_error      & i_frame_number;
        elsif ( i_frame_info_rdy= '1' ) then -- by defenition the first thing that happens
            ----------- HEADER -----------
            --                   4bit - & 2bit identifier   & filler             & frame id
            s_full_event_data <= "0000" & "10"              & X"00000000" & "00" & i_frame_number;
        elsif ( i_event_ready = '1' ) then -- the MSB of the event data is '1' for event data)
            -----------  DATA  -----------
            -- note: eflag reshuffled to have consistent position of this bit independent of data type
            -- identifier, short event flag, event data (cn,tbh,tcc,tf,ef,ebh,ecc,ef)
            if ( i_frame_info(14)='1' ) then --short event
                --                   4bit - & 2bit identifier   & filler    & hit type         & event data
                s_full_event_data <= "0000" & "00"              & "0"       & i_frame_info(14) & i_event_data(47 downto 21) & i_event_data(21 downto 1);
            else
                --                   4bit - & 2bit identifier   & filler    & hit type         & event data
                s_full_event_data <= "0000" & "00"              & "0"       & i_frame_info(14) & i_event_data(47 downto 22) & i_event_data(0) & i_event_data(21 downto 1);
            end if;
        end if;
    end if;
    end process;

    -- simulation signals
    hit_type <= i_frame_info(14);
    channel  <= i_event_data(47 downto 43);


    rst_sync_clear : entity work.reset_sync
    port map ( i_areset_n => not i_aclear, o_reset_n => s_clear_rxclk_n, i_clk => i_clk_deser);

    u_channel_data_fifo : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => 8,
        g_DATA_WIDTH => 56,
        g_WREG_N => 1,
        g_RREG_N => 1--,
    )
    port map (
        i_wdata     => s_full_event_data,
        i_we        => s_event_ready,
        o_wfull     => s_fifofull,
        o_wusedw    => s_fifoused,
        i_wclk      => i_clk_deser,

        o_rdata     => o_fifo_data,
        i_rack      => i_fifo_rd,
        o_rempty    => o_fifo_empty,
        i_rclk      => i_clk_rd,

        i_reset_n   => (not i_reset) or s_clear_rxclk_n--,
    );

    o_fifo_full     <= s_fifofull;

end architecture;
