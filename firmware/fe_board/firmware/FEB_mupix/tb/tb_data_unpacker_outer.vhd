library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_data_unpacker_outer is
    -- no input/outputs for a testbench
end entity;

architecture arch of tb_data_unpacker_outer is
    signal reset_n             : std_logic;
    signal clk                 : std_logic := '0';
    signal datain              : std_logic_vector(7 downto 0);
    signal kin                 : std_logic;
    signal i_bad               : std_logic := '0';
    signal readyin             : std_logic := '0';
    signal i_mp_readout_mode   : std_logic_vector(31 downto 0) := X"00000000";
    signal o_ts                : std_logic_vector(10 downto 0);
    signal o_chip_ID           : std_logic_vector(5 downto 0);
    signal o_row               : std_logic_vector(7 downto 0);
    signal o_col               : std_logic_vector(7 downto 0);
    signal o_tot               : std_logic_vector(5 downto 0);
    signal o_hit_ena           : std_logic;
    signal o_coarsecounter     : std_logic_vector(23 downto 0);
    signal o_coarsecounter_ena : std_logic;
    signal o_counters          : std_logic_vector(255 downto 0);
    signal o_link              : std_logic_vector(3 downto 0); -- one-hot link encoding
    signal o_slowctrl_data     : std_logic_vector(31 downto 0);
    signal o_slowctrl_data_ena : std_logic := '0';
    signal i_slowctrl_empty    : std_logic := '0';

    --
    signal inputCounter : integer := 0; -- counts where in the input arrays we are
begin
    deviceUnderTest : entity work.data_unpacker_outer
    port map(
        reset_n             => reset_n,
        clk                 => clk,
        datain              => datain,
        kin                 => kin,
        i_bad               => i_bad,
        readyin             => readyin,
        i_mp_readout_mode   => i_mp_readout_mode,
        o_ts                => o_ts,
        o_chip_ID           => o_chip_ID,
        o_row               => o_row,
        o_col               => o_col,
        o_tot               => o_tot,
        o_hit_ena           => o_hit_ena,
        o_coarsecounter     => o_coarsecounter,
        o_coarsecounter_ena => o_coarsecounter_ena,
        o_counters          => o_counters,
        o_link              => o_link,
        o_slowctrl_data     => o_slowctrl_data,
        o_slowctrl_data_ena => o_slowctrl_data_ena,
        i_slowctrl_empty    => i_slowctrl_empty
    );

    clk <= not clk after 1 ns;
    reset_n <= '0', '1' after 8 ns;

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            --
        elsif rising_edge(clk) then
            -- Loop through each byte of the input and pump it into the device under test
            if inputCounter < work.test_data.linksel3_timerend2.recording1_datain'length then
                datain <= work.test_data.linksel3_timerend2.recording1_datain(inputCounter);
                kin <= work.test_data.linksel3_timerend2.recording1_kin(inputCounter);
                readyin <= '1';
            else
                readyin <= '0';
            end if;
            inputCounter <= inputCounter + 1;
        end if;
    end process;
end architecture;
