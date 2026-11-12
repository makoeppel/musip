-- counters for hits per channel

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

entity asic_rate is
generic (
    num_ch       : natural;
    reset_1s     : boolean; -- reset counters every second
    reset_crc_1s : boolean--; -- reset crc counter every second
);
port (
    i_hit           : in    work.mutrig_hit_types.t_v_hit_presort;
    i_new_frame     : in    std_logic_vector(num_ch - 1 downto 0);
    i_crc_error     : in    std_logic_vector(num_ch - 1 downto 0);

    o_hit_cnt       : out   slv32_array_t(num_ch-1 downto 0);
    o_frames_cnt    : out   slv32_array_t(num_ch-1 downto 0);
    o_crcerror_cnt  : out   slv32_array_t(num_ch-1 downto 0);

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture rtl of asic_rate is

    signal hit_counter : slv32_array_t(num_ch-1 downto 0);
    signal err_counter : slv32_array_t(num_ch-1 downto 0);
    signal frm_counter : slv32_array_t(num_ch-1 downto 0);

    signal time_counter : std_logic_vector(31 downto 0);

begin

	process(i_clk, i_reset_n)
	begin
	if ( i_reset_n /= '1' ) then
		o_hit_cnt       <= (others => (others => '0'));
		o_crcerror_cnt  <= (others => (others => '0'));
		o_frames_cnt    <= (others => (others => '0'));
		hit_counter     <= (others => (others => '0'));
		err_counter     <= (others => (others => '0'));
		frm_counter     <= (others => (others => '0'));
		time_counter    <= (others => '0');
	--
	elsif rising_edge(i_clk) then
		hit_counter <= hit_counter;
		err_counter <= err_counter;
		frm_counter <= frm_counter;
		time_counter <= time_counter + '1';

		for i in i_hit'range loop
			if ( i_hit(i).valid = '1' ) then
				hit_counter(i) <= hit_counter(i) + '1';
			end if;
			if ( i_new_frame(i) = '1' ) then
				frm_counter(i) <= frm_counter(i) + '1';
			end if;
			if ( i_crc_error(i) = '1' ) then
				err_counter(i) <= err_counter(i) + '1';
			end if;
		end loop;
		if (reset_1s) then
			if ( time_counter = x"7735940" ) then
				o_hit_cnt      <= hit_counter;
				o_frames_cnt   <= frm_counter;

				hit_counter  <= (others => (others => '0') );
				frm_counter  <= (others => (others => '0'));
				time_counter <= (others => '0');
			end if;
		else
			o_hit_cnt <= hit_counter;
			o_frames_cnt <= frm_counter;
		end if;
		if (reset_crc_1s) then
			if ( time_counter = x"7735940" ) then
				o_crcerror_cnt <= err_counter;
			end if;
		else
			o_crcerror_cnt <= err_counter;
		end if;
	end if;
	end process;

end architecture;
