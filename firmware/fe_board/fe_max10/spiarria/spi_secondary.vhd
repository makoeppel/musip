library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_secondary is
generic (
    g_CS_LEVEL : std_logic; -- CS sensitive level
    g_DELAY : integer := 0; -- time diff between tx/rx data
    g_RW_READ : std_logic; -- when (r/w = g_RW_READ) => read || when (r/w != g_RW_READ) => write
    g_LANES : integer--; number of possible lanes (2 or 4)
);
port (
    ------ Max Data --register interface
    o_Max_rw    : out   std_logic;
    o_Max_data  : out   std_logic_vector(31 downto 0);
    o_Max_addr  : out   std_logic_vector(6 downto 0);
    o_b_addr    : out   std_logic_vector(7 downto 0); -- command addr
    --o_Ar_done   : out   std_logic;
    i_Max_data  : in    std_logic_vector(31 downto 0);

    ------ SPI
    i_SPI_cs    : in    std_logic;
    i_SPI_clk   : in    std_logic;
    io_SPI_mosi : inout std_logic;
    io_SPI_miso : inout std_logic;
    io_SPI_D1   : inout std_logic;
    io_SPI_D2   : inout std_logic;
    io_SPI_D3   : inout std_logic--;
);
end entity;

architecture rtl of spi_secondary is

    type State_type is (
        Adrr , W_Data , S_DELAY , R_Data,
        Idle
    );
    type s_regs is Array (0 to (g_LANES-1)) of std_logic_vector(((32/g_LANES)-1) downto 0);
    type s_addr_regs is Array (0 to (g_LANES-1)) of std_logic_vector(((16/g_LANES)-1) downto 0);

    -- state and arrays
    signal State            : State_type;
    signal s_r_reg_16       : s_regs; --shift register read SPI Slave
    signal s_reg_16         : s_regs; --shift register write SPI Slave
    signal s_addr_reg       : s_addr_regs; -- shift address register

    -- input signal -> vector for 2/4 lanes
    signal io_SPI_D         : std_logic_vector(3 downto 0);
    signal cnt_8            : integer range 0 to (16/g_LANES); -- addr  cnt
    signal cnt_del          : integer range 0 to 64; -- delay cnt
    -- read cnt needs until int 17 but cnts to 16 for 2 lines
    -- read cnt needs until int 9 but cnts to 8 for 4 lines
    signal cnt_16           : integer range 0 to (32/g_LANES)+1 := 0;
    signal cnt_words        : unsigned (6 downto 0) := "0000000";
    signal cnt_words_test   : std_logic_vector(6 downto 0);
    signal setup            : std_logic := '1';
    signal addr_offset      : unsigned(6 downto 0);
    signal aktiv            : std_logic;
    signal rw               : std_logic := '0';
    signal ss_del           : std_logic;

    -- arria register
    signal i_command        : std_logic_vector(15 downto 0); --[15-9] empty ,[8-2] cnt , [1] rw , [0] aktiv,

begin

    assert ( true
        and ( g_LANES = 2 or g_LANES = 4 )
    ) severity failure;

    --commands
    rw_Max_2 : if ( g_LANES = 2 ) generate
        rw          <= s_addr_reg(1)(0);
        o_b_addr    <= s_addr_reg(1)(7 downto 0);
        io_SPI_D2   <= 'Z';
        io_SPI_mosi <= 'Z';
    end generate;

    rw_Max : if ( g_LANES = 4 ) generate
        o_b_addr(7 downto 4)    <= s_addr_reg(2)(3 downto 0);
        o_b_addr(3 downto 0)    <= s_addr_reg(3)(3 downto 0);
        rw                      <= s_addr_reg(3)(0);
    end generate;

    -- 2/4 lane Imput
    io_SPI_D(0) <= io_SPI_mosi;
    io_SPI_D(1) <= io_SPI_D1; -- when State /= R_Data;
    io_SPI_D(2) <= io_SPI_D2; --when State /= R_Data;
    io_SPI_D(3) <= io_SPI_miso; --when State /= R_Data;
    io_SPI_mosi <= s_r_reg_16(0)((32/g_LANES)-1) when State = R_Data else 'Z';
    io_SPI_D1   <= s_r_reg_16(1)((32/g_LANES)-1) when State = R_Data else 'Z';

    quad : if ( g_LANES = 4 ) generate
        io_SPI_D2   <= s_r_reg_16(2)((32/g_LANES)-1) when State = R_Data else 'Z';
        io_SPI_miso <= s_r_reg_16(3)((32/g_LANES)-1) when State = R_Data else 'Z';
    end generate;

    process(i_SPI_clk, i_SPI_cs)
    begin
    if ( i_SPI_cs /= g_CS_LEVEL ) then
        State       <= Idle;
        cnt_16      <= 1;
        cnt_8       <= 2;
        cnt_del     <= 0;
        o_Max_data  <= X"00000000";
        addr_offset <= "0000000";
        o_Max_rw    <= g_RW_READ;
    elsif rising_edge(i_SPI_clk) then
        o_Max_addr <= std_logic_vector(addr_offset);
        case State is
        when Idle =>
            setup <= '0';
            for i in 0 to (g_LANES -1) loop
                s_addr_reg(i)(0) <= io_SPI_D(i);
            end loop;
            if ( setup = '0' ) then
                -- shift reg (0->15)
                for i in  0 to (g_LANES -1) loop
                    for j in  1 to (16/g_LANES)-1 loop
                        s_addr_reg(i)(j) <= s_addr_reg(i)(j-1);
                    end loop;
                end loop;
                setup <= '1';
                State <= Adrr;
            end if;
            cnt_16      <= 1;
            cnt_8       <= 2;
            cnt_del     <= 0;
            o_Max_data  <= X"00000000";
            addr_offset <= "0000000";
            o_Max_rw    <= g_RW_READ;

        when Adrr =>
            if ( cnt_8 /= (16/g_LANES) ) then
                cnt_8 <= cnt_8 + 1;
                for i in 0 to (g_LANES -1) loop
                    s_addr_reg(i)(0) <= io_SPI_D(i);
                end loop;
                -- shift reg (0->15)
                for i in 0 to (g_LANES -1) loop
                    for j in 1 to (16/g_LANES)-1 loop
                        s_addr_reg(i)(j) <= s_addr_reg(i)(j-1);
                    end loop;
                end loop;
            elsif ( rw = g_RW_READ ) then
                State <= S_DELAY;
            else
                State <= W_Data;
                for i in 0 to (g_LANES -1) loop
                    s_reg_16(i)(0) <= io_SPI_D(i);
                end loop;
            end if;

        when W_Data =>
            cnt_16      <= cnt_16 +1;
            o_Max_rw    <= g_RW_READ;
            for i in 0 to (g_LANES-1) loop
                s_reg_16(i)(0) <= io_SPI_D(i);
            end loop;
            -- shift reg (0->15)
            for i in  0 to (g_LANES -1) loop
                for j in  1 to (32/g_LANES)-1 loop
                    s_reg_16(i)(j) <= s_reg_16(i)(j-1);
                end loop;
            end loop;
            if ( cnt_16 = (32/g_LANES) ) then
                cnt_16 <= 1;
                addr_offset <= addr_offset + 1;
                o_Max_rw <= not g_RW_READ;
                for i in  0 to (g_LANES -1) loop
                    o_Max_data((31-32/g_LANES*i) downto (32-32/g_LANES*(i+1))) <= s_reg_16(i);
                end loop;
            end if;

        when S_DELAY =>
            if ( cnt_del /= g_DELAY ) then
                cnt_del <= cnt_del + 1;
            else
                State <= R_Data;
                for i in  0 to (g_LANES -1) loop
                    s_r_reg_16(i) <= i_Max_data((31-32/g_LANES*i) downto (32-32/g_LANES*(i+1)));
                end loop;
                addr_offset <= addr_offset +1;
            end if;

        when R_Data =>
            cnt_16 <= cnt_16 +1;
            for i in  0 to (g_LANES -1) loop
                for j in  1 to (32/g_LANES)-1 loop
                    s_r_reg_16(i)(j) <= s_r_reg_16(i)(j-1);
                end loop;
            end loop;
            if ( cnt_16 = (32/g_LANES) ) then
                for i in  0 to (g_LANES -1) loop
                    s_r_reg_16(i) <= i_Max_data((31-32/g_LANES*i) downto (32-32/g_LANES*(i+1)));
                end loop;
                addr_offset <= addr_offset + 1;
                cnt_16 <= 1;
            end if;

        when others =>
            State       <= Idle;
            setup       <= '1';
            cnt_16      <= 1;
            cnt_8       <= 2;
            cnt_del     <= 0;
            o_Max_data  <= X"00000000";
            addr_offset <= "0000000";
            o_Max_rw    <= g_RW_READ;
        end case;
    end if;
    end process;

end architecture;
