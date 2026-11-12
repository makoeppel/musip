--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.util_slv.all;

use work.mudaq.all;

entity mupix_run_start_ack is
generic (
    NLVDS : integer := 32--;
);
port (
    i_disable                   : in    std_logic;
    i_stable_required           : in    unsigned(15 downto 0);
    i_lvds_err_counter          : in    slv32_array_t(NLVDS-1 downto 0);
    i_lvds_data_valid           : in    std_logic_vector(NLVDS-1 downto 0);
    i_lvds_mask                 : in    slv32_array_t(1 downto 0);
    i_sc_busy                   : in    std_logic;
    i_run_state_156             : in    run_state_t;
    o_ack_run_prep_permission   : out   std_logic;

    i_reset_156_n               : in    std_logic;
    i_clk_156                   : in    std_logic--;
);
end entity;

architecture arch of mupix_run_start_ack is

    --signal lvds_stable_count
    signal stable_counter   : unsigned(15 downto 0) := (others => '0');
    signal lvds_stable      : std_logic_vector(NLVDS-1 downto 0) := (others => '0');
    signal prev_err_counter : std_logic_vector(NLVDS*4-1 downto 0);
    signal lvds_mask        : std_logic_vector(NLVDS-1 downto 0);

begin

    process(i_clk_156)
        variable lvds_mask_slv  : std_logic_vector(63 downto 0) := (others => '0');
    begin
    if rising_edge(i_clk_156) then
        lvds_mask_slv       := i_lvds_mask(1) & i_lvds_mask(0);
        lvds_mask           <= lvds_mask_slv(NLVDS-1 downto 0);
    end if;
    end process;

    process(i_clk_156, i_reset_156_n)
    begin
    if ( i_reset_156_n /= '1' ) then
        o_ack_run_prep_permission     <= '0';
        stable_counter              <= (others => '0');
        lvds_stable                 <= (others => '0');
        prev_err_counter            <= (others => '0');

    elsif rising_edge(i_clk_156) then
        if(i_disable = '1') then
            o_ack_run_prep_permission   <= '1';
        elsif(i_run_state_156 = RUN_STATE_PREP and i_sc_busy='0' and stable_counter = i_stable_required and and_reduce(i_lvds_data_valid or lvds_mask)='1') then
            o_ack_run_prep_permission   <= '1';
        else
            o_ack_run_prep_permission   <= '0';
        end if;

        for I in NLVDS-1 downto 0 loop
            if(prev_err_counter((I+1)*4-1 downto I*4) = i_lvds_err_counter(I)(3 downto 0)) then
                lvds_stable(I)          <= '1';
            else
                lvds_stable(I)          <= '0';
            end if;
            prev_err_counter((I+1)*4-1 downto I*4)  <= i_lvds_err_counter(I)(3 downto 0);
        end loop;

        if ( and_reduce(lvds_stable) = '0' ) then
            stable_counter              <= (others => '0');
        elsif ( stable_counter /= i_stable_required ) then
            stable_counter              <= stable_counter + 1;
        end if;
    end if;
    end process;

end architecture;
