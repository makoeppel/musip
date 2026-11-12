library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mupix_ctrl_tb is
end entity;

architecture rtl of mupix_ctrl_tb is

    constant CLK_MHZ        : positive := 125;
    constant CLK_MHZ2       : real := 125.0;

    signal clk, reset_n     : std_logic := '0';
    signal clk_slow         : std_logic := '0';
    signal reset            : std_logic;
    signal first_reset      : std_logic;
    signal first_reset_n    : std_logic;

    signal counter_int      : unsigned(31 downto 0);

    signal reg_addr         : std_logic_vector(15 downto 0);
    signal reg_re           : std_logic;
    signal reg_rdata        : std_logic_vector(31 downto 0);
    signal reg_we           : std_logic;
    signal reg_wdata        : std_logic_vector(31 downto 0);

    signal clock            : std_logic_vector( 3 downto 0);
    signal SIN              : std_logic_vector( 3 downto 0);
    signal mosi             : std_logic_vector( 3 downto 0);
    signal cs               : std_logic_vector(11 downto 0);


    --from matrix - part A
    signal PriFromDet_PartA :  std_logic;
    signal RowAddFromDet_PartA :  std_logic_vector(8 downto 0);
    signal ColAddFromDet_PartA :  std_logic_vector(6 downto 0);
    signal TSFromDet_PartA :  std_logic_vector(15 downto 0);
    --from matrix - part B
    signal PriFromDet_PartB :  std_logic;
    signal RowAddFromDet_PartB :  std_logic_vector(8 downto 0);
    signal ColAddFromDet_PartB :  std_logic_vector(6 downto 0);
    signal TSFromDet_PartB :  std_logic_vector(15 downto 0);
    --from matrix - part C
    signal PriFromDet_PartC :  std_logic;
    signal RowAddFromDet_PartC :  std_logic_vector(8 downto 0);
    signal ColAddFromDet_PartC :  std_logic_vector(6 downto 0);
    signal TSFromDet_PartC :  std_logic_vector(15 downto 0);
    --to matrix
    signal TSToDet :  std_logic_vector(10 downto 0);
    signal TSToDet2 :  std_logic_vector(4 downto 0);
    -- to matrix - part A
    signal LdCol_PartA :  std_logic;
    signal RdCol_PartA :  std_logic;
    signal LdPix_PartA :  std_logic;
    signal PullDN_PartA :  std_logic;
    -- to matrix - part B
    signal LdCol_PartB :  std_logic;
    signal RdCol_PartB :  std_logic;
    signal LdPix_PartB :  std_logic;
    signal PullDN_PartB :  std_logic;
    -- to matrix - part C
    signal LdCol_PartC :  std_logic;
    signal RdCol_PartC :  std_logic;
    signal LdPix_PartC :  std_logic;
    signal PullDN_PartC :  std_logic;

    --sm control
    signal Aur_res_n :  std_logic;
    signal Ser_res_n :  std_logic;
    signal RO_res_n :  std_logic;

    signal sync_reset_Ext :  std_logic;--syncRes;
    --ser out - four links
    signal d_out_A :  std_logic_vector(1 downto 0);
    signal d_out_B :  std_logic_vector(1 downto 0);
    signal d_out_C :  std_logic_vector(1 downto 0);
    signal d_out_D :  std_logic_vector(1 downto 0);
    --clk in
    signal clk_800p:  std_logic;
    --clk out
    signal clk_8n :  std_logic;
    --debug
    signal Cnt4 :  std_logic_vector(1 downto 0);
    signal Cnt5 :  std_logic_vector(2 downto 0);
    signal clkOut_4n :  std_logic;
    -- clock
    signal clkIn_4n :  std_logic;

    --SlowControl

    --Enable Multiplexing
    signal EnSC :  std_logic;--

    signal ref_clock :  std_logic;--
    signal slow_clock_div:  std_logic_vector(3 downto 0);--
    signal Serial_In :  std_logic;--
    signal Chip_Address:  std_logic_vector(3 downto 0);--
    signal ResetSCB:  std_logic;--
    signal Bias_Back_In:  std_logic;
    signal VDAC_Back_In:  std_logic;
    signal Col_Back_In:  std_logic;
    signal Test_Back_In:  std_logic;
    signal TDAC_Back_In:  std_logic;
    signal ADC_CompIn:  std_logic;
    signal sync_reset_SC :  std_logic;
    signal ResetBiasBlocksB :  std_logic;--ivan changed to B
    signal SIn_Ext :  std_logic;
    signal Ck1_Ext :  std_logic;
    signal Ck2_Ext :  std_logic;
    signal Readback_Ext :  std_logic;
    signal Load_BiasExt :  std_logic;
    signal Load_ConfExt :  std_logic;
    signal Load_VDACExt :  std_logic;
    signal Load_ColExt :  std_logic;
    signal Load_TestExt :  std_logic;
    signal Load_TDACExt :  std_logic;
    signal SIn_Bias :  std_logic;
    signal Load_Bias :  std_logic;
    signal Ck1_Bias :  std_logic;
    signal Ck2_Bias :  std_logic;
    signal SIn_VDAC :  std_logic;
    signal Load_VDAC :  std_logic;
    signal Ck1_VDAC :  std_logic;
    signal Ck2_VDAC :  std_logic;
    signal SIn_Col :  std_logic;
    signal Load_Col :  std_logic;
    signal Ck1_Col :  std_logic;
    signal Ck2_Col :  std_logic;
    signal SIn_Test :  std_logic;
    signal Load_Test :  std_logic;
    signal Ck1_Test :  std_logic;
    signal Ck2_Test :  std_logic;
    signal SIn_TDAC :  std_logic;
    signal Load_TDAC :  std_logic;
    signal Ck1_TDAC :  std_logic;
    signal Ck2_TDAC :  std_logic;
    signal Readback :  std_logic;
    signal PCH_Ext :  std_logic;
    signal WrEn_Ext :  std_logic;
    signal WR_Ext :  std_logic;
    signal Injection_Ext :  std_logic;
    signal PCH :  std_logic;
    signal WrEnable :  std_logic;
    signal WR :  std_logic;
    signal Injection :  std_logic;
    signal SOutSC :  std_logic; --output of the data reveiver register
    signal slow_clockSC :  std_logic;
    signal ADC_VDAC :  std_logic_vector(9 downto 0);
    signal ADC_Mux :  std_logic_vector(4 downto 0);
    signal ResetConfigB :  std_logic;--reset of config reg
    signal QConfigOut :  std_logic_vector(39 downto 0);
    signal QBConfigOut :  std_logic_vector(39 downto 0);
    signal MISO :  std_logic;
    signal SCK :  std_logic;
    signal CSB :  std_logic;
    signal UseSPI :  std_logic;
    signal UseSPIRO :  std_logic;
    signal clk_ts_out :  std_logic;
    signal clk_ts_in :  std_logic;

    component MuPixDigitalTop is
    port (
        --from matrix - part A
        PriFromDet_PartA : in std_logic;
        RowAddFromDet_PartA : in std_logic_vector(8 downto 0);
        ColAddFromDet_PartA : in std_logic_vector(6 downto 0);
        TSFromDet_PartA : in std_logic_vector(15 downto 0);
        --from matrix - part B
        PriFromDet_PartB : in std_logic;
        RowAddFromDet_PartB : in std_logic_vector(8 downto 0);
        ColAddFromDet_PartB : in std_logic_vector(6 downto 0);
        TSFromDet_PartB : in std_logic_vector(15 downto 0);
        --from matrix - part C
        PriFromDet_PartC : in std_logic;
        RowAddFromDet_PartC : in std_logic_vector(8 downto 0);
        ColAddFromDet_PartC : in std_logic_vector(6 downto 0);
        TSFromDet_PartC : in std_logic_vector(15 downto 0);
        --to matrix
        TSToDet : out std_logic_vector(10 downto 0);
        TSToDet2 : out std_logic_vector(4 downto 0);
        -- to matrix - part A
        LdCol_PartA : out std_logic;
        RdCol_PartA : out std_logic;
        LdPix_PartA : out std_logic;
        PullDN_PartA : out std_logic;
        -- to matrix - part B
        LdCol_PartB : out std_logic;
        RdCol_PartB : out std_logic;
        LdPix_PartB : out std_logic;
        PullDN_PartB : out std_logic;
        -- to matrix - part C
        LdCol_PartC : out std_logic;
        RdCol_PartC : out std_logic;
        LdPix_PartC : out std_logic;
        PullDN_PartC : out std_logic;

        --sm control
        Aur_res_n : in std_logic;
        Ser_res_n : in std_logic;
        RO_res_n : in std_logic;

        sync_reset_Ext : in std_logic;--syncRes;
        --ser out - four links
        d_out_A : out std_logic_vector(1 downto 0);
        d_out_B : out std_logic_vector(1 downto 0);
        d_out_C : out std_logic_vector(1 downto 0);
        d_out_D : out std_logic_vector(1 downto 0);
        --clk in
        clk_800p: in std_logic;
        --clk out
        clk_8n : out std_logic;
        --debug
        Cnt4 : out std_logic_vector(1 downto 0);
        Cnt5 : out std_logic_vector(2 downto 0);
        clkOut_4n : out std_logic;
        -- clock
        clkIn_4n : in std_logic;

        --SlowControl

        --Enable Multiplexing
        EnSC : in std_logic;--

        ref_clock : in std_logic;--
        slow_clock_div: in std_logic_vector(3 downto 0);--
        Serial_In : in std_logic;--
        Chip_Address: in std_logic_vector(3 downto 0);--
        ResetSCB: in std_logic;--


        Bias_Back_In: in std_logic;
        VDAC_Back_In: in std_logic;
        Col_Back_In: in std_logic;
        Test_Back_In: in std_logic;
        TDAC_Back_In: in std_logic;
        ADC_CompIn: in std_logic;

        sync_reset_SC : out std_logic;
        ResetBiasBlocksB : out std_logic;--ivan changed to B

        SIn_Ext : in std_logic;
        Ck1_Ext : in std_logic;
        Ck2_Ext : in std_logic;
        Readback_Ext : in std_logic;
        Load_BiasExt : in std_logic;
        Load_ConfExt : in std_logic;
        Load_VDACExt : in std_logic;
        Load_ColExt : in std_logic;
        Load_TestExt : in std_logic;
        Load_TDACExt : in std_logic;

        SIn_Bias : out std_logic;
        Load_Bias : out std_logic;
        Ck1_Bias : out std_logic;
        Ck2_Bias : out std_logic;
        SIn_VDAC : out std_logic;
        Load_VDAC : out std_logic;
        Ck1_VDAC : out std_logic;
        Ck2_VDAC : out std_logic;
        SIn_Col : out std_logic;
        Load_Col : out std_logic;
        Ck1_Col : out std_logic;
        Ck2_Col : out std_logic;
        SIn_Test : out std_logic;
        Load_Test : out std_logic;
        Ck1_Test : out std_logic;
        Ck2_Test : out std_logic;
        SIn_TDAC : out std_logic;
        Load_TDAC : out std_logic;
        Ck1_TDAC : out std_logic;
        Ck2_TDAC : out std_logic;
        Readback : out std_logic;

        --/
        PCH_Ext : in std_logic;
        WrEn_Ext : in std_logic;
        WR_Ext : in std_logic;
        Injection_Ext : in std_logic;

        PCH : out std_logic;
        WrEnable : out std_logic;
        WR : out std_logic;
        Injection : out std_logic;

        SOutSC : out std_logic; --output of the data reveiver register
        slow_clockSC : out std_logic;

        --ADC
        ADC_VDAC : out std_logic_vector(9 downto 0);
        ADC_Mux : out std_logic_vector(4 downto 0);

        ResetConfigB : in std_logic;--reset of config reg
        QConfigOut : out std_logic_vector(39 downto 0);
        QBConfigOut : out std_logic_vector(39 downto 0);

        --SPI
        MOSI : in std_logic;
        MISO : out std_logic;
        SCK : in std_logic;
        CSB : in std_logic;
        UseSPI : in std_logic;
        UseSPIRO : in std_logic;

        clk_ts_out : out std_logic;
        clk_ts_in : in std_logic--;
    );
    end component;

begin

    clk <= not clk after (500 ns / CLK_MHZ);
    clk_slow <= not clk_slow after (500 ns / CLK_MHZ2);
    first_reset <= '1', '0' after 40 ns;
    first_reset_n <= not first_reset;
    reset_n <= '0', '1' after 6000 ns;
    reset <= not reset_n;
    CSB <= cs(0);

    e_mp_ctrl : entity work.mupix_ctrl
    port map (
        i_reg_addr          => reg_addr,
        i_reg_re            => reg_re,
        o_reg_rdata         => reg_rdata,
        i_reg_we            => reg_we,
        i_reg_wdata         => reg_wdata,

        o_clock             => clock,
        o_SIN               => SIN,
        o_mosi              => mosi,
        o_cs                => cs,

        i_clk_125           => clk_slow,
        i_reset_n           => reset_n,
        i_clk               => clk--,
    );

    process
    begin
        counter_int <= (others => '0');
        reg_addr    <= (others => '0');
        reg_re      <= '0';
        reg_we      <= '0';
        reg_wdata   <= (others => '0');

        wait until ( reset_n = '1' );

        for i in 0 to 80000 loop
            wait until rising_edge(clk);
            counter_int <= counter_int + 1;
        end loop;
        wait;
    end process;

    Serial_In <= SIN(0);
    ref_clock <= clk;

    mupixdigitaltop_inst: MuPixDigitalTop
    port map (
        PriFromDet_PartA    => PriFromDet_PartA,
        RowAddFromDet_PartA => RowAddFromDet_PartA,
        ColAddFromDet_PartA => ColAddFromDet_PartA,
        TSFromDet_PartA     => TSFromDet_PartA,
        PriFromDet_PartB    => PriFromDet_PartB,
        RowAddFromDet_PartB => RowAddFromDet_PartB,
        ColAddFromDet_PartB => ColAddFromDet_PartB,
        TSFromDet_PartB     => TSFromDet_PartB,
        PriFromDet_PartC    => PriFromDet_PartC,
        RowAddFromDet_PartC => RowAddFromDet_PartC,
        ColAddFromDet_PartC => ColAddFromDet_PartC,
        TSFromDet_PartC     => TSFromDet_PartC,
        TSToDet             => TSToDet,
        TSToDet2            => TSToDet2,
        LdCol_PartA         => LdCol_PartA,
        RdCol_PartA         => RdCol_PartA,
        LdPix_PartA         => LdPix_PartA,
        PullDN_PartA        => PullDN_PartA,
        LdCol_PartB         => LdCol_PartB,
        RdCol_PartB         => RdCol_PartB,
        LdPix_PartB         => LdPix_PartB,
        PullDN_PartB        => PullDN_PartB,
        LdCol_PartC         => LdCol_PartC,
        RdCol_PartC         => RdCol_PartC,
        LdPix_PartC         => LdPix_PartC,
        PullDN_PartC        => PullDN_PartC,
        Aur_res_n           => Aur_res_n,
        Ser_res_n           => Ser_res_n,
        RO_res_n            => RO_res_n,
        sync_reset_Ext      => sync_reset_Ext,
        d_out_A             => d_out_A,
        d_out_B             => d_out_B,
        d_out_C             => d_out_C,
        d_out_D             => d_out_D,
        clk_800p            => clk_800p,
        clk_8n              => clk_8n,
        Cnt4                => Cnt4,
        Cnt5                => Cnt5,
        clkOut_4n           => clkOut_4n,
        clkIn_4n            => clkIn_4n,
        EnSC                => EnSC,
        ref_clock           => ref_clock,
        slow_clock_div      => "0011",
        Serial_In           => Serial_In,
        Chip_Address        => "0001",
        ResetSCB            => first_reset_n,
        Bias_Back_In        => '0',
        VDAC_Back_In        => '0',
        Col_Back_In         => '0',
        Test_Back_In        => '0',
        TDAC_Back_In        => '0',
        ADC_CompIn          => ADC_CompIn,
        sync_reset_SC       => sync_reset_SC,
        ResetBiasBlocksB    => ResetBiasBlocksB,
        SIn_Ext             => SIn_Ext,
        Ck1_Ext             => Ck1_Ext,
        Ck2_Ext             => Ck2_Ext,
        Readback_Ext        => Readback_Ext,
        Load_BiasExt        => Load_BiasExt,
        Load_ConfExt        => Load_ConfExt,
        Load_VDACExt        => Load_VDACExt,
        Load_ColExt         => Load_ColExt,
        Load_TestExt        => Load_TestExt,
        Load_TDACExt        => Load_TDACExt,
        SIn_Bias            => SIn_Bias,
        Load_Bias           => Load_Bias,
        Ck1_Bias            => Ck1_Bias,
        Ck2_Bias            => Ck2_Bias,
        SIn_VDAC            => SIn_VDAC,
        Load_VDAC           => Load_VDAC,
        Ck1_VDAC            => Ck1_VDAC,
        Ck2_VDAC            => Ck2_VDAC,
        SIn_Col             => SIn_Col,
        Load_Col            => Load_Col,
        Ck1_Col             => Ck1_Col,
        Ck2_Col             => Ck2_Col,
        SIn_Test            => SIn_Test,
        Load_Test           => Load_Test,
        Ck1_Test            => Ck1_Test,
        Ck2_Test            => Ck2_Test,
        SIn_TDAC            => SIn_TDAC,
        Load_TDAC           => Load_TDAC,
        Ck1_TDAC            => Ck1_TDAC,
        Ck2_TDAC            => Ck2_TDAC,
        Readback            => Readback,
        PCH_Ext             => PCH_Ext,
        WrEn_Ext            => WrEn_Ext,
        WR_Ext              => WR_Ext,
        Injection_Ext       => Injection_Ext,
        PCH                 => PCH,
        WrEnable            => WrEnable,
        WR                  => WR,
        Injection           => Injection,
        SOutSC              => SOutSC,
        slow_clockSC        => slow_clockSC,
        ADC_VDAC            => ADC_VDAC,
        ADC_Mux             => ADC_Mux,
        ResetConfigB        => ResetConfigB,
        QConfigOut          => QConfigOut,
        QBConfigOut         => QBConfigOut,
        MOSI                => MOSI(0),
        MISO                => MISO,
        SCK                 => clock(0),
        CSB                 => CSB,
        UseSPI              => UseSPI,
        UseSPIRO            => UseSPIRO,
        clk_ts_out          => clk_ts_out,
        clk_ts_in           => clk_ts_in
    );

end architecture;
