----------------------------------------------------------------------------
-- Slow Control Secondary Unit for Switching Board
-- Marius Koeppel, Mainz University
-- mkoeppel@uni-mainz.de
--
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity swb_sc_secondary is
generic (
    NLINKS      : positive := 4;
    skip_init   : std_logic := '0'
);
port (
    i_link_enable               : in    std_logic_vector(NLINKS-1 downto 0);
    i_link_data                 : in    work.mu3e.link32_array_t(NLINKS-1 downto 0);

    o_mem_addr                  : out   std_logic_vector(15 downto 0);
    o_mem_addr_finished         : out   std_logic_vector(15 downto 0);
    o_mem_data                  : out   std_logic_vector(31 downto 0);
    o_mem_we                    : out   std_logic;

    o_state                     : out   std_logic_vector(3 downto 0);

    i_reset_n                   : in    std_logic;
    i_clk                       : in    std_logic--;
);
end entity;

architecture arch of swb_sc_secondary is

    signal link_data : work.mu3e.link32_array_t(NLINKS-1 downto 0);
    signal rdempty, wrfull, ren : std_logic_vector(NLINKS-1 downto 0);

    signal mem_data_o : std_logic_vector(31 downto 0);
    signal mem_addr_o : std_logic_vector(15 downto 0);
    signal mem_wren_o : std_logic;
    signal cur_link : work.mu3e.link32_t;
    signal current_link : integer range 0 to NLINKS - 1;

    type state_type is (init, waiting, startup, starting);
    signal state : state_type;

begin

    o_mem_data <= mem_data_o;
    o_mem_addr <= mem_addr_o;
    o_mem_we <= mem_wren_o;

    gen_buffer_sc : FOR i in 0 to NLINKS - 1 GENERATE

        e_fifo : entity work.link32_scfifo
        generic map (
            g_ADDR_WIDTH=> 8,
            g_WREG_N    => 1,
            g_RREG_N    => 2--,
        )
        port map (
            i_wdata     => i_link_data(i),
            i_we        => not i_link_data(i).idle,
            o_wfull     => wrfull(i),

            o_rdata     => link_data(i),
            i_rack      => ren(i),
            o_rempty    => rdempty(i),

            i_reset_n   => i_reset_n,
            i_clk       => i_clk--,
        );

    END GENERATE;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        mem_data_o <= (others => '0');
        mem_addr_o <= (others => '1');
        o_mem_addr_finished <= (others => '1');
        o_state <= (others => '0');
        ren <= (others => '0');
        mem_wren_o <= '0';
        current_link <= 0;
        cur_link <= work.mu3e.LINK32_IDLE;
        if ( skip_init = '0' ) then
            state <= init;
        else
            state <= waiting;
        end if;

    elsif rising_edge(i_clk) then
        o_state <= (others => '0');
        mem_data_o <= (others => '0');
        ren <= (others => '0');
        mem_wren_o <= '0';
        mem_wren_o <= '0';
        cur_link <= link_data(current_link);

        if ( ren(current_link) /= '1' ) then
            case state is
            when init =>
                o_state(3 downto 0) <= x"1";
                mem_addr_o <= mem_addr_o + '1';
                mem_data_o <= (others => '0');
                mem_wren_o <= '1';
                if ( mem_addr_o = x"FFFE" ) then
                    o_mem_addr_finished <= (others => '1');
                    state <= waiting;
                end if;
                --
            when waiting =>
                o_state(3 downto 0) <= x"2";
                --LOOP link mux take the last one for prio
                link_mux:
                FOR i in 0 to NLINKS - 1 LOOP
                    if ( i_link_enable(i) = '1' and link_data(i).sop = '1' and rdempty(i) = '0' ) then
                        state <= startup;
                        current_link <= i;
                    end if;
                END LOOP;

            when startup =>
                ren(current_link) <= '1';
                state <= starting;

            when starting =>
                o_state(3 downto 0) <= x"3";
                if ( rdempty(current_link) = '0' ) then
                    ren(current_link) <= '1';
                    if ( link_data(current_link).eop = '1' ) then
                        o_mem_addr_finished <= mem_addr_o + '1';
                        state <= waiting;
                    end if;
                end if;
                --
            when others =>
                o_state(3 downto 0) <= x"E";
                mem_data_o <= (others => '0');
                mem_wren_o <= '0';
                state <= waiting;
                --
            end case;
        else
            mem_addr_o <= mem_addr_o + '1';
            mem_data_o <= cur_link.data;
            mem_wren_o <= '1';
        end if;

    end if;
    end process;

end architecture;
