--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

-- Fast passive parallel programmer, to work with Quad SPI flash
-- Niklaus Berger niberger@uni-mainz.de
-- August 2020
entity fpp_programmer is
generic (
    COMPRESSION : boolean := false--;
    -- [AK] TODO: add g_CLK_MHZ
);
port (
    i_start                   : in std_logic;
    i_start_address           : in std_logic_vector(23 downto 0) := X"000000";

    -- Interface to SPI flash
    o_spi_strobe              : out std_logic;
    o_spi_command             : out std_logic_vector(7 downto 0);
    o_spi_addr                : out std_logic_vector(23 downto 0);
    o_spi_continue            : out std_logic;
    i_spi_byte_out            : in std_logic_vector(7 downto 0);
    i_spi_byte_ready          : in std_logic;

    o_spi_flash_request       : out std_logic;
    i_spi_flash_granted       : in std_logic;

    -- Interface to FPGA
    i_fpga_conf_done          : in    std_logic;
    i_fpga_nstatus            : in    std_logic;
    o_fpga_nconfig            : out   std_logic;
    o_fpga_data               : out   std_logic_vector(7 downto 0);
    o_fpga_clk                : out   std_logic;

    -- Debug and status info
    o_crcerror                : out std_logic;
    o_timeout                 : out std_logic;
    o_debug                   : out std_logic_vector(7 downto 0);
    o_crclocation             : out std_logic_vector(31 downto 0);

    i_reset_n                 : in std_logic;
    -- 100 MHz clock
    i_clk                     : in std_logic--;
);
end entity;

architecture rtl of fpp_programmer is

    type state_type is (
        idle, flashwait, porwait, nconfig, nstatuswait, progwait,
        startflash, writing, ending
    );
    signal state : state_type;
    signal count : integer range 0 to 511;

    signal timeoutcounter : integer range 0 to 2147483647;
    signal crclocation_reg : unsigned(31 downto 0);

    signal start_last : std_logic;

    signal shiftregister : std_logic_vector(7 downto 0);
    signal toggle : unsigned(1 downto 0);

    -- Delays in units of 10 ns (100 MHz clock)
    constant nconfigdelay : integer := 220; -- Min 2 us plus some safety
    constant nstatusdelay : integer := 220; -- Min 2 us plus some safety

    constant timeouttime : integer := 10*10**8; -- 10 seconds

begin

    o_crclocation <= std_logic_vector(crclocation_reg);

    sm: process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        state           <= idle;

        start_last <= '0';

        o_fpga_nconfig    <= '1';
        o_fpga_data       <= (others => '0');
        o_fpga_clk        <= '0';

        o_spi_strobe      <= '0';
        o_spi_continue    <= '0';

        o_spi_flash_request <= '0';

        o_crcerror    <= '0';
        o_debug <= (others => '0');

        timeoutcounter <= 0;
        o_timeout        <= '0';
        crclocation_reg     <= (others => '0');

    elsif rising_edge(i_clk) then

        o_fpga_nconfig <= '1';
        o_fpga_clk     <= '0';
        o_spi_strobe   <= '0';

        start_last <= i_start;

        -- Logic for getting unstuck if something unexpected happens
        if(state /= idle) then
            timeoutcounter <= timeoutcounter + 1;
            if(timeoutcounter > timeouttime) then
                state <= ending;
                o_timeout <= '1';
            end if;
        end if;

        -- Grab the Arria V device handbook, chapter 8, page 8-12 complemented by the
        -- Arria V device datasheet, configuration specifications section for actual
        -- timing values

        case state is
        -- We stay in idle until the start signal is triggered; this has to be cleverly done
        -- on power up
        when idle =>
            if(i_start = '1' and start_last = '0')then
                state <= flashwait;
                     o_crcerror <= '0';
                     crclocation_reg <= (others => '0');
                     o_timeout  <= '0';
            end if;
            timeoutcounter <= 0;
            o_debug <= X"01";
        -- We then request access to the SPI flash (and keep it for us until we are done)
        when flashwait =>
            o_spi_flash_request <= '1';
            if(i_spi_flash_granted = '1')then
                state <= porwait;
            end if;
            o_debug <= X"02";
        -- During power-on-reset, the Arria drives nStatus low - wait until it is high
        when porwait =>
            if(i_fpga_nstatus = '1')then
                state   <= nconfig;
                count   <= 0;
            end if;
            o_debug <= X"03";
        -- We drive nconfig low for at least 2us to start the procedure
        when nconfig =>
            o_fpga_nconfig <= '0';
            count <= count + 1;
            if(count >= nconfigdelay)then
                state   <= nstatuswait;
            end if;
            o_debug <= X"04";
        -- The Arria acknowledges nConfig with nStatus low - once that is done, we can go on
        when nstatuswait =>
            if(i_fpga_nstatus = '1')then
                state   <= progwait;
                count   <= 0;
            end if;
            o_debug <= X"05";
        -- and wait another 2 us until we start with programming in earnest
        -- here we can already set the inputs to the flash
        when progwait =>
            count           <= count + 1;
            o_spi_command     <= COMMAND_QUAD_OUTPUT_FAST_READ;
            o_spi_addr        <= i_start_address;
            o_spi_continue    <= '1';

            if(count >= nstatusdelay)then
                state   <= startflash;
            end if;
            o_debug <= X"06";
        -- now we strobe the flash entity, command and address will be sent and soon
        -- the first byte will be available
        when startflash =>
            o_spi_strobe <= '1';
            if(i_spi_byte_ready = '1')then
                shiftregister <= i_spi_byte_out;
                state         <= writing;
                toggle        <= "00";
                count         <= 0;
            end if;
            o_debug <= X"07";
        -- We should receive a new word from the SPI flash every 16 cycles of clk
        -- We clock out the bits LSB to MSB on the falling edges of clk - the Arria
        -- latches on the rising edge
        -- When it has seen enough bits, the Arria pull conf_done high - we are encouraged
        -- to send two more falling edges of the clock in order to start FPGA initialization
        -- but here the documentation seems to be wrong, we need to send quite a few
        -- additional bits - we do 500 here
        when writing =>
            toggle <= toggle + 1;
            if(COMPRESSION) then
                -- If we use a compressed image, then we have to drive two clock cycles
                -- per data word
                if (toggle = "00") then
                    o_fpga_clk <= '0';
                    o_fpga_data <= shiftregister;
                elsif(toggle = "01") then
                    o_fpga_clk <= '1';
                elsif(toggle = "10") then
                    o_fpga_clk <= '0';
                elsif(toggle = "11") then
                    o_fpga_clk <= '1';
                end if;
            else
                -- Uncompressed image, one clock cycle per data word
                if (toggle = "00") then
                    o_fpga_clk <= '0';
                    o_fpga_data <= shiftregister;
                elsif(toggle = "10") then
                    o_fpga_clk <= '1';
                elsif(toggle = "11") then
                    o_fpga_clk <= '1';
                end if;
            end if;

            if(i_spi_byte_ready = '1')then
                shiftregister <= i_spi_byte_out;
                crclocation_reg  <=  crclocation_reg + 1;
            end if;

            if(i_fpga_conf_done = '1')then
                if(toggle = "00") then
                    count <= count + 1;
                end if;
                if(count >= 500)then
                    state <= ending;
                    o_fpga_clk   <= '0';
                end if;
            end if;

            if(i_fpga_nstatus = '0') then
                o_crcerror <= '1';
                state <= ending;
            end if;

            o_debug <= X"08";
        -- Put everything in default
        when ending =>
            o_fpga_clk            <= '0';
            o_spi_continue        <= '0';
            o_spi_strobe          <= '0';
            o_spi_flash_request   <= '0';
            state               <= idle;
            o_debug <= X"09";
        when others =>
            state <= idle;
            o_debug <= X"0A";
        end case;
    end if;
    end process;

end architecture;
