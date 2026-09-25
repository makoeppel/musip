
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

-- synthesis read_comments_as_HDL on
--library arriav;
--use arriav.all;
-- synthesis read_comments_as_HDL off

entity ip_reset_shift is
generic (
    P_WIDTH             : natural
);
port (
    datain              : in    std_logic_vector(P_WIDTH-1 downto 0);
    io_config_clk       : in    std_logic;
    io_config_clkena    : in    std_logic_vector(P_WIDTH-1 downto 0);
    io_config_datain    : in    std_logic;
    io_config_update    : in    std_logic;
	 io_config_phase180       : in    std_logic_vector(P_WIDTH-1 downto 0);
    dataout             : out   std_logic_vector(P_WIDTH-1 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture rtl of ip_reset_shift is

    COMPONENT arriav_delay_chain IS
    GENERIC (
        sim_falling_delay_increment : NATURAL := 10;
        sim_intrinsic_falling_delay : NATURAL := 200;
        sim_intrinsic_rising_delay : NATURAL := 200;
        sim_rising_delay_increment : NATURAL := 10;
        lpm_type : STRING := "arriav_delay_chain"
    );
    PORT (
        datain : IN STD_LOGIC := '0';
        dataout : OUT STD_LOGIC;
        delayctrlin : IN STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0')
    );
    END COMPONENT;

    COMPONENT arriav_io_config IS
    PORT (
        clk : IN STD_LOGIC := '0';
        datain : IN STD_LOGIC := '0';
        dataout : OUT STD_LOGIC;
        ena : IN STD_LOGIC := '0';
        outputenabledelaysetting : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
        outputhalfratebypass : OUT STD_LOGIC;
        outputregdelaysetting : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
        padtoinputregisterdelaysetting : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
        readfifomode : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        readfiforeadclockselect : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        update : IN STD_LOGIC := '0'
    );
    END COMPONENT;

    signal s_delay_ctrl  : STD_LOGIC_VECTOR(5*P_WIDTH-1 DOWNTO 0);
    signal s_sig_from_ddio : STD_LOGIC_VECTOR(P_WIDTH-1 DOWNTO 0);
    signal s_data : STD_LOGIC_VECTOR(P_WIDTH-1 DOWNTO 0);
    signal s_data_del : STD_LOGIC_VECTOR(P_WIDTH-1 DOWNTO 0);
    signal io_config_phase180_clk : std_logic_vector(P_WIDTH-1 downto 0);

begin	 
    e_io_config_phase180 : entity work.ff_sync
    generic map ( W => io_config_phase180_clk'length )
    port map (
        i_d => io_config_phase180, o_q => io_config_phase180_clk,
        i_reset_n => i_reset_n, i_clk => i_clk--,
    );

    half_cycle : process(i_clk, io_config_phase180_clk)
    begin
    if rising_edge(i_clk) then
		  for i in io_config_phase180_clk'range loop
			  s_data(i) <= datain(i);
           if io_config_phase180_clk(i) = '1' then
					s_data_del(i) <= s_data(i);
			  else
					s_data_del(i) <= datain(i);
			  end if;
		  end loop;
    end if;
    end process;
	 
    g_ioconfig: for i in 0 to P_WIDTH -1 generate
       ioconfig : arriav_io_config
       port map (
         clk => io_config_clk,
         datain => io_config_datain,
         ena => io_config_clkena(i),
         outputregdelaysetting => s_delay_ctrl(i*5+4 DOWNTO i*5),
         update => io_config_update
		 );
    end generate;

    buf : altddio_out
    generic map (
        extend_oe_disable => "OFF",
        intended_device_family => "Arria V",
        invert_output => "OFF",
        lpm_hint => "UNUSED",
        lpm_type => "altddio_out",
        oe_reg => "UNREGISTERED",
        power_up_high => "OFF",
        width => P_WIDTH
    )
    port map (
        datain_h => s_data_del,
        datain_l => s_data,
        outclock => i_clk,
        dataout => s_sig_from_ddio
    );

	 g_delaychains: for i in 0 to P_WIDTH -1 generate
	 
		 sd1 : arriav_delay_chain
		 generic map (
			  sim_falling_delay_increment => 200,
			  sim_rising_delay_increment => 200
		 )
		 port map (
			  datain => s_sig_from_ddio(i),
			  dataout => dataout(i),
			  delayctrlin => s_delay_ctrl(i*5+4 DOWNTO i*5)
		 );
	 end generate;

end architecture;
