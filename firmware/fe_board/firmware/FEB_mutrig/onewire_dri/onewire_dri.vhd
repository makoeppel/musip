library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.feb_sc_registers.all;
use work.mudaq.all;

entity onewire_dri is
port (
    -- module clock and ctrl
    i_clk_125   : in    std_logic; -- input clock of 125MHz
    i_rst_n     : in    std_logic; -- input reset signal reset on low

    -- module signals
    io_dq       : inout std_logic; -- output to 18B20 DQ pin 2v5.  Will be converted by DAB to 3.3V.
    o_reading   : out   std_logic_vector(19 downto 0)--;
);
end entity;

architecture rtl of onewire_dri is

    -- command codes of DS18D20
    constant ROM_SKIP_CMD_c : integer := 16#CC#;
    constant CONVERT_CMD_c  : integer := 16#44#;
    constant READ_TEMP_c    : integer := 16#BE#;

    -- clock and counters
    signal clk_1us          : std_logic;
    signal cnt_1us_en       : std_logic;
    signal cnt_tmp          : std_logic_vector(7 downto 0);
    signal cnt_1us          : unsigned(19 downto 0);
    signal bit_cnt          : integer := 0; -- from 0 to 2^4-1(15)
    signal byte_cnt         : integer := 0;
    signal cmd_cnt          : integer := 0;

    -- state machine flags
    type state_t is (init,rom_skip,wr_byte,temp_convert,delay,rd_temp,rd_byte,idle);--, rom_skip, wr_byte, temp_convert, delay, rd_temp, rd_byte);
    signal curr_st          : state_t;--std_logic_vector(2 downto 0);
    signal next_st          : state_t;--std_logic_vector(2 downto 0);
    type flow_t is ( s0, s1, s2, s3 ,s4, s5, s6 );
    signal flow_step        : flow_t := s0;

    signal init_done_flg    : std_logic := '0';
    signal conv_done_flg    : std_logic := '0';
    signal wr_done_flg      : std_logic := '0';
    signal rd_done_flg      : std_logic := '0';
    signal timeout_flg      : std_logic := '0';
    signal present_flg      : std_logic := '0';

    signal FSM_err          : std_logic := '0';

    -- registers
    signal wr_data          : std_logic_vector(7 downto 0);

    type schpad_DS18B20_t is array (0 to 8) of std_logic_vector(7 downto 0);
    signal rd_data          : schpad_DS18B20_t;
    signal rd_data_bit      : std_logic;
    signal CRC_lfsr         : std_logic_vector(7 downto 0);
    signal CRC_en           : std_logic := '1';
    signal CRC_rst_n        : std_logic := '1';
    signal crc_err          : std_logic := '0';

    -- tri-state I/O to DS18B20
    signal dq_z             : std_logic;

begin

    -- Assignment
    io_dq <= dq_z;
    o_reading(19 downto 17) <= "000";
    o_reading(16) <= crc_err;

    -- 1 MHz clock generator
    e_clk_1_Mhz_inst0 : entity work.clkdiv
    generic map ( g_N => 125 )
    port map ( o_clk => clk_1us, i_reset_n => i_rst_n, i_clk => i_clk_125);

    -- 1 MHz counter: rst in sysclk
    process(i_clk_125, i_rst_n, clk_1us)
    begin
    if rising_edge(i_clk_125) then
        if (i_rst_n /= '1' or cnt_1us_en /= '1') then
            cnt_1us <= (others => '0');
            cnt_tmp <= (others => '0');
        else
            cnt_tmp <= cnt_tmp + 1;
        end if;
        if (cnt_tmp = "01111100") then -- counted to 125(-1)
            cnt_1us <= cnt_1us + 1;
            cnt_tmp <= (others => '0');
        end if;
    end if;
    end process;

    -- CRC checker entity: 8-bit, poly 'x^8 + x^5 + x^4 + 1'
    e_checker_inst0 : entity work.checker_crc8_maxim
    port map (
        i_din => rd_data_bit,
        o_lfsr => CRC_lfsr,
        i_CRC_en => CRC_en,
        i_rst_n => i_rst_n and CRC_rst_n,
        i_clk => clk_1us--,
    );

    -- initialize the state machine
    process(i_clk_125, i_rst_n)
    begin
    if(i_rst_n /= '1') then
        curr_st <= init;
    elsif rising_edge(i_clk_125) then
        curr_st <= next_st;
    end if;
    end process;

    -- state machine: communication handler
    process(clk_1us, i_rst_n)
    begin
    if (i_rst_n /= '1') then
        init_done_flg <= '0';
        conv_done_flg <= '0';
        wr_done_flg <= '0';
        rd_done_flg <= '0';
        timeout_flg <= '0';
        present_flg <= '0';
        FSM_err <= '0';
        crc_err <= '0';
        dq_z <= '1';
        next_st <= init;

        flow_step <= s0;
        bit_cnt <= 0;
        byte_cnt <= 0;
        cmd_cnt <= 0;
        cnt_1us_en <= '0';
        rd_data <=  (OTHERS => (OTHERS => '0'));
        CRC_en <= '1';
        CRC_rst_n  <= '1';

    elsif rising_edge(clk_1us) then
        case curr_st is
        -- initialization pulse and slave response
        when init =>
            case flow_step is
            when s0 =>
                cnt_1us_en <= '0';
                flow_step <= s1;
            when s1 => -- master pull low for 500us, then release the line
                cnt_1us_en <= '1';
                if (cnt_1us < to_unsigned(500,cnt_1us'length)) then
                    dq_z <= '0';
                else
                    cnt_1us_en <='0';
                    dq_z <= 'Z';
                    flow_step <= s2;
                end if;
            when s2 =>
                cnt_1us_en <= '0';
                flow_step <=s3; -- wait for counter to reset
            when s3=> -- master release the line, then wait for 45us
                cnt_1us_en<= '1';
                if (cnt_1us < to_unsigned(45,cnt_1us'length)) then
                    dq_z <= 'Z';
                    flow_step <= s3;
                else
                    cnt_1us_en <= '0';
                    flow_step <= s4;
                end if;
            when s4 =>
                cnt_1us_en <= '0';
                flow_step <=s5; -- wait for counter to reset
            when s5 => -- master detect the slave response
                cnt_1us_en<= '1';
                dq_z <= 'Z';
                if (io_dq = '0') then -- detected DS18B20 presense pulse
                    present_flg <= '1'; -- detected flag
                    timeout_flg <= '0'; -- clear init-timeout flag
                    flow_step <= s6;
                    cnt_1us_en <= '0';
                else -- wait until pulse of timeout at 5000us
                    flow_step <= s5;
                    if (cnt_1us > to_unsigned(5000,cnt_1us'length)) then
                        flow_step <= s6;
                        timeout_flg <= '1'; -- init-timeout flag
                        cnt_1us_en <= '0';
                    end if;
                end if;
            when s6 => -- wait for init to be done
                if (timeout_flg = '1') then
                    cnt_1us_en <= '1';
                    flow_step <= s6;
                    if (cnt_1us = to_unsigned(1000000,cnt_1us'length)) then --wait 1s to re-init
                        flow_step <= s0;
                    end if;
                else
                    cnt_1us_en <= '1';
                    if (cnt_1us > to_unsigned(500,cnt_1us'length)) then -- wait 500us for presense rx '0' to be done. ~120us after 30us release
                        next_st <= rom_skip; -- exit init state
                        init_done_flg <= '1';
                        -- restore reg
                        cnt_1us_en <= '0';
                        flow_step <= s0;
                    end if;
                end if;
            when others => -- default
                flow_step <= s0;
            end case;

        when rom_skip =>
            wr_data <= std_logic_vector(to_unsigned(ROM_SKIP_CMD_c,wr_data'length));
            bit_cnt <= 0;
            dq_z <= 'Z';
            flow_step <= s0;
            next_st <= wr_byte;
            cnt_1us_en <= '0';
            wr_done_flg <= '0';

        when wr_byte => -- master tx: starting from LSB
            if (bit_cnt <= 7) then
                wr_done_flg <= '0';
                case flow_step is
                when s0 =>
                    dq_z <= '0';
                    cnt_1us_en <= '1';
                    flow_step <=s1;
                when s1 =>
                    if (cnt_1us < to_unsigned(60+20,cnt_1us'length)) then -- tx bit between 60-120 us
                        dq_z <= wr_data(bit_cnt);
                    elsif (cnt_1us < to_unsigned(60+20+10,cnt_1us'length)) then -- release for another 10us
                        dq_z <= 'Z';
                    else -- write another bit
                        bit_cnt <= bit_cnt + 1;
                        flow_step <= s0;
                        cnt_1us_en <= '0';
                        if (bit_cnt = 7) then -- if last bit, increase cmd_cnt
                            cmd_cnt <= cmd_cnt + 1;
                        end if;
                    end if;
                when others =>
                    flow_step <=s0;
                end case;
            else -- finish write byte
                case flow_step is
                when s0 =>
                    cnt_1us_en <= '1';
                    if (cnt_1us > to_unsigned(100,cnt_1us'length)) then -- wait for 100us after each command byte write
                        flow_step <= s1;
                        cnt_1us_en <= '0';
                    end if;
                when s1 =>
                    flow_step <= s0;
                    bit_cnt <= 0;
                    cnt_1us_en <= '0';
                    wr_done_flg <= '1';
                    if (cmd_cnt = 1) then
                        next_st <= temp_convert;
                    elsif (cmd_cnt = 2) then
                        next_st <= delay;
                    elsif (cmd_cnt = 3) then
                        next_st <= rd_temp;
                    else
                        next_st <= rd_byte;
                    end if;
                when others =>
                    flow_step <= s0;
                end case;
            end if;

        when temp_convert =>
            wr_data <= std_logic_vector(to_unsigned(CONVERT_CMD_c,wr_data'length));
            wr_done_flg <= '0';
            next_st <= wr_byte;

        when delay =>
            cnt_1us_en <= '1';
            dq_z <= '1'; -- pull high release during temp conversion
            if (cnt_1us = to_unsigned(800000,cnt_1us'length)) then -- delay 800ms
                cnt_1us_en <= '0';
                conv_done_flg <= '1';
                init_done_flg <= '0';
                next_st <= init; -- goto rd_temp state
            end if;

        when rd_temp =>
            wr_data <= std_logic_vector(to_unsigned(READ_TEMP_c,wr_data'length));
            wr_done_flg <= '0';
            next_st <= wr_byte;

        when rd_byte => -- master rx: LSB first from byte 0 to 8
            case flow_step is
            when s0 => -- wait 500 us after sending READ_TEMP_c command
                if (wr_done_flg = '1') then
                    cnt_1us_en <= '1';
                    if (cnt_1us >= to_unsigned(500,cnt_1us'length)) then
                        flow_step <= s1;
                        bit_cnt <= 0; -- reset its counters and flags
                        byte_cnt <= 0;
                        wr_done_flg <= '0';
                    end if;
                elsif (bit_cnt = 0) then -- only wait for 100us between bytes
                    cnt_1us_en <= '1';
                    if (cnt_1us >= to_unsigned(100,cnt_1us'length)) then
                        flow_step <= s1;
                    end if;
                else -- only wait for 20us between bits
                    cnt_1us_en <= '1';
                    if (cnt_1us >= to_unsigned(20,cnt_1us'length)) then
                        flow_step <= s1;
                    end if;
                end if;
            when s1 => -- reset counter
                cnt_1us_en <= '0';
                flow_step <= s2;
            when s2 => -- pull low 5us: master start read time slot
                cnt_1us_en <= '1';
                dq_z <= '0';
                if (cnt_1us >= to_unsigned(5,cnt_1us'length)) then
                    flow_step <= s3;
                end if;
            when s3 =>
                dq_z <= 'Z';
                if (cnt_1us = to_unsigned(15,cnt_1us'length)) then -- master rx samples at 15us after read time slot started
                    rd_data(byte_cnt)(bit_cnt) <= io_dq;
                    flow_step <= s4;
                end if;
            when s4 =>
                if (cnt_1us > to_unsigned(60,cnt_1us'length)) then -- wait until read time slot ends
                    flow_step <= s0;
                    cnt_1us_en <= '0';
                    if (bit_cnt < 7) then
                        bit_cnt <= bit_cnt + 1;
                    elsif (bit_cnt = 7) then
                        byte_cnt <= byte_cnt + 1;
                        bit_cnt <= 0;
                        if (byte_cnt = 8) then -- byte 8 - bit 7
                            rd_done_flg <= '1';
                            next_st <= idle;
                            flow_step <= s0;
                            cnt_1us_en <= '0';
                            dq_z <= 'Z';
                        end if;
                    end if;
                end if;
            when others =>
                flow_step <= s0;
            end case;

        when idle =>
            case flow_step is
            when s0 =>
                o_reading(7 downto 0) <= rd_data(0)(7 downto 0);
                o_reading(15 downto 8) <= rd_data(1)(7 downto 0);
                init_done_flg <= '0';
                wr_done_flg <= '0';
                dq_z <= 'Z';
                bit_cnt <= 0;
                byte_cnt <= 0;
                cmd_cnt <= 0;
                cnt_1us_en <= '0';
                CRC_rst_n <= '0';
                flow_step <= s1;
            when s1 => -- display of rd_data
                CRC_rst_n <= '1';
                CRC_en <= '0';
                flow_step <= s2;
                CRC_rst_n <= '0'; -- reset the CRC check entity's reg
                bit_cnt <= 0;
                byte_cnt <= 0;
            when s2 =>
                CRC_rst_n <= '1';
                CRC_en <= '1';
                if (byte_cnt = 9) then -- XXX|end at byte 7 last bit, before CRC byt|XXX
                    flow_step <= s3;
                    -- CRC pass flag: 0=pass, 1=fail
                    crc_err <= CRC_lfsr(7) or CRC_lfsr(6) or CRC_lfsr(5) or
                               CRC_lfsr(4) or CRC_lfsr(3) or CRC_lfsr(2) or
                               CRC_lfsr(1) or CRC_lfsr(0);
                else
                    rd_data_bit <= rd_data(byte_cnt)(bit_cnt); -- pass into the shift_reg
                    if (bit_cnt < 7) then -- update counters
                        bit_cnt <= bit_cnt + 1;
                    elsif (bit_cnt = 7) then
                        byte_cnt <= byte_cnt + 1;
                        bit_cnt <= 0;
                    end if;
                end if;

            when s3 =>
                init_done_flg <= '0';
                conv_done_flg <= '0';
                wr_done_flg <= '0';
                rd_done_flg <= '0';
                FSM_err <= '0';
                dq_z <= '1';
                next_st <= init;
                flow_step <= s0;
                bit_cnt <= 0;
                byte_cnt <= 0;
                cmd_cnt <= 0;
                cnt_1us_en <= '0';
                rd_data <=  (OTHERS => (OTHERS => '0'));
                CRC_en <= '1';
                CRC_rst_n  <= '1';
            when others =>
                flow_step <= s0;
            end case;

        when others =>
            next_st <= init;
        end case;
    end if;
    end process;

end architecture;
