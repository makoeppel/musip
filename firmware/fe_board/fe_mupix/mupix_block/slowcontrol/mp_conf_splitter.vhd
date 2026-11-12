----------------------------------------------------------------------------
-- entity to split mupix conf from midas into CONF, VDAC and BIAS parts
-- M. Mueller
-- Feb 2022
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

use work.mupix.all;
use work.mudaq.all;

entity mp_conf_splitter is
generic (
    g_CHIPS                 : positive := 4
);
port (
    i_data              : in  std_logic_vector(31 downto 0);
    i_data_we           : in  std_logic;
    i_chip_cvb          : in  std_logic_vector(g_CHIPS-1 downto 0); -- one hot encoded which chip to write to (set by the used address in reg_mapping)

    o_conf_dpf_we       : out std_logic_vector(g_CHIPS-1 downto 0);
    o_vdac_dpf_we       : out std_logic_vector(g_CHIPS-1 downto 0);
    o_bias_dpf_we       : out std_logic_vector(g_CHIPS-1 downto 0);

    o_conf_dpf_wdata    : out reg32array(g_CHIPS-1 downto 0);
    o_vdac_dpf_wdata    : out reg32array(g_CHIPS-1 downto 0);
    o_bias_dpf_wdata    : out reg32array(g_CHIPS-1 downto 0);

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture RTL of mp_conf_splitter is

    signal data_in_all_position_32  : integer range 0 to 84;
    signal data_in_leftovers        : std_logic_vector(63 downto 0);
    signal last_chip_cvb            : std_logic_vector(g_CHIPS-1 downto 0);
    signal last_we                  : std_logic;

begin

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_conf_dpf_we             <= (others => '0');
        o_vdac_dpf_we             <= (others => '0');
        o_bias_dpf_we             <= (others => '0');
        o_conf_dpf_wdata          <= (others => (others => '0'));
        o_vdac_dpf_wdata          <= (others => (others => '0'));
        o_bias_dpf_wdata          <= (others => (others => '0'));
        last_chip_cvb             <= (others => '0');
        last_we                   <= '0';

        data_in_all_position_32   <= 0;
        data_in_leftovers         <= (others => '0');

    elsif rising_edge(i_clk) then
        o_conf_dpf_we             <= (others => '0');
        o_vdac_dpf_we             <= (others => '0');
        o_bias_dpf_we             <= (others => '0');
        o_conf_dpf_wdata          <= (others => (others => '0'));
        o_vdac_dpf_wdata          <= (others => (others => '0'));
        o_bias_dpf_wdata          <= (others => (others => '0'));
        last_chip_cvb             <= i_chip_cvb;
        last_we                   <= i_data_we;


        --Bits: BIAS 210, CONF 90, VDAC 80, COL 896, TDAC 512, TEST 896
        if(i_data_we='1') then
            -- keep track in which 32 bit word of the config we are in order to put stuff into correct places
            -- do not change chip mask while writing !! (using only 1 position for all chips)
            -- TODO: reset for this ? (options: No reset at all between chips ? writing an additional reg each time to do that ? timeout ?)
            data_in_all_position_32 <= data_in_all_position_32 + 1;
        end if;

        for I in 0 to g_CHIPS-1 loop

            if((i_data_we='1' and i_chip_cvb(I)='1') or (last_we = '1' and last_chip_cvb(I)='1' and data_in_all_position_32 = 12)) then

                case data_in_all_position_32 is
                when 0 to 5 =>
                    -- 192 BIAS Bits
                    o_bias_dpf_we(I)         <= '1';
                    o_bias_dpf_wdata(I)      <= i_data;
                    data_in_leftovers(I)     <= '0';
                when 6 =>
                    -- 18 Bias Bits
                    o_bias_dpf_we(I)        <= '1';
                    o_bias_dpf_wdata(I)     <= i_data(31 downto 16) & x"0000"; -- TODO: check order again, why was this neccessary in old firmware ?

                    -- 16 leftover
                    data_in_leftovers(15 downto 0) <= i_data(15 downto 0);
                when 7 to 8 =>
                    -- 64 CONF Bits
                    o_conf_dpf_we(I)        <= '1';
                    o_conf_dpf_wdata(I)     <= data_in_leftovers(15 downto 0) & i_data(31 downto 16);

                    -- 16 leftover
                    data_in_leftovers(15 downto 0) <= i_data(15 downto 0);
                when 9 =>
                    -- 26 CONF Bits  (16 from leftover, 10 from input --> 22 new leftover)
                    o_conf_dpf_we(I)        <= '1';
                    o_conf_dpf_wdata(I)     <= data_in_leftovers(15 downto 0) & i_data(31 downto 22) & "000000";

                    -- 22 leftover
                    data_in_leftovers(21 downto 0) <= i_data(21 downto 0);
                when 10 to 11 =>
                    -- 64 VDAC Bits  (22 from leftover, 10 from input --> 22 new leftover)
                    o_vdac_dpf_we(I)        <= '1';
                    o_vdac_dpf_wdata(I)     <= data_in_leftovers(21 downto 0) & i_data(31 downto 22);

                    -- 22 leftover
                    data_in_leftovers(21 downto 0) <= i_data(21 downto 0);
                when 12 =>
                    -- 16 VDAC Bits  (16 from leftover)
                    o_vdac_dpf_we(I)        <= '1';
                    o_vdac_dpf_wdata(I)     <= data_in_leftovers(21 downto 6) & x"0000";

                    data_in_all_position_32 <= 0;

                ----------------------------------------------------------
                -- NEW: stop here, handle COL, TDAC and TEST elsewhere

                --     -- 6 new leftover ... but will throw them away here since this probably makes the software easier when col, tdac and test are read from file instead of odb
                --     -- --> col tac and test are 32 bit aligned and do not overlap with odb config

                --     -- 32 COL Bits
                --     fifo_write(WR_COL_BIT) <= '1';
                --     fifo_wdata(WR_COL_BIT) <= i_data_all;
                -- when 13 to 39 =>
                --     -- 864 COL Bits
                --     fifo_write(WR_COL_BIT) <= '1';
                --     fifo_wdata(WR_COL_BIT) <= i_data_all;
                -- when 40 to 55 =>
                --     -- 512 TDAC Bits
                --     fifo_write(WR_TDAC_BIT) <= '1';
                --     fifo_wdata(WR_TDAC_BIT) <= i_data_all;
                -- when 56 to 82 =>
                --     -- 896 Test Bits
                --     fifo_write(WR_TEST_BIT) <= '1';
                --     fifo_wdata(WR_TEST_BIT) <= i_data_all;
                -- when 83 =>
                --     fifo_write(WR_TEST_BIT) <= '1';
                --     fifo_wdata(WR_TEST_BIT) <= i_data_all;

                --     -- All data is there --> trigger start of spi writing
                --     internal_enable         <= '1';

                when others =>
                    data_in_all_position_32 <= 0;
                end case;
            end if;
        end loop;
    end if;
    end process;

end architecture;
