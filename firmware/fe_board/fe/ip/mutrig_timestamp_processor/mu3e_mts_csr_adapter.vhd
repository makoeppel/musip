-- File name: mu3e_mts_csr_adapter.vhd
-- Author: Yifeng Wang
-- =======================================
-- Version : 26.0.1
-- Date    : 20260608
-- Change  : Pipeline the v1 single-transaction CSR issue and constrain the CDC handshake.
-- =======================================
--
-- Mu3e register-bus to MTS CSR adapter.
--
-- Register map on the Mu3e side: you can also check the svd file (scifi_mts_slow_control.svd for a documentation)
--   0: CONTROL_STATUS
--      write bit 0: start one transaction
--      write bit 1: transaction is write when set, read when clear
--      write bit 2: clear done and overrun sticky bits
--      read  bit 0: busy
--      read  bit 1: done
--      read  bit 2: overrun, set when start is written while busy
--      read  bit 3: last command was write
--      read bits 10:8: latched MTS CSR address
--   1: MTS CSR address, bits 2:0
--   2: write data
--   3: read data from the last completed read

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mu3e_mts_csr_adapter is
port (
    i_mu3e_clk             : in  std_logic;
    i_mu3e_reset_n         : in  std_logic;
    i_mu3e_reg_addr        : in  std_logic_vector(1 downto 0);
    i_mu3e_reg_re          : in  std_logic;
    o_mu3e_reg_rdata       : out std_logic_vector(31 downto 0);
    i_mu3e_reg_we          : in  std_logic;
    i_mu3e_reg_wdata       : in  std_logic_vector(31 downto 0);

    i_mts_clk              : in  std_logic;
    i_mts_reset_n          : in  std_logic;
    i_mts_csr_readdata     : in  std_logic_vector(31 downto 0);
    o_mts_csr_read         : out std_logic;
    o_mts_csr_address      : out std_logic_vector(2 downto 0);
    i_mts_csr_waitrequest  : in  std_logic;
    o_mts_csr_write        : out std_logic;
    o_mts_csr_writedata    : out std_logic_vector(31 downto 0)
);
end entity;

architecture rtl of mu3e_mts_csr_adapter is

    constant REG_CONTROL_STATUS_CONST : integer := 0;
    constant REG_ADDRESS_CONST        : integer := 1;
    constant REG_WRITE_DATA_CONST     : integer := 2;
    constant REG_READ_DATA_CONST      : integer := 3;

    constant CMD_START_BIT_CONST      : integer := 0;
    constant CMD_WRITE_BIT_CONST      : integer := 1;
    constant CMD_CLEAR_BIT_CONST      : integer := 2;

    constant STATUS_BUSY_BIT_CONST    : integer := 0;
    constant STATUS_DONE_BIT_CONST    : integer := 1;
    constant STATUS_OVERRUN_BIT_CONST : integer := 2;
    constant STATUS_WRITE_BIT_CONST   : integer := 3;

    type mts_state_t is (IDLING, ISSUING, COMPLETING);

    signal mu3e_addr                : std_logic_vector(2 downto 0);
    signal mu3e_wdata               : std_logic_vector(31 downto 0);
    signal mu3e_rdata               : std_logic_vector(31 downto 0);
    signal mu3e_reg_rdata           : std_logic_vector(31 downto 0);
    signal mu3e_cmd_addr            : std_logic_vector(2 downto 0);
    signal mu3e_cmd_wdata           : std_logic_vector(31 downto 0);
    signal mu3e_cmd_write           : std_logic;
    signal mu3e_req_toggle          : std_logic;
    signal mu3e_done                : std_logic;
    signal mu3e_overrun             : std_logic;
    signal mu3e_ack_meta            : std_logic;
    signal mu3e_ack_sync            : std_logic;
    signal mu3e_ack_last            : std_logic;

    signal mts_req_meta             : std_logic;
    signal mts_req_sync             : std_logic;
    signal mts_req_seen             : std_logic;
    signal mts_ack_toggle           : std_logic;
    signal mts_state                : mts_state_t;
    signal mts_cmd_addr             : std_logic_vector(2 downto 0);
    signal mts_cmd_wdata            : std_logic_vector(31 downto 0);
    signal mts_cmd_write            : std_logic;
    signal mts_return_data          : std_logic_vector(31 downto 0);

    signal mu3e_busy                : std_logic;

begin

    mu3e_busy <= mu3e_req_toggle xor mu3e_ack_sync;
    o_mu3e_reg_rdata <= mu3e_reg_rdata;

    proc_mu3e_side : process(i_mu3e_clk, i_mu3e_reset_n)
        variable status_v : std_logic_vector(31 downto 0);
    begin
        if (i_mu3e_reset_n = '0') then
            mu3e_addr       <= (others => '0');
            mu3e_wdata      <= (others => '0');
            mu3e_rdata      <= (others => '0');
            mu3e_reg_rdata  <= (others => '0');
            mu3e_cmd_addr   <= (others => '0');
            mu3e_cmd_wdata  <= (others => '0');
            mu3e_cmd_write  <= '0';
            mu3e_req_toggle <= '0';
            mu3e_done       <= '0';
            mu3e_overrun    <= '0';
            mu3e_ack_meta   <= '0';
            mu3e_ack_sync   <= '0';
            mu3e_ack_last   <= '0';
        elsif rising_edge(i_mu3e_clk) then
            mu3e_ack_meta <= mts_ack_toggle;
            mu3e_ack_sync <= mu3e_ack_meta;
            mu3e_ack_last <= mu3e_ack_sync;

            if (mu3e_ack_sync /= mu3e_ack_last) then
                mu3e_rdata <= mts_return_data;
                mu3e_done  <= '1';
            end if;

            if (i_mu3e_reg_we = '1') then
                case to_integer(unsigned(i_mu3e_reg_addr)) is
                    when REG_CONTROL_STATUS_CONST =>
                        if (i_mu3e_reg_wdata(CMD_CLEAR_BIT_CONST) = '1') then
                            mu3e_done    <= '0';
                            mu3e_overrun <= '0';
                        end if;

                        if (i_mu3e_reg_wdata(CMD_START_BIT_CONST) = '1') then
                            if (mu3e_busy = '1') then
                                mu3e_overrun <= '1';
                            else
                                mu3e_cmd_addr   <= mu3e_addr;
                                mu3e_cmd_wdata  <= mu3e_wdata;
                                mu3e_cmd_write  <= i_mu3e_reg_wdata(CMD_WRITE_BIT_CONST);
                                mu3e_req_toggle <= not mu3e_req_toggle;
                                mu3e_done       <= '0';
                            end if;
                        end if;

                    when REG_ADDRESS_CONST =>
                        mu3e_addr <= i_mu3e_reg_wdata(mu3e_addr'range);

                    when REG_WRITE_DATA_CONST =>
                        mu3e_wdata <= i_mu3e_reg_wdata;

                    when others =>
                        null;
                end case;
            end if;

            if (i_mu3e_reg_re = '1') then
                status_v := (others => '0');
                status_v(STATUS_BUSY_BIT_CONST)    := mu3e_busy;
                status_v(STATUS_DONE_BIT_CONST)    := mu3e_done;
                status_v(STATUS_OVERRUN_BIT_CONST) := mu3e_overrun;
                status_v(STATUS_WRITE_BIT_CONST)   := mu3e_cmd_write;
                status_v(10 downto 8)              := mu3e_cmd_addr;

                case to_integer(unsigned(i_mu3e_reg_addr)) is
                    when REG_CONTROL_STATUS_CONST =>
                        mu3e_reg_rdata <= status_v;

                    when REG_ADDRESS_CONST =>
                        mu3e_reg_rdata <= (31 downto 3 => '0') & mu3e_addr;

                    when REG_WRITE_DATA_CONST =>
                        mu3e_reg_rdata <= mu3e_wdata;

                    when REG_READ_DATA_CONST =>
                        mu3e_reg_rdata <= mu3e_rdata;

                    when others =>
                        mu3e_reg_rdata <= x"CCCCCCCC";
                end case;
            end if;
        end if;
    end process;

    proc_mts_side : process(i_mts_clk, i_mts_reset_n)
    begin
        if (i_mts_reset_n = '0') then
            mts_req_meta        <= '0';
            mts_req_sync        <= '0';
            mts_req_seen        <= '0';
            mts_ack_toggle      <= '0';
            mts_state           <= IDLING;
            mts_cmd_addr        <= (others => '0');
            mts_cmd_wdata       <= (others => '0');
            mts_cmd_write       <= '0';
            mts_return_data     <= (others => '0');
            o_mts_csr_read      <= '0';
            o_mts_csr_address   <= (others => '0');
            o_mts_csr_write     <= '0';
            o_mts_csr_writedata <= (others => '0');
        elsif rising_edge(i_mts_clk) then
            mts_req_meta   <= mu3e_req_toggle;
            mts_req_sync   <= mts_req_meta;
            o_mts_csr_read  <= '0';
            o_mts_csr_write <= '0';

            case mts_state is
                when IDLING =>
                    if (mts_req_sync /= mts_req_seen) then
                        mts_cmd_addr  <= mu3e_cmd_addr;
                        mts_cmd_wdata <= mu3e_cmd_wdata;
                        mts_cmd_write <= mu3e_cmd_write;
                        mts_state     <= ISSUING;
                    end if;

                when ISSUING =>
                    o_mts_csr_address   <= mts_cmd_addr;
                    o_mts_csr_writedata <= mts_cmd_wdata;
                    o_mts_csr_write     <= mts_cmd_write;
                    o_mts_csr_read      <= not mts_cmd_write;

                    if (i_mts_csr_waitrequest = '0') then
                        mts_state <= COMPLETING;
                    end if;

                when COMPLETING =>
                    if (mts_cmd_write = '0') then
                        mts_return_data <= i_mts_csr_readdata;
                    end if;
                    mts_req_seen   <= mts_req_sync;
                    mts_ack_toggle <= not mts_ack_toggle;
                    mts_state      <= IDLING;
            end case;
        end if;
    end process;

end architecture;
