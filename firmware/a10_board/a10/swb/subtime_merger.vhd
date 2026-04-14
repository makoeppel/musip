--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;


entity subtime_merger is
  generic (
    g_LINK_N : positive := 4;
    g_N_HITTIME : positive := 16;
    g_N_SUBTIME_BITS : positive := 3;
    g_DATA_WIDTH : positive := 64--;
  );
  port (
    i_data          : in  slv64_array_t(g_LINK_N-1 downto 0);
    i_valid         : in  std_logic_vector(g_LINK_N-1 downto 0);

    out_data        : out std_logic_vector(g_LINK_N*g_DATA_WIDTH-1 downto 0);
    out_data_valid  : out std_logic;

    o_word_cnt      : out std_logic_vector(63 downto 0);
    o_fifo_full_cnt : out std_logic_vector(31 downto 0);

    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic--;
  );
end entity;

architecture rtl of subtime_merger is

  signal cur_hittime : slv4_array_t(g_LINK_N-1 downto 0);
  signal cur_subhdr : slv7_array_t(g_LINK_N-1 downto 0);

  -- fifo(subtime, hittime, lane)
  type word_fifo_array_t is array(0 to 2**g_N_SUBTIME_BITS-1, 0 to g_N_HITTIME-1, 0 to g_LINK_N-1) of std_logic_vector(g_DATA_WIDTH-1 downto 0);
  type sl_fifo_array_t is array(0 to 2**g_N_SUBTIME_BITS-1, 0 to g_N_HITTIME-1, 0 to g_LINK_N-1) of std_logic;
  type out_array_t is array (0 to g_LINK_N-1) of std_logic_vector(g_DATA_WIDTH-1 downto 0);
  type subheader_time_array_t is array (0 to 2**g_N_SUBTIME_BITS-1) of std_logic_vector(g_LINK_N-1 downto 0);
  type subheader_array_t is array (0 to g_LINK_N-1) of std_logic_vector(g_N_SUBTIME_BITS-1 downto 0);

  -- FIFO signals
  signal fifo_din, fifo_dout : word_fifo_array_t;
  signal fifo_wr_en, fifo_rd_en, fifo_full, fifo_empty : sl_fifo_array_t;

  -- subtime_changed(win)(lane) = lane has moved away from this window
  signal subtime_changed : subheader_time_array_t := (others => (others => '0'));
  signal advance_window_next : std_logic := '0';
  signal cur_subtime_reading_window : unsigned(g_N_SUBTIME_BITS-1 downto 0) := (others => '0');
  signal last_subtime_window : subheader_array_t;

  -- output
  signal out_data_arr_r, out_data_arr_next : out_array_t := (others => (others => '0'));
  signal out_valid_r, out_valid_next : std_logic := '0';

  signal word_cnt : std_logic_vector(63 downto 0);
  signal fifo_full_cnt : std_logic_vector(31 downto 0);

begin

  ----------------------------------------------------------------------------
  -- Extract subtime + hittime
  ----------------------------------------------------------------------------
  p_extract : process(all)
  begin
    for i in 0 to g_LINK_N-1 loop
      cur_subhdr(i) <= i_data(i)(10 downto 4);
      cur_hittime(i) <= i_data(i)(3 downto 0);
    end loop;
  end process;

  ----------------------------------------------------------------------------
  -- Write side: one write per lane per cycle
  ----------------------------------------------------------------------------
  p_write_comb : process(all)
  begin
    fifo_wr_en <= (others => (others => (others => '0')));
    fifo_din <= (others => (others => (others => (others => '0'))));

    for i in 0 to g_LINK_N-1 loop
      if i_valid(i) = '1' then
        fifo_wr_en(to_integer(unsigned(cur_subhdr(i)(g_N_SUBTIME_BITS-1 downto 0))), to_integer(unsigned(cur_hittime(i))), i) <= '1';
        fifo_din(to_integer(unsigned(cur_subhdr(i)(g_N_SUBTIME_BITS-1 downto 0))), to_integer(unsigned(cur_hittime(i))), i) <= i_data(i);
      end if;
    end loop;
  end process;

  ----------------------------------------------------------------------------
  -- Read selector for show-ahead FIFO
  -- This is combinational so rd_en is high BEFORE the edge.
  ----------------------------------------------------------------------------
  p_read_comb : process(all)
    variable cur_win_v         : integer range 0 to 2**g_N_SUBTIME_BITS;
    variable idx_v             : integer range 0 to g_LINK_N;
    variable found_any_v       : boolean;
    variable any_left_after_v  : boolean;
    variable selected_v        : sl_fifo_array_t;
    variable out_v             : out_array_t;
    variable still_nonempty_v  : boolean;
  begin
    selected_v        := (others => (others => (others => '0')));
    out_v             := (others => (others => '0'));
    out_valid_next    <= '0';
    advance_window_next <= '0';

    cur_win_v    := to_integer(unsigned(cur_subtime_reading_window));
    idx_v        := 0;
    found_any_v  := false;

    if (and_reduce(subtime_changed(cur_win_v)) = '1') then

      -- select up to g_LINK_N hits in priority order
      for h in 0 to g_N_HITTIME-1 loop
        exit when idx_v = g_LINK_N;
        for lane in 0 to g_LINK_N-1 loop
          exit when idx_v = g_LINK_N;

          if fifo_empty(cur_win_v, h, lane) = '0' then
            out_v(idx_v) := fifo_dout(cur_win_v, h, lane);
            selected_v(cur_win_v, h, lane) := '1';
            idx_v := idx_v + 1;
            found_any_v := true;
          end if;
        end loop;
      end loop;

      -- Check whether anything would remain after these pops
      any_left_after_v := false;
      still_nonempty_v := false;

      for h in 0 to g_N_HITTIME-1 loop
        for lane in 0 to g_LINK_N-1 loop
          still_nonempty_v := (fifo_empty(cur_win_v, h, lane) = '0');

          -- if non-empty and NOT selected this cycle, it remains
          if still_nonempty_v and (selected_v(cur_win_v, h, lane) = '0') then
            any_left_after_v := true;
          end if;
        end loop;
      end loop;

      out_data_arr_next <= out_v;

      if idx_v = g_LINK_N then
        out_valid_next <= '1';
      elsif found_any_v and (not any_left_after_v) then
        -- flush tail packet
        out_valid_next     <= '1';
        advance_window_next <= '1';
      elsif (not found_any_v) then
        -- nothing there at all, move on
        advance_window_next <= '1';
      end if;

    else
      out_data_arr_next    <= (others => (others => '0'));
      out_valid_next       <= '0';
      advance_window_next  <= '0';
    end if;

    fifo_rd_en <= selected_v;
  end process;

  ----------------------------------------------------------------------------
  -- Register outputs and update read window state
  ----------------------------------------------------------------------------
  p_read_seq : process(i_clk, i_reset_n)
  begin
  if ( i_reset_n /= '1' ) then
    out_data_arr_r <= (others => (others => '0'));
    out_valid_r <= '0';
    cur_subtime_reading_window <= (others => '0');
    last_subtime_window <= (others => (others => '0'));
    subtime_changed <= (others => (others => '0'));
    word_cnt <= (others => '0');
    fifo_full_cnt <= (others => '0');
    --
  elsif rising_edge(i_clk) then
      out_data_arr_r  <= out_data_arr_next;
      out_valid_r     <= out_valid_next;

      if ( out_valid_next = '1' ) then
        word_cnt <= word_cnt + '1';
      end if;

      -- track if all inputs have moved to a new subheader
      for i in 0 to g_LINK_N-1 loop
        if i_valid(i) = '1' then
          if (last_subtime_window(i) /= cur_subhdr(i)(g_N_SUBTIME_BITS-1 downto 0)) then
            -- mark OLD window complete for this lane
            subtime_changed(to_integer(unsigned(last_subtime_window(i))))(i) <= '1';
          end if;
          last_subtime_window(i) <= cur_subhdr(i)(g_N_SUBTIME_BITS-1 downto 0);
        end if;
      end loop;

      if (and_reduce(subtime_changed(to_integer(unsigned(cur_subtime_reading_window)))) = '1' and advance_window_next = '1') then
        -- current window finished
        subtime_changed(to_integer(unsigned(cur_subtime_reading_window))) <= (others => '0');

        if cur_subtime_reading_window = 7 then
          cur_subtime_reading_window <= (others => '0');
        else
          cur_subtime_reading_window <= cur_subtime_reading_window + 1;
        end if;
      end if;
  end if;
  end process;

  ----------------------------------------------------------------------------
  -- Pack outputs
  ----------------------------------------------------------------------------
  gen_pack : for i in 0 to g_LINK_N-1 generate
    out_data((i+1)*g_DATA_WIDTH-1 downto i*g_DATA_WIDTH) <= out_data_arr_r(i);
  end generate;

  out_data_valid <= out_valid_r;
  o_fifo_full_cnt <= fifo_full_cnt;
  o_word_cnt <= word_cnt;

  ----------------------------------------------------------------------------
  -- FIFO instances
  -- Assumed interface for a SHOW-AHEAD FIFO:
  --   dout shows front word whenever empty='0'
  --   rd_en pops on rising edge
  ----------------------------------------------------------------------------
  gen_fifo_sub : for s in 0 to 2**g_N_SUBTIME_BITS-1 generate
    gen_fifo_hit : for h in 0 to g_N_HITTIME-1 generate
      gen_fifo_lane : for l in 0 to g_LINK_N-1 generate
        u_fifo : entity work.ip_dcfifo_v2
        generic map (
            g_ADDR_WIDTH => 8,
            g_DATA_WIDTH => g_DATA_WIDTH--,
        )
        port map (
            i_we        => fifo_wr_en(s, h, l),
            i_wdata     => fifo_din(s, h, l),
            o_wfull     => fifo_full(s, h, l),
            i_wclk      => i_clk,

            i_rack      => fifo_rd_en(s, h, l),
            o_rdata     => fifo_dout(s, h, l),
            o_rempty    => fifo_empty(s, h, l),
            i_rclk      => i_clk,

            i_reset_n   => i_reset_n--,
        );
      end generate;
    end generate;
  end generate;

end architecture;