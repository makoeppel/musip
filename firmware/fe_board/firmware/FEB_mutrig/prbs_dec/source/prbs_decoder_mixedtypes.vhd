---------------------------------------
--
-- On the fly PRBS decoder for mutrig/stic event data
-- Variant with E<-decoding: single port decoding T&E
-- [KB,9/2022] Implemented block
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

use work.mutrig_hit_types.all;


entity prbs_decoder_mixedtypes is
port (
    --system
    i_coreclk       : in  std_logic;
    i_rst           : in  std_logic;
    o_initializing  : out std_logic;

    --data stream input
    i_A_data        : in  t_hit_presort;

    --data stream output
    o_A_data        : out t_hit_presort;

    --disable block (make transparent)
    i_SC_disable_dec : in std_logic--;

);
end entity;



architecture impl of prbs_decoder_mixedtypes is
    signal s_Tdecoded : t_hit_presort;
    signal s_Edecoded : t_hit_presort;
begin
    --TODO: check if things get optimized away as they should
    u_decoder: entity work.prbs_decoder
    generic map (
        DECODE_E_A => false,
        DECODE_E_B => true--,
    )
    port map (
        i_coreclk      => i_coreclk,
        i_rst          => i_rst,
        o_initializing => o_initializing,
        i_A_data       => i_A_data,
        i_B_data       => i_A_data,
        o_A_data       => s_Tdecoded,
        o_B_data       => s_Edecoded,
        i_SC_disable_dec => i_SC_disable_dec--,
    );

    p_out: process (s_Tdecoded, s_Edecoded)
    begin
        o_A_data     <= s_Tdecoded;
        o_A_data.E_CC <= s_Edecoded.E_CC;
    end process;
end architecture;

