-----------------------------------
--
-- Removing SC information from hit data stream for MP10
-- Sebastian Dittmeier, June 2020
--
-- dittmeier@physi.uni-heidelberg.de
--
-- last edit: M.Mueller, March 2021
----------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity mp_sc_removal is
port (
    i_sc_active         : in std_logic;
    i_new_block         : in std_logic;
    i_hit               : in std_logic_vector(31 DOWNTO 0);
    i_hit_ena           : in std_logic;
    i_coarsecounters_ena: in std_logic; -- has to be '0' for hits!
    o_hit               : out std_logic_vector(31 DOWNTO 0);
    o_hit_ena           : out std_logic;
    i_reset_n           : in std_logic;
    i_clk               : in std_logic--;
);
end entity;

architecture rtl of mp_sc_removal is

-- it may be only the last two hits of a readout block, that could be SC
-- so we simply store the last two hits of a readout cycle
-- we check the following signals:
-- sc_active: only if = '1' then we take action, otherwise bypass
-- new_block: indicates, that a readout cylce has passed, then we delete last two hits
-- we do that by erasing the hin_ena flag
-- we can use the link_id_flag for that
    signal hit_reg_1        : std_logic_vector(31 DOWNTO 0);
    signal hit_reg_2        : std_logic_vector(31 DOWNTO 0);
    signal hit_reg_out      : std_logic_vector(31 DOWNTO 0);
    signal hit_ena_reg_1    : std_logic;
    signal hit_ena_reg_2    : std_logic;
    signal hit_ena_reg_out  : std_logic;

begin

    -- we do not forward coarsecounter data on hit lines
    o_hit               <= (others => '0')  when i_coarsecounters_ena = '1' else
                            hit_reg_out when (i_sc_active = '1') else
                            i_hit;

    -- we do not forward coarsecounters_ena signal
    o_hit_ena           <= '0' when i_coarsecounters_ena = '1' else
                            hit_ena_reg_out when (i_sc_active = '1') else
                            i_hit_ena;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        hit_reg_1       <= (others => '0');
        hit_reg_2       <= (others => '0');
        hit_reg_out     <= (others => '0');
        hit_ena_reg_1   <= '0';
        hit_ena_reg_2   <= '0';
        hit_ena_reg_out <= '0';
    elsif rising_edge(i_clk) then
        hit_ena_reg_out <= '0'; -- defaults to low
        if ( i_new_block = '1' ) then
            hit_ena_reg_1 <= '0'; -- we delete the stored flags
            hit_ena_reg_2 <= '0'; -- we delete the stored flags
        elsif ( i_hit_ena = '1' and i_coarsecounters_ena = '0' ) then -- here we deal with hits
            hit_reg_1       <= i_hit;
            hit_reg_2       <= hit_reg_1;
            hit_reg_out     <= hit_reg_2; -- SC data would actually pop out as hits, but the enable signals are deleted

            hit_ena_reg_1   <= i_hit_ena;
            hit_ena_reg_2   <= hit_ena_reg_1;
            hit_ena_reg_out <= hit_ena_reg_2;
        end if;
    end if;
    end process;

end architecture;
