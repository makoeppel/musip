
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mutrig.all;

entity replace_length is
port (
    i_data                  : in  std_logic_vector(7 downto 0);
    i_datak                 : in  std_logic;
    i_enable                : in  std_logic;

    o_data                  : out std_logic_vector(7 downto 0);
    o_datak                 : out std_logic;

    i_reset_n               : in  std_logic;
    i_clk                   : in  std_logic--;
);
end entity;

architecture rtl of replace_length is

    -- ram
    signal w_ram_en, read, valid, wrong_trailer : std_logic;
    signal w_ram_addr, r_ram_addr, length_add0, length_add1, w_ram_add_reg : std_logic_vector(10 downto 0);
    signal w_ram_data, r_ram_data : std_logic_vector(8 downto 0);
    signal data_flags : std_logic_vector(5 downto 0);

    signal package_cnt, byte_cnt : std_logic_vector(9 downto 0);
    type FSM_states is (IDLE, FRAME_CNT1, FRAME_CNT2, FLAGS, LEN, TRAILER, SET_LEN0, SET_LEN1, SET_ADDR);
    signal FSM_state : FSM_states;

begin

    e_ram : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => 11,
        g_ADDR1_WIDTH => 11,
        g_DATA0_WIDTH => 9,
        g_DATA1_WIDTH => 9--,
    )
    port map (
        i_addr0     => w_ram_addr,
        i_addr1     => r_ram_addr,
        i_clk0      => i_clk,
        i_clk1      => i_clk,
        i_wdata0    => w_ram_data,
        i_wdata1    => (others => '0'),
        i_we0       => w_ram_en,
        i_we1       => '0',
        o_rdata0    => open,
        o_rdata1    => r_ram_data--,
    );

    o_data  <=  i_data                  when i_enable = '0' else
                r_ram_data(7 downto 0)  when valid = '1' else
                x"BC";

    o_datak <=  i_datak                 when i_enable = '0' else
                r_ram_data(8)           when valid = '1' else
                '1';

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        package_cnt     <= (others => '0');
        byte_cnt        <= (others => '0');
        w_ram_addr      <= (others => '1');
        r_ram_addr      <= (others => '1');
        length_add0     <= (others => '0');
        length_add1     <= (others => '0');
        read            <= '0';
        valid           <= '0';
        wrong_trailer   <= '0';
        FSM_state       <= IDLE;
        --
    elsif rising_edge(i_clk) then

        if ( read = '1' ) then
            r_ram_addr <= r_ram_addr + '1';
        end if;

        valid <= read;

        w_ram_en   <= '0';

        -- dont write when we set the length
        -- assuming here that after a package we have BC
        if ( FSM_state = SET_LEN0 or FSM_state = SET_LEN1 or FSM_state = SET_ADDR ) then
            --
        else
            w_ram_en        <= '1';
            w_ram_addr      <= w_ram_addr + 1;
            w_ram_add_reg   <= w_ram_addr + 1;
            w_ram_data      <= i_datak & i_data;
        end if;

        case FSM_state is
        when IDLE =>
            length_add0     <= (others => '0');
            length_add1     <= (others => '0');
            package_cnt     <= (others => '0');
            byte_cnt        <= (others => '0');
            wrong_trailer   <= '0';

            if ( i_datak = '1' and i_data = c_header ) then
                FSM_state   <= FRAME_CNT1;
            end if;

        when FRAME_CNT1 =>
            if ( not ( i_datak = '1' and i_data = x"BC" ) ) then
                FSM_state   <= FRAME_CNT2;
            end if;

        when FRAME_CNT2 =>
            if ( not ( i_datak = '1' and i_data = x"BC" ) ) then
                FSM_state   <= FLAGS;
            end if;

        when FLAGS =>
            if ( not ( i_datak = '1' and i_data = x"BC" ) ) then
                data_flags  <= i_data(7 downto 2);
                length_add0 <= w_ram_addr + 1;
                FSM_state   <= LEN;
            end if;

        when LEN =>
            if ( not ( i_datak = '1' and i_data = x"BC" ) ) then
                length_add1 <= w_ram_addr + 1;
                FSM_state   <= TRAILER;
            end if;

        when TRAILER =>
            -- we now have to wait two cycles with reading
            -- since we dont write when we set the length
            if ( i_datak = '1' and i_data = x"9C" ) then
                wrong_trailer <= '0';
                read <= '0';
                FSM_state   <= SET_LEN0;
            -- we stop at any comma word but mark such a package
            elsif ( i_datak = '1' and i_data /= x"BC" ) then
                wrong_trailer <= '1';
                read <= '0';
                FSM_state   <= SET_LEN0;
            -- cnt all non comma idle
            elsif ( not ( i_datak = '1' and i_data = x"BC" ) ) then
                byte_cnt <= byte_cnt + 1;
                if ( byte_cnt + 1 = 6 ) then
                    package_cnt <= package_cnt + 1;
                    byte_cnt <= (others => '0');
                end if;
            end if;

        when SET_LEN0 =>
            w_ram_en   <= '1';
            w_ram_addr <= length_add0;
            w_ram_data <= '0' & data_flags(5 downto 1) & wrong_trailer & package_cnt(9 downto 8);

            FSM_state   <= SET_LEN1;

        when SET_LEN1 =>
            w_ram_en   <= '1';
            w_ram_addr <= length_add1;
            w_ram_data <= '0' & package_cnt(7 downto 0);

            read        <= '1';
            --r_ram_addr  <= r_ram_addr + '1';

            FSM_state   <= SET_ADDR;

        when SET_ADDR =>
            w_ram_addr <= w_ram_add_reg;
            FSM_state <= IDLE;

        when others =>
            w_ram_data <= (others => '0');
            w_ram_en   <= '0';
            FSM_state   <= IDLE;

        end case;
    end if;
    end process;

end architecture;
