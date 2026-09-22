-- debug stream controller for mu3e FEB
-- Martin Mueller, September 2022

-- 2 modes of operation, selected by DISABLE_BUFFER_g:
-- DISABLE_BUFFER_g = false:
--    merger will try to send all the received debug packets.
--    If not immediately possible buffer them in a fifo,
--    if fifo gets 3/4 filled send backpressure to detector part
--    if fifo becomes full throw packets away
-- DISABLE_BUFFER_g = true:
--    select with signals i_n_pakets_before_debug and i_no_of_debug_pakets how many debug packets you want to see
--    everything else is thrown away

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use work.mudaq.all;


entity debug_stream_controller is
generic (
    ADDR_WIDTH_g : positive := 10;
    DISABLE_BUFFER_g : boolean := false--;
);
port (
    i_clk_subdetector           : in    std_logic;
    i_fpga_ID_in                : in    std_logic_vector(15 downto 0);
    i_FEB_type_in               : in    std_logic_vector(5  downto 0); -- Type of the frontendboard (111010: mupix, 111000: mutrig, DO NOT USE 000111 or 000000 HERE !!!!)

    i_no_of_debug_pakets        : in    std_logic_vector(15 downto 0) := (others => '0'); -- number of consecutive debug pakets to send once debug controller has control, default: 1
    i_n_pakets_before_debug     : in    std_logic_vector(15 downto 0) := (others => '1'); -- 0xFFFF --> debug disabled, otherwise: number of data pakets to send before debug controller asks for control
    o_debug_frame_counter       : out   reg32 := (others => '0');
    o_subdetector_error_flag    : out   std_logic := '0'; -- subdetector protocol error
    i_max_cycles_in_debug       : in    integer := 9000; -- If the detector firmware is wrong and does not always send a proper eop this has to be set to a low value

    i_data_debug                : in    work.mu3e.link32_t := work.mu3e.LINK32_IDLE;
    i_data_debug_write          : in    std_logic := '0';

    o_override_request          : out   std_logic := '0'; -- asking merger for complete control of the link
    i_override_granted          : in    std_logic := '0'; -- control of link granted
    i_normal_data_almost_full   : in    std_logic := '0'; -- the fifo buffering the normal data is almost full, give back link at end of next packet
    i_normal_data_full          : in    std_logic := '0'; -- the fifo buffering the normal data is full, give back link now, set error flag

    i_new_data_packet           : in    std_logic := '0'; -- pull to 1 in merger for each normal data paket
    i_running                   : in    std_logic := '0'; -- FEB state running

    o_debug_almost_full         : out   std_logic := '0'; -- backpressure to whatever sends us debug packets
    o_data                      : out   work.mu3e.link32_t := work.mu3e.LINK32_IDLE;

    i_reset_n                   : in    std_logic;
    i_clk                       : in    std_logic--;
);
end entity;

architecture rtl of debug_stream_controller is

    type debug_controller_state_t     is (idle, requesting, sending_debug);
    signal debug_controller_state     : debug_controller_state_t;
    signal data_paket_counter         : integer range 0 to 65535;
    signal debug_paket_counter        : integer range 0 to 65535;
    type debug_frame_state_t          is (sop, payload);
    signal debug_frame_state          : debug_frame_state_t;
    signal cycles_in_debug_counter    : unsigned (31 downto 0);
    signal total_debug_frame_counter  : unsigned (31 downto 0);

    signal data_debug                 : work.mu3e.link32_t := work.mu3e.LINK32_IDLE;
    signal eop_prev                   : std_logic;
    signal wusedw                     : std_logic_vector(ADDR_WIDTH_g-1 downto 0);
    signal rusedw                     : std_logic_vector(ADDR_WIDTH_g-1 downto 0);
    signal fifo_full                  : std_logic;
    signal fifo_empty                 : std_logic;
    signal fifo_read                  : std_logic := '0';

    signal protocol_error_recovery    : std_logic; -- we got nonsense from the subdetector and currectly try to recover from it (read and ignore fifo until next sop)

begin

    o_debug_frame_counter <= std_logic_vector(total_debug_frame_counter);
    fifo_read <= not fifo_empty when
                    -- when we have the buffer disabled and will throw packets away anyways
                    (DISABLE_BUFFER_g = true or
                    -- when we are sending a debug packet and do not have a eop at the end of the fifo
                    (debug_controller_state = sending_debug and eop_prev = '0') or
                    -- when we do have a eop at the end of the fifo, still have more data in the fifo and the merger does not want the link back
                    (debug_controller_state = sending_debug and or_reduce(rusedw(ADDR_WIDTH_g-1 downto 5)) = '1' and i_normal_data_almost_full='0')) or
                    -- when the subdetector does not behave and we need to ignore it for a bit
                    (protocol_error_recovery = '1' and data_debug.sop='0' and debug_controller_state = idle)
                    -- else we give the link back (see process)
                    else '0';


    process (i_clk, i_reset_n) is
    begin
    if(i_reset_n = '0') then
        debug_controller_state      <= idle;
        debug_paket_counter         <= 0;
        data_paket_counter          <= 0;
        o_data                      <= work.mu3e.LINK32_IDLE;
        o_override_request          <= '0';
        total_debug_frame_counter   <= to_unsigned(0, 32);
        debug_frame_state           <= sop;
        cycles_in_debug_counter     <= to_unsigned(0, 32);
        o_subdetector_error_flag    <= '0';
        protocol_error_recovery     <= '0';
        eop_prev                    <= '0';
    elsif(rising_edge(i_clk)) then
        o_data                      <= work.mu3e.LINK32_IDLE;
        o_override_request          <= '0';
        protocol_error_recovery     <= '0';

        case debug_controller_state is
        when idle =>
            cycles_in_debug_counter <= to_unsigned(0, 32);
            eop_prev                <= '0';

            if(i_new_data_packet = '1') then
                data_paket_counter <= data_paket_counter + 1;
            end if;

            if(fifo_empty = '0' and data_debug.sop = '0') then
                -- subdetector protocol error (either not starting with a sop or not sending eop for max_cycles_in_debug or not reacting to backpressure)
                -- we read from the fifo until we get the next valid sop, only then do we ask for the link again
                o_subdetector_error_flag <= '1';
                protocol_error_recovery  <= '1';
            else
                if(DISABLE_BUFFER_g = true and data_paket_counter = to_integer(unsigned(i_n_pakets_before_debug)) and i_n_pakets_before_debug /= x"FFFF" and i_running = '1') then
                    debug_controller_state <= requesting;
                end if;
                if(DISABLE_BUFFER_g = false and fifo_empty = '0') then
                    debug_controller_state <= requesting;
                end if;
            end if;

        when requesting =>
            o_override_request <= '1';
            data_paket_counter <= 0;
            eop_prev           <= '0';

            if(i_override_granted = '1') then
                debug_controller_state <= sending_debug;
                debug_frame_state      <= sop;
            end if;

        when sending_debug =>
            o_override_request      <= '1';
            cycles_in_debug_counter <= cycles_in_debug_counter + 1;
            eop_prev                <= data_debug.eop;

            case debug_frame_state is
            when sop =>
                if(data_debug.sop = '1' and fifo_read = '1') then
                    debug_frame_state   <= payload;
                    o_data              <= data_debug;

                    -- ensure the protocol here, ignore whatever is send in the bits that are required for the protocol
                    o_data.datak                <= "0001";
                    o_data.data( 7 downto  0)   <= work.util.K28_5;
                    o_data.data(31 downto 26)   <= i_FEB_type_in(5 downto 1) & '1';
                    o_data.data(23 downto  8)   <= i_fpga_ID_in;
                end if;

            when payload =>
                if(fifo_read = '1') then
                    o_data          <= data_debug;
                    o_data.datak    <= "0000";

                    if(data_debug.eop = '1') then -- send trailer and decide if to send another debug frame or to hand back control to merger
                      debug_paket_counter       <= debug_paket_counter + 1;
                      total_debug_frame_counter <= total_debug_frame_counter + 1;
                      o_data.datak              <= "0001";
                      o_data.data(7 downto 0)   <= work.util.K28_4;
                      if(DISABLE_BUFFER_g = false and (or_reduce(rusedw(ADDR_WIDTH_g-1 downto 5)) = '0' or i_normal_data_almost_full='1')) then
                        debug_frame_state       <= sop;
                        debug_controller_state  <= idle;
                        debug_paket_counter     <= 0;
                      elsif(DISABLE_BUFFER_g = true and debug_paket_counter = to_integer(unsigned(i_no_of_debug_pakets))) then
                        debug_frame_state       <= sop;
                        debug_controller_state  <= idle;
                        debug_paket_counter     <= 0;
                      else
                        debug_frame_state <= sop;
                      end if;
                    end if;
                end if;
            when others =>
                debug_frame_state <= sop;
            end case;

            If(cycles_in_debug_counter = to_unsigned(i_max_cycles_in_debug,cycles_in_debug_counter'length)) then
              debug_controller_state  <= idle;
              o_data.datak            <= "0001";
              o_data.data(7 downto 0) <= work.util.K28_4;
            end if;

        when others =>
            debug_controller_state <= idle;
        end case;

        if(i_running = '0') then
            total_debug_frame_counter <= to_unsigned(0, 32);
        end if;
    end if;
    end process;

  ----------------------------------
  -- debug sync and buffer fifo
  -- 1 version with buffer, 1 without buffer
  -- case without buffer throws away debug packets instead of buffering them

    buffer_gen0 : if DISABLE_BUFFER_g = true generate
        debug_fifo : entity work.link32_dcfifo
        generic map (
            g_ADDR_WIDTH=> 4--,
        )
        port map (
            i_wdata     => i_data_debug,
            i_we        => i_data_debug_write,
            o_wfull     => fifo_full,
            o_wusedw    => wusedw(3 downto 0),

            o_rdata     => data_debug,
            i_rack      => fifo_read,
            o_rempty    => fifo_empty,
            o_rusedw    => rusedw(3 downto 0),

            i_rclk      => i_clk,
            i_wclk      => i_clk_subdetector,
            i_reset_n   => i_reset_n--;
        );
        o_debug_almost_full <= '0'; -- no buffering here, we throw things away all the time and never get full
    end generate;

    buffer_gen1 : if DISABLE_BUFFER_g = false generate
        debug_fifo : entity work.link32_dcfifo
        generic map (
            g_ADDR_WIDTH=> ADDR_WIDTH_g--,
        )
        port map (
            i_wdata     => i_data_debug,
            i_we        => i_data_debug_write,
            o_wfull     => fifo_full,
            o_wusedw    => wusedw,

            o_rdata     => data_debug,
            i_rack      => fifo_read,
            o_rempty    => fifo_empty,
            o_rusedw    => rusedw,

            i_rclk      => i_clk,
            i_wclk      => i_clk_subdetector,
            i_reset_n   => i_reset_n--;
        );
        o_debug_almost_full <= and_reduce(wusedw(ADDR_WIDTH_g-1 downto ADDR_WIDTH_g)); -- 3/4 of fifo filled
    end generate;

end architecture;
