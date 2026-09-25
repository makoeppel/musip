library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

package mapping_functions is

    function convert_row_mp10 (
        i_row : std_logic_vector(8 downto 0)--;
    ) return std_logic_vector;

    function convert_row (
        i_row : std_logic_vector(8 downto 0)--;
    ) return std_logic_vector;

    function convert_col_mp10 (
        i_col : std_logic_vector(6 downto 0);
        i_row : std_logic_vector(8 downto 0)--;
    ) return std_logic_vector;

    function convert_col (
        i_col : std_logic_vector(6 downto 0);
        i_row : std_logic_vector(8 downto 0)--;
    ) return std_logic_vector;

    function calc_tot (
        ts2       : std_logic_vector( 4 downto 0);
        ts        : std_logic_vector(10 downto 0);
        tot_mode  : std_logic_vector( 2 downto 0)--;
    ) return std_logic_vector;

    function convert_lvds_to_chip_id (
        lvds_ID       : integer;
        chip_ID_mode  : std_logic_vector(1 downto 0);
        g_LVDS_ID     : integer --;
    ) return std_logic_vector;

end package;

package body mapping_functions is

    function convert_lvds_to_chip_id (
        lvds_ID       : integer;
        chip_ID_mode  : std_logic_vector(1 downto 0);
        g_LVDS_ID     : integer --;
    ) return std_logic_vector is
        variable chip_id : std_logic_vector(5 downto 0);
    begin
        -- TODO: correct numbering for different feb positions (chip_id_mode's)
        chip_id := std_logic_vector(to_unsigned(g_LVDS_ID, chip_id'length));
        return chip_id;
    end function;

    -- this is the Mupix10 version of convert_row
    function convert_row_mp10 (
        i_row : std_logic_vector(8 downto 0)--;
    ) return std_logic_vector is
        variable row            : std_logic_vector(7 downto 0);
        variable tmp            : std_logic_vector(8 downto 0);
        variable i_row_inverted : std_logic_vector(8 downto 0);
    begin
        i_row_inverted := not i_row;
        if ( i_row_inverted > 380 ) then
            tmp := 499 - i_row_inverted;
            if ( i_row_inverted(0) = '0' ) then
                row := tmp(8 downto 1) + 60;
            else
                row := tmp(8 downto 1);
            end if;
        elsif ( i_row_inverted(8) = '1' ) then
            tmp := 380 - i_row_inverted;
            if (i_row_inverted(0)='0') then
                row := tmp(8 downto 1) + 62;
            else
                row := tmp(8 downto 1);
            end if;
        elsif (i_row_inverted>124) then
            tmp := 255 - i_row_inverted;
            if ( i_row_inverted(0) = '0' ) then
                row := tmp(8 downto 1) + 119 + 66;
            else
                row := tmp(8 downto 1) + 119;
            end if;
        else
            tmp := 124 - i_row_inverted;
            if ( i_row_inverted(0) = '0' ) then
                row := tmp(8 downto 1) + 125 + 62;
            else
                row := tmp(8 downto 1) + 125;
            end if;
        end if;
        return row;
    end function;

    -- this is the Mupix11 version of convert_row
    function convert_row (
        i_row : std_logic_vector(8 downto 0)--;
    ) return std_logic_vector is
        variable row            : std_logic_vector(7 downto 0);
        variable tmp            : std_logic_vector(8 downto 0);
        variable i_row_inverted : std_logic_vector(8 downto 0);
    begin
        i_row_inverted := not i_row;
        if ( i_row_inverted > 249 ) then
            tmp := i_row_inverted - 250;
            row := tmp(7 downto 0);
        else
            tmp := i_row_inverted;
            row := tmp(7 downto 0);
        end if;
        return row;
    end function;

    -- this is the mupix10 version of convert_col
    function convert_col_mp10 (
        i_col : std_logic_vector(6 downto 0);
        i_row : std_logic_vector(8 downto 0)--;
    ) return std_logic_vector is
        variable col            : std_logic_vector(7 downto 0);
        variable i_row_inverted : std_logic_vector(8 downto 0);
    begin
        i_row_inverted := not i_row;
        if ( i_row_inverted > 380 or ( i_row_inverted(8) = '0' and i_row_inverted > 124 ) ) then
            col := i_col & '1';
        else
            col := i_col & '0';
        end if;
        return col;
    end function;

    -- this is the mupix11 version of convert_col
    function convert_col (
        i_col : std_logic_vector(6 downto 0);
        i_row : std_logic_vector(8 downto 0)--;
    ) return std_logic_vector is
        variable col            : std_logic_vector(7 downto 0);
        variable i_row_inverted : std_logic_vector(8 downto 0);
    begin
        i_row_inverted := not i_row;
        if ( i_row_inverted > 249 ) then
            col := i_col & '1';
        else
            col := i_col & '0';
        end if;
        return col;
    end function;

    function calc_tot (
        ts2       : std_logic_vector( 4 downto 0);
        ts        : std_logic_vector(10 downto 0);
        tot_mode  : std_logic_vector( 2 downto 0)--;
    ) return std_logic_vector is
        variable tot : std_logic_vector(5 downto 0);
    begin
        -- TODO: calc. something here
        tot := '0' & ts2;
        return tot;
    end function;

end package body;
