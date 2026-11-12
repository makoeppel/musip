library IEEE;
use IEEE.std_logic_1164.all;

entity obuf_config is
generic (
    datawidth : integer := 1
);
port (
    i_cdata : in std_logic_vector(datawidth*6-1 downto 0); --incoming configurational data
    o_cclkena : out std_logic_vector(datawidth-1 downto 0); --clock enable IO ring, hard IP shift register
    i_cstart : in std_logic;
    o_cdata : out std_logic := '0'; --serial data input
    o_cupdate : out std_logic := '0';
    o_config_phase180 : out std_logic_vector(datawidth-1 downto 0); --half clock shift
    i_reset_n : in std_logic;
    i_cclk : in std_logic--;
);
end entity;

architecture bhv of obuf_config is

    type conf_state is ( fs_idle, fs_rec, fs_send, fs_update );

    signal s_ccnt : integer := 0;
    signal s_state : conf_state;

    signal s_cclk : std_logic := '0'; -- clkin
    signal s_cclkena : std_logic_vector(datawidth-1 downto 0); --TODO: extend to multi-pad configuration
    signal s_cdata : std_logic_vector(0 to 4) := (others => '0'); -- datain
    signal s_cstart : std_logic := '0'; -- initializing signal for fsm
    signal s_startcheck : std_logic := '0'; -- indicator for the "right" start signa
    signal s_cconfout : std_logic := '0'; -- dataout (serialized)
    signal s_cupdateout : std_logic := '0';

begin

    state_machine_conf : process(i_cclk, i_reset_n)
    begin
	 for i in o_config_phase180'range loop
        o_config_phase180(i) <= i_cdata(6*i+5);
	 end loop;
	 
    if rising_edge(i_cclk) then
        s_cstart <= i_cstart;

        s_startcheck <= s_cstart;
        if ( i_reset_n = '1' ) then
            s_cconfout <= s_cdata(0);
            case s_state is
            when fs_idle =>
                s_cupdateout <= '0';
                s_cconfout <= '0';
                if s_cstart ='1' and s_startcheck = '0' then
                    s_state <= fs_rec;
                    s_cclkena <= (others=>'1'); --TODO: extend to multi-pad configuration
                end if;
            when fs_rec =>
                s_state <= fs_send;
                s_ccnt <= 0;
                s_cdata <= i_cdata(4 downto 0); --TODO: extend to multi-pad configuration
            when fs_send =>
                if s_ccnt < 5 then
                    s_ccnt <= s_ccnt + 1;
                else
                    s_ccnt <= 0;
                    s_cconfout <= '0';
                    s_cclkena <= (others => '0'); --TODO: extend to multi-pad configuration
                    -- return to idle
                    s_state <= fs_update;
                end if;
                for i in 0 to 3 loop
                    s_cdata(i) <= s_cdata(i+1);
                end loop;
            when fs_update =>
                s_cdata <= (others => '0');
                s_cconfout <= '0';
                if s_ccnt < 10 then
                    s_ccnt <= s_ccnt + 1;
                -- send update signal after 10 clock cycles
                elsif s_ccnt = 10 then
                    s_ccnt <= s_ccnt + 1;
                    s_cupdateout <= '1';
                -- return to idle
                else
                    s_ccnt <= 0;
                    s_cupdateout <= '0';
                    s_state <= fs_idle;
						  s_cclkena <= (others => '0'); --TODO: extend to multi-pad configuration
                end if;
            end case;
        else
            s_state <= fs_idle;
        end if;
    end if;
    end process;

    o_cdata <= s_cconfout;
    o_cupdate <= s_cupdateout;
    o_cclkena <= s_cclkena;

end architecture;
