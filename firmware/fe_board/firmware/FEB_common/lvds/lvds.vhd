--

library ieee;
use ieee.std_logic_1164.all;

package lvds is

    type lvds_status_t is record
        disperr         :   std_logic_vector(31 downto 0);
        err8b10b        :   std_logic_vector(31 downto 0);
        hitcnt          :   std_logic_vector(31 downto 0);
        pll_locked      :   std_logic;
        ready           :   std_logic;
        dpa_locked      :   std_logic;
        aligncnt        :   std_logic_vector(5 downto 0);
        arrival_phase   :   std_logic_vector(1 downto 0);
        out_of_phase_cnt:   std_logic_vector(15 downto 0);
    end record;
    constant LVDS_ZERO : lvds_status_t := (
        disperr => (others => '0'),
        err8b10b => (others => '0'),
        hitcnt => (others => '0'),
        pll_locked => '0',
        ready  => '0',
        dpa_locked => '0',
        aligncnt => (others => '0'),
        arrival_phase => (others => '0'),
        out_of_phase_cnt => (others => '0')
    );
    type lvds_status_array_t is array (natural range <>) of lvds_status_t;

end package;
