-- File name: mu3e_hist_avmm_cdc_adapter.vhd
-- Author : Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.5.0
-- Date    : 20260713
-- Change  : Add a fixed-latency Mu3e SC mailbox for the HIST CSR/bin AVMM ports.
-- =======================================
--
-- The Mu3e slow-control tree has a compile-time read latency and cannot carry
-- Avalon-MM waitrequest/readdatavalid directly. This adapter therefore exposes
-- four local SC words and permits one indirect transaction at a time:
--
--   word 0 CONTROL_STATUS
--     write bit 0  : start transaction
--     write bit 1  : write when set, read when clear
--     write bit 2  : clear done/overrun/timeout/response status
--     read  bit 0  : busy
--     read  bit 1  : done (sticky)
--     read  bit 2  : overrun (sticky)
--     read  bit 3  : last command was a write
--     read  bit 4  : response timeout (sticky)
--     read bits 6:5: Avalon response from the completed transaction
--     read bits 16:8: latched target address
--   word 1 TARGET_ADDRESS
--     bit 8 = 0, bits 4:0 select HIST CSR word 0..31
--     bit 8 = 1, bits 7:0 select HIST bin word 0..255
--   word 2 WRITE_DATA
--   word 3 READ_DATA
--
-- The command and response are synchronized as stable mailbox bundles. The
-- destination waits one extra clock after observing each synchronized toggle
-- before consuming its payload, so the bundled fields are coherent. A HIST CSR
-- read has a synthesized one-cycle response-valid because that slave registers
-- readdata without exporting readdatavalid. HIST bin reads use the slave's real
-- readdatavalid. Bin accesses are always single-beat (burstcount = 1).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mu3e_hist_avmm_cdc_adapter is
generic (
    TIMEOUT_CYCLES    : positive    := 1024
);
port (
    sc_clk          : in  std_logic;
    sc_reset_n      : in  std_logic;
    sc_address      : in  std_logic_vector(1 downto 0);
    sc_read         : in  std_logic;
    sc_readdata     : out std_logic_vector(31 downto 0);
    sc_write        : in  std_logic;
    sc_writedata    : in  std_logic_vector(31 downto 0);

    hist_clk        : in  std_logic;
    hist_reset_n    : in  std_logic;

    avm_csr_address        : out std_logic_vector(4 downto 0);
    avm_csr_read           : out std_logic;
    avm_csr_readdata       : in  std_logic_vector(31 downto 0);
    avm_csr_waitrequest    : in  std_logic;
    avm_csr_write          : out std_logic;
    avm_csr_writedata      : out std_logic_vector(31 downto 0);

    avm_hist_bin_address               : out std_logic_vector(7 downto 0);
    avm_hist_bin_read                  : out std_logic;
    avm_hist_bin_readdata              : in  std_logic_vector(31 downto 0);
    avm_hist_bin_readdatavalid         : in  std_logic;
    avm_hist_bin_waitrequest           : in  std_logic;
    avm_hist_bin_write                 : out std_logic;
    avm_hist_bin_writedata             : out std_logic_vector(31 downto 0);
    avm_hist_bin_burstcount            : out std_logic_vector(8 downto 0);
    avm_hist_bin_writeresponsevalid    : in  std_logic;
    avm_hist_bin_response              : in  std_logic_vector(1 downto 0)
);
end entity;

architecture rtl of mu3e_hist_avmm_cdc_adapter is

    constant SC_CONTROL_STATUS_WORD_CONST : natural    := 0;
    constant SC_TARGET_ADDRESS_WORD_CONST : natural    := 1;
    constant SC_WRITE_DATA_WORD_CONST     : natural    := 2;
    constant SC_READ_DATA_WORD_CONST      : natural    := 3;

    constant COMMAND_START_BIT_CONST      : natural    := 0;
    constant COMMAND_WRITE_BIT_CONST      : natural    := 1;
    constant COMMAND_CLEAR_BIT_CONST      : natural    := 2;

    constant STATUS_BUSY_BIT_CONST        : natural    := 0;
    constant STATUS_DONE_BIT_CONST        : natural    := 1;
    constant STATUS_OVERRUN_BIT_CONST     : natural    := 2;
    constant STATUS_WRITE_BIT_CONST       : natural    := 3;
    constant STATUS_TIMEOUT_BIT_CONST     : natural    := 4;
    constant STATUS_RESPONSE_LO_CONST     : natural    := 5;
    constant STATUS_RESPONSE_HI_CONST     : natural    := 6;
    constant STATUS_TARGET_LO_CONST       : natural    := 8;
    constant STATUS_TARGET_HI_CONST       : natural    := 16;

    constant TARGET_ADDRESS_WIDTH_CONST   : positive                         := 9;
    constant COMMAND_BUNDLE_WIDTH_CONST   : positive                         := 43;
    constant RESPONSE_BUNDLE_WIDTH_CONST  : positive                         := 36;
    constant AVMM_RESPONSE_OK_CONST       : std_logic_vector(1 downto 0)     := "00";
    constant AVMM_RESPONSE_DECERR_CONST   : std_logic_vector(1 downto 0)     := "11";
    constant TIMEOUT_READ_DATA_CONST      : std_logic_vector(31 downto 0)    := x"EEEEEEEE";

    type sc_response_state_t is (MONITORING_RESPONSE, CAPTURING_RESPONSE);
    type hist_state_t is (
        IDLING,
        COMMAND_CAPTURING,
        COMMAND_ISSUING,
        CSR_READ_WAITING,
        BIN_READ_WAITING,
        BIN_WRITE_WAITING
    );

    type sc_owner_t is record
        response_state       : sc_response_state_t;
        target_address       : std_logic_vector(TARGET_ADDRESS_WIDTH_CONST - 1 downto 0);
        write_data           : std_logic_vector(31 downto 0);
        command_address      : std_logic_vector(TARGET_ADDRESS_WIDTH_CONST - 1 downto 0);
        command_writedata    : std_logic_vector(31 downto 0);
        command_write        : std_logic;
        request_toggle       : std_logic;
        acknowledge_seen     : std_logic;
        read_data            : std_logic_vector(31 downto 0);
        readback             : std_logic_vector(31 downto 0);
        done                 : std_logic;
        overrun              : std_logic;
        timeout              : std_logic;
        response             : std_logic_vector(1 downto 0);
    end record;

    constant SC_RESET_CONST : sc_owner_t := (
        response_state       => MONITORING_RESPONSE,
        target_address       => (others => '0'),
        write_data           => (others => '0'),
        command_address      => (others => '0'),
        command_writedata    => (others => '0'),
        command_write        => '0',
        request_toggle       => '0',
        acknowledge_seen     => '0',
        read_data            => (others => '0'),
        readback             => (others => '0'),
        done                 => '0',
        overrun              => '0',
        timeout              => '0',
        response             => AVMM_RESPONSE_OK_CONST
    );

    type hist_owner_t is record
        state                 : hist_state_t;
        request_seen          : std_logic;
        command_address       : std_logic_vector(TARGET_ADDRESS_WIDTH_CONST - 1 downto 0);
        command_writedata     : std_logic_vector(31 downto 0);
        command_write         : std_logic;
        acknowledge_toggle    : std_logic;
        response_readdata     : std_logic_vector(31 downto 0);
        response_code         : std_logic_vector(1 downto 0);
        response_timeout      : std_logic;
        timeout_count         : natural range 0 to TIMEOUT_CYCLES;
    end record;

    constant HIST_RESET_CONST : hist_owner_t := (
        state                 => IDLING,
        request_seen          => '0',
        command_address       => (others => '0'),
        command_writedata     => (others => '0'),
        command_write         => '0',
        acknowledge_toggle    => '0',
        response_readdata     => (others => '0'),
        response_code         => AVMM_RESPONSE_OK_CONST,
        response_timeout      => '0',
        timeout_count         => 0
    );

    signal sc                         : sc_owner_t;
    signal hist                       : hist_owner_t;
    signal sc_busy                    : std_logic;
    signal sc_status_word             : std_logic_vector(31 downto 0);
    signal command_bundle_async       : std_logic_vector(COMMAND_BUNDLE_WIDTH_CONST - 1 downto 0);
    signal command_bundle_sync        : std_logic_vector(COMMAND_BUNDLE_WIDTH_CONST - 1 downto 0);
    signal response_bundle_async      : std_logic_vector(RESPONSE_BUNDLE_WIDTH_CONST - 1 downto 0);
    signal response_bundle_sync       : std_logic_vector(RESPONSE_BUNDLE_WIDTH_CONST - 1 downto 0);
    signal selected_waitrequest       : std_logic;
    signal csr_target_valid           : std_logic;
    signal csr_stalled_d1             : std_logic;
    signal csr_hold_address           : std_logic_vector(4 downto 0);
    signal csr_hold_read              : std_logic;
    signal csr_hold_write             : std_logic;
    signal csr_hold_writedata         : std_logic_vector(31 downto 0);
    signal bin_stalled_d1             : std_logic;
    signal bin_hold_address           : std_logic_vector(7 downto 0);
    signal bin_hold_read              : std_logic;
    signal bin_hold_write             : std_logic;
    signal bin_hold_writedata         : std_logic_vector(31 downto 0);

begin

    sc_busy        <= sc.request_toggle xor sc.acknowledge_seen;
    sc_readdata    <= sc.readback;

    -- Source-held mailbox payloads. The synchronized toggle is the ownership
    -- transfer; the receiving side deliberately captures the other fields one
    -- clock later.
    command_bundle_async     <= sc.command_writedata & sc.command_address &
                             sc.command_write & sc.request_toggle;
    response_bundle_async    <= hist.response_readdata & hist.response_code &
                             hist.response_timeout & hist.acknowledge_toggle;

    command_mailbox_sync : entity work.ff_sync
    generic map (
        W    => COMMAND_BUNDLE_WIDTH_CONST,
        N    => 2
    )
    port map (
        i_d          => command_bundle_async,
        o_q          => command_bundle_sync,
        i_reset_n    => hist_reset_n,
        i_clk        => hist_clk
    );

    response_mailbox_sync : entity work.ff_sync
    generic map (
        W    => RESPONSE_BUNDLE_WIDTH_CONST,
        N    => 2
    )
    port map (
        i_d          => response_bundle_async,
        o_q          => response_bundle_sync,
        i_reset_n    => sc_reset_n,
        i_clk        => sc_clk
    );

    csr_target_valid        <= '1' when hist.command_address(7 downto 5) = "000" else '0';
    selected_waitrequest    <= avm_csr_waitrequest when hist.command_address(8) = '0'
                            else avm_hist_bin_waitrequest;

    avm_csr_address      <= hist.command_address(4 downto 0);
    avm_csr_writedata    <= hist.command_writedata;
    avm_csr_read         <= '1' when (
        hist.state = COMMAND_ISSUING and
        hist.command_address(8) = '0' and
        csr_target_valid = '1' and
        hist.command_write = '0'
    ) else '0';
    avm_csr_write    <= '1' when (
        hist.state = COMMAND_ISSUING and
        hist.command_address(8) = '0' and
        csr_target_valid = '1' and
        hist.command_write = '1'
    ) else '0';

    avm_hist_bin_address       <= hist.command_address(7 downto 0);
    avm_hist_bin_writedata     <= hist.command_writedata;
    avm_hist_bin_burstcount    <= std_logic_vector(to_unsigned(1, avm_hist_bin_burstcount'length));
    avm_hist_bin_read          <= '1' when (
        hist.state = COMMAND_ISSUING and
        hist.command_address(8) = '1' and
        hist.command_write = '0'
    ) else '0';
    avm_hist_bin_write    <= '1' when (
        hist.state = COMMAND_ISSUING and
        hist.command_address(8) = '1' and
        hist.command_write = '1'
    ) else '0';

    sc_status_comb : process (all)
        variable status_v : std_logic_vector(31 downto 0);
    begin
        status_v := (others => '0');
        status_v(STATUS_BUSY_BIT_CONST) := sc_busy;
        status_v(STATUS_DONE_BIT_CONST) := sc.done;
        status_v(STATUS_OVERRUN_BIT_CONST) := sc.overrun;
        status_v(STATUS_WRITE_BIT_CONST) := sc.command_write;
        status_v(STATUS_TIMEOUT_BIT_CONST) := sc.timeout;
        status_v(STATUS_RESPONSE_HI_CONST downto STATUS_RESPONSE_LO_CONST) := sc.response;
        status_v(STATUS_TARGET_HI_CONST downto STATUS_TARGET_LO_CONST) := sc.command_address;
        sc_status_word <= status_v;
    end process sc_status_comb;

    sc_owner : process (sc_clk, sc_reset_n)
    begin
        if sc_reset_n = '0' then
            sc    <= SC_RESET_CONST;
        elsif rising_edge(sc_clk) then
            case sc.response_state is
                when MONITORING_RESPONSE =>
                    if response_bundle_sync(0) /= sc.acknowledge_seen then
                        sc.response_state    <= CAPTURING_RESPONSE;
                    end if;

                when CAPTURING_RESPONSE =>
                    if response_bundle_sync(0) /= sc.acknowledge_seen then
                        sc.read_data           <= response_bundle_sync(35 downto 4);
                        sc.response            <= response_bundle_sync(3 downto 2);
                        sc.timeout             <= response_bundle_sync(1);
                        sc.acknowledge_seen    <= response_bundle_sync(0);
                        sc.done                <= '1';
                    end if;
                    sc.response_state    <= MONITORING_RESPONSE;
            end case;

            if sc_write = '1' then
                case to_integer(unsigned(sc_address)) is
                    when SC_CONTROL_STATUS_WORD_CONST =>
                        if sc_writedata(COMMAND_CLEAR_BIT_CONST) = '1' then
                            sc.done        <= '0';
                            sc.overrun     <= '0';
                            sc.timeout     <= '0';
                            sc.response    <= AVMM_RESPONSE_OK_CONST;
                        end if;

                        if sc_writedata(COMMAND_START_BIT_CONST) = '1' then
                            if sc_busy = '1' then
                                sc.overrun    <= '1';
                            else
                                sc.command_address      <= sc.target_address;
                                sc.command_writedata    <= sc.write_data;
                                sc.command_write        <= sc_writedata(COMMAND_WRITE_BIT_CONST);
                                sc.request_toggle       <= not sc.request_toggle;
                                sc.done                 <= '0';
                                sc.timeout              <= '0';
                                sc.response             <= AVMM_RESPONSE_OK_CONST;
                            end if;
                        end if;

                    when SC_TARGET_ADDRESS_WORD_CONST =>
                        sc.target_address    <= sc_writedata(TARGET_ADDRESS_WIDTH_CONST - 1 downto 0);

                    when SC_WRITE_DATA_WORD_CONST =>
                        sc.write_data    <= sc_writedata;

                    when others =>
                        null;
                end case;
            end if;

            if sc_read = '1' then
                case to_integer(unsigned(sc_address)) is
                    when SC_CONTROL_STATUS_WORD_CONST =>
                        sc.readback    <= sc_status_word;

                    when SC_TARGET_ADDRESS_WORD_CONST =>
                        sc.readback    <= std_logic_vector(resize(unsigned(sc.target_address), sc.readback'length));

                    when SC_WRITE_DATA_WORD_CONST =>
                        sc.readback    <= sc.write_data;

                    when SC_READ_DATA_WORD_CONST =>
                        sc.readback    <= sc.read_data;

                    when others =>
                        sc.readback    <= x"CCCCCCCC";
                end case;
            end if;
        end if;
    end process sc_owner;

    hist_owner : process (hist_clk, hist_reset_n)
    begin
        if hist_reset_n = '0' then
            hist    <= HIST_RESET_CONST;
        elsif rising_edge(hist_clk) then
            case hist.state is
                when IDLING =>
                    if command_bundle_sync(0) /= hist.request_seen then
                        hist.state    <= COMMAND_CAPTURING;
                    end if;

                when COMMAND_CAPTURING =>
                    hist.command_writedata    <= command_bundle_sync(42 downto 11);
                    hist.command_address      <= command_bundle_sync(10 downto 2);
                    hist.command_write        <= command_bundle_sync(1);
                    hist.request_seen         <= command_bundle_sync(0);
                    hist.response_code        <= AVMM_RESPONSE_OK_CONST;
                    hist.response_timeout     <= '0';
                    hist.timeout_count        <= 0;
                    hist.state                <= COMMAND_ISSUING;

                when COMMAND_ISSUING =>
                    if hist.command_address(8) = '0' and csr_target_valid = '0' then
                        if hist.command_write = '0' then
                            hist.response_readdata    <= TIMEOUT_READ_DATA_CONST;
                        end if;
                        hist.response_code         <= AVMM_RESPONSE_DECERR_CONST;
                        hist.response_timeout      <= '0';
                        hist.acknowledge_toggle    <= not hist.acknowledge_toggle;
                        hist.state                 <= IDLING;
                    elsif selected_waitrequest = '0' then
                        if hist.command_write = '1' then
                            if hist.command_address(8) = '0' then
                                hist.response_code         <= AVMM_RESPONSE_OK_CONST;
                                hist.response_timeout      <= '0';
                                hist.acknowledge_toggle    <= not hist.acknowledge_toggle;
                                hist.state                 <= IDLING;
                            elsif avm_hist_bin_writeresponsevalid = '1' then
                                hist.response_code         <= avm_hist_bin_response;
                                hist.response_timeout      <= '0';
                                hist.acknowledge_toggle    <= not hist.acknowledge_toggle;
                                hist.state                 <= IDLING;
                            else
                                hist.timeout_count    <= 0;
                                hist.state            <= BIN_WRITE_WAITING;
                            end if;
                        elsif hist.command_address(8) = '0' then
                            -- HIST CSR readdata is registered on this accepted
                            -- read edge; consume it on the following edge.
                            hist.state    <= CSR_READ_WAITING;
                        elsif avm_hist_bin_readdatavalid = '1' then
                            hist.response_readdata     <= avm_hist_bin_readdata;
                            hist.response_code         <= avm_hist_bin_response;
                            hist.response_timeout      <= '0';
                            hist.acknowledge_toggle    <= not hist.acknowledge_toggle;
                            hist.state                 <= IDLING;
                        else
                            hist.timeout_count    <= 0;
                            hist.state            <= BIN_READ_WAITING;
                        end if;
                    end if;

                when CSR_READ_WAITING =>
                    hist.response_readdata     <= avm_csr_readdata;
                    hist.response_code         <= AVMM_RESPONSE_OK_CONST;
                    hist.response_timeout      <= '0';
                    hist.acknowledge_toggle    <= not hist.acknowledge_toggle;
                    hist.state                 <= IDLING;

                when BIN_READ_WAITING =>
                    if avm_hist_bin_readdatavalid = '1' then
                        hist.response_readdata     <= avm_hist_bin_readdata;
                        hist.response_code         <= avm_hist_bin_response;
                        hist.response_timeout      <= '0';
                        hist.acknowledge_toggle    <= not hist.acknowledge_toggle;
                        hist.timeout_count         <= 0;
                        hist.state                 <= IDLING;
                    elsif hist.timeout_count >= TIMEOUT_CYCLES - 1 then
                        hist.response_readdata     <= TIMEOUT_READ_DATA_CONST;
                        hist.response_code         <= AVMM_RESPONSE_DECERR_CONST;
                        hist.response_timeout      <= '1';
                        hist.acknowledge_toggle    <= not hist.acknowledge_toggle;
                        hist.timeout_count         <= 0;
                        hist.state                 <= IDLING;
                    else
                        hist.timeout_count    <= hist.timeout_count + 1;
                    end if;

                when BIN_WRITE_WAITING =>
                    if avm_hist_bin_writeresponsevalid = '1' then
                        hist.response_code         <= avm_hist_bin_response;
                        hist.response_timeout      <= '0';
                        hist.acknowledge_toggle    <= not hist.acknowledge_toggle;
                        hist.timeout_count         <= 0;
                        hist.state                 <= IDLING;
                    elsif hist.timeout_count >= TIMEOUT_CYCLES - 1 then
                        hist.response_code         <= AVMM_RESPONSE_DECERR_CONST;
                        hist.response_timeout      <= '1';
                        hist.acknowledge_toggle    <= not hist.acknowledge_toggle;
                        hist.timeout_count         <= 0;
                        hist.state                 <= IDLING;
                    else
                        hist.timeout_count    <= hist.timeout_count + 1;
                    end if;
            end case;
        end if;
    end process hist_owner;

    -- Assert Avalon-MM command stability while a target holds waitrequest.
    avmm_stall_guard : process (hist_clk, hist_reset_n)
    begin
        if hist_reset_n = '0' then
            csr_stalled_d1        <= '0';
            csr_hold_address      <= (others => '0');
            csr_hold_read         <= '0';
            csr_hold_write        <= '0';
            csr_hold_writedata    <= (others => '0');
            bin_stalled_d1        <= '0';
            bin_hold_address      <= (others => '0');
            bin_hold_read         <= '0';
            bin_hold_write        <= '0';
            bin_hold_writedata    <= (others => '0');
        elsif rising_edge(hist_clk) then
            if csr_stalled_d1 = '1' then
                assert avm_csr_address = csr_hold_address and
                       avm_csr_read = csr_hold_read and
                       avm_csr_write = csr_hold_write and
                       avm_csr_writedata = csr_hold_writedata
                    report "HIST CSR AVMM command changed while stalled"
                    severity failure;
            end if;

            if bin_stalled_d1 = '1' then
                assert avm_hist_bin_address = bin_hold_address and
                       avm_hist_bin_read = bin_hold_read and
                       avm_hist_bin_write = bin_hold_write and
                       avm_hist_bin_writedata = bin_hold_writedata and
                       avm_hist_bin_burstcount = std_logic_vector(to_unsigned(1, avm_hist_bin_burstcount'length))
                    report "HIST bin AVMM command changed while stalled"
                    severity failure;
            end if;

            if (avm_csr_read = '1' or avm_csr_write = '1') and avm_csr_waitrequest = '1' then
                csr_stalled_d1    <= '1';
            else
                csr_stalled_d1    <= '0';
            end if;
            csr_hold_address      <= avm_csr_address;
            csr_hold_read         <= avm_csr_read;
            csr_hold_write        <= avm_csr_write;
            csr_hold_writedata    <= avm_csr_writedata;

            if (avm_hist_bin_read = '1' or avm_hist_bin_write = '1') and avm_hist_bin_waitrequest = '1' then
                bin_stalled_d1    <= '1';
            else
                bin_stalled_d1    <= '0';
            end if;
            bin_hold_address      <= avm_hist_bin_address;
            bin_hold_read         <= avm_hist_bin_read;
            bin_hold_write        <= avm_hist_bin_write;
            bin_hold_writedata    <= avm_hist_bin_writedata;
        end if;
    end process avmm_stall_guard;

    assert not (avm_csr_read = '1' and avm_csr_write = '1')
        report "HIST CSR AVMM read and write asserted together"
        severity failure;
    assert not (avm_hist_bin_read = '1' and avm_hist_bin_write = '1')
        report "HIST bin AVMM read and write asserted together"
        severity failure;
    assert not (
        (avm_csr_read = '1' or avm_csr_write = '1') and
        (avm_hist_bin_read = '1' or avm_hist_bin_write = '1')
    )
        report "HIST CSR and bin AVMM commands asserted together"
        severity failure;

end architecture;
