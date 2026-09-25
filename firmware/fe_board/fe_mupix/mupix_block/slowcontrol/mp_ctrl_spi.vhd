----------------------------------------------------------------------------
-- Mupix SPI
-- M. Mueller
-- JAN 2022

-- assembles correct sequence of 29 bit words for mp_ctrl_direct_spi.vhd
-- reads single bits out of the config mirrors
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.mupix.all;
use work.mudaq.all;
use work.mupix_registers.all;

entity mp_ctrl_spi is
generic (
    g_CHIPS_PER_SPI: positive := 4--;
);
port (
    -- connections to config storage
    o_read                  : out mp_conf_array_in(g_CHIPS_PER_SPI-1 downto 0);
    i_data                  : in  mp_conf_array_out(g_CHIPS_PER_SPI-1 downto 0);

    -- connections to direct spi entity
    o_data_to_direct_spi    : out std_logic_vector(31 downto 0);
    o_data_to_direct_spi_we : out std_logic;
    i_direct_spi_fifo_full  : in  std_logic;
    i_direct_spi_fifo_empty : in  std_logic;
    o_spi_chip_selct_mask   : out std_logic_vector(g_CHIPS_PER_SPI-1 downto 0);

    i_run_test              : in  std_logic;

    i_reset_n               : in  std_logic;
    i_clk                   : in  std_logic--;
);
end entity;

architecture RTL of mp_ctrl_spi is

    signal vdac_rdy             : std_logic_vector(g_CHIPS_PER_SPI-1 downto 0);
    signal bias_rdy             : std_logic_vector(g_CHIPS_PER_SPI-1 downto 0);
    signal conf_rdy             : std_logic_vector(g_CHIPS_PER_SPI-1 downto 0);
    signal tdac_rdy             : std_logic_vector(g_CHIPS_PER_SPI-1 downto 0);

    signal chip_is_writing      : std_logic_vector(g_CHIPS_PER_SPI-1 downto 0);
    signal chip_is_writing_int  : integer range 0 to g_CHIPS_PER_SPI-1;
    signal reg_is_writing       : std_logic_vector(3 downto 0);

    type mp_spi_state_type      is (init, test, test2, test3, idle, waiting, load_bits, writing, shift_col_by_one, load, pre_load, rem_load);
    signal mp_spi_state         : mp_spi_state_type;
    type mp_spi_clk_state_type  is (zero1, clk1, zero2, clk2, zero3);
    signal mp_spi_clk_state     : mp_spi_clk_state_type;
    type col_shift_state_type   is (zero1, clk1, zero2, clk2, zero3, load, write1, write2, zero4);
    signal col_shift_state      : col_shift_state_type;

    signal spi_data_vector      : reg32array(g_CHIPS_PER_SPI-1 downto 0);

    signal vdac                 : std_logic;
    signal bias                 : std_logic;
    signal conf                 : std_logic;
    signal tdac                 : std_logic;
    signal col                  : std_logic;


    -- bits in 29-bit spi reg
    -- "documentation" in Mupix10.hpp, Mupix8_daq repo
    signal Sin_Bias             : std_logic;
    signal Ck1_Bias             : std_logic;
    signal Ck2_Bias             : std_logic;
    signal Sin_Conf             : std_logic;
    signal Ck1_Conf             : std_logic;
    signal Ck2_Conf             : std_logic;
    signal Sin_VDAC             : std_logic;
    signal Ck1_VDAC             : std_logic;
    signal Ck2_VDAC             : std_logic;
    signal Sin_Col              : std_logic;
    signal Ck1_Col              : std_logic;
    signal Ck2_Col              : std_logic;
    signal Sin_Test             : std_logic;
    signal Ck1_Test             : std_logic;
    signal Ck2_Test             : std_logic;
    signal Sin_TDAC             : std_logic;
    signal Ck1_TDAC             : std_logic;
    signal Ck2_TDAC             : std_logic;
    signal Load_Bias            : std_logic;
    signal Load_Conf            : std_logic;
    signal Load_VDAC            : std_logic;
    signal Load_Col             : std_logic;
    signal Load_Test            : std_logic;
    signal Load_TDAC            : std_logic;
    signal Readback             : std_logic;
    signal PCH                  : std_logic;
    signal WR                   : std_logic;
    signal WrEnable             : std_logic;
    signal Injection            : std_logic;

    signal dpf_empty_this_round : std_logic_vector(3 downto 0);
    signal init_counter         : integer range 0 to 1023;

    signal run_test_prev        : std_logic;
    signal test_tdac_step       : integer range 0 to 7;
    signal running_test         : std_logic;

begin

    -- map signals to 29 bit mupix spi vector  (check order and positon of 000)
    o_data_to_direct_spi <= Sin_Bias & Ck1_Bias & Ck2_Bias & Sin_Conf & Ck1_Conf & Ck2_Conf & Sin_VDAC & Ck1_VDAC & Ck2_VDAC & Sin_Col & Ck1_Col & Ck2_Col & Sin_Test & Ck1_Test & Ck2_Test & Sin_TDAC & Ck1_TDAC & Ck2_TDAC &
                            Load_Bias & Load_Conf & Load_VDAC & Load_Col & Load_Test & Load_TDAC & Readback & PCH & WR & WrEnable & Injection & "000";

    -- things that we are going to fully ignore here:
    -- if you want to use them you need to use direct spi intput from slowcontrol and you need to know what you are doing (see code in mupix8_daq repo, Feb2022)
    -- do not expect things to be fast if you do that

    Sin_Test  <= '0';
    Readback  <= '0';
    PCH       <= '0';
    Injection <= '0';

    -- hardwire bits
    Sin_Bias <= bias;
    Sin_Conf <= conf;
    Sin_VDAC <= vdac;
    Sin_TDAC <= tdac;
    Sin_Col  <= col;


    genrdy: for I in 0 to g_CHIPS_PER_SPI-1 generate
        vdac_rdy(I) <= i_data(I).rdy(VDAC_BIT);
        bias_rdy(I) <= i_data(I).rdy(BIAS_BIT);
        conf_rdy(I) <= i_data(I).rdy(CONF_BIT);
        tdac_rdy(I) <= i_data(I).rdy(TDAC_BIT);
    end generate;

    process(i_clk, i_reset_n) is
    begin
    if ( i_reset_n = '0' ) then
        for I in 0 to g_CHIPS_PER_SPI-1 loop
            o_read(I).spi_read  <= (others => '0');
        end loop;
        o_data_to_direct_spi_we <= '0';
        o_spi_chip_selct_mask   <= (others => '0');
        mp_spi_clk_state        <= zero1;
        dpf_empty_this_round    <= (others => '0');
        reg_is_writing          <= (others => '0');
        chip_is_writing         <= (others => '0');

        -- IMPORTANT: needs to go into init case, use idle only for simulation here !!!
        mp_spi_state            <= init;

        -- synthesis translate_off
        -- don't want to wait for the init sequence in testbench
            mp_spi_state <= idle;
        -- synthesis translate_on

        init_counter            <= 0;
        col_shift_state         <= zero1;
        chip_is_writing_int     <= 0;
        col                     <= '0';

        Ck1_Bias    <= '0';
        Ck2_Bias    <= '0';
        Ck1_Col     <= '0';
        Ck2_Col     <= '0';
        Ck1_VDAC    <= '0';
        Ck2_VDAC    <= '0';
        Ck1_Conf    <= '0';
        Ck2_Conf    <= '0';
        Ck1_TDAC    <= '0';
        Ck2_TDAC    <= '0';
        Ck1_Col     <= '0';
        Ck2_Col     <= '0';
        bias        <= '0';
        conf        <= '0';
        vdac        <= '0';
        tdac        <= '0';
        col         <= '0';
        WrEnable    <= '0';
        WR          <= '0';
        Load_TDAC   <= '0';
        Load_Col    <= '0';
        Load_VDAC   <= '0';
        Load_Bias   <= '0';
        Load_Conf   <= '0';
        Load_Test   <= '0';
        Ck1_Test    <= '0';
        Ck2_Test    <= '0';

        run_test_prev  <= '0';
        test_tdac_step <= 0;
        running_test   <= '0';

    elsif rising_edge(i_clk) then
        -- defaults
        for I in 0 to g_CHIPS_PER_SPI-1 loop
            o_read(I).spi_read  <= (others => '0');
        end loop;
        o_data_to_direct_spi_we <= '0';
        Ck1_Bias    <= '0';
        Ck2_Bias    <= '0';
        Ck1_Col     <= '0';
        Ck2_Col     <= '0';
        Ck1_VDAC    <= '0';
        Ck2_VDAC    <= '0';
        Ck1_Conf    <= '0';
        Ck2_Conf    <= '0';
        Ck1_TDAC    <= '0';
        Ck2_TDAC    <= '0';
        Ck1_Col     <= '0';
        Ck2_Col     <= '0';
        col         <= '0';
        WrEnable    <= '0';
        WR          <= '0';
        Load_TDAC   <= '0';
        Load_Col    <= '0';
        Load_VDAC   <= '0';
        Load_Bias   <= '0';
        Load_Conf   <= '1';
        Load_Test   <= '0';
        Ck1_Test    <= '0';
        Ck2_Test    <= '0';

        run_test_prev <= i_run_test;

        case mp_spi_state is
          when init =>
            -- 0 col register of all chips, put a single 1 into start of col register for all chips
            o_spi_chip_selct_mask <= (others => '1');

            if(init_counter = 900) then
                col <= '1';
            end if;

            case mp_spi_clk_state is
              when zero1 =>
                if(init_counter = 901 and i_direct_spi_fifo_empty = '1') then
                    o_data_to_direct_spi_we <= '1';
                    Load_Col <= '1';
                    Load_Test <= '1';
                    init_counter <= init_counter + 1;
                elsif(init_counter = 902 and i_direct_spi_fifo_empty = '1') then
                    o_data_to_direct_spi_we <= '1';
                    Load_Col <= '0';
                    Load_Test <= '0';
                    mp_spi_state <= idle;
                    o_spi_chip_selct_mask <= (others => '0');
                    mp_spi_clk_state <= zero1;

                elsif(i_direct_spi_fifo_empty = '1') then
                    mp_spi_clk_state <= clk1;
                    init_counter <= init_counter + 1;
                    o_data_to_direct_spi_we <= '1';
                end if;
                -- default all
              when clk1 =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_clk_state <= zero2;
                Ck1_Col <= '1';
                Ck1_Test <= '1';
                -- others to default
              when zero2 =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_clk_state <= clk2;
                -- default all
              when clk2 =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_clk_state <= zero3;
                Ck2_Col <= '1';
                Ck2_Test <= '1';
                -- others to default
              when zero3 => -- is this one needed ?
                mp_spi_clk_state <= zero1;
                o_data_to_direct_spi_we <= '1';
                -- default all
              when others =>
                mp_spi_clk_state <= zero1;
                o_data_to_direct_spi_we <= '0';
            end case;

          when test =>
            o_spi_chip_selct_mask <= (others => '1');
            running_test          <= '1';

            case mp_spi_clk_state is
              when zero1 =>
                if(init_counter = 350 and i_direct_spi_fifo_empty = '1') then
                    o_data_to_direct_spi_we <= '1';
                    Load_Col <= '1';
                    init_counter <= init_counter + 1;
                elsif(init_counter = 351 and i_direct_spi_fifo_empty = '1') then
                    o_data_to_direct_spi_we <= '1';
                    Load_Col <= '0';
                    mp_spi_clk_state <= zero1;
                    init_counter <= 0;
                    mp_spi_state <= test2;
                elsif(i_direct_spi_fifo_empty = '1') then
                    mp_spi_clk_state <= clk1;
                    init_counter <= init_counter + 1;
                    o_data_to_direct_spi_we <= '1';
                end if;
                -- default all
              when clk1 =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_clk_state <= zero2;
                Ck1_Col <= '1';
                Ck1_tdac <= '1';
                -- others to default
              when zero2 =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_clk_state <= clk2;
                -- default all
              when clk2 =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_clk_state <= zero3;
                Ck2_Col <= '1';
                Ck2_tdac <= '1';
                -- others to default
              when zero3 => -- is this one needed ?
                mp_spi_clk_state <= zero1;
                o_data_to_direct_spi_we <= '1';
                -- default all
              when others =>
                mp_spi_clk_state <= zero1;
                o_data_to_direct_spi_we <= '0';
            end case;
        when test2 =>
            o_spi_chip_selct_mask <= (others => '1');
            tdac <= '1';

            case mp_spi_clk_state is
              when zero1 =>
                if(init_counter = 512 and i_direct_spi_fifo_empty = '1') then
                    o_data_to_direct_spi_we <= '1';
                    Load_tdac               <= '1';
                    init_counter <= init_counter + 1;
                elsif(init_counter = 513 and i_direct_spi_fifo_empty = '1') then
                    o_data_to_direct_spi_we <= '1';
                    Load_tdac <= '0';
                    mp_spi_clk_state <= zero1;
                    init_counter <= 0;
                    if(test_tdac_step = 7) then
                        mp_spi_state <= idle;
                        o_spi_chip_selct_mask <= (others => '1');
                        test_tdac_step <= 0;
                    else
                        test_tdac_step <= test_tdac_step + 1;
                        mp_spi_state <= shift_col_by_one;
                    end if;
                elsif(i_direct_spi_fifo_empty = '1') then
                    mp_spi_clk_state <= clk1;
                    init_counter <= init_counter + 1;
                    o_data_to_direct_spi_we <= '1';
                end if;
                -- default all
              when clk1 =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_clk_state <= zero2;
                Ck1_tdac <= '1';
                -- others to default
              when zero2 =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_clk_state <= clk2;
                -- default all
              when clk2 =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_clk_state <= zero3;
                Ck2_tdac <= '1';
                -- others to default
              when zero3 => -- is this one needed ?
                mp_spi_clk_state <= zero1;
                o_data_to_direct_spi_we <= '1';
                -- default all
              when others =>
                mp_spi_clk_state <= zero1;
                o_data_to_direct_spi_we <= '0';
            end case;

          -- mupix 10 load conf bug does not allow for this .. put in again for mp 11
          -- when idle =>
          --   if(or_reduce(vdac_rdy & bias_rdy & conf_rdy & tdac_rdy)='1' and i_direct_spi_fifo_empty = '1') then
          --       mp_spi_state    <= load_bits;
          --       for I in 0 to g_CHIPS_PER_SPI-1 loop -- decide on the chip that is supposed to write this round (could also write more than 1 chip if bits are identical but i dont want to right now)
          --           if(or_reduce(i_data(I).rdy) = '1') then
          --               chip_is_writing     <= (I => '1', others => '0');
          --               o_read              <= (I => (spi_read => i_data(I).rdy, mu3e_read => (others => 'Z')), others =>(spi_read => (others => '0'), mu3e_read => (others => 'Z')));
          --               reg_is_writing      <= i_data(I).rdy;
          --               chip_is_writing_int <= I;
          --           end if;
          --       end loop;
          --       -- now we know the chip (chip_is_writing, chip is writing int) and the regs of that chip (reg_is_writing) that we want to write this round
          --   end if;

        when idle =>
            running_test <= '0';
            if(i_run_test = '1' and run_test_prev = '0') then
                mp_spi_state        <= test;
                mp_spi_clk_state    <= zero1;
                init_counter        <= 0;
                col                 <= '0';
                tdac                <= '0';
            else
                for I in 0 to g_CHIPS_PER_SPI-1 loop -- decide on the chip that is supposed to write this round (could also write more than 1 chip if bits are identical but i dont want to right now)
                  if((bias_rdy(I)='1'or tdac_rdy(I)='1' or vdac_rdy(I)='1' or conf_rdy(I)='1') and i_direct_spi_fifo_empty = '1') then
                    mp_spi_state    <= load_bits;
                    chip_is_writing     <= (others => '0');
                    chip_is_writing(I)  <= '1';
                    o_read              <= (others => (spi_read => (others => '0'), mu3e_read => (others => '0')));
                    o_read(I).spi_read  <= i_data(I).rdy;
                    reg_is_writing      <= i_data(I).rdy;
                    chip_is_writing_int <= I;
                  end if;
                end loop;
                -- now we know the chip (chip_is_writing, chip is writing int) and the regs of that chip (reg_is_writing) that we want to write this round
            end if;

        when load_bits =>
            mp_spi_state <= waiting;
            -- save the bits we want to write this round

            vdac <= '0';
            conf <= '0';
            bias <= '0';
            tdac <= '0';

            if(reg_is_writing(VDAC_BIT) = '1') then
                vdac <= i_data(chip_is_writing_int).spi_data(VDAC_BIT);
            end if;
            if(reg_is_writing(CONF_BIT) = '1') then
                conf <= i_data(chip_is_writing_int).spi_data(CONF_BIT);
            end if;
            if(reg_is_writing(BIAS_BIT) = '1') then
                bias <= i_data(chip_is_writing_int).spi_data(BIAS_BIT);
            end if;
            if(reg_is_writing(TDAC_BIT) = '1') then
                tdac <= i_data(chip_is_writing_int).spi_data(TDAC_BIT);
            end if;

          when waiting =>
            -- if we emptied the dpf with this read we need to add additional steps at the end (load reg for vdac, conf and bias, shift by one shenanigans for tdac)
            -- -> save here which one we emptied so rest of firmware can start filling them again immediately
            dpf_empty_this_round    <= reg_is_writing and not i_data(chip_is_writing_int).rdy; -- TODO: check if this is actually the place where to check for empty
            -- set chip mask for direct spi, leave it until we get here again

            --o_spi_chip_selct_mask   <= (chip_is_writing_int=> '0', others => '1'); -- (quartus does not like it)
            for I in 0 to g_CHIPS_PER_SPI-1 loop
                if(chip_is_writing_int=I) then
                    o_spi_chip_selct_mask(I) <= '1';
                else
                    o_spi_chip_selct_mask(I) <= '0';
                end if;
            end loop;

            mp_spi_state            <= writing;
            mp_spi_clk_state        <= zero1;

          when writing =>
            -- now send the 5 29-bit words to direct SPI that we need to write a bit (no need to check if there is space since we only start from idle when i_direct_spi_fifo_empty)
            o_data_to_direct_spi_we <= '1';
            case mp_spi_clk_state is

              when zero1 =>
                mp_spi_clk_state <= clk1;
                Load_Conf <= not reg_is_writing(CONF_BIT);
                -- default all
              when clk1 =>
                mp_spi_clk_state <= zero2;
                Ck1_Bias <= reg_is_writing(BIAS_BIT);
                Ck1_VDAC <= reg_is_writing(VDAC_BIT);
                Ck1_Conf <= reg_is_writing(CONF_BIT);
                Ck1_TDAC <= reg_is_writing(TDAC_BIT);
                Load_Conf <= not reg_is_writing(CONF_BIT);
                -- others to default
              when zero2 =>
                mp_spi_clk_state <= clk2;
                Load_Conf <= not reg_is_writing(CONF_BIT);
                -- default all
              when clk2 =>
                mp_spi_clk_state <= zero3;
                Ck2_Bias <= reg_is_writing(BIAS_BIT);
                Ck2_VDAC <= reg_is_writing(VDAC_BIT);
                Ck2_Conf <= reg_is_writing(CONF_BIT);
                Ck2_TDAC <= reg_is_writing(TDAC_BIT);
                Load_Conf <= not reg_is_writing(CONF_BIT);
                -- others to default
              when zero3 => -- is this one needed ?
                Load_Conf <= not reg_is_writing(CONF_BIT);
                mp_spi_clk_state <= zero1;
                -- default all

                -- decide what to do next:
                -- default is to go back to idle and get the next round of bits:
                mp_spi_state <= idle;

                -- if this was the last round of bits for any of the 4 regs we need to load the reg

                --if(or_reduce(dpf_empty_this_round) = '1') then -- mupix 10 bug does not allow for this, put in again for mp 11
                if(dpf_empty_this_round(BIAS_BIT)='1' or dpf_empty_this_round(TDAC_BIT)='1') then
                    --mp_spi_state <= load; -- mupix 10 bug does not allow for this, put in again for mp 11
                    mp_spi_state <= pre_load;
                end if;
              when others =>
                mp_spi_clk_state <= zero1;
                o_data_to_direct_spi_we <= '0';
            end case;

            when pre_load =>
                o_data_to_direct_spi_we <= '1';
                mp_spi_state <= load;

            -- mupix 10 load conf bug does not allow for this .. put in again for mp 11
            -- when load =>
            --     o_data_to_direct_spi_we <= '1';

            --     -- load only the regs that are writing and for which dpf went empty this round
            --     Load_Bias <= reg_is_writing(BIAS_BIT) and dpf_empty_this_round(BIAS_BIT);
            --     --Load_conf <= reg_is_writing(CONF_BIT) and dpf_empty_this_round(CONF_BIT); -- is always 1, mupix10 bug
            --     Load_VDAC <= reg_is_writing(VDAC_BIT) and dpf_empty_this_round(VDAC_BIT);
            --     Load_TDAC <= reg_is_writing(TDAC_BIT) and dpf_empty_this_round(TDAC_BIT);
            --     Load_Conf <= '1';

            --     -- when TDACs have to be loaded this round we need to do the shift by one shenanigans (we could continue clocking in bias, conf and vdac data while doing shift by one shenanigans but seems not worth the effort)
            --     if((reg_is_writing(TDAC_BIT) and dpf_empty_this_round(TDAC_BIT)) = '1') then
            --         mp_spi_state <= shift_col_by_one;
            --         col_shift_state <= zero1;
            --     else
            --         mp_spi_state <= idle;
            --     end if;

            when load =>
                o_data_to_direct_spi_we <= '1';

                if(dpf_empty_this_round(BIAS_BIT)='1') then
                  Load_Bias <= '1';
                  Load_VDAC <= '1';
                end if;

                if(reg_is_writing(TDAC_BIT)='1' and dpf_empty_this_round(TDAC_BIT) = '1') then
                  Load_TDAC <= '1';
                end if;

                mp_spi_state <= rem_load;

            when rem_load =>
                o_data_to_direct_spi_we <= '1';
                if((reg_is_writing(TDAC_BIT)='1' and dpf_empty_this_round(TDAC_BIT) = '1')) then
                    mp_spi_state <= shift_col_by_one;
                    col_shift_state <= zero1;
                else
                    mp_spi_state <= idle;
                end if;


            when shift_col_by_one =>
                o_data_to_direct_spi_we <= '1';

                case col_shift_state is
                  when zero1 => -- is this one needed ?
                    col_shift_state <= clk1;
                  when clk1 =>
                    col_shift_state <= zero2;
                    Ck1_Col <= '1';
                  when zero2 =>
                    col_shift_state <= clk2;
                  when clk2 =>
                    col_shift_state <= zero3;
                    Ck2_Col <= '1';
                  when zero3 =>
                    col_shift_state <= load;
                  when load =>
                    col_shift_state <= write1;
                    Load_Col <= '1';
                  when write1 =>
                    col_shift_state <= write2;
                    WR       <= '1';
                    WrEnable <= '1'; -- TODO: should this be enough ? .. i think so
                  when write2 =>
                    col_shift_state <= zero4;
                    --WR       <= '1';
                    --WrEnable <= '1';
                  when zero4 => -- is this one needed ?
                    col_shift_state <= zero1;
                    if(running_test = '1') then
                        mp_spi_state <= test2;
                    else
                        mp_spi_state <= idle;
                    end if;
                  when others =>
                    col_shift_state <= zero1;
                    o_data_to_direct_spi_we <= '0';
                end case;

          when others =>
            mp_spi_state <= idle;
        end case;

    end if;
    end process;

end architecture;
