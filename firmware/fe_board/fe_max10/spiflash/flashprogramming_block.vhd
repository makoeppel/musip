--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;
use work.feb_sc_registers.all;

entity flashprogramming_block is
port (
    i_control               : in    std_logic_vector(31 downto 0);
    o_status                : out   std_logic_vector(31 downto 0);

    -- Flash SPI IF
    o_flash_csn             : out   std_logic;
    o_flash_sck             : out   std_logic;
    io_flash_io0            : inout std_logic;
    io_flash_io1            : inout std_logic;
    io_flash_io2            : inout std_logic;
    io_flash_io3            : inout std_logic;

    -- FPGA programming interface
    i_fpga_conf_done        : in    std_logic;
    i_fpga_nstatus          : in    std_logic;
    o_fpga_nconfig          : out   std_logic;
    o_fpga_data             : out   std_logic_vector(7 downto 0);
    o_fpga_clk              : out   std_logic;

    o_fpp_crclocation       : out   std_logic_vector(31 downto 0);

    -- NIOS interface
    i_flash_programming_ctrl        : in    std_logic_vector(31 downto 0);
    o_flash_w_cnt                   : out   std_logic_vector(31 downto 0);
    i_spi_flash_cmdaddr_to_flash    : in    std_logic_vector(31 downto 0);
    i_spi_flash_ctrl                : in    std_logic_vector(7 downto 0);
    i_spi_flash_data_to_flash_nios  : in    std_logic_vector(7 downto 0);
    o_spi_flash_data_from_flash     : out   std_logic_vector(7 downto 0);
    o_spi_flash_status              : out   std_logic_vector(7 downto 0);
    i_spi_flash_fifo_data_nios      : in    std_logic_vector(8 downto 0);

    -- Arria SPI interface
    i_spi_arria_byte_from_arria     : in    std_logic_vector(7 downto 0);
    i_spi_arria_byte_en             : in    std_logic;
    i_spi_arria_addr                : in    std_logic_vector(6 downto 0);
    i_addr_from_arria               : in    std_logic_vector(23 downto 0);

    -- Backplane SPI interface
    i_spi_bp_byte_from_bp   : in    std_logic_vector(7 downto 0);
    i_spi_bp_byte_en        : in    std_logic;
    i_spi_bp_addr           : in    std_logic_vector(7 downto 0);

    -- 100 MHz clock
    i_reset_n               : in    std_logic;
    i_clk                   : in    std_logic--;
);
end entity;

architecture RTL of flashprogramming_block is

    -- SPI Flash
    signal spi_strobe_programmer                : std_logic;
    signal spi_command_programmer               : std_logic_vector(7 downto 0);
    signal spi_addr_programmer                  : std_logic_vector(23 downto 0);
    signal spi_continue_programmer              : std_logic;
    signal spi_flash_request_programmer         : std_logic;
    signal spi_flash_granted_programmer         : std_logic;

    signal spi_flash_data_to_flash              : std_logic_vector(7 downto 0);
    signal spi_flash_data_from_flash_int        : std_logic_vector(7 downto 0);

    signal spi_strobe_nios                      : std_logic;
    signal spi_command_nios                     : std_logic_vector(7 downto 0);
    signal spi_addr_nios                        : std_logic_vector(23 downto 0);
    signal spi_continue_nios                    : std_logic;

    signal spi_ack                              : std_logic;
    signal spi_busy                             : std_logic;
    signal spi_next_byte                        : std_logic;
    signal spi_byte_ready                       : std_logic;

    signal spi_strobe                           : std_logic;
    signal spi_continue                         : std_logic;
    signal spi_command                          : std_logic_vector(7 downto 0);
    signal spi_addr                             : std_logic_vector(23 downto 0);

    type spiflashstate_type is (idle, fifowriting,
        arriawriting1, arriawriting2, arriawriting3, arriawriting4, arriawriting5,
        arriawriting6, arriawriting7, arriafifowriting, arriawriting8, programming);
    signal spiflashstate : spiflashstate_type;
    signal fifo_req_last                        : std_logic;
    signal arria_write_req_last                 : std_logic;
    signal fifo_read_pulse                      : std_logic;
    signal wcounter                             : std_logic_vector(15 downto 0);

    -- Fifo for programming data to the SPIflash
    signal spiflash_to_fifo_we                     : std_logic;
    signal spiflashfifo_empty                      : std_logic;
    signal spiflashfifo_full                       : std_logic;
    signal spiflashfifo_data_in                    : std_logic_vector(7 downto 0);
    signal spiflashfifo_data_out                   : std_logic_vector(7 downto 0);
    signal read_spiflashfifo                       : std_logic;
    signal fifopiotoggle_last                      : std_logic;

    signal arriawriting                            : std_logic;
    signal wipseen                                 : std_logic;

    signal spi_strobe_arria                      : std_logic;
    signal spi_command_arria                     : std_logic_vector(7 downto 0);
    signal spi_addr_arria                        : std_logic_vector(23 downto 0);
    signal spi_continue_arria                    : std_logic;

    signal fpp_crcerror                         : std_logic;
    signal fpp_timeout                          : std_logic;
    signal fpp_debug                            : std_logic_vector(7 downto 0);

begin

    o_spi_flash_data_from_flash <= spi_flash_data_from_flash_int;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        spiflashstate                   <= idle;
        spi_flash_granted_programmer    <= '0';
        fifo_req_last                   <= '0';
        arria_write_req_last            <= '0';
        spiflash_to_fifo_we             <= '0';
        fifopiotoggle_last              <= '0';
        arriawriting                    <= '0';
        spi_strobe_arria                <= '0';
        spi_continue_arria              <= '0';
        o_status                          <= (others => '0');


    elsif rising_edge(i_clk) then
        fifopiotoggle_last              <= i_spi_flash_fifo_data_nios(8);
        fifo_req_last                   <= i_spi_flash_ctrl(7);
        arria_write_req_last            <= i_control(0);
        spiflash_to_fifo_we             <= '0';

        o_status(PROGRAMMING_STATUS_BIT_ARRIAWRITING) <= arriawriting; -- 0
        o_status(PROGRAMMING_STATUS_BIT_SPI_BUSY) <= spi_busy; -- 1
        o_status(PROGRAMMING_STATUS_BIT_FIFO_EMPTY) <= spiflashfifo_empty; -- 14
        o_status(PROGRAMMING_STATUS_BIT_FIFO_FULL) <= spiflashfifo_full; -- 15

        o_status(PROGRAMMING_STATUS_BIT_CONF_DONE)              <= i_fpga_conf_done; -- 16
        o_status(PROGRAMMING_STATUS_BIT_NSTATUS)              <= i_fpga_nstatus; -- 17
        o_status(PROGRAMMING_STATUS_BIT_TIMEOUT)              <= fpp_timeout; -- 18
        o_status(PROGRAMMING_STATUS_BIT_CRCERROR)              <= fpp_crcerror; -- 19
        o_status(23 downto 20)    <= (others => '0');
        o_status(31 downto 24)    <= fpp_debug;

        o_status(13 downto 2) <= (others => '0');

        case spiflashstate is
        when idle =>
            if (spi_busy = '0' and spi_flash_request_programmer = '1' ) then
                spiflashstate <= programming;
            end if;

            if ( i_spi_flash_ctrl(7) = '1' and  fifo_req_last = '0') then
                spiflashstate   <= fifowriting;
                wcounter        <= (others => '0');
            end if;

            if(i_control(0) = '1' and arria_write_req_last = '0') then -- here we start the sequence for erasing
                                                                     -- and writing an spi flash block
                                                                     -- we only erase if we just passed a 64K block boundary
                if(i_addr_from_arria(15 downto 0) = X"0000") then
                    spiflashstate  <= arriawriting1;
                    arriawriting   <= '1';
                else
                    spiflashstate  <= arriawriting5;
                    arriawriting   <= '1';
                end if;

            end if;


            if(i_spi_bp_byte_en = '1' and i_spi_bp_addr = "0" & FEBSPI_ADDR_PROGRAMMING_WFIFO) then
                spiflash_to_fifo_we  <= '1';
                spiflashfifo_data_in <= i_spi_bp_byte_from_bp;
            elsif (i_spi_arria_byte_en = '1' and i_spi_arria_addr = FEBSPI_ADDR_PROGRAMMING_WFIFO) then
                spiflash_to_fifo_we  <= '1';
                spiflashfifo_data_in <= i_spi_arria_byte_from_arria;
            elsif(fifopiotoggle_last /= i_spi_flash_fifo_data_nios(8)) then
                spiflash_to_fifo_we  <= '1';
                spiflashfifo_data_in <= i_spi_flash_fifo_data_nios(7 downto 0);
            end if;

        when arriawriting1 =>    -- set the write enable
            o_status(2)               <= '1';
            spi_command_arria       <= COMMAND_WRITE_ENABLE;
            spi_addr_arria          <= (others => '0');
            spi_continue_arria      <= '0';
            spi_strobe_arria        <= '1';
            if(spi_ack = '1')then
                spiflashstate <= arriawriting2;
                spi_strobe_arria        <= '0';
            end if;
        when arriawriting2 =>  -- send the erase command
            o_status(3)               <= '1';
            spi_command_arria       <= COMMAND_BLOCK_ERASE_64;
            spi_addr_arria          <= i_addr_from_arria;
            spi_continue_arria      <= '0';
            spi_strobe_arria        <= '1';
            if(spi_ack = '1')then
                spiflashstate <= arriawriting3;
                spi_strobe_arria        <= '0';
                wipseen                 <= '0';
            end if;
        when arriawriting3 => -- wait for the WIP bit to go off
            o_status(4)               <= '1';
            spi_command_arria       <= COMMAND_READ_STATUS_REGISTER1;
            spi_addr_arria          <= (others => '0');
            spi_continue_arria      <= '1';
            spi_strobe_arria        <= '1';
            if(spi_byte_ready = '1' and spi_flash_data_from_flash_int(0) = '1') then
                wipseen <= '1';
            end if;

            if(spi_byte_ready = '1' and spi_flash_data_from_flash_int(0) = '0' and wipseen = '1') then
                spiflashstate           <= arriawriting4;
                spi_continue_arria      <= '0';
                spi_strobe_arria        <= '0';
            end if;
        when arriawriting4 => -- make sure spi is ready again
            o_status(5)               <= '1';
            if(spi_busy <= '0')then
                spiflashstate           <= arriawriting5;
            end if;
        when arriawriting5 =>  -- set the write enable
            o_status(6)               <= '1';
            spi_command_arria       <= COMMAND_WRITE_ENABLE;
            spi_addr_arria          <= (others => '0');
            spi_continue_arria      <= '0';
            spi_strobe_arria        <= '1';
            if(spi_ack = '1')then
                spiflashstate <= arriawriting6;
                spi_strobe_arria        <= '0';
            end if;
        when arriawriting6 => -- check if we set the write enable successfully
            o_status(7)               <= '1';
            spi_command_arria       <= COMMAND_READ_STATUS_REGISTER1;
            spi_addr_arria          <= (others => '0');
            spi_continue_arria      <= '0';
            spi_strobe_arria        <= '1';
            if(spi_byte_ready = '1' and spi_flash_data_from_flash_int(1) = '1') then
                spiflashstate <= arriawriting7;
                spi_strobe_arria        <= '0';
            elsif(spi_byte_ready = '1' and spi_flash_data_from_flash_int(1) = '0') then
                spiflashstate <= arriawriting5;  -- try setting write enable again (note tha this is a potential endless loop, maybe we should drop that?)
                spi_strobe_arria        <= '0';
            end if;
        when arriawriting7 => -- make sure spi is ready again
            o_status(8)               <= '1';
            if(spi_busy <= '0')then
                spiflashstate           <= arriafifowriting;
            end if;
        when arriafifowriting => -- start writing
            o_status(9)               <= '1';
            spi_command_arria       <= COMMAND_QUAD_PAGE_PROGRAM;
            spi_addr_arria          <= i_addr_from_arria;
            spi_continue_arria      <= '1';
            spi_strobe_arria        <= '1';
            wcounter                <= wcounter + 1;
            if ( spiflashfifo_empty = '1' and spi_busy = '0') then
                spiflashstate <= arriawriting8;
                spi_continue_arria      <= '0';
                spi_strobe_arria        <= '0';
                wipseen                 <= '0';
            end if;
        when arriawriting8 => -- wait for the WIP bit to go off
            o_status(10)               <= '1';
            spi_command_arria       <= COMMAND_READ_STATUS_REGISTER1;
            spi_addr_arria          <= (others => '0');
            spi_continue_arria      <= '1';
            spi_strobe_arria        <= '1';

            if(spi_byte_ready = '1' and spi_flash_data_from_flash_int(0) = '1') then
                wipseen <= '1';
            end if;
            if(spi_byte_ready = '1' and spi_flash_data_from_flash_int(0) = '0' and wipseen = '1') then
                spiflashstate           <= idle;
                arriawriting            <= '0';
                spi_continue_arria      <= '0';
                spi_strobe_arria        <= '0';
            end if;

        when fifowriting =>
            o_status(11)               <= '1';
            wcounter                 <= wcounter + 1;
            if ( spiflashfifo_empty = '1' ) then
                spiflashstate <= idle;
            end if;


        when programming =>
            o_status(12)               <= '1';
            spi_flash_granted_programmer    <= '1';
            if(spi_flash_request_programmer = '0') then
                spiflashstate <= idle;
            end if;
        when others =>
            spiflashstate <= idle;
        end case;
    end if;
    end process;

    o_flash_w_cnt(31 downto 16) <= std_logic_vector(wcounter);

    spi_strobe_nios             <= i_spi_flash_ctrl(0);
    spi_command_nios            <= i_spi_flash_cmdaddr_to_flash(31 downto 24);
    spi_addr_nios               <= i_spi_flash_cmdaddr_to_flash(23 downto 0);

    read_spiflashfifo           <= spi_next_byte;

    spi_flash_data_to_flash     <= spiflashfifo_data_out when spiflashstate = fifowriting
                                                           or spiflashstate = arriafifowriting
                                  else  i_spi_flash_data_to_flash_nios;

    spi_continue                <= spi_continue_programmer  when spiflashstate = programming
                                else not spiflashfifo_empty when spiflashstate = fifowriting
                                else not spiflashfifo_empty when spiflashstate = arriafifowriting
                                else spi_continue_arria when arriawriting = '1'
                                else i_spi_flash_ctrl(1);

    spi_strobe                  <= spi_strobe_programmer when spiflashstate = programming
                                   else spi_strobe_arria      when arriawriting = '1'
                                   else spi_strobe_nios;
    spi_command                 <= spi_command_programmer when spiflashstate = programming
                                   else spi_command_arria      when arriawriting = '1'
                                   else spi_command_nios;
    spi_addr                    <= spi_addr_programmer when spiflashstate = programming
                                   else spi_addr_arria      when arriawriting = '1'
                                   else spi_addr_nios;

    o_spi_flash_status(0) <= spi_ack;
    o_spi_flash_status(1) <= spi_next_byte;
    o_spi_flash_status(2) <= spi_byte_ready;
    o_spi_flash_status(3) <= spi_busy;

    --o_spi_flash_status(4) <= '0';
    o_spi_flash_status(5) <= spiflashfifo_full;
    o_spi_flash_status(6) <= spiflashfifo_empty;
    o_spi_flash_status(7) <= '1' when spiflashstate = fifowriting else '0';


    e_spiflash : entity work.spiflash
    port map (
        -- spi ctrl
        i_spi_strobe        => spi_strobe,
        o_spi_ack           => spi_ack,
        o_spi_busy          => spi_busy,
        i_spi_command       => spi_command,
        i_spi_addr          => spi_addr,
        i_spi_data          => spi_flash_data_to_flash,
        o_spi_next_byte     => spi_next_byte,
        i_spi_continue      => spi_continue,
        o_spi_byte_out      => spi_flash_data_from_flash_int,
        o_spi_byte_ready    => spi_byte_ready,
        -- spi to flash
        o_spi_sclk          => o_flash_sck,
        o_spi_csn           => o_flash_csn,
        io_spi_mosi         => io_flash_io0,
        io_spi_miso         => io_flash_io1,
        io_spi_D2           => io_flash_io2,
        io_spi_D3           => io_flash_io3,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );

    programming_if : entity work.fpp_programmer
    generic map (
        COMPRESSION => true
    )
    port map (
        -- spi addr
        i_start             => i_flash_programming_ctrl(31),
        i_start_address     => i_flash_programming_ctrl(23 downto 0),
        --Interface to SPI flash
        o_spi_strobe        => spi_strobe_programmer,
        o_spi_command       => spi_command_programmer,
        o_spi_addr          => spi_addr_programmer,
        o_spi_continue      => spi_continue_programmer,
        i_spi_byte_out      => spi_flash_data_from_flash_int,
        i_spi_byte_ready    => spi_byte_ready,
        o_spi_flash_request => spi_flash_request_programmer,
        i_spi_flash_granted => spi_flash_granted_programmer,
        --Interface to FPGA
        i_fpga_conf_done    => i_fpga_conf_done,
        i_fpga_nstatus      => i_fpga_nstatus,
        o_fpga_nconfig      => o_fpga_nconfig,
        o_fpga_data         => o_fpga_data,
        o_fpga_clk          => o_fpga_clk,
        o_crcerror          => fpp_crcerror,
        o_timeout           => fpp_timeout,
        o_debug             => fpp_debug,
        o_crclocation       => o_fpp_crclocation,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );

    e_scfifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 9,
        g_DATA_WIDTH => 8,
        g_RAM_OUTREG => "ON"--,
    )
    port map (
        i_we => spiflash_to_fifo_we,
        i_wdata => spiflashfifo_data_in,
        o_wfull => spiflashfifo_full,

        i_rack => read_spiflashfifo,
        o_rdata => spiflashfifo_data_out,
        o_rempty => spiflashfifo_empty,

        i_reset_n => i_reset_n and not i_control(1),
        i_clk => i_clk--,
    );

end architecture;
