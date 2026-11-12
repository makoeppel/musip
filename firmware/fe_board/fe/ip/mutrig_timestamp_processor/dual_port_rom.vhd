-- File name: dual_port_rom.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.4.2
-- Date    : 20260629
-- Change  : Convert the MTS timestamp-decode ROM leaf to VHDL with a generated MIF init file.
-- Prior   : The ROM leaf used Verilog $readmemb for initialization.
-- =======================================
--
-- Dual-port ROM for the MuTRiG timestamp decoder.

library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity dual_port_rom is
    generic (
        DATA_WIDTH    : natural    := 15;
        ADDR_WIDTH    : natural    := 15
    );
    port (
        addr_a    : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
        q_a       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        addr_b    : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
        q_b       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        clk       : in  std_logic
    );
end entity dual_port_rom;

architecture rtl of dual_port_rom is

    constant ROM_ZERO_CONST    : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

    signal rom_q_a             : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal rom_q_b             : std_logic_vector(DATA_WIDTH - 1 downto 0);

begin

    q_a <= rom_q_a;
    q_b <= rom_q_b;

    cc_rom : altsyncram
    generic map (
        address_reg_b                         => "CLOCK0",
        clock_enable_input_a                  => "BYPASS",
        clock_enable_input_b                  => "BYPASS",
        clock_enable_output_a                 => "BYPASS",
        clock_enable_output_b                 => "BYPASS",
        indata_reg_b                          => "CLOCK0",
        init_file                             => "dual_port_rom_init.mif",
        init_file_layout                      => "PORT_A",
        intended_device_family                => "Arria V",
        lpm_type                              => "altsyncram",
        numwords_a                            => 2 ** ADDR_WIDTH,
        numwords_b                            => 2 ** ADDR_WIDTH,
        operation_mode                        => "BIDIR_DUAL_PORT",
        outdata_aclr_a                        => "NONE",
        outdata_aclr_b                        => "NONE",
        outdata_reg_a                         => "UNREGISTERED",
        outdata_reg_b                         => "UNREGISTERED",
        power_up_uninitialized                => "FALSE",
        read_during_write_mode_mixed_ports    => "DONT_CARE",
        read_during_write_mode_port_a         => "NEW_DATA_NO_NBE_READ",
        read_during_write_mode_port_b         => "NEW_DATA_NO_NBE_READ",
        width_a                               => DATA_WIDTH,
        width_b                               => DATA_WIDTH,
        widthad_a                             => ADDR_WIDTH,
        widthad_b                             => ADDR_WIDTH,
        width_byteena_a                       => 1,
        width_byteena_b                       => 1,
        wrcontrol_wraddress_reg_b             => "CLOCK0"
    )
    port map (
        address_a    => addr_a,
        address_b    => addr_b,
        clock0       => clk,
        data_a       => ROM_ZERO_CONST,
        data_b       => ROM_ZERO_CONST,
        q_a          => rom_q_a,
        q_b          => rom_q_b,
        wren_a       => '0',
        wren_b       => '0'
    );

end architecture rtl;
