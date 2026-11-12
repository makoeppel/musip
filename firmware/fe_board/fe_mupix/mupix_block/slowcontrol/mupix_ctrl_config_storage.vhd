----------------------------------------------------------------------------
-- storage logic of MP configuration
-- M. Mueller
-- Feb 2022

-- everything related to storing mupix configuration on the FEB
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

use work.mupix_registers.all;
use work.mupix.all;
use work.mudaq.all;


entity mupix_ctrl_config_storage is
generic (
    g_CHIPS : positive := 4;
    g_IS_MUPIX10 : boolean  := false--;
);
port (
    i_chip_cvb          : in    std_logic_vector(g_CHIPS-1 downto 0);   -- used for conf, vdac, bias and combined, 1 hot encoding
    i_chip_tdac         : in    integer range 0 to g_CHIPS-1;           -- used for TDACs (will stay like this if i dont implement a way to write equal TDACs in parallel)

    i_conf_reg_data     : in    reg32;
    i_conf_reg_we       : in    std_logic;
    i_vdac_reg_data     : in    reg32;
    i_vdac_reg_we       : in    std_logic;
    i_bias_reg_data     : in    reg32;
    i_bias_reg_we       : in    std_logic;

    i_combined_data     : in    reg32;
    i_combined_data_we  : in    std_logic;

    i_tdac_data         : in    reg32;
    i_tdac_we           : in    std_logic;

    o_data              : out   mp_conf_array_out(g_CHIPS-1 downto 0);
    i_read              : in    mp_conf_array_in(g_CHIPS-1 downto 0);

    o_testram_rdata     : out   reg32;
    i_testram_raddr     : in    reg32;
    i_testram_waddr     : in    reg32;
    i_testram_wdata     : in    reg32;

    o_n_free_pages      : out   std_logic_vector(31 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture RTL of mupix_ctrl_config_storage is

    signal conf_dpf_full : std_logic_vector(g_CHIPS-1 downto 0);
    signal vdac_dpf_full : std_logic_vector(g_CHIPS-1 downto 0);
    signal bias_dpf_full : std_logic_vector(g_CHIPS-1 downto 0);
    signal tdac_dpf_full : std_logic_vector(g_CHIPS-1 downto 0);

    signal conf_dpf_empty : std_logic_vector(g_CHIPS-1 downto 0);
    signal vdac_dpf_empty : std_logic_vector(g_CHIPS-1 downto 0);
    signal bias_dpf_empty : std_logic_vector(g_CHIPS-1 downto 0);
    signal tdac_dpf_empty : std_logic_vector(g_CHIPS-1 downto 0);

    signal conf_rdy : std_logic_vector(g_CHIPS-1 downto 0);
    signal vdac_rdy : std_logic_vector(g_CHIPS-1 downto 0);
    signal bias_rdy : std_logic_vector(g_CHIPS-1 downto 0);
    signal tdac_rdy : std_logic_vector(g_CHIPS-1 downto 0);

    signal conf_dpf_we : std_logic_vector(g_CHIPS-1 downto 0);
    signal vdac_dpf_we : std_logic_vector(g_CHIPS-1 downto 0);
    signal bias_dpf_we : std_logic_vector(g_CHIPS-1 downto 0);
    signal tdac_dpf_we : std_logic_vector(g_CHIPS-1 downto 0);

    signal conf_dpf_wdata : reg32array(g_CHIPS-1 downto 0);
    signal vdac_dpf_wdata : reg32array(g_CHIPS-1 downto 0);
    signal bias_dpf_wdata : reg32array(g_CHIPS-1 downto 0);
    signal tdac_dpf_wdata : std_logic_vector(3 downto 0);

    signal conf_dpf_we_splitter : std_logic_vector(g_CHIPS-1 downto 0);
    signal vdac_dpf_we_splitter : std_logic_vector(g_CHIPS-1 downto 0);
    signal bias_dpf_we_splitter : std_logic_vector(g_CHIPS-1 downto 0);

    signal conf_dpf_wdata_splitter : reg32array(g_CHIPS-1 downto 0);
    signal vdac_dpf_wdata_splitter : reg32array(g_CHIPS-1 downto 0);
    signal bias_dpf_wdata_splitter : reg32array(g_CHIPS-1 downto 0);

begin

    mp_conf_splitter: entity work.mp_conf_splitter
    generic map (
        g_CHIPS => g_CHIPS--,
    )
    port map (
        i_data              => i_combined_data,
        i_data_we           => i_combined_data_we,
        i_chip_cvb          => i_chip_cvb,

        o_conf_dpf_we       => conf_dpf_we_splitter,
        o_vdac_dpf_we       => vdac_dpf_we_splitter,
        o_bias_dpf_we       => bias_dpf_we_splitter,
        o_conf_dpf_wdata    => conf_dpf_wdata_splitter,
        o_vdac_dpf_wdata    => vdac_dpf_wdata_splitter,
        o_bias_dpf_wdata    => bias_dpf_wdata_splitter,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );


    gen_dp_fifos: for I in 0 to g_CHIPS-1 generate

        o_data(I).rdy <= (
            TDAC_BIT => tdac_rdy(I),
            BIAS_BIT => bias_rdy(I),
            VDAC_BIT => vdac_rdy(I),
            CONF_BIT => conf_rdy(I)
        );

        process(i_clk, i_reset_n) is
        begin
        if ( i_reset_n = '0' ) then
            tdac_rdy(I) <= '0';
            bias_rdy(I) <= '0';
            vdac_rdy(I) <= '0';
            conf_rdy(I) <= '0';
        elsif rising_edge(i_clk) then
            -- data is ready when dpf becomes full and stays ready until its empty
            if(tdac_dpf_full(I) = '1') then
                tdac_rdy(I) <= '1';
            elsif(tdac_dpf_empty(I) = '1') then
                tdac_rdy(I) <= '0';
            end if;

            if(conf_dpf_full(I) = '1') then
                conf_rdy(I) <= '1';
            elsif(conf_dpf_empty(I) = '1') then
                conf_rdy(I) <= '0';
            end if;

            if(bias_dpf_full(I) = '1' and conf_rdy(I)='1' and vdac_rdy(I)='1') then  -- mupix 10 bug, remove for mupix 11
                bias_rdy(I) <= '1';
            elsif(bias_dpf_empty(I) = '1') then
                bias_rdy(I) <= '0';
            end if;

            if(vdac_dpf_full(I) = '1') then
                vdac_rdy(I) <= '1';
            elsif(vdac_dpf_empty(I) = '1') then
                vdac_rdy(I) <= '0';
            end if;
        end if;
        end process;

        conf_dpf_we(I) <= (i_conf_reg_we and i_chip_cvb(I)) or conf_dpf_we_splitter(I);
        vdac_dpf_we(I) <= (i_vdac_reg_we and i_chip_cvb(I)) or vdac_dpf_we_splitter(I);
        bias_dpf_we(I) <= (i_bias_reg_we and i_chip_cvb(I)) or bias_dpf_we_splitter(I);

        -- have to turn the bit order around since bit 31 of each word needs to be the first bit to go into the mupix
        gen_invert_bit_order: for J in 0 to 31 generate
            conf_dpf_wdata(I)(31-J) <= conf_dpf_wdata_splitter(I)(J) when conf_dpf_we_splitter(I)='1' else i_conf_reg_data(J);
            vdac_dpf_wdata(I)(31-J) <= vdac_dpf_wdata_splitter(I)(J) when vdac_dpf_we_splitter(I)='1' else i_vdac_reg_data(J);
            bias_dpf_wdata(I)(31-J) <= bias_dpf_wdata_splitter(I)(J) when bias_dpf_we_splitter(I)='1' else i_bias_reg_data(J);
        end generate;

        conf: entity work.tdac_dp_fifo
        generic map (
            g_BITS          => MP_CONFIG_REGS_LENGTH(CONF_BIT),
            g_WDATA_WIDTH   => 32,
            g_RDATA1_WIDTH  => 1,
            g_RDATA2_WIDTH  => 54,
            g_TYPE          => "CONF"--,
        )
        port map (
            o_full      => conf_dpf_full(I),
            o_empty     => conf_dpf_empty(I),
            i_we        => conf_dpf_we(I),
            i_wdata     => conf_dpf_wdata(I),
            i_re1       => i_read(I).spi_read(CONF_BIT),
            o_rdata1    => o_data(I).spi_data(CONF_BIT downto CONF_BIT),
            i_re2       => i_read(I).mu3e_read(CONF_BIT),
            o_rdata2    => o_data(I).conf,
            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

        vdac: entity work.tdac_dp_fifo
        generic map (
            g_BITS          => MP_CONFIG_REGS_LENGTH(VDAC_BIT),
            g_WDATA_WIDTH   => 32,
            g_RDATA1_WIDTH  => 1,
            g_RDATA2_WIDTH  => 54,
            g_TYPE          => "VDAC"--,
        )
        port map (
            o_full      => vdac_dpf_full(I),
            o_empty     => vdac_dpf_empty(I),
            i_we        => vdac_dpf_we(I),
            i_wdata     => vdac_dpf_wdata(I),
            i_re1       => i_read(I).spi_read(VDAC_BIT),
            o_rdata1    => o_data(I).spi_data(VDAC_BIT downto VDAC_BIT),
            i_re2       => i_read(I).mu3e_read(VDAC_BIT),
            o_rdata2    => o_data(I).vdac,
            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

        bias: entity work.tdac_dp_fifo
        generic map (
            g_BITS          => MP_CONFIG_REGS_LENGTH(BIAS_BIT),
            g_WDATA_WIDTH   => 32,
            g_RDATA1_WIDTH  => 1,
            g_RDATA2_WIDTH  => 54,
            g_TYPE          => "BIAS"--,
        )
        port map (
            o_full      => bias_dpf_full(I),
            o_empty     => bias_dpf_empty(I),
            i_we        => bias_dpf_we(I),
            i_wdata     => bias_dpf_wdata(I),
            i_re1       => i_read(I).spi_read(BIAS_BIT),
            o_rdata1    => o_data(I).spi_data(BIAS_BIT downto BIAS_BIT),
            i_re2       => i_read(I).mu3e_read(BIAS_BIT),
            o_rdata2    => o_data(I).bias,
            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

        tdac: entity work.tdac_dp_fifo
        generic map (
            g_BITS          => MP_CONFIG_REGS_LENGTH(5),
            g_WDATA_WIDTH   => 4,
            g_RDATA1_WIDTH  => 1,
            g_RDATA2_WIDTH  => 54,
            g_IS_TDAC_DPF   => true,
            g_IS_MUPIX10    => g_IS_MUPIX10,
            g_TYPE          => "TDAC"--,
        )
        port map (
            o_full      => tdac_dpf_full(I),
            o_empty     => tdac_dpf_empty(I),
            i_we        => tdac_dpf_we(I),
            i_wdata     => tdac_dpf_wdata,
            i_re1       => i_read(I).spi_read(TDAC_BIT),
            o_rdata1    => o_data(I).spi_data(TDAC_BIT downto TDAC_BIT),
            i_re2       => i_read(I).mu3e_read(TDAC_BIT),
            o_rdata2    => o_data(I).tdac,
            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

    end generate;

    tdac_memory : entity work.tdac_memory
    generic map (
        g_CHIPS => g_CHIPS--,
    )
    port map (
        o_tdac_dpf_we       => tdac_dpf_we,
        o_tdac_dpf_wdata    => tdac_dpf_wdata,
        i_tdac_dpf_empty    => tdac_dpf_empty,

        o_testram_rdata     => o_testram_rdata,
        i_testram_raddr     => i_testram_raddr,
        i_testram_waddr     => i_testram_waddr,
        i_testram_wdata     => i_testram_wdata,

        i_data              => i_tdac_data,
        i_we                => i_tdac_we,
        i_chip              => i_chip_tdac,
        o_n_free_pages      => o_n_free_pages,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );

end architecture;
