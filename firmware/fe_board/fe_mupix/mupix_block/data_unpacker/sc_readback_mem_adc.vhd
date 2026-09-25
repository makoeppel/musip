-------------------------------------------------------------
--
-- Place to organize storage of adc measurements, readback of config and error signals
--
-- M. Mueller, Nov 2023
--------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;
use work.mupix.all;
use work.mupix_registers.all;

entity sc_readback_mem_adc is
generic(
    g_CHIPS : positive := 1--;
);
port (
    -- clk_125
    i_slowctrl_data64       : in    reg64array(g_CHIPS-1 downto 0);
    i_slowctrl_data64_ena   : in    std_logic_vector(g_CHIPS-1 downto 0);
    i_clk_125               : in    std_logic;

    io_readback_mems_reg    : inout work.util.rw_t;

    i_reset_156_n           : in    std_logic;
    i_clk_156               : in    std_logic--;
);
end entity;

architecture RTL of sc_readback_mem_adc is

    -- [MM] use 64 element arrays to avoid `raddr < g_CHIPS` check
    signal fifo_rack  : std_logic_vector(63 downto 0) := (others => '0');
    signal fifo_rdata : reg32array(63 downto 0) := (others => X"CCCCCCCC");
    
    constant NADC : integer := 13;

    subtype adc_val is std_logic_vector(7 downto 0);
    type adc_val_array_t is array (NADC-1 downto 0) of adc_val;
    type chip_adc_val_array_t is array (g_CHIPS-1 downto 0)  of adc_val_array_t;

    signal adcs : chip_adc_val_array_t;
    signal adcs156 : chip_adc_val_array_t;

    signal slowctrl_data64_ena_last: std_logic_vector(g_CHIPS-1 downto 0);
    signal slowctrl_data64_ena_last_last: std_logic_vector(g_CHIPS-1 downto 0);
    
begin

    assert ( true
        and ( g_CHIPS <= 64 )
    ) severity failure;


    process(i_clk_125)
    begin
    if rising_edge(i_clk_125) then
       for i in g_CHIPS-1 downto 0 loop
            if (i_slowctrl_data64_ena(i) = '1') then
                if(i_slowctrl_data64(i)(63 downto 60) = "1100") then -- ADC flag
                    if(to_integer(unsigned(i_slowctrl_data64(i)(14 downto 10))) < 13) then -- The ADC cycles through 32 possible measurements, but only 13 make sense
                        adcs(i)(to_integer(unsigned(i_slowctrl_data64(i)(13 downto 10)))) <= i_slowctrl_data64(i)(9 downto 2);
                    end if;
                end if;
            end if;
       end loop;
    end if;
    end process;

    process(i_clk_156, i_reset_156_n)
        variable regaddr : integer;
        variable regaddr_low : integer range 0 to 3; 
        variable regaddr_hi : integer range 0 to g_CHIPS; 
    begin
    if ( i_reset_156_n = '0' ) then
        io_readback_mems_reg.rdata <= X"CCCCCCCC";
        --
    elsif rising_edge(i_clk_156) then

        slowctrl_data64_ena_last <= i_slowctrl_data64_ena;
        slowctrl_data64_ena_last_last <= slowctrl_data64_ena_last;

        for i in g_CHIPS-1 downto 0 loop
            if (slowctrl_data64_ena_last(i) = '0' and slowctrl_data64_ena_last_last(i) = '1') then
                adcs156(i) <= adcs(i);
            end if;
        end loop;

        io_readback_mems_reg.rdata  <= X"CCCCCCCC";
        --regaddr                     := to_integer(unsigned(io_readback_mems_reg.addr)) - work.mupix_registers.MP_READBACK_MEMS_START_REGISTER_R;
        -- Assume lower 8 bits of  work.mupix_registers.MP_READBACK_MEMS_START_REGISTER_R are 0
        if(io_readback_mems_reg.re = '1') then
            regaddr_low                 := to_integer(unsigned(io_readback_mems_reg.addr(1 downto 0)));
            regaddr_hi                  := to_integer(unsigned(io_readback_mems_reg.addr(7 downto 2)));
            if(regaddr_low = 0) then 
                io_readback_mems_reg.rdata <= adcs156(regaddr_hi)(3) &  adcs156(regaddr_hi)(2) &  adcs156(regaddr_hi)(1) &  adcs156(regaddr_hi)(0);
            end if;
            if(regaddr_low = 1) then 
                io_readback_mems_reg.rdata <= adcs156(regaddr_hi)(7) &  adcs156(regaddr_hi)(6) &  adcs156(regaddr_hi)(5) &  adcs156(regaddr_hi)(4);
            end if;    
            if(regaddr_low = 2) then
                io_readback_mems_reg.rdata <= adcs156(regaddr_hi)(11) &  adcs156(regaddr_hi)(10) &  adcs156(regaddr_hi)(9) &  adcs156(regaddr_hi)(8);
            end if;    
            if(regaddr_low = 3) then
                io_readback_mems_reg.rdata <= X"ADC134" & adcs156(regaddr_hi)(12);
            end if;
        end if;
    end if;
    end process;


 -- Memory for TDAC values:

    -- Address Mux Value
    -- 0 ref_vssa
    -- 1 Baseline
    -- 2 blpix
    -- 3 thpix
    -- 4 blpix
    -- 5 ThLow
    -- 6 ThHigh
    -- 7 TEST OUT
    -- 8 vssa
    -- 9 thpix
    -- 10 VCAL
    -- 11 VTemp1
    -- 12 VTemp2

    -- with Address from i_slowctrl_data(14:10) here:

   -- DataOut[9:0] <= AdcVDAC;
   -- DataOut[14:10] <= MuxAddr[4:0];
   -- DataOut[24:15] <= AdcDiv;
   -- DataOut[28:25] <= AdcMode;
   -- DataOut[59:54] <= AdcMeasurementCnt;
   -- DataOut[63:60] <= ADC_FLAG;

    -- whenever 63:60 of i_slowctrl_data is the ADC_FLAG (1100)

end architecture;
