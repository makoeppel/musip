-- data generator for mupix datapath on FEB
-- Martin Mueller (muellem@uni-mainz.de)
-- November 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.lfsr_taps.all;
use work.mupix_registers.all;
use work.mupix.all;
use work.mudaq.all;


entity mp_sorter_datagen is
generic (
    send_header_trailer : std_logic := '0'--;
);
port (
    i_running           : in  std_logic;
    i_global_ts         : in  std_logic_vector(63 downto 0);
    i_control_reg       : in  std_logic_vector(31 downto 0);
    i_seed              : in  std_logic_vector(64 downto 0);
    o_hit_counter       : out std_logic_vector(63 downto 0);

    -- signals to insert after sorter
    o_fifo_wdata        : out std_logic_vector(35 downto 0);
    o_fifo_write        : out std_logic;
    o_datak             : out std_logic_vector(3 downto 0);

    -- signals to insert before sorter
    o_ts                : out ts_array_t      (35 downto 0);
    o_chip_ID           : out ch_ID_array_t   (35 downto 0);
    o_row               : out row_array_t     (35 downto 0);
    o_col               : out col_array_t     (35 downto 0);
    o_tot               : out tot_array_t     (35 downto 0);
    o_hit_ena           : out std_logic_vector(35 downto 0);

    i_generror_register : in  std_logic_vector(31 downto 0) := (others => '0');
    o_error_generated   : out std_logic;

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture rtl of mp_sorter_datagen is

    signal reset                : std_logic;
    signal lfsr_reset           : std_logic;

    signal fwdata               : std_logic_vector(35 downto 0);
    signal fwrite               : std_logic;
    signal enable               : std_logic;
    signal running_prev         : std_logic;
    signal hit_counter          : unsigned(63 downto 0);
    signal frame_ts_overflow    : std_logic;
    signal packet_ts_overflow   : std_logic;
    signal run_shutdown         : std_logic;
    signal global_ts            : std_logic_vector(63 downto 0);

    type genstate_t is (
        pre, head1, head2, subhead, trail, EoR, hitgen,
        idle
    );
    signal genstate : genstate_t;

    -- rate control signals
    signal produce_next_packet  : std_logic;
    signal produce_next_frame   : std_logic;
    signal produce_next_hit     : std_logic;
    signal hit_ena_vec          : std_logic_vector(35 downto 0);
    signal hit_ena_vec_prev     : std_logic_vector(35 downto 0);
    signal hit_ena_vec_prev2    : std_logic_vector(35 downto 0);

    type   next_hit_p_t           is array(35 downto 0) of std_logic_vector(15 downto 0);
    signal next_hit_p           : next_hit_p_t := (others => x"FFFF");
    signal ts_pull_ahead        : std_logic;

    -- control signals to generate errors for testing downstream components (was used at some point in sim, compiles away for hardware)
    signal unsorted             : std_logic := '0'; -- send hits unsorted in time
    signal skip_frame           : std_logic := '0'; -- skip one subheader
    signal repeat_frame_ts      : std_logic := '0'; -- send subheader again/ to early
    signal data_burst           : std_logic := '0'; -- full steam for x cycles
    signal miss_trailer         : std_logic := '0'; -- skip trailer
    signal miss_header          : std_logic := '0'; -- skip header
    signal miss_half_of_header  : std_logic := '0'; -- skip 1/2 header
    signal miss_EOR             : std_logic := '0'; -- skip end of run
    signal complete_nonsense    : std_logic := '0'; -- random timestamp

    signal n_error               : std_logic_vector(7 downto 0);
    signal n_error_remaining     : std_logic_vector(7 downto 0);
    signal error_probability     : std_logic_vector(7 downto 0);--something like and_reduce(random1(setting downto 0))
    signal error_generated      : std_logic; -- a single one

    -- randoms:
    signal ts                   : std_logic_vector(3 downto 0);
    signal chipID_index         : std_logic_vector(5 downto 0);
    signal chipID               : std_logic_vector(5 downto 0);
    signal row                  : std_logic_vector(7 downto 0);
    signal col                  : std_logic_vector(7 downto 0);
    signal tot                  : std_logic_vector(5 downto 0);
    signal ts_before_sorter     : std_logic_vector(10 downto 0);

    -- 64 bit lfsr taps are not good for the rate distribution, using 65 bit instead
    signal random0              : std_logic_vector(64 downto 0);
    signal random_seed          : std_logic_vector(64 downto 0);

    type valid_ID_t             is array (3 downto 0) of std_logic_vector(5 downto 0);
    constant valid_chipIDs      : valid_ID_t :=("001000", "010001", "100010", "000011"); --TODO: list all valid ID's depending on reg for layer

    begin
    o_fifo_wdata        <= fwdata;
    o_fifo_write        <= fwrite;
    enable              <= i_control_reg(31);
    o_hit_counter       <= std_logic_vector(hit_counter);
    reset               <= not i_reset_n;
    random_seed         <= "11001111101100010101110100100010011010110001101011110100101000000" when i_control_reg(MP_DATA_GEN_SYNC_BIT) = '1' else i_seed;
    lfsr_reset          <= '1' when (i_running = '0' or i_reset_n = '0') else '0';

    -- this only works in simulation -.-
    -- next_hit_p_range <= to_integer(unsigned(i_control_reg(MP_DATA_GEN_HIT_P_RANGE)));
    -- produce_next_hit <= and_reduce(random0(next_hit_p_range downto 0));
    -- New way:
    gen_next_hit_p2 : for j in 0 to 35 generate
        gen_next_hit_p: for i in 0 to 15 generate
            next_hit_p(j)(i)   <= random0(i+J) when unsigned(i_control_reg(MP_DATA_GEN_HIT_P_RANGE)) >= i else '1';
        end generate;
    end generate;

    process(i_clk,i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        fwdata              <= (others => '0');
        fwrite              <= '0';
        run_shutdown        <= '0';
        produce_next_packet <= '0';
        produce_next_frame  <= '0';
        produce_next_hit    <= '0';
        hit_counter         <= (others => '0');
        running_prev        <= '0';
        frame_ts_overflow   <= '0';
        packet_ts_overflow  <= '0';
        genstate            <= idle;
        global_ts           <= (others => '0');
        ts                  <= (others => '0');
        ts_pull_ahead       <= '0';
        ts_before_sorter    <= (others => '0');

    elsif rising_edge(i_clk) then
        fwdata              <= (others => '0');
        o_datak             <= (others => '0');
        fwrite              <= '0';
        running_prev        <= i_running;
        frame_ts_overflow   <= '0';
        packet_ts_overflow  <= '0';
        error_generated     <= '0';

        -------REMOVE / generate -------------------
        produce_next_packet <= '1';
        produce_next_frame  <= '1';
        --------------------------------------------

        ------- pre-sorter signals -----------------
        o_ts                <= (others => ts_before_sorter);
        o_chip_ID           <= (others => chipID);
        o_row               <= (others => row);
        o_col               <= (others => col);
        o_tot               <= (others => tot);
        o_hit_ena           <= hit_ena_vec and (not hit_ena_vec_prev) and (not hit_ena_vec_prev2); -- hit can only come every 3rd cycle
        hit_ena_vec_prev    <= hit_ena_vec;
        hit_ena_vec_prev2   <= hit_ena_vec_prev;
        --------------------------------------------

        if(i_control_reg(4) = '1') then
            hit_ena_vec         <= (others => '1'); -- full steam -- this is 36 * 125 Mhz here !!! will not work
        else
            for i in 0 to 35 loop
                hit_ena_vec(i)  <= and_reduce(next_hit_p(i));
            end loop;
        end if;

        if(i_control_reg(4) = '1') then
            produce_next_hit    <= '1'; -- full steam
        else
            produce_next_hit    <= and_reduce(next_hit_p(0)); -- probability to actually send the hit
        end if;

        if(running_prev = '1' and i_running = '0') then -- goto EoR marker
            run_shutdown        <= '1';
        end if;

        if(i_global_ts(3 downto 0) = "1110") then -- send new subheader
            frame_ts_overflow   <= '1';
        end if;

        if(i_global_ts(10 downto 0) = "11111111110") then -- send new preamble
            packet_ts_overflow  <= '1';
        end if;

        if(complete_nonsense = '1') then -- test-option
            global_ts           <= random0(63 downto 0);
            error_generated     <= '1';
        else
            global_ts           <= i_global_ts;
        end if;


        ts                  <= random0(33 downto 30);
        ts_before_sorter    <= random0(40 downto 30);
        --if (unsorted = '1' or complete_nonsense = '1') then --test-option
        --    ts                  <= random0(33 downto 30);
        --    ts_before_sorter    <= random0(40 downto 30); -- before sorter option
        if(genstate = subhead) then
            ts                  <= i_global_ts(3 downto 0);
            ts_pull_ahead       <= '0';
        elsif(random0(40) = '1' and ts_pull_ahead = '0') then
            ts                  <= i_global_ts(3 downto 0);
        elsif(random0(54 downto 50) = "11111") then
            ts_pull_ahead       <= '1';
            ts                  <= "1111";
        end if;

        case genstate is
        when idle =>
            if(run_shutdown = '1') then
                genstate <= EoR;
            elsif( i_running = '1' and enable = '1' and produce_next_packet = '1') then
                if(miss_header = '0') then
                    if ( send_header_trailer = '1' ) then
                        genstate <= pre;
                    else
                        genstate <= head1;
                    end if;
                else
                    genstate <= subhead;
                    error_generated  <= '1';
                end if;
            end if;

        when pre =>
            fwdata(31 downto 26)   <= MUPIX_HEADER_ID;
            fwdata(25 downto 8)    <= (others => '0');
            fwdata(7 downto 0)     <= x"bc";
            o_datak                <= "0001";
            fwrite                 <= '1';
            genstate               <= head1;

        when head1 =>
            if(miss_half_of_header = '0') then
                genstate            <= head2;
            else
                genstate            <= subhead;
                error_generated     <= '1';
            end if;
            fwdata(35 downto 32)    <= MERGER_FIFO_PAKET_START_MARKER;
            fwdata(31 downto  0)    <= global_ts(47 downto 16);
            fwrite                  <= '1';

        when head2 =>
            genstate                <= subhead;
            fwdata(31 downto 16)    <= global_ts(15 downto  0);
            fwrite                  <= '1';

        when subhead =>
            if(packet_ts_overflow = '1') then
                genstate            <= trail;
            elsif(produce_next_frame = '1') then
                genstate            <= hitgen;
                fwdata(31 downto 26)<= "111111";
                fwdata(25 downto 23)<= "000";
                fwdata(22 downto 16)<= global_ts(10 downto 4);
                fwrite              <= '1';
            end if;

        when hitgen =>
            if(packet_ts_overflow = '1') then
                genstate            <= trail;
            elsif(frame_ts_overflow = '1') then
                genstate            <= subhead;
            elsif(repeat_frame_ts = '1') then
                genstate            <= subhead;
                error_generated     <= '1';
            end if;
            if(produce_next_hit = '1') then
                fwdata              <= "0000" & ts & chipID & row & col & tot;
                fwrite              <= '1';
                hit_counter         <= hit_counter + 1;
            end if;

        when trail =>
            genstate                <= idle;
            if(miss_trailer = '0') then
                fwdata(35 downto 32)<= MERGER_FIFO_PAKET_END_MARKER;
                if ( send_header_trailer = '1') then
                    fwdata(7 downto 0) <= x"9c";
                end if;
                o_datak             <= "0001";
                fwrite              <= '1';
            else
                error_generated     <= '1';
            end if;

        when EoR =>
            if(miss_EOR = '0') then
                fwdata(35 downto 32)<= MERGER_FIFO_RUN_END_MARKER;
                fwrite              <= '1';
                run_shutdown        <= '0';
            else
                error_generated     <= '1';
            end if;
            genstate                <= idle;

        when others =>
            genstate <= idle;
        end case;

    end if;
    end process;

    e_shift0 : entity work.linear_shift
    generic map (
        g_m => 65,
        g_poly => lfsr_taps65
    )
    port map (
        i_sync_reset        => lfsr_reset, -- sync with run state --> all FEBs generate the same thing in sync--> can measure delays between them etc.
        i_seed              => random_seed,
        i_en                => '1',
        o_lfsr              => random0,
        i_reset_n           => '1',
        i_clk               => i_clk--,
    );

    tot         <= random0( 5 downto  0);
    col         <= random0(13 downto  6);
    row         <= random0(21 downto 14);
    chipID_index<= random0(27 downto 22);
    chipID      <= valid_chipIDs(to_integer(unsigned(chipID_index)) mod valid_chipIDs'length); -- a random valid_chipID

end architecture;
