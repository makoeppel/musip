-- M. Mueller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mupix_registers.all;
use work.mupix.all;
use work.mudaq.all;

entity mupix_ctrl_reg_mapping is
generic (
    g_CHIPS_PER_SPI             : positive := 3;
    g_N_SPI                     : positive := 4
);
port (
    i_reg_addr                  : in  std_logic_vector(15 downto 0);
    i_reg_re                    : in  std_logic;
    o_reg_rdata                 : out std_logic_vector(31 downto 0);
    i_reg_we                    : in  std_logic;
    i_reg_wdata                 : in  std_logic_vector(31 downto 0);

    ----------------------------------------

    i_mp_spi_busy               : in std_logic := '0';

    o_chip_cvb                  : out std_logic_vector(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0);
    o_chip_tdac                 : out integer range 0 to g_CHIPS_PER_SPI*g_N_SPI-1;

    o_conf_reg_data             : out reg32;
    o_conf_reg_we               : out std_logic;
    o_vdac_reg_data             : out reg32;
    o_vdac_reg_we               : out std_logic;
    o_bias_reg_data             : out reg32;
    o_bias_reg_we               : out std_logic;

    o_vdac_ctrl                 : out std_logic_vector(31 downto 0);

    o_combined_data             : out reg32;
    o_combined_data_we          : out std_logic;

    o_tdac_data                 : out reg32;
    o_tdac_we                   : out std_logic;
    o_run_tdac_test             : out std_logic;

    o_mp_ctrl_slow_down         : out std_logic_vector(31 downto 0);
    o_mp_direct_spi_data        : out reg32array(g_N_SPI-1 downto 0);
    o_mp_direct_spi_data_wr     : out std_logic_vector(g_N_SPI-1 downto 0);
    i_mp_direct_spi_busy        : in  std_logic_vector(g_N_SPI-1 downto 0);
    o_mp_ctrl_direct_spi_enable : out std_logic;
    o_mp_ctrl_direct_spi_chip_m : out std_logic_vector(35 downto 0);
    o_mp_ctrl_spi_enable        : out std_logic;
    o_mp_ctrl_clk_slow_shift    : out std_logic_vector(2 downto 0);
    o_mp_ctrl_sin_invert        : out std_logic;
    o_mp_ctrl_external_cmd      : out work.mupix.mp_ctrl_external_command_array_t(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0) := (others => MP_CTRL_EXT_CMD_DEFAULT);

    i_testram_rdata             : in  reg32;
    o_testram_raddr             : out reg32 := (others => '0');
    o_testram_waddr             : out reg32 := (others => '0');
    o_testram_wdata             : out reg32 := (others => '0');

    i_n_free_pages              : in  std_logic_vector(31 downto 0);

    o_reset_n                   : out std_logic;

    i_reset_n                   : in  std_logic;
    i_clk                       : in  std_logic--;
);
end entity;

architecture rtl of mupix_ctrl_reg_mapping is

    signal mp_ctrl_slow_down        : std_logic_vector(31 downto 0);
    signal mp_ctrl_clk_slow_shift   : std_logic_vector(2 downto 0);
    signal mp_ctrl_sin_invert       : std_logic := '0';
    signal mp_ctrl_direct_spi_chip_m: std_logic_vector(63 downto 0);
    signal mp_spi_busy              : std_logic;
    signal mp_ctrl_direct_spi_enable: std_logic;
    signal mp_ctrl_spi_enable       : std_logic;
    signal conf_write_chip_select   : std_logic_vector(63 downto 0);
    signal reset_reg_n              : std_logic := '1';
    signal vdac_ctrl                : std_logic_vector(31 downto 0);

begin

    process(i_clk, i_reset_n)
        variable regaddr : integer;
    begin
    if ( i_reset_n /= '1' ) then
        o_reset_n                   <= '0';
        o_mp_ctrl_slow_down         <= (others => '0');
        mp_ctrl_slow_down           <= (others => '0');
        o_mp_direct_spi_data_wr     <= (others => '0');
        o_mp_direct_spi_data        <= (others => (others => '0'));
        o_reg_rdata                 <= x"CCCCCCCC";
        mp_ctrl_direct_spi_enable   <= '0';
        mp_ctrl_spi_enable          <= '0';
        o_mp_ctrl_direct_spi_enable <= '0';
        o_mp_ctrl_spi_enable        <= '0';
        o_conf_reg_we               <= '0';
        o_combined_data_we          <= '0';
        vdac_ctrl                   <= (others => '0');
        o_tdac_we                   <= '0';
        o_vdac_reg_we               <= '0';
        o_bias_reg_we               <= '0';
        o_conf_reg_data             <= (others => '0');
        o_bias_reg_data             <= (others => '0');
        o_vdac_reg_data             <= (others => '0');
        o_tdac_data                 <= (others => '0');
        o_chip_cvb                  <= (others => '0');
        o_combined_data             <= (others => '0');
        conf_write_chip_select      <= (others => '0');
        o_run_tdac_test             <= '0';
        o_mp_ctrl_clk_slow_shift    <= (others => '0');
        mp_ctrl_clk_slow_shift      <= (others => '0');
        mp_ctrl_sin_invert          <= '0';
        o_mp_ctrl_sin_invert        <= '0';
        --
    elsif rising_edge(i_clk) then

        o_reset_n                   <= reset_reg_n;
        o_mp_ctrl_slow_down         <= mp_ctrl_slow_down;
        regaddr                     := to_integer(unsigned(i_reg_addr));
        o_reg_rdata                 <= x"CCCCCCCC";
        o_mp_direct_spi_data_wr     <= (others => '0');
        mp_spi_busy                 <= i_mp_spi_busy;
        o_mp_ctrl_direct_spi_enable <= mp_ctrl_direct_spi_enable;
        o_mp_ctrl_spi_enable        <= mp_ctrl_spi_enable;
        o_mp_ctrl_clk_slow_shift    <= mp_ctrl_clk_slow_shift;
        o_mp_ctrl_sin_invert        <= mp_ctrl_sin_invert;
        o_mp_ctrl_direct_spi_chip_m <= mp_ctrl_direct_spi_chip_m(35 downto 0);

        o_chip_cvb                  <= conf_write_chip_select(g_CHIPS_PER_SPI*g_N_SPI-1 downto 0); -- o_chip_cvb is Overwritten in case of regaddr match with MP_CTRL_COMBINED_START_REGISTER_W !!!
        o_combined_data_we          <= '0';
        o_tdac_we                   <= '0';
        o_conf_reg_we               <= '0';
        o_vdac_reg_we               <= '0';
        o_bias_reg_we               <= '0';
        o_run_tdac_test             <= '0';

        o_vdac_ctrl                 <= vdac_ctrl;

        -----------------------------------------------------------------
        ---- mupix ctrl -------------------------------------------------
        -----------------------------------------------------------------

        loopctrlALL: for I in 0 to g_N_SPI*g_CHIPS_PER_SPI-1 loop
            if ( regaddr = MP_CTRL_COMBINED_START_REGISTER_W + I and i_reg_we = '1' ) then
                o_combined_data     <= i_reg_wdata;
                o_combined_data_we  <= '1';
                o_chip_cvb          <= (others => '0');
                o_chip_cvb(I)       <= '1';
            end if;
        end loop;

        loopTDACs: for I in 0 to g_N_SPI*g_CHIPS_PER_SPI-1 loop
            if ( regaddr = MP_CTRL_TDAC_START_REGISTER_W + I and i_reg_we = '1' ) then
                o_tdac_data         <= i_reg_wdata;
                o_tdac_we           <= '1';
                o_chip_tdac         <= I;
            end if;
        end loop;

        if ( regaddr = MP_CTRL_CHIP_SELECT1_REGISTER_W and i_reg_we = '1' ) then
            conf_write_chip_select(31 downto 0) <= i_reg_wdata;
        end if;
        if ( regaddr = MP_CTRL_CHIP_SELECT1_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= conf_write_chip_select(31 downto 0);
        end if;
        if ( regaddr = MP_CTRL_CHIP_SELECT2_REGISTER_W and i_reg_we = '1' ) then
            conf_write_chip_select(63 downto 32) <= i_reg_wdata;
        end if;
        if ( regaddr = MP_CTRL_CHIP_SELECT2_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= conf_write_chip_select(63 downto 32);
        end if;

        if ( regaddr = MP_CTRL_VDAC_WRITE_REGISTER_W and i_reg_we = '1' ) then
            vdac_ctrl <= i_reg_wdata;
        end if;
        if ( regaddr = MP_CTRL_VDAC_WRITE_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= vdac_ctrl;
        end if;

        if ( regaddr = MP_CTRL_VDAC_REGISTER_W and i_reg_we = '1' ) then
            o_vdac_reg_data <= i_reg_wdata;
            o_vdac_reg_we   <= '1';
        end if;
        if ( regaddr = MP_CTRL_BIAS_REGISTER_W and i_reg_we = '1' ) then
            o_bias_reg_data <= i_reg_wdata;
            o_bias_reg_we   <= '1';
        end if;

        if ( regaddr = MP_CTRL_SLOW_DOWN_REGISTER_W and i_reg_we = '1' ) then
            mp_ctrl_slow_down <= i_reg_wdata;
        end if;
        if ( regaddr = MP_CTRL_SLOW_DOWN_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= mp_ctrl_slow_down;
        end if;

        if ( regaddr = MP_CTRL_SPI_BUSY_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(0) <= mp_spi_busy;
            o_reg_rdata(31 downto 1) <= (others => '0');
        end if;

        loopdirectspi: for I in 0 to g_N_SPI-1 loop
        if ( regaddr = MP_CTRL_DIRECT_SPI_START_REGISTER_W+I and i_reg_we = '1' ) then
            o_mp_direct_spi_data(I) <= i_reg_wdata;
            o_mp_direct_spi_data_wr(I) <= '1';
        end if;
        end loop;

        if ( regaddr = MP_CTRL_DIRECT_SPI_ENABLE_REGISTER_W and i_reg_we = '1' ) then
            mp_ctrl_direct_spi_enable   <= i_reg_wdata(0);
        end if;
        if ( regaddr = MP_CTRL_DIRECT_SPI_ENABLE_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata(0)  <= mp_ctrl_direct_spi_enable;
            o_reg_rdata(31 downto 1) <= (others => '0');
        end if;

        if ( regaddr = MP_CTRL_SPI_ENABLE_REGISTER_W and i_reg_we = '1' ) then
            mp_ctrl_spi_enable   <= i_reg_wdata(0);
        end if;
        if ( regaddr = MP_CTRL_SPI_ENABLE_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata(0)  <= mp_ctrl_spi_enable;
            o_reg_rdata(31 downto 1) <= (others => '0');
        end if;

        if ( regaddr = MP_CTRL_DIRECT_SPI_BUSY_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata(g_N_SPI-1 downto 0) <= i_mp_direct_spi_busy;
            o_reg_rdata(31 downto g_N_SPI) <= (others => '0');
        end if;

        if ( regaddr = MP_CTRL_DIRECT_SPI_CHIP_M_LOW_REGISTER_W and i_reg_we = '1' ) then
            mp_ctrl_direct_spi_chip_m(31 downto 0) <= i_reg_wdata;
        end if;
        if ( regaddr = MP_CTRL_DIRECT_SPI_CHIP_M_LOW_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= mp_ctrl_direct_spi_chip_m(31 downto 0);
        end if;

        if ( regaddr = MP_CTRL_DIRECT_SPI_CHIP_M_HIGH_REGISTER_W and i_reg_we = '1' ) then
            mp_ctrl_direct_spi_chip_m(63 downto 32) <= i_reg_wdata;
        end if;
        if ( regaddr = MP_CTRL_DIRECT_SPI_CHIP_M_HIGH_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata <= mp_ctrl_direct_spi_chip_m(63 downto 32);
        end if;

        if ( regaddr = MP_CTRL_RESET_REGISTER_W and i_reg_we = '1' ) then
            reset_reg_n <= not i_reg_wdata(0);
        end if;

        if ( regaddr = MP_CTRL_RUN_TEST_REGISTER_W and i_reg_we = '1' ) then
            o_run_tdac_test <= '1';
        end if;

        if ( regaddr = MP_CTRL_N_FREE_PAGES_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_n_free_pages;
        end if;


        if ( regaddr = MP_CTRL_TESTRAM_RDATA_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_testram_rdata;
        end if;

        if ( regaddr = MP_CTRL_TESTRAM_WADDR_REGISTER_W and i_reg_we = '1' ) then
            o_testram_waddr <= i_reg_wdata;
        end if;

        if ( regaddr = MP_CTRL_TESTRAM_RADDR_REGISTER_W and i_reg_we = '1' ) then
            o_testram_raddr <= i_reg_wdata;
        end if;

        if ( regaddr = MP_CTRL_TESTRAM_WDATA_REGISTER_W and i_reg_we = '1' ) then
            o_testram_wdata <= i_reg_wdata;
        end if;

        if ( regaddr = MP_CTRL_SLOW_CLK_SHIFT_REGISTER_W and i_reg_we = '1' ) then
            mp_ctrl_clk_slow_shift   <= i_reg_wdata(2 downto 0);
        end if;
        if ( regaddr = MP_CTRL_SLOW_CLK_SHIFT_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata(2 downto 0)  <= mp_ctrl_clk_slow_shift;
            o_reg_rdata(31 downto 3) <= (others => '0');
        end if;

                    if ( regaddr = MP_CTRL_TESTRAM_WDATA_REGISTER_W and i_reg_we = '1' ) then
            o_testram_wdata <= i_reg_wdata;
        end if;

        if ( regaddr = MP_CTRL_SIN_INVERT_REGISTER_W and i_reg_we = '1' ) then
            mp_ctrl_sin_invert   <= i_reg_wdata(0);
        end if;
        if ( regaddr = MP_CTRL_SIN_INVERT_REGISTER_W and i_reg_re = '1' ) then
            o_reg_rdata(0)           <= mp_ctrl_sin_invert;
            o_reg_rdata(31 downto 1) <= (others => '0');
        end if;

            -- (MM):
            -- we have g_CHIPS_PER_SPI*g_N_SPI mupix chips connected to this FEB
            -- These registers are intended to send direct commands to these chips
            -- every command is a 64 bit word, our slowcontrol operates on 32-bit words
            -- --> we need 2 slowcontrol words for a command to a mupix
            -- --> g_CHIPS_PER_SPI*g_N_SPI*2 registers which we loop here:
            loopextcmd: for I in 0 to g_CHIPS_PER_SPI*g_N_SPI*2-1 loop
            if ( regaddr = MP_CTRL_EXT_CMD_START_REGISTER_W+I and i_reg_we = '1' ) then
                -- we have a write signal to reg with addr MP_CTRL_EXT_CMD_START_REGISTER_W+I
                -- o_mp_ctrl_external_cmd is the command to the mupix
                --                    (I/2):because we need 2 addr's for each command,
                --                          so the chip that we are talking to at addr MP_CTRL_EXT_CMD_START_REGISTER_W+I
                --                          is chip I/2
                --                                  (I mod 2): so we write into both parts of the command reg
                o_mp_ctrl_external_cmd(I/2).command((I mod 2)*32+31 downto (I mod 2)* 32) <= i_reg_wdata;
                -- now the command was written
                -- only if the 2nd part of the command was just written we want to trigger sending it
                if((I mod 2) = 1) then
                --                        (I/2): reason for I/2 same as above
                --                                         not: following logic will detect changes on
                --                                              the "trigger" signal and send the command
                --                                              whenever that happens
                    o_mp_ctrl_external_cmd(I/2).trigger <= not o_mp_ctrl_external_cmd(I/2).trigger;
                end if;
            end if;
            end loop;
    end if;
    end process;

end architecture;
