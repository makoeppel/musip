-- Sorter reg mapping, fairly generic
-- M. Mueller, Nov 2021

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sorter_registers.all;
use work.mudaq.all;
use work.mupix_registers.all;

entity sorter_reg_mapping is
generic (
    NSORTERINPUTS   : integer := 12; -- If larger than 12, the register mapping needs to be adapted
    TIMESTAMPSIZE   : integer := 11; -- should not be larger than 32
    IS_MUTRIG       : boolean := false
 );
port (
    i_clk156                    : in  std_logic;
    i_reset_n                   : in  std_logic;

    i_reg_addr                  : in  std_logic_vector(15 downto 0);
    i_reg_re                    : in  std_logic;
    o_reg_rdata                 : out std_logic_vector(31 downto 0);
    i_reg_we                    : in  std_logic;
    i_reg_wdata                 : in  std_logic_vector(31 downto 0);

    i_nintime                   : in  reg32array(NSORTERINPUTS-1 downto 0);
    i_noutoftime                : in  reg32array(NSORTERINPUTS-1 downto 0);
    i_noverflow                 : in  reg32array(NSORTERINPUTS-1 downto 0);
    i_nout                      : in  reg32;
    i_credit                    : in  reg32;

    i_nprewindow                : in  reg32array(NSORTERINPUTS-1 downto 0);
    i_npastwindow               : in  reg32array(NSORTERINPUTS-1 downto 0);
    i_noutdiag                  : in  reg32array(NSORTERINPUTS-1 downto 0);
    o_diagwidth                 : out std_logic_vector(TIMESTAMPSIZE-1 downto 0);

    o_sorter_delay              : out std_logic_vector(TIMESTAMPSIZE-1 downto 0)--;
);
end entity;

architecture rtl of sorter_reg_mapping is
    signal sorter_delay              : std_logic_vector(TIMESTAMPSIZE-1 downto 0);

    signal nintime                   : reg32array(NSORTERINPUTS-1 downto 0);
    signal noutoftime                : reg32array(NSORTERINPUTS-1 downto 0);
    signal noverflow                 : reg32array(NSORTERINPUTS-1 downto 0);
    signal nout                      : reg32;
    signal credit                    : reg32;

    signal nprewindow       : reg32array(NSORTERINPUTS-1 downto 0);
    signal npastwindow      : reg32array(NSORTERINPUTS-1 downto 0);
    signal noutdiag         : reg32array(NSORTERINPUTS-1 downto 0);
    signal diagwidth        : std_logic_vector(TIMESTAMPSIZE-1 downto 0);

begin

    process (i_clk156, i_reset_n, i_reg_addr)
    variable regaddr : integer range 0 to 255;
    begin
    regaddr := to_integer(unsigned(i_reg_addr(7 downto 0)));

    if ( i_reset_n = '0' ) then
        o_sorter_delay              <= (others => '0');
        sorter_delay                <= (others => '0');--"101" & x"FC";
        o_diagwidth                 <= (others => '0');
        diagwidth                   <= (others => '0');

    elsif(rising_edge(i_clk156)) then
        o_sorter_delay              <= sorter_delay;

        -- register sorter signals once in 156 Mhz domain and put a false path between i_nintime and nintime, ...
        nintime                     <= i_nintime;
        noutoftime                  <= i_noutoftime;
        noverflow                   <= i_noverflow;
        nout                        <= i_nout;
        credit                      <= i_credit;

        nprewindow                  <= i_nprewindow;
        npastwindow                 <= i_npastwindow;
        noutdiag                    <= i_noutdiag;
        o_diagwidth                 <= diagwidth;

        o_reg_rdata <= X"BBBBBBBB";

        -----------------------------------------------------------------
        ---- sorter regs ------------------------------------------------
        -----------------------------------------------------------------
        for I in 0 to NSORTERINPUTS-1 loop
            if ( (regaddr = I + SORTER_INDEX_NINTIME)  ) then
                o_reg_rdata <= nintime(I);
            end if;
        end loop;

        for I in 0 to NSORTERINPUTS-1 loop
            if ( (regaddr = I + SORTER_INDEX_NOUTOFTIME)  ) then
                o_reg_rdata <= noutoftime(I);
            end if;
        end loop;

        for I in 0 to NSORTERINPUTS-1 loop
            if ( regaddr = I + SORTER_INDEX_NOVERFLOW  ) then
                o_reg_rdata <= noverflow(I);
            end if;
        end loop;

        for I in 0 to NSORTERINPUTS-1 loop
            if ( regaddr = I + SORTER_INDEX_NPREWINDOW  ) then
                o_reg_rdata <= nprewindow(I);
            end if;
        end loop;

        if(IS_MUTRIG) then
            for I in 0 to NSORTERINPUTS-1 loop
                if ( regaddr = I + SORTER_INDEX_NPASTWINDOW  ) then
                o_reg_rdata <= npastwindow(I);
                end if;
            end loop;

            for I in 0 to NSORTERINPUTS-1 loop
                if ( regaddr = I + SORTER_INDEX_NOUTDIAG  ) then
                    o_reg_rdata <= noutdiag(I);
                end if;
            end loop;
        end if;

        if ( regaddr = SORTER_INDEX_NOUT  ) then
            o_reg_rdata <= nout;
        end if;

        if ( regaddr = SORTER_INDEX_CREDIT  ) then
            o_reg_rdata <= credit;
        end if;

        if ( regaddr = SORTER_INDEX_DELAY and i_reg_we = '1' ) then
            sorter_delay <= i_reg_wdata(TIMESTAMPSIZE-1 downto 0);
        end if;
        if ( regaddr = SORTER_INDEX_DELAY  ) then
            o_reg_rdata(TIMESTAMPSIZE-1 downto 0) <= sorter_delay;
        end if;

        if ( regaddr = SORTER_INDEX_DIAGNOSE and i_reg_we = '1' ) then
            diagwidth <= i_reg_wdata(TIMESTAMPSIZE-1 downto 0);
        end if;
        if ( regaddr = SORTER_INDEX_DIAGNOSE  ) then
            o_reg_rdata(TIMESTAMPSIZE-1 downto 0) <= diagwidth;
        end if;

    end if;
    end process;

end architecture;
