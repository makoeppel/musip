--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity hit_compactor is
  generic (
    g_WORD_WIDTH : positive := 64;
    g_WORDS_IN   : positive := 4;
    g_WORDS_OUT  : positive := 4
  );
  port (
    i_clk        : in  std_logic;
    i_reset_n    : in  std_logic;

    i_data       : in  std_logic_vector(g_WORDS_IN*g_WORD_WIDTH-1 downto 0);
    i_valid      : in  std_logic;

    o_data       : out std_logic_vector(g_WORDS_OUT*g_WORD_WIDTH-1 downto 0);
    o_valid      : out std_logic
  );
end entity;

architecture rtl of hit_compactor is

  constant c_INVALID_WORD : std_logic_vector(g_WORD_WIDTH-1 downto 0) := (others => '1');
  constant c_HOLD_DEPTH   : positive := g_WORDS_OUT + g_WORDS_IN - 1;

  type word_array_in_t   is array (0 to g_WORDS_IN-1) of std_logic_vector(g_WORD_WIDTH-1 downto 0);
  type word_array_out_t  is array (0 to g_WORDS_OUT-1) of std_logic_vector(g_WORD_WIDTH-1 downto 0);
  type hold_array_t      is array (0 to c_HOLD_DEPTH-1) of std_logic_vector(g_WORD_WIDTH-1 downto 0);

  signal hold_reg   : hold_array_t := (others => c_INVALID_WORD);
  signal hold_count : integer range 0 to c_HOLD_DEPTH := 0;

  signal o_data_r   : std_logic_vector(g_WORDS_OUT*g_WORD_WIDTH-1 downto 0) := (others => '1');
  signal o_valid_r  : std_logic := '0';

begin

  p_compact_and_buffer : process(i_clk, i_reset_n)
    variable in_words_v     : word_array_in_t;
    variable merged_v       : hold_array_t;
    variable next_hold_v    : hold_array_t;
    variable out_words_v    : word_array_out_t;
    variable total_count_v  : integer range 0 to c_HOLD_DEPTH;
    variable wr_idx_v       : integer range 0 to c_HOLD_DEPTH;
    variable out_flat_v     : std_logic_vector(g_WORDS_OUT*g_WORD_WIDTH-1 downto 0);
  begin
    if i_reset_n /= '1' then
      hold_reg   <= (others => c_INVALID_WORD);
      hold_count <= 0;
      o_data_r   <= (others => '1');
      o_valid_r  <= '0';

    elsif rising_edge(i_clk) then
      -- defaults
      merged_v      := (others => c_INVALID_WORD);
      next_hold_v   := (others => c_INVALID_WORD);
      out_words_v   := (others => c_INVALID_WORD);
      out_flat_v    := (others => '1');
      total_count_v := 0;
      wr_idx_v      := 0;

      -- unpack input bus
      for i in 0 to g_WORDS_IN-1 loop
        in_words_v(i) := i_data((i+1)*g_WORD_WIDTH-1 downto i*g_WORD_WIDTH);
      end loop;

      -- start with previously buffered words
      for i in 0 to c_HOLD_DEPTH-1 loop
        if i < hold_count then
          merged_v(total_count_v) := hold_reg(i);
          total_count_v := total_count_v + 1;
        end if;
      end loop;

      -- append valid input words from this cycle
      if i_valid = '1' then
        for i in 0 to g_WORDS_IN-1 loop
          if in_words_v(i) /= c_INVALID_WORD then
            merged_v(total_count_v) := in_words_v(i);
            total_count_v := total_count_v + 1;
          end if;
        end loop;
      end if;

      -- only emit when we have a full output word
      if total_count_v >= g_WORDS_OUT then
        for i in 0 to g_WORDS_OUT-1 loop
          out_words_v(i) := merged_v(i);
          out_flat_v((i+1)*g_WORD_WIDTH-1 downto i*g_WORD_WIDTH) := merged_v(i);
        end loop;

        o_data_r  <= out_flat_v;
        o_valid_r <= '1';

        -- keep leftover words in the holding register
        wr_idx_v := 0;
        for i in 0 to c_HOLD_DEPTH-1 loop
          if (i >= g_WORDS_OUT) and (i < total_count_v) then
            next_hold_v(wr_idx_v) := merged_v(i);
            wr_idx_v := wr_idx_v + 1;
          end if;
        end loop;

        hold_reg   <= next_hold_v;
        hold_count <= total_count_v - g_WORDS_OUT;

      else
        -- not enough valid words yet, just buffer them
        o_data_r  <= (others => '1');
        o_valid_r <= '0';

        for i in 0 to c_HOLD_DEPTH-1 loop
          if i < total_count_v then
            next_hold_v(i) := merged_v(i);
          end if;
        end loop;

        hold_reg   <= next_hold_v;
        hold_count <= total_count_v;
      end if;
    end if;
  end process;

  o_data  <= o_data_r;
  o_valid <= o_valid_r;

end architecture;
