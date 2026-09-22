--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

use work.feb_sc_registers.all;

entity top is
port (
    reset_max_bp_n          : in std_logic; -- Active low reset
    max10_si_clk            : in std_logic; -- 50 MHZ clock from SI chip // SI5345
    max10_osc_clk           : in std_logic; -- 50 MHZ clock from oscillator

    -- Flash SPI IF
    flash_csn               : out std_logic;
    flash_sck               : out std_logic;
    flash_io0               : inout std_logic;
    flash_io1               : inout std_logic;
    flash_io2               : inout std_logic;
    flash_io3               : inout std_logic;

    -- FPGA programming interface
    fpga_conf_done          : in std_logic;
    fpga_nstatus            : in std_logic;
    fpga_nconfig            : out std_logic;
    fpga_data               : out std_logic_vector(7 downto 0);
    fpga_clk                : out std_logic;
    fpga_reset              : out std_logic;

    -- SPI Interface to FPGA
    fpga_spi_clk            : in std_logic;
    fpga_spi_mosi           : inout std_logic;
    fpga_spi_miso           : inout std_logic;
    fpga_spi_D1             : inout std_logic;
    fpga_spi_D2             : inout std_logic;
    fpga_spi_D3             : inout std_logic;
    fpga_spi_csn            : in std_logic;

    -- SPI Interface to backplane
    bp_spi_clk              : in std_logic;
    bp_spi_mosi             : in std_logic;
    bp_spi_miso             : out std_logic;
    bp_spi_miso_en          : out std_logic;
    bp_spi_csn              : in std_logic;

    -- Backplane signals
    board_select            : in std_logic;
    reset_cpu_backplane_n   : in std_logic;
    reset_fpga_bp_n         : in std_logic; -- which one is the right one here?
    bp_reset_fpga           : in std_logic;
    bp_mode_select          : in std_logic_vector(1 downto 0);
    mscb_out                : out std_logic;
    mscb_in                 : in std_logic;
    fpga_mscb_oe            : in std_logic;
    mscb_ena                : out std_logic;
    mscb_reset_n            : out std_logic;
    ref_addr                : in std_logic_vector(7 downto 0);
    spi_adr                 : in std_logic_vector(2 downto 0);
    attention_n             : inout std_logic_vector(1 downto 0);
    temp_sens_dis           : out std_logic;
    spare                   : in std_logic_vector(2 downto 0)--;
);
end entity;

architecture arch of top is

    signal max10_osc_clk_e                      : std_logic;
    signal pll_locked                           : std_logic;
    signal pll_locked_last                      : std_logic;

    signal clk10 : std_logic;
    signal clk50 : std_logic;
    signal clk_100 : std_logic;
    signal reset_100_n : std_logic;

    signal startup : std_logic;

    signal version                              : std_logic_vector(31 downto 0);
    signal status                               : std_logic_vector(31 downto 0);
    signal control                              : std_logic_vector(31 downto 0);

    signal flash_programming_ctrl               : std_logic_vector(31 downto 0);
    signal flash_programming_status             : std_logic_vector(31 downto 0);
    signal flash_programming_ctrl_arria         : std_logic_vector(31 downto 0);
    signal flash_programming_status_arria       : std_logic_vector(31 downto 0);
    signal flash_w_cnt                          : std_logic_vector(31 downto 0);
    signal reset_n                              : std_logic;
    signal programming_addr_from_arria          : std_logic_vector(23 downto 0);


    signal spi_flash_ctrl                       : std_logic_vector(7 downto 0);
    signal spi_flash_status                     : std_logic_vector(7 downto 0);
    signal spi_flash_data_from_flash            : std_logic_vector(7 downto 0);

    signal spi_flash_data_to_flash_nios         : std_logic_vector(7 downto 0);
    signal spi_flash_cmdaddr_to_flash           : std_logic_vector(31 downto 0);
    signal spi_flash_fifo_data_nios             : std_logic_vector(8 downto 0);

    signal shutdown_internal                    : std_logic_vector(31 downto 0);
    signal shutdown                             : std_logic := '0';
    signal shutdown_latch                       : std_logic := '0';
    signal max_10_temperature                   : std_logic_vector(11 downto 0);
    signal first_max_10_temperature             : std_logic_vector(11 downto 0);


    -- Fifo for programming data to the SPIflash
    signal spiflash_to_fifo_we                     : std_logic;
    signal spiflashfifo_empty                      : std_logic;
    signal spiflashfifo_full                       : std_logic;
    signal spiflashfifo_data_in                    : std_logic_vector(7 downto 0);
    signal spiflashfifo_data_out                   : std_logic_vector(7 downto 0);
    signal read_spiflashfifo                       : std_logic;
    signal fifopiotoggle_last                       : std_logic;

    -- spi arria
    signal SPI_inst                             : std_logic_vector(7 downto 0);
    signal SPI_Aria_data                        : std_logic_vector(31 downto 0);
    signal SPI_Max10_data                       : std_logic_vector(31 downto 0);
    signal SPI_addr_o                           : std_logic_vector(6 downto 0);
    signal SPI_rw                               : std_logic;

    signal spi_arria_addr                       : std_logic_vector(6 downto 0);
    signal spi_arria_addr_offset                : std_logic_vector(7 downto 0);
    signal spi_arria_rw                         : std_logic;
    signal spi_arria_data_to_arria              : std_logic_vector(31 downto 0);
    --signal spi_arria_next_data                  : std_logic;
    signal spi_arria_word_from_arria            : std_logic_vector(31 downto 0);
    signal spi_arria_word_en                    : std_logic;
    signal spi_arria_byte_from_arria            : std_logic_vector(7 downto 0);
    signal spi_arria_byte_en                    : std_logic;

    -- SPI Backplane
    signal spi_bp_addr_long     : std_logic_vector(7 downto 0);
    signal spi_bp_addr          : std_logic_vector(6 downto 0);
    signal spi_bp_addr_offset   : std_logic_vector(7 downto 0);
    signal spi_bp_rw            : std_logic;
    signal spi_bp_data_to_bp    : std_logic_vector(31 downto 0);
    signal spi_bp_word_from_bp  : std_logic_vector(31 downto 0);
    signal spi_bp_word_en       : std_logic;
    signal spi_bp_byte_from_bp  : std_logic_vector(7 downto 0);
    signal spi_bp_byte_en       : std_logic;


    -- spi arria ram
    signal ram_SPI_data                         : std_logic_vector(31 downto 0);
    signal SPI_ram_data                         : std_logic_vector(31 downto 0);
    signal SPI_ram_addr                         : std_logic_vector(13 downto 0);
    signal SPI_ram_rw                           : std_logic;

    -- ADC
    signal adc_response_valid : std_logic;
    signal adc_response_channel : std_logic_vector(4 downto 0);
    signal adc_response_data : std_logic_vector(11 downto 0);

    signal adc_sequencer_csr_address : std_logic;
    signal adc_sequencer_csr_read : std_logic;
    signal adc_sequencer_csr_write : std_logic;
    signal adc_sequencer_csr_writedata : std_logic_vector(31 downto 0);
    signal adc_seqeuncer_csr_readdata : std_logic_vector(31 downto 0);

    signal adc_data_0                           : std_logic_vector(31 downto 0);
    signal adc_data_1                           : std_logic_vector(31 downto 0);
    signal adc_data_2                           : std_logic_vector(31 downto 0);
    signal adc_data_3                           : std_logic_vector(31 downto 0);
    signal adc_data_4                           : std_logic_vector(31 downto 0);
    signal max_temp_written                     : std_logic := '0';

    signal startupcounter                       : integer;

    signal fpp_crclocation                      : std_logic_vector(31 downto 0);
    signal programming_control_nios             : std_logic_vector(31 downto 0);

    -- backplane stuff
    signal bp_spi_reg : std_logic;

begin

    temp_sens_dis <= not board_select; -- temp_sens_dis is used in the 1-wire discovery process.
                                       -- only sensors with temp_sens_dis low will reply to the
                                       -- discovery command. The crate controller selects one board,
                                       -- there temp_sens_dis should be low, high otherwise
                                       -- Note that the signal is pulled low if the FEB is not powered,
                                       -- so discovery with more than one FEB in a crate requires a
                                       -- programmed and powered MAX10

    --------------------
    -- SHUTDOWN logic --

    shutdown <= '1' when (
        -- shutdown_internal(0) = '1'
        -- shut down at 85 C (see MuFeb.cpp)
         (pll_locked = '1' and max_temp_written = '1' and max_10_temperature < X"DD7") -- nominal temp is X"E70" "DD7"
    ) else '0';

    process(shutdown)
    begin
    if (shutdown = '1') then
        -- NOTE: latch is intended
        shutdown_latch <= '1';
    end if;
    end process;

    fpga_reset <= shutdown_latch;

    ------------
    -- CLOCKS --

    max10_osc_clk_e     <= max10_osc_clk when shutdown_latch = '0' else '0';
    reset_n             <= '0' when pll_locked = '0' or (reset_max_bp_n = '0' and board_select = '1') or shutdown_latch = '1'
                           else '1';
    mscb_ena            <= '0';
    max_10_temperature  <= adc_data_4(27 downto 16);

    e_pll : entity work.ip_altpll
    port map (
        c0          => clk10,
        c1          => clk_100,
        c2          => clk50,
        locked      => pll_locked,
        areset      => shutdown_latch,
        inclk0      => max10_osc_clk--,
    );
    reset_100_n <= reset_n;

    version <= GIT_HEAD_INT32(work.cmp.GIT_HEAD);

    status(MAX10_STATUS_BIT_PLL_LOCKED) <= pll_locked;
    status(MAX10_STATUS_BIT_SPI_ARRIA_CLK) <= fpga_spi_clk;
    status(           2) <= board_select;
    status(           3) <= reset_cpu_backplane_n;
    status(           4) <= reset_fpga_bp_n;
    status(           5) <= bp_reset_fpga;
    status( 7 downto  6) <= bp_mode_select;
    status(10 downto  8) <= spi_adr;
    status(12 downto 11) <= attention_n;
    status(15 downto 13) <=  spare;
    status(23 downto 16) <= ref_addr;
    status(31 downto 24) <= spi_flash_status;
    --status(31 downto 20)  <= first_max_10_temperature;
    attention_n <= "ZZ";


    -- Backplane SPI
    ----------------
    e_spi_bp : entity work.spi_bp
    port map (
        i_boardselect   => board_select,
        i_SPI_csn       => bp_spi_csn,
        i_SPI_clk       => bp_spi_clk,
        i_SPI_mosi      => bp_spi_mosi,
        o_SPI_miso      => bp_spi_miso,
        o_SPI_miso_en   => bp_spi_miso_en,

        o_addr          => spi_bp_addr_long,
        o_addroffset    => spi_bp_addr_offset,
        o_rw            => spi_bp_rw,
        i_data_to_bp    => spi_bp_data_to_bp,
        o_next_data     => open,
        o_word_from_bp  => spi_bp_word_from_bp,
        o_word_en       => spi_bp_word_en,
        o_byte_from_bp  => spi_bp_byte_from_bp,
        o_byte_en       => spi_bp_byte_en,

        i_reset_n       => reset_100_n,
        i_clk           => clk_100--,
    );
    spi_bp_addr  <= spi_bp_addr_long(6 downto 0);

    -- SPI Arria5 to MAX10
    -----------------------
    e_spi_arria : entity work.spi_arria
    port map (
        ------ SPI
        i_SPI_csn           => fpga_spi_csn,
        i_SPI_clk           => fpga_spi_miso, -- replacement for missing connection
        io_SPI_mosi         => fpga_spi_mosi,
        io_SPI_miso         => open,
        io_SPI_D1           => fpga_spi_D1,
        io_SPI_D2           => fpga_spi_D2,
        io_SPI_D3           => fpga_spi_D3, -- again, replacement

        o_addr              => spi_arria_addr,
        o_addroffset        => spi_arria_addr_offset,
        i_data_to_arria     => spi_arria_data_to_arria,
        o_next_data         => open,
        o_rw                => spi_arria_rw,
        o_word_from_arria   => spi_arria_word_from_arria,
        o_word_en           => spi_arria_word_en,
        o_byte_from_arria   => spi_arria_byte_from_arria,
        o_byte_en           => spi_arria_byte_en,

        i_reset_n           => reset_100_n,
        i_clk               => clk_100--,
    );

    -- Multiplexer for data to_arria
    spi_arria_data_to_arria <=
        version when spi_arria_addr = FEBSPI_ADDR_GITHASH else
        status when spi_arria_addr = FEBSPI_ADDR_STATUS else
        control when  spi_arria_addr = FEBSPI_ADDR_CONTROL else
        X"00" & programming_addr_from_arria when spi_arria_addr = FEBSPI_ADDR_PROGRAMMING_ADDR else
        flash_programming_status_arria when spi_arria_addr = FEBSPI_ADDR_PROGRAMMING_STATUS else
        flash_w_cnt when spi_arria_addr = FEBSPI_ADDR_PROGRAMMING_COUNT else
        adc_data_0 when spi_arria_addr = FEBSPI_ADDR_ADCDATA
                    and spi_arria_addr_offset = "00000000" else
        adc_data_1 when spi_arria_addr = FEBSPI_ADDR_ADCDATA
                    and spi_arria_addr_offset = "00000001" else
        adc_data_2 when spi_arria_addr = FEBSPI_ADDR_ADCDATA
                    and spi_arria_addr_offset = "00000010" else
        adc_data_3 when spi_arria_addr = FEBSPI_ADDR_ADCDATA
                    and spi_arria_addr_offset = "00000011" else
        adc_data_4 when spi_arria_addr = FEBSPI_ADDR_ADCDATA
                    and spi_arria_addr_offset = "00000100" else
        (others => '0');

    -- Multiplexer for data to backplane
    spi_bp_data_to_bp <=
        version when spi_bp_addr = FEBSPI_ADDR_GITHASH else
        status when spi_bp_addr = FEBSPI_ADDR_STATUS else
        control when  spi_bp_addr = FEBSPI_ADDR_CONTROL else
        X"00" & programming_addr_from_arria when spi_bp_addr = FEBSPI_ADDR_PROGRAMMING_ADDR else
        flash_programming_status_arria when spi_bp_addr = FEBSPI_ADDR_PROGRAMMING_STATUS else
        flash_w_cnt when spi_bp_addr = FEBSPI_ADDR_PROGRAMMING_COUNT else
        adc_data_0 when spi_bp_addr = FEBSPI_ADDR_ADCDATA
                    and spi_bp_addr_offset = "00000000" else
        adc_data_1 when spi_bp_addr = FEBSPI_ADDR_ADCDATA
                    and spi_bp_addr_offset = "00000001" else
        adc_data_2 when spi_bp_addr = FEBSPI_ADDR_ADCDATA
                    and spi_bp_addr_offset = "00000010" else
        adc_data_3 when spi_bp_addr = FEBSPI_ADDR_ADCDATA
                    and spi_bp_addr_offset = "00000011" else
        adc_data_4 when spi_bp_addr = FEBSPI_ADDR_ADCDATA
                    and spi_bp_addr_offset = "00000100" else
        (others => '0');



    -- Write multiplexer
    process(clk_100, reset_100_n)
    begin
    if ( reset_100_n = '0' ) then
        control <= (others => '0');
    elsif rising_edge(clk_100) then
        -- Word-wise writing from Arria
        if(spi_arria_rw = '1' and spi_arria_word_en = '1') then
            if(spi_arria_addr = FEBSPI_ADDR_CONTROL) then
                control <= spi_arria_word_from_arria;
            end if;
            if(spi_arria_addr = FEBSPI_ADDR_PROGRAMMING_CTRL) then
                flash_programming_ctrl_arria <= spi_arria_word_from_arria;
            end if;
            if(spi_arria_addr = FEBSPI_ADDR_PROGRAMMING_ADDR ) then
                programming_addr_from_arria <= spi_arria_word_from_arria(23 downto 0);
            end if;
        end if;
        -- Word-wise writing from BP
        if(spi_bp_rw = '1' and spi_bp_word_en = '1') then
            if(spi_bp_addr = FEBSPI_ADDR_CONTROL) then
                control <= spi_bp_word_from_bp;
            end if;
            if(spi_bp_addr = FEBSPI_ADDR_PROGRAMMING_CTRL) then
                flash_programming_ctrl_arria <= spi_bp_word_from_bp;
            end if;
            if(spi_bp_addr = FEBSPI_ADDR_PROGRAMMING_ADDR ) then
                programming_addr_from_arria <= spi_bp_word_from_bp(23 downto 0);
            end if;
        end if;

        -- Byte-wise writing
        if(spi_arria_rw = '1' and spi_arria_byte_en = '1') then
            --if(spi_arria_addr = FEBSPI_ADDR_CONTROL) then
            --    control <= spi_arria_byte_from_arria;
            --end if;
        end if;

    end if;
    end process;



    e_adc : component work.cmp.adc
    port map (
        adc_pll_clock_clk     => clk10,
        adc_pll_locked_export => pll_locked,
        clock_clk             => clk_100,
        reset_sink_reset_n    => reset_n,
        response_valid        => adc_response_valid,
        response_channel      => adc_response_channel,
        response_data         => adc_response_data,
        response_startofpacket=> open,
        response_endofpacket  => open,
        sequencer_csr_address => adc_sequencer_csr_address,
        sequencer_csr_read    => adc_sequencer_csr_read,
        sequencer_csr_write   => adc_sequencer_csr_write,
        sequencer_csr_writedata => adc_sequencer_csr_writedata,
        sequencer_csr_readdata => adc_seqeuncer_csr_readdata
    );

    -- Start the ADC sequencer
    process(clk_100, reset_100_n)
    begin
    if ( reset_100_n = '0' ) then
        adc_sequencer_csr_read <= '0';
        adc_sequencer_csr_write <= '0';
        adc_sequencer_csr_address <= '0'; -- address is one bit and always 0
        pll_locked_last <= '0';
    elsif rising_edge(clk_100) then
        pll_locked_last <= pll_locked;
        adc_sequencer_csr_write <= '0';
        if ( pll_locked = '1' and pll_locked_last = '0' ) then -- is this safe??
            adc_sequencer_csr_write <= '1';
            adc_sequencer_csr_writedata <= X"00000001";
        end if;
    end if;
    end process;

    -- ADC multiplexer
    process(clk_100, reset_100_n)
    begin
    if ( reset_100_n = '0' ) then
        adc_data_0  <= (others => '0');
        adc_data_1  <= (others => '0');
        adc_data_2  <= (others => '0');
        adc_data_3  <= (others => '0');
        adc_data_4  <= (others => '0');
        max_temp_written <= '0';
    elsif rising_edge(clk_100) then
        if(adc_response_valid = '1') then
            case adc_response_channel is
            when "00000" =>
                adc_data_0(11 downto 0) <= adc_response_data;
            when "00001" =>
                adc_data_0(27 downto 16) <= adc_response_data;
            when "00010" =>
                adc_data_1(11 downto 0) <= adc_response_data;
            when "00011" =>
                adc_data_1(27 downto 16) <= adc_response_data;
            when "00100" =>
                adc_data_2(11 downto 0) <= adc_response_data;
            when "00101" =>
                adc_data_2(27 downto 16) <= adc_response_data;
            when "00110" =>
                adc_data_3(11 downto 0) <= adc_response_data;
            when "00111" =>
                adc_data_3(27 downto 16) <= adc_response_data;
            when "01000" =>
                adc_data_4(11 downto 0) <= adc_response_data;
            when "10001" => -- Temperature sensor is channel 17!
                if(adc_response_data /= "000") then
                    adc_data_4(27 downto 16) <= adc_response_data;
                    max_temp_written <= '1';
                    if(max_temp_written = '0') then
                        first_max_10_temperature <= adc_response_data;
                    end if;
                end if;

            when others =>
                --
            end case;
        end if;
    end if;
    end process;

    -- NIOS
    -----------------------
    e_nios : component work.cmp.nios
    port map (
        -- clk & reset
        clk_clk                     => clk_100,
        clk_spi_clk                 => clk_100,
        rst_reset_n                 => reset_100_n,
        rst_spi_reset_n             => reset_100_n,

        -- generic pio
        pio_export                  => open,

        -- arria spi
        ava_mm_address              => SPI_ram_addr,
        ava_mm_read                 => SPI_ram_rw,
        ava_mm_readdata             => ram_SPI_data,
        ava_mm_write                => '0',
        ava_mm_writedata            => SPI_ram_data,

        -- spi not used at the moment
        spi_MISO                    => '1',
        spi_MOSI                    => open,
        spi_SCLK                    => open,
        spi_SS_n                    => open,

        -- i2c not used at the moment
        i2c_sda_in                  => '1',
        i2c_scl_in                  => '1',
        i2c_sda_oe                  => open,
        i2c_scl_oe                  => open,

        -- flash spi
        flash_ps_ctrl_export        => open,
        flash_w_cnt_export          => flash_w_cnt,
        flash_cmd_addr_export       => spi_flash_cmdaddr_to_flash,
        flash_ctrl_export           => spi_flash_ctrl,
        flash_i_data_export         => spi_flash_data_to_flash_nios,
        flash_o_data_export         => spi_flash_data_from_flash,
        flash_status_export         => spi_flash_status,
        flash_fifo_data_export      => spi_flash_fifo_data_nios,

        status_export               => status,
        programming_status_export   => flash_programming_status_arria,
        crclocation_export          => fpp_crclocation,
        programming_control_export  => programming_control_nios,
        shutdown_export             => shutdown_internal,
        temperature_export          => X"00000" & max_10_temperature
    );

    --flash_programming_ctrl(31) <= startup;
    e_startup_sync : entity work.reset_sync
    port map ( i_areset_n => startup, o_reset_n => flash_programming_ctrl(31), i_clk => clk_100 );

    process(max10_osc_clk_e, reset_n)
    begin
    if ( reset_n = '0' ) then
        startup <= '0';
        startupcounter <= 0;
    elsif rising_edge(max10_osc_clk_e) then
        -- Choose flash image with bp_mode_sel - the emergency image starts at 0xC0 00 00
        if(bp_mode_select = "01") then
            flash_programming_ctrl(30 downto 0) <= "000" & X"0C00000";
        else
            flash_programming_ctrl(30 downto 0) <= (others => '0');
        end if;

        if(pll_locked = '1')then
            startupcounter <= startupcounter + 1;

            if(startupcounter > 4095000)then
                startup <= '1';
            end if;

            if(startupcounter > 5000000)then
                startupcounter <= 5001000;
                startup <= '0';
                -- Reprogram the FPGA on request from the crate controller
                if(board_select = '1' and reset_fpga_bp_n = '0') then
                    startup <= '1';
                end if;
            end if;
        end if;
    end if;
    end process;


    e_flashprogramming_block: entity work.flashprogramming_block
    port map (
        i_control               => flash_programming_ctrl_arria,
        o_status                => flash_programming_status_arria,

        -- Flash SPI IF
        o_flash_csn             => flash_csn,
        o_flash_sck             => flash_sck,
        io_flash_io0            => flash_io0,
        io_flash_io1            => flash_io1,
        io_flash_io2            => flash_io2,
        io_flash_io3            => flash_io3,

        -- FPGA programming interface
        i_fpga_conf_done        => fpga_conf_done,
        i_fpga_nstatus          => fpga_nstatus,
        o_fpga_nconfig          => fpga_nconfig,
        o_fpga_data             => fpga_data,
        o_fpga_clk              => fpga_clk,

        o_fpp_crclocation       => fpp_crclocation,

        i_flash_programming_ctrl        => flash_programming_ctrl,
        o_flash_w_cnt                   => flash_w_cnt,
        i_spi_flash_cmdaddr_to_flash    => spi_flash_cmdaddr_to_flash,
        i_spi_flash_ctrl                => spi_flash_ctrl,
        i_spi_flash_data_to_flash_nios  => spi_flash_data_to_flash_nios,
        o_spi_flash_data_from_flash     => spi_flash_data_from_flash,
        o_spi_flash_status              => spi_flash_status,
        i_spi_flash_fifo_data_nios      => spi_flash_fifo_data_nios,

        -- Arria SPI interface
        i_spi_arria_byte_from_arria     => spi_arria_byte_from_arria,
        i_spi_arria_byte_en             => spi_arria_byte_en,
        i_spi_arria_addr                => spi_arria_addr,
        i_addr_from_arria               => programming_addr_from_arria,

        -- Arria SPI interface
        i_spi_bp_byte_from_bp   => spi_bp_byte_from_bp,
        i_spi_bp_byte_en        => spi_bp_byte_en,
        i_spi_bp_addr           => spi_bp_addr_long,

        i_reset_n               => reset_100_n,
        i_clk                   => clk_100--,
    );

end architecture;
