//
#include "../../../../registers/sorter_registers.h"

void menu_sorter();
void menu_lapse();
void menu_pll_injection();
void menu_reg_dummyctrl();
void menu_subdet_reset();
void menu_mutrig_counters(uint32_t numModule, uint32_t numASICsPerMod);
void menu_mutrig_counters_rates(uint32_t numModule, uint32_t numASICsPerMod);
void mutrig_reset_counters();
void menu_reg_resetskew();
//Copied from FEB1 including comment
//Reset skew configuration
//shadow storage of reset skew configuration,
//we do not have this in a register
uint8_t resetskew_count[4];
void RSTSKWctrl_Clear();
void RSTSKWctrl_Set(uint8_t channel, uint8_t value);

uint32_t get_value_hex(){
    char str[2] = {0};
    uint32_t value = 0x0;
    printf("Enter Value in hex: ");
    for ( int i = 0; i < 8; i++ ) {
        printf("val: 0x%08x\n", value);
        str[0] = wait_key();
        value = value*16+strtol(str,NULL,16);
    }
    printf("setting value to 0x%08x\n", value);
    return value;
}



void menu_mutrig_common(uint32_t numModule, uint32_t numASICsPerMod) {
    volatile sc_ram_t* ram = (sc_ram_t*) AVM_SC_BASE;
    uint32_t value = 0x0;

    while(1) {
        printf("CTRL DP = 0x%08X\n", ram->data[MUTRIG_CTRL_DP_REGISTER_W]);
        printf("CNT CTRL = 0x%08X\n", ram->data[MUTRIG_CNT_CTRL_REGISTER_W]);
        printf("DUM CTRL = 0x%08X\n", ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]);
        printf("  [0] => lvds status\n");
        printf("  [1] => rate counters\n");
        printf("  [2] => counters\n");
        printf("  [3] => lapse correction menu\n");
        printf("  [4] => set ASIC mask\n");
        printf("  [5] => get slow control registers\n");
        printf("  [6] => dummy generator settings\n");
        printf("  [7] => reset things\n");
        printf("  [8] => PLL injection\n");
        printf("  [s] => (Tile) Sorter debugging\n");
        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        printf("%c\n", cmd);
        switch(cmd) {
            case '0':
                printf("TODO add me\n");
                break;
            case '1':
                menu_mutrig_counters_rates(numModule,numASICsPerMod);
                break;
            case '2':
                menu_mutrig_counters(numModule,numASICsPerMod);
                break;
            case '3':
                menu_lapse();
                break;
            case '4':
                value = get_value_hex();
                sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W] = value;
                break;
            case '5': //get slowcontrol registers

                printf("MUTRIG_CNT_CTRL_REGISTER_W: 0x%08X\n",  sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W]);
                printf("    :pll_test_mode 0x%02X\n",  (sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W])&0xff);

                printf("MUTRIG_CTRL_DUMMY_REGISTER_W:    0x%08X\n", sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]);
                printf("    :datagen_en   0x%X\n", (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]>>0)&1);
                printf("    :datagen_fast 0x%X\n", (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]>>1)&1);
                printf("    :datagen_cnt  0x%X\n", (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]>>2)&0x3ff);

                printf("MUTRIG_CTRL_DP_REGISTER_W:       0x%08X\n", sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W]);
                printf("    :dec_disable  0x%X\n", (sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W]>>31)&1);
                printf("    :mask         0b");
                for(int i=25;i>=13;i--)
                    printf("%d", (sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W]>>i)&1);
                printf("\n");
                printf("    :mask_rx      0b");
                for(int i=12;i>=0;i--)
                    printf("%d", (sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W]>>i)&1);
                printf("\n");


                printf("MUTRIG_CTRL_RESET_REGISTER_W: 0x%08X\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W]);
                printf("MUTRIG_CTRL_RESETDELAY_REGISTER_W: 0x%08X\n", sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W]);
                printf("MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W: 0x%08X\n", sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W]);
                printf("    :lapse_ena   0x%X\n", (sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W]>>31)&1);
                printf("    :upper       0x%X\n", (sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W]>>15)&0xffff);
                printf("    :lower       0x%X\n", (sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W]>>0)&0xffff);
                printf("MUTRIG_CTRL_LAPSE_DELAY_W: 0x%08X\n", sc.ram->data[MUTRIG_CTRL_LAPSE_DELAY_W]);
                printf("    :delay       0x%X\n", (sc.ram->data[MUTRIG_CTRL_LAPSE_DELAY_W]>>0)&0xffff);
                printf("    :repl_late   0x%X\n", (sc.ram->data[MUTRIG_CTRL_LAPSE_DELAY_W]>>15)&0x1);

                break;
            case '6':
                menu_reg_dummyctrl();
                break;
            case '7':
                menu_subdet_reset();
                break;
            case '8':
                menu_pll_injection();
                break;
            case 's':
                menu_sorter();
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}


void menu_sorter() {
    while(1) {
        printf("Sorter Menu\n");
        uint32_t data[76];
        for(int i=0;i<76;i++){data[i]=sc.ram->data[SORTER_COUNTER_REGISTER_R+i];};
        printf("NINTIME [0]      = 0x%08X\n", data[0]);
        printf("NINTIME [1]      = 0x%08X\n", data[01]);
        printf("NINTIME [2]      = 0x%08X\n", data[02]);
        
        printf("NOUTOFTIME [0]   = 0x%08X\n", data[12]);
        printf("NOUTOFTIME [1]   = 0x%08X\n", data[13]);
        printf("NOUTOFTIME [2]   = 0x%08X\n", data[14]);
        
        printf("NOVERFLOW [0]    = 0x%08X\n", data[24]);
        printf("NOVERFLOW [1]    = 0x%08X\n", data[25]);
        printf("NOVERFLOW [2]    = 0x%08X\n", data[26]);
        
        printf("PREWINDOW [0]    = 0x%08X\n", data[36]);
        printf("PREWINDOW [1]    = 0x%08X\n", data[37]);
        printf("PREWINDOW [2]    = 0x%08X\n", data[38]);
        
        printf("PASTWINDOW [0]   = 0x%08X\n", data[48]);
        printf("PASTWINDOW [1]   = 0x%08X\n", data[49]);
        printf("PASTWINDOW [2]   = 0x%08X\n", data[50]);
        
        printf("OUTDIAG [0]      = 0x%08X\n", data[60]);
        printf("OUTDIAG [1]      = 0x%08X\n", data[61]);
        printf("OUTDIAG [2]      = 0x%08X\n", data[62]);
        
        printf("NOUT             = 0x%08X\n", data[72]);
        printf("CREDIT           = 0x%08X\n", data[73]);
        
        printf("DWIDTH           = 0x%08X\n", data[SORTER_INDEX_DIAGNOSE]);
        printf("DELAY            = 0x%08X\n", data[SORTER_INDEX_DELAY]);
/*
        sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = 0x80000000;
        printf("NINTIME [0]      = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+0]);
        printf("NINTIME [1]      = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+01]);
        printf("NINTIME [2]      = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+02]);
        
        printf("NOUTOFTIME [0]   = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+12]);
        printf("NOUTOFTIME [1]   = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+13]);
        printf("NOUTOFTIME [2]   = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+14]);
        
        printf("NOVERFLOW [0]    = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+24]);
        printf("NOVERFLOW [1]    = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+25]);
        printf("NOVERFLOW [2]    = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+26]);
        
        printf("PREWINDOW [0]    = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+36]);
        printf("PREWINDOW [1]    = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+37]);
        printf("PREWINDOW [2]    = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+38]);
        
        printf("PASTWINDOW [0]   = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+48]);
        printf("PASTWINDOW [1]   = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+49]);
        printf("PASTWINDOW [2]   = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+50]);
        
        printf("OUTDIAG [0]      = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+60]);
        printf("OUTDIAG [1]      = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+61]);
        printf("OUTDIAG [2]      = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+62]);
        
        printf("NOUT             = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+72]);
        printf("CREDIT           = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R+73]);

        printf("DWIDTH           = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R + SORTER_INDEX_DIAGNOSE]);
        printf("DELAY            = 0x%08X\n", sc.ram->data[SORTER_COUNTER_REGISTER_R + SORTER_INDEX_DELAY]);
        sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = 0x00000000;
*/
        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void menu_lapse() {
    while(1) {
        printf("CTRL_LAPSE = 0x%08X\n", sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W]);
        printf("  [0|1] => disable | enable\n");
        printf("  [l] => set lower boundary\n");
        printf("  [u] => set upper boundary\n");


        printf("Select entry ...\n");
        char cmd = wait_key();
        uint32_t val = sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W];
        switch(cmd) {
            case '1':
                sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] | (1<<31);
                break;
            case '0':
                sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] & ~(1<<31);
                break;
            case 'u':
                val = (val & 0x80007fff) | (get_value_hex()<<15);
                printf("setting value to 0x%08x\n", val);
                sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] = val;
                break;
            case 'l':
                val = (val & 0x9fff8000) | (get_value_hex()<<0);
                printf("setting value to 0x%08x\n", val);
                sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] = val;
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void menu_pll_injection() {
    while(1) {
        printf("CNT CTRL = 0x%08X\n", sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W]);
        printf("  [1] => enable injection 100kHz pulse\n");
        printf("  [2] => disable injection 100kHz pulse\n");
        printf("  [3] => enable analog injection 100kHz pulse\n");
        printf("  [4] => disable analog injection 100kHz pulse\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
            case '1':
                sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] | (1<<0);
                break;
            case '2':
                sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] & ~(1<<0);
                break;
            case '3':
                sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] | (1<<1);
                break;
            case '4':
                sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] & ~(1<<1);
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void menu_reg_dummyctrl(){
    while(1) {
        auto reg = sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W];
        //printf("Dummy reg now: %16.16x / %16.16x\n",sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W], reg);
        printf("  [0] => %s config dummy\n",(reg&1) == 0?"enable":"disable");
        printf("  [1] => %s data dummy\n",(reg&2) == 0?"enable":"disable");
        printf("  [2] => %s fast hit mode\n",(reg&4) == 0?"enable":"disable");
        printf("  [+] => increase count (currently %u)\n",(reg>>3&0x3fff));
        printf("  [-] => decrease count\n");
        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        uint32_t val;
        char cmd = wait_key();
        switch(cmd) {
            case '0':
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] ^ (1<<0);
                break;
            case '1':
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] ^ (1<<1);
                break;
            case '2':
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] ^ (1<<2);
                break;
            case '+':
                val=(reg>>3&0x3fff)+1;
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] & 0x07) | (0x3fff&(val <<3));
                break;
            case '-':
                val=(reg>>3&0x3fff)-1;
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] & 0x07) | (0x3fff&(val <<3));
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void menu_subdet_reset() {
    while(1) {
        printf("  [0] => reset asic continuous\n");
        printf("  [1] => reset asic\n");
        printf("  [2] => reset datapath\n");
        printf("  [3] => reset lvds_rx\n");
        printf("  [4] => reset skew settings\n");
        printf("  [5] => reset counter addr\n");
        printf("  [6] => read reset reg\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
            case '0':
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0;
                printf("%x, %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W], MUTRIG_CTRL_RESET_REGISTER_W);
                break;
            case '1':
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 1;
                printf("%x, %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W], MUTRIG_CTRL_RESET_REGISTER_W);
                usleep(50000);
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0;
                break;
            case '2':
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 2;
                printf("%x, %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W], MUTRIG_CTRL_RESET_REGISTER_W);
                usleep(50000);
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0;
                break;
            case '3':
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 4;
                printf("%x, %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W], MUTRIG_CTRL_RESET_REGISTER_W);
                usleep(50000);
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0;
                break;
            case '4':
                menu_reg_resetskew();
                break;
            case '5':
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0x10;
                printf("%x, %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W], MUTRIG_CTRL_RESET_REGISTER_W);
                usleep(50000);
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0;
                break;
            case '6':
                printf("Reset red %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W]);
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void RSTSKWctrl_Clear(){
    //reset pll to zero phase counters
    sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = 0x8000;
    for(int i=0; i<4;i++)
        resetskew_count[i]=0;
    sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = 0x0000;
}

void RSTSKWctrl_Set(uint8_t channel, uint8_t value){
    if(channel>7) return;
    if(value>7) return;
    uint32_t val = sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] & 0xffc0;
    //printf("PLL_phaseadjust #%u: ",channel);
    while(value!=resetskew_count[channel]){
        val |= (channel+2)<<2;
        if(value>resetskew_count[channel]){ //increment counter
            val |= 2;
            //printf("+");
            resetskew_count[channel]++;
        }else{
            val |= 1;
            //printf("-");
            resetskew_count[channel]--;
        }
        sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = val;
    }
    //printf("\n");
    sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W]= val & 0xffc0;
}

void menu_reg_resetskew(){
    int selected=0;
    while(1) {
        auto reg = sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W];
        printf("Reset delay reg now: %16.16x\n",reg);
        printf("  [0..3] => Select line N (currently %d)\n",selected);

        printf("  [p] => swap phase bit (currently %d)\n",(reg>>(6 +selected)&0x1));
        printf("  [d] => swap delay bit (currently %d)\n",(reg>>(10+selected)&0x1));
        printf("  [+] => increase count (currently %d)\n",resetskew_count[selected]);
        printf("  [-] => increase count (currently %d)\n",resetskew_count[selected]);
        printf("  [r] => reset phase configuration\n");

        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
            case '0':
                break;
            case '1':
                selected=1;
                break;
            case '2':
                selected=2;
                break;
            case '3':
                selected=3;
                break;
            case 'r':
                RSTSKWctrl_Clear();
                break;
            case '+':
                RSTSKWctrl_Set(selected, resetskew_count[selected]+1);
                break;
            case '-':
                RSTSKWctrl_Set(selected, resetskew_count[selected]-1);
                break;
            case 'd':
                sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W]^(1<<(10+selected));
                break;
            case 'p':
                sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W]^(1<<( 6+selected));
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void menu_mutrig_counters_rates(uint32_t numModule, uint32_t numASICsPerMod){
    char cmd;
    while(1){
        printf("\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
        printf("| ");
        printf("%10s | ","ASIC");
        for ( uint32_t sel = 0; sel < 16; sel++ ) {
            printf("RATE %5u | ",sel);
        }
        printf("\n");

        //reset counter address
        sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] |= 1<<4;
        sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] ^= 1<<4;

        for ( uint32_t mid = 0; mid < numModule ; mid++ ) {
            for ( uint32_t aid = 0; aid < numASICsPerMod; aid++ ) {
                uint32_t counters[64];
                for ( uint32_t sel = 0; sel < 64; sel++ )
                    counters[sel] = sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_R];
                //special case for ASICid: has a bit of BEEF ;)
                counters[0] &= 0xffff;

                printf("| (0..15) %2u |", counters[0]); // ASIC ID
                for ( uint32_t sel = 0; sel < 16; sel++ ) {
                    printf(" %10.10u |", counters[8 + sel]); // RATES
                }
                printf("\n");

                printf("| (16.31) %2u |", counters[0]); // ASIC ID
                for ( uint32_t sel = 16; sel < 32; sel++ ) {
                    printf(" %10.10u |", counters[8 + sel]); // RATES
                }
                printf("\n");
            }
            printf("-------------------------------------------------------------------------------\n");
        }
        if (read(uart,&cmd, 1) > 0){
            printf("--\n");
            if(cmd=='q') return;
            if(cmd=='r'){
               mutrig_reset_counters();
               printf("-- reset\n");
            };
        }
        usleep(2000000);
    };

}

void menu_mutrig_counters(uint32_t numModule, uint32_t numASICsPerMod){
    // Counters per ASIC N_ASICS_TOTAL
    //    s_counters( 0+i*64)              <= x"BEEF000" & C_ASICNO_PREFIX(4*i+3 downto i*4); -- ASIC ID
    //    s_counters( 1+i*64)              <= x"AFFEAFFE"; -- DEBUG
    //    s_counters( 2+i*64)              <= x"AFFEAFFE"; -- DEBUG
    //    s_counters( 3+i*64)              <= s_eventcounter(i);
    //    s_counters( 4+i*64)              <= s_timestamp_125(31 downto 0); -- take only the first one
    //    s_counters( 5+i*64)              <= s_timestamp_125(63 downto 32);
    //    s_counters( 6+i*64)              <= s_crcerrorcounter(i);
    //    s_counters( 7+i*64)              <= s_framecounter(i);
    //    s_counters(39+i*64 downto 8+i*64)<= s_ch_rate(i*32 + 31 downto i*32);
    //    s_counters(62+i*64)              <= x"BEEFBEEF"; -- DEBUG
    //    s_counters(63+i*64)              <= x"BEEF000" & C_ASICNO_PREFIX(4*i+3 downto i*4); -- ASIC ID
    char cmd;
    const uint32_t counter_idx[5] = {0, 3, 6, 7};
    const char *counter_names[] = {"ASIC", "Hits", "CRC Errors", "Frames"};
    while(1){
        printf("\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
        printf("| ");
        for ( uint32_t sel = 0; sel < 4; sel++ ) {
            printf("%10s | ",counter_names[sel]);
        }
        printf("\n");

        //reset counter address
        sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] |= 1<<4;
        sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] ^= 1<<4;

        for ( uint32_t mid = 0; mid < numModule ; mid++ ) {
            for ( uint32_t aid = 0; aid < numASICsPerMod; aid++ ) {
                printf("| ");
                uint32_t counters[64];
                for ( uint32_t sel = 0; sel < 64; sel++ )
                    counters[sel] = sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_R];
                //special case for ASICid: has a bit of BEEF ;)
                counters[0] &= 0xffff;

                for ( uint32_t sel = 0; sel < 4; sel++ ) {
                    printf("%10u |", counters[counter_idx[sel]]);
                }
                printf("\n");
            }
            printf("-------------------------------------------------------------------------------\n");
        }
        if (read(uart,&cmd, 1) > 0){
            printf("--\n");
            if(cmd=='q') return;
            if(cmd=='r'){
               mutrig_reset_counters();
               printf("-- reset\n");
            };
        }
        usleep(200000);
    };

}

void mutrig_reset_counters(){
    sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] | ((1<<3) | (1<<4)) ;
}
