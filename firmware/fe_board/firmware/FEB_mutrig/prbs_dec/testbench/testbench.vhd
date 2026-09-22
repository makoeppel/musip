--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use ieee.math_real.all; -- for UNIFORM, TRUNC
use ieee.std_logic_textio.all; -- for write std_logic_vector to line
library std;
use std.textio.all; -- FOR LOGFILE WRITING

--library mutrig_sim;
--use mutrig_sim.txt_util.all;
--library modelsim_lib;
--use modelsim_lib.util.all;

use work.mutrig_hit_types.all;

entity testbench is
end entity;

architecture RTL of testbench is

    -- DUT signals --{{{
    type t_stimulus_vec is array (natural range <>) of std_logic_vector(35 downto 0);
    signal s_stimulus : t_stimulus_vec(1 to 278) := (
        X"200000000",
        X"000010000",
        X"000000000",
        X"008000000",
        X"000000001",
        X"008000001",
        X"000000000",
        X"008000002",
        X"000000001",
        X"008000003",
        X"000000000",
        X"008000004",
        X"000000001",
        X"008000005",
        X"000000000",
        X"008000006",
        X"000000001",
        X"008000007",
        X"000000000",
        X"008000008",
        X"000000001",
        X"008000009",
        X"000000000",
        X"00800000A",
        X"000000001",
        X"00800000B",
        X"000000000",
        X"00800000C",
        X"000000001",
        X"00800000D",
        X"000000000",
        X"00800000E",
        X"000000001",
        X"00800000F",
        X"000000000",
        X"008000010",
        X"000000001",
        X"008000011",
        X"000000000",
        X"008000012",
        X"000000001",
        X"008000013",
        X"000000000",
        X"008000014",
        X"000000001",
        X"008000015",
        X"000000000",
        X"008000016",
        X"000000001",
        X"008000017",
        X"000000000",
        X"008000018",
        X"000000001",
        X"008000019",
        X"000000000",
        X"00800001A",
        X"000000001",
        X"00800001B",
        X"000000000",
        X"00800001C",
        X"000000001",
        X"00800001D",
        X"000000000",
        X"00800001E",
        X"000000001",
        X"00800001F",
        X"300000000",
        X"200000000",
        X"000010001",
        X"000000000",
        X"008000020",
        X"000000001",
        X"008000021",
        X"000000000",
        X"008000022",
        X"000000001",
        X"008000023",
        X"200000000",
        X"000010000",
        X"000000000",
        X"008000000",
        X"000000001",
        X"008000001",
        X"000000000",
        X"008000002",
        X"000000001",
        X"008000003",
        X"000000000",
        X"008000004",
        X"000000001",
        X"008000005",
        X"000000000",
        X"008000006",
        X"000000001",
        X"008000007",
        X"000000000",
        X"008000008",
        X"000000001",
        X"008000009",
        X"000000000",
        X"00800000A",
        X"000000001",
        X"00800000B",
        X"000000000",
        X"00800000C",
        X"000000001",
        X"00800000D",
        X"000000000",
        X"00800000E",
        X"000000001",
        X"00800000F",
        X"000000000",
        X"008000010",
        X"000000001",
        X"008000011",
        X"000000000",
        X"008000012",
        X"000000001",
        X"008000013",
        X"000000000",
        X"008000014",
        X"000000001",
        X"008000015",
        X"000000000",
        X"008000016",
        X"000000001",
        X"008000017",
        X"000000000",
        X"008000018",
        X"000000001",
        X"008000019",
        X"000000000",
        X"00800001A",
        X"000000001",
        X"00800001B",
        X"000000000",
        X"00800001C",
        X"000000001",
        X"00800001D",
        X"000000000",
        X"00800001E",
        X"000000001",
        X"00800001F",
        X"300000000",
        X"200000000",
        X"000010001",
        X"000000000",
        X"008000020",
        X"000000001",
        X"008000021",
        X"000000000",
        X"008000022",
        X"000000001",
        X"008000023",
        X"000000000",
        X"008000024",
        X"000000001",
        X"008000025",
        X"000000000",
        X"008000026",
        X"000000001",
        X"008000027",
        X"000000000",
        X"008000028",
        X"000000001",
        X"008000029",
        X"000000000",
        X"00800002A",
        X"000000001",
        X"00800002B",
        X"000000000",
        X"00800002C",
        X"000000001",
        X"00800002D",
        X"000000000",
        X"00800002E",
        X"000000001",
        X"00800002F",
        X"000000000",
        X"008000030",
        X"000000001",
        X"008000031",
        X"000000000",
        X"008000032",
        X"000000001",
        X"008000033",
        X"000000000",
        X"008000034",
        X"000000001",
        X"008000035",
        X"000000000",
        X"008000036",
        X"000000001",
        X"008000037",
        X"000000000",
        X"008000038",
        X"000000001",
        X"008000039",
        X"000000000",
        X"00800003A",
        X"000000001",
        X"00800003B",
        X"000000000",
        X"00800003C",
        X"000000001",
        X"00800003D",
        X"000000000",
        X"00800003E",
        X"000000001",
        X"00800003F",
        X"300000000",
        X"200000000",
        X"000010002",
        X"000000000",
        X"008000040",
        X"000000001",
        X"008000041",
        X"000000000",
        X"008000042",
        X"000000001",
        X"008000043",
        X"000000000",
        X"008000044",
        X"000000001",
        X"008000045",
        X"000000000",
        X"008000046",
        X"000000001",
        X"008000047",
        X"000000000",
        X"008000048",
        X"000000001",
        X"008000049",
        X"000000000",
        X"00800004A",
        X"000000001",
        X"00800004B",
        X"000000000",
        X"00800004C",
        X"000000001",
        X"00800004D",
        X"000000000",
        X"00800004E",
        X"000000001",
        X"00800004F",
        X"000000000",
        X"008000050",
        X"000000001",
        X"008000051",
        X"000000000",
        X"008000052",
        X"000000001",
        X"008000053",
        X"000000000",
        X"008000054",
        X"000000001",
        X"008000055",
        X"000000000",
        X"008000056",
        X"000000001",
        X"008000057",
        X"000000000",
        X"008000058",
        X"000000001",
        X"008000059",
        X"000000000",
        X"00800005A",
        X"000000001",
        X"00800005B",
        X"000000000",
        X"00800005C",
        X"000000001",
        X"00800005D",
        X"000000000",
        X"00800005E",
        X"000000001",
        X"00800005F",
        X"300000000"
    );

    signal i_A_data : t_hit_presort;
    signal i_B_data : t_hit_presort;

    signal o_A_data : t_hit_presort;
    signal o_B_data : t_hit_presort;

    --system signals
    signal i_rst : std_logic:='0';
    signal i_coreclk : std_logic:='0';
    signal o_initializing : std_logic;

begin

    -- basic stimulus for receiver
    i_coreclk <= not i_coreclk after  4 ns; -- 125 MHz system core clock
    i_rst <= '1' after 20 ns, '0' after 200 ns; -- Basic reset

    --dut
    e_dut : entity work.prbs_decoder
    port map (
        i_coreclk => i_coreclk,
        i_rst => i_rst,
        i_A_data    => i_A_data,
        o_A_data    => o_A_data,
        i_B_data    => i_B_data,
        o_B_data    => o_B_data,
        i_SC_disable_dec => '0',
        o_initializing => o_initializing
    );

    i_A_data.channel<="00000";
    i_B_data.channel<="00000";
    i_A_data.T_fine <="00000";
    i_B_data.T_fine <="00000";
    i_A_data.asic<=X"0";
    i_B_data.asic<=X"1";

    stim_A: process
    begin
        i_A_data.T_CC<=std_logic_vector(to_unsigned(0,15));
        i_A_data.E_CC<=std_logic_vector(to_unsigned(0,15));
        i_A_data.valid<='0';

        wait for 1 us;
        wait until falling_edge(o_initializing);
        wait until rising_edge(i_coreclk);
        wait until rising_edge(i_coreclk);
        for i in 1 to 100 loop
            i_A_data.valid<='1';
            i_A_data.E_CC<=std_logic_vector(to_unsigned(i,15));
            i_A_data.T_CC<=s_stimulus(i)(14 downto 0);
            if(s_stimulus(i)(14 downto 0) = (14 downto 0 => '0')) then
                i_A_data.valid<='0';
            end if;
            wait until rising_edge(i_coreclk);
        end loop;
        i_A_data.valid<='0';
        wait for 200 ns;
        assert false report "Simulation Finished." severity FAILURE;
        wait;
    end process;

    stim_B: process
    begin
        i_B_data.T_CC<=std_logic_vector(to_unsigned(0,15));
        i_B_data.E_CC<=std_logic_vector(to_unsigned(0,15));
        i_B_data.valid<='0';

        wait for 1 us;
        wait until falling_edge(o_initializing);
        wait until rising_edge(i_coreclk);
        wait until rising_edge(i_coreclk);
        --wait until rising_edge(i_coreclk);
        --wait until rising_edge(i_coreclk);
        for i in 1 to 100 loop
            i_B_data.valid<='1';
            i_B_data.E_CC<=std_logic_vector(to_unsigned(i,15));
            i_B_data.T_CC<=s_stimulus(i)(14 downto 0);
            if(s_stimulus(i)(14 downto 0) = (14 downto 0 => '0')) then
                i_B_data.valid<='0';
            end if;
            wait until rising_edge(i_coreclk);
        end loop;
        i_B_data.valid<='0';
        wait for 200 ns;
        assert false report "Simulation Finished." severity FAILURE;
        wait;
    end process;

    check: process(i_coreclk)
    begin
        assert o_A_data.valid=o_B_data.valid report "A!=B (valid)" severity FAILURE;
        if(o_A_data.valid='1') then
            assert o_A_data=o_B_data   report "A!=B (data)" severity FAILURE;
        end if;
    end process;

    ---------------------------------------------A side logger --------------------------------------------------------
    ---- prepocess logger
    --fifo_logging_A: process(i_coreclk)
    --file log_file : TEXT open write_mode is "preprocess_A_data.txt";
    --variable l : line;
    --begin
    --if rising_edge(i_rst) then
    --    -- write header
    --    write(l, string'("--------------------------------------------------"));
    --
    --elsif rising_edge(i_coreclk) and ( i_A_valid = '1') then
    --    if(i_A_data(33 downto 32)="10") then
    --        write(log_file,"Frame Header / Payload 1"&
    --            HT & "RAW "& to_hstring(i_A_data) &
    --            LF);
    --            s_A_header_payload_pre<='1';
    --    elsif(i_A_data(33 downto 32)="11") then
    --        write(log_file,"Frame Trailer "&
    --            HT & "RAW "& to_hstring(i_A_data) &
    --            HT & "L2F="& "0x" & to_hstring(i_A_data(1 downto 1)) &
    --            HT & "CRC="& "0x" & to_hstring(i_A_data(0 downto 0)) &
    --            LF);
    --    elsif(i_A_data(33 downto 32)="00") then
    --        if(s_A_header_payload_pre='1') then
    --            write(log_file,"Frame Header / Payload 2"&
    --                HT & "RAW "& to_hstring(i_A_data) &
    --                HT & "TS(LO)="& "0x" & to_hstring(i_A_data(31 downto 16)) &
    --                HT & "FSYN="& "0x" & to_hstring(i_A_data(15 downto 15)) &
    --                HT & "FID ="& "0x" & to_hstring(i_A_data(14 downto 0)) &
    --                LF);
    --            s_A_header_payload_pre<='0';
    --        else
    --            write(log_file,"Hit data");
    --            write(log_file,
    --                HT & " RAW "& to_hstring(i_A_data) &
    --                HT & "ASIC "& natural'image(to_integer(unsigned(i_A_data(31 downto 28)))) &
    --                HT & "TYPE "& natural'image(to_integer(unsigned(i_A_data(27 downto 27)))) &
    --                HT & "  CH "& natural'image(to_integer(unsigned(i_A_data(26 downto 22)))) &
    --                HT & " EBH "& to_hstring(i_A_data(21 downto 21)) &
    --                HT & " ECC "& to_hstring(i_A_data(20 downto  6)) &
    --                HT & " EFC "& to_hstring(i_A_data( 5 downto  1)) &
    --                HT & "EFLG "& to_hstring(i_A_data( 0 downto  0)) &
    --                LF);
    --        end if;
    --    end if;
    --
    --    flush(log_file);
    --end if;
    --end process;
    --
    --
    ---- postpocess logger
    --post_logging_A: process(i_coreclk)
    --file log_file : TEXT open write_mode is "postprocess_data_A.txt";
    --variable l : line;
    --begin
    --if rising_edge(i_rst) then
    --    -- write header
    --    write(l, string'("--------------------------------------------------"));
    --elsif rising_edge(i_coreclk) and ( o_A_valid = '1' ) then
    --    if(o_A_data(33 downto 32)="10") then
    --        write(log_file,"Frame Header / Payload 1"&
    --            HT & "RAW "& to_hstring(o_A_data) &
    --            LF);
    --            s_A_header_payload_post<='1';
    --    elsif(o_A_data(33 downto 32)="11") then
    --        write(log_file,"Frame Trailer "&
    --            HT & "RAW "& to_hstring(o_A_data) &
    --            HT & "L2F="& "0x" & to_hstring(o_A_data(1 downto 1)) &
    --            HT & "CRC="& "0x" & to_hstring(o_A_data(0 downto 0)) &
    --            LF);
    --    elsif(o_A_data(33 downto 32)="00") then
    --        if(s_A_header_payload_post='1') then
    --            write(log_file,"Frame Header / Payload 2"&
    --                HT & "RAW "& to_hstring(o_A_data) &
    --                HT & "TS(LO)="& "0x" & to_hstring(o_A_data(31 downto 16)) &
    --                HT & "FSYN="& "0x" & to_hstring(o_A_data(15 downto 15)) &
    --                HT & "FID ="& "0x" & to_hstring(o_A_data(14 downto 0)) &
    --                LF);
    --            s_A_header_payload_post<='0';
    --        else
    --            write(log_file,"Hit data");
    --            write(log_file,
    --                HT & " RAW "& to_hstring(o_A_data) &
    --                HT & "ASIC "& natural'image(to_integer(unsigned(o_A_data(31 downto 28)))) &
    --                HT & "TYPE "& natural'image(to_integer(unsigned(o_A_data(27 downto 27)))) &
    --                HT & "  CH "& natural'image(to_integer(unsigned(o_A_data(26 downto 22)))) &
    --                HT & " EBH "& to_hstring(o_A_data(21 downto 21)) &
    --                HT & " ECC "& to_hstring(o_A_data(20 downto  6)) &
    --                HT & " EFC "& to_hstring(o_A_data( 5 downto  1)) &
    --                HT & "EFLG "& to_hstring(o_A_data( 0 downto  0)) &
    --                LF);
    --        end if;
    --    end if;
    --
    --    flush(log_file);
    --end if;
    --end process;
    --
    --
    ---------------------------------------------B side logger --------------------------------------------------------
    ---- prepocess logger
    --fifo_logging_B: process(i_coreclk)
    --file log_file : TEXT open write_mode is "preprocess_B_data.txt";
    --variable l : line;
    --begin
    --if rising_edge(i_rst) then
    --    -- write header
    --    write(l, string'("--------------------------------------------------"));
    --elsif rising_edge(i_coreclk) and ( i_B_valid = '1' ) then
    --    if(i_B_data(33 downto 32)="10") then
    --        write(log_file,"Frame Header / Payload 1"&
    --            HT & "RAW "& to_hstring(i_B_data) &
    --            LF);
    --            s_B_header_payload_pre<='1';
    --    elsif(i_B_data(33 downto 32)="11") then
    --        write(log_file,"Frame Trailer "&
    --            HT & "RAW "& to_hstring(i_B_data) &
    --            HT & "L2F="& "0x" & to_hstring(i_B_data(1 downto 1)) &
    --            HT & "CRC="& "0x" & to_hstring(i_B_data(0 downto 0)) &
    --            LF);
    --    elsif(i_B_data(33 downto 32)="00") then
    --        if(s_B_header_payload_pre='1') then
    --            write(log_file,"Frame Header / Payload 2"&
    --                HT & "RAW "& to_hstring(i_B_data) &
    --                HT & "TS(LO)="& "0x" & to_hstring(i_B_data(31 downto 16)) &
    --                HT & "FSYN="& "0x" & to_hstring(i_B_data(15 downto 15)) &
    --                HT & "FID ="& "0x" & to_hstring(i_B_data(14 downto 0)) &
    --                LF);
    --            s_B_header_payload_pre<='0';
    --        else
    --            write(log_file,"Hit data");
    --            write(log_file,
    --                HT & " RAW "& to_hstring(i_B_data) &
    --                HT & "ASIC "& natural'image(to_integer(unsigned(i_B_data(31 downto 28)))) &
    --                HT & "TYPE "& natural'image(to_integer(unsigned(i_B_data(27 downto 27)))) &
    --                HT & "  CH "& natural'image(to_integer(unsigned(i_B_data(26 downto 22)))) &
    --                HT & " EBH "& to_hstring(i_B_data(21 downto 21)) &
    --                HT & " ECC "& to_hstring(i_B_data(20 downto  6)) &
    --                HT & " EFC "& to_hstring(i_B_data( 5 downto  1)) &
    --                HT & "EFLG "& to_hstring(i_B_data( 0 downto  0)) &
    --                LF);
    --        end if;
    --    end if;
    --
    --    flush(log_file);
    --end if;
    --end process;
    --
    --
    --- postpocess logger
    --post_logging_B: process(i_coreclk)
    --file log_file : TEXT open write_mode is "postprocess_data_B.txt";
    --variable l : line;
    --begin
    --if rising_edge(i_rst) then
    --    -- write header
    --    write(l, string'("--------------------------------------------------"));
    --elsif rising_edge(i_coreclk) and ( o_B_valid = '1' ) then
    --    if(o_B_data(33 downto 32)="10") then
    --        write(log_file,"Frame Header / Payload 1"&
    --            HT & "RAW "& to_hstring(o_B_data) &
    --            LF);
    --            s_B_header_payload_post<='1';
    --    elsif(o_B_data(33 downto 32)="11") then
    --        write(log_file,"Frame Trailer "&
    --            HT & "RAW "& to_hstring(o_B_data) &
    --            HT & "L2F="& "0x" & to_hstring(o_B_data(1 downto 1)) &
    --            HT & "CRC="& "0x" & to_hstring(o_B_data(0 downto 0)) &
    --            LF);
    --    elsif(o_B_data(33 downto 32)="00") then
    --        if(s_B_header_payload_post='1') then
    --            write(log_file,"Frame Header / Payload 2"&
    --                HT & "RAW "& to_hstring(o_B_data) &
    --                HT & "TS(LO)="& "0x" & to_hstring(o_B_data(31 downto 16)) &
    --                HT & "FSYN="& "0x" & to_hstring(o_B_data(15 downto 15)) &
    --                HT & "FID ="& "0x" & to_hstring(o_B_data(14 downto 0)) &
    --                LF);
    --            s_B_header_payload_post<='0';
    --        else
    --            write(log_file,"Hit data");
    --            write(log_file,
    --                HT & " RAW "& to_hstring(o_B_data) &
    --                HT & "ASIC "& natural'image(to_integer(unsigned(o_B_data(31 downto 28)))) &
    --                HT & "TYPE "& natural'image(to_integer(unsigned(o_B_data(27 downto 27)))) &
    --                HT & "  CH "& natural'image(to_integer(unsigned(o_B_data(26 downto 22)))) &
    --                HT & " EBH "& to_hstring(o_B_data(21 downto 21)) &
    --                HT & " ECC "& to_hstring(o_B_data(20 downto  6)) &
    --                HT & " EFC "& to_hstring(o_B_data( 5 downto  1)) &
    --                HT & "EFLG "& to_hstring(o_B_data( 0 downto  0)) &
    --                LF);
    --        end if;
    --    end if;
    --
    --    flush(log_file);
    --end if;
    --end process;

end architecture;
