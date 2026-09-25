//

struct mupix_datapath_t {
    sc_t* sc;
    mupix_datapath_t(sc_t* sc_): sc(sc_){};

    void menu() {
        //auto& regs = sc->ram->regs.scifi;
        alt_u32 datagenreg = 0x0;
        char str[2] = {0};
        alt_u32 trigger0_time = 0x0;
        alt_u32 trigger0_time_pre = 0x0;
        alt_u32 trigger1_time = 0x0;
        alt_u32 trigger1_time_pre = 0x0;

        while(1) {
            printf("  [0] => write datagen control reg\n");
            printf("  [1] => read  datagen control reg\n");

            if((sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 31) & 1U){
                printf("  [2] => disable data gen\n");
            }else{
                printf("  [2] => enable data gen\n");
            }
            if((sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 16) & 1U){
                printf("  [3] => disengage data gen\n");
            }else{
                printf("  [3] => engage data gen\n");
            }
            if((sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 17) & 1U){
                printf("  [4] => insert before sorter\n");
            }else{
                printf("  [4] => insert after sorter\n");
            }
            printf("  [5] => print sorter counters\n");
            printf("  [6] => set data bypass select\n");
            printf("  [7] => write sorter inject reg\n");
            printf("  [8] => print hit ena counters\n");
            printf("  [9] => print trigger diff\n");

            if((sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 4) & 1U){
                printf("\n DataGen RATE: Full Stream\n");
            }else{
                printf("\n DataGen RATE:0x%01x\n", 0xF - (sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] & 0xF) + 1);
            }
            printf("  [+]\n");
            printf("  [-]\n");

            printf("Select entry ...\n");
            char cmd = wait_key();
            switch(cmd) {
            case '0':
                datagenreg = 0x0;
                printf("Enter datagen reg in hex: ");

                for(int i = 0; i<8; i++){
                    printf("mask: 0x%08x\n", datagenreg);
                    str[0] = wait_key();
                    datagenreg = datagenreg*16+strtol(str,NULL,16);
                }

                printf("setting reg to 0x%08x\n", datagenreg);
                sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] = datagenreg;
                break;
            case '1':
                printf("0x%08x\n", sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W]);
                break;
            case '2':
                sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] ^= 1UL << 31;
                break;
            case '3':
                sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] ^= 1UL << 16;
                break;
            case '4':
                sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] ^= 1UL << 17;
            case '-':
                if((sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 4) & 1U){
                    sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] ^= 1UL << 4;
                }else if(sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] & 1U and (sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 1) & 1U and (sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 2) & 1U and (sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 3) & 1U){

                }else{
                    sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] = sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] + 1;
                }
                break;
            case '+':
                if(!((sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W]) & 1U) and !((sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 1) & 1U) and !((sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 2) & 1U) and !((sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] >> 3) & 1U)){
                    sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] |= 1UL << 4;
                }else{
                    sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] = sc->ram->data[MP_DATA_GEN_CONTROL_REGISTER_W] - 1;
                }
                break;
            case '5':
                printf("sorter counters:\n");
                printf("MP_SORTER_NINTIME_REGISTER_R\n");
                for(int i=0; i<12; i++){
                    printf("%i: 0x%08x\n",i,sc->ram->data[MP_SORTER_NINTIME_REGISTER_R+i]);
                }
                printf("MP_SORTER_NOUTOFTIME_REGISTER_R\n");
                for(int i=0; i<12; i++){
                    printf("%i: 0x%08x\n",i,sc->ram->data[MP_SORTER_NOUTOFTIME_REGISTER_R+i]);
                }
                printf("MP_SORTER_NOVERFLOW_REGISTER_R\n");
                for(int i=0; i<12; i++){
                    printf("%i: 0x%08x\n",i,sc->ram->data[MP_SORTER_NOVERFLOW_REGISTER_R+i]);
                }
                printf("MP_SORTER_NOUT_REGISTER_R: 0x%08x\n", sc->ram->data[MP_SORTER_NOUT_REGISTER_R]);
                printf("MP_SORTER_CREDIT_REGISTER_R: 0x%08x\n", sc->ram->data[MP_SORTER_CREDIT_REGISTER_R]);
                printf("MP_SORTER_DELAY_REGISTER_W: 0x%08x\n", sc->ram->data[MP_SORTER_DELAY_REGISTER_W]);
                break;
            case '6':
                datagenreg = 0x0;
                printf("enter data bypass select in hex: ");

                for(int i = 0; i<8; i++){
                    printf("mask: 0x%08x\n", datagenreg);
                    str[0] = wait_key();
                    datagenreg = datagenreg*16+strtol(str,NULL,16);
                }

                printf("setting reg to 0x%08x\n", datagenreg);
                sc->ram->data[MP_DATA_BYPASS_SELECT_REGISTER_W] = datagenreg;
                break;
            case '7':
                datagenreg = 0x0;
                sc->ram->data[MP_SORTER_INJECT_REGISTER_W] = datagenreg;
                printf("enter sorter inject reg in hex: ");

                for(int i = 0; i<8; i++){
                    printf("mask: 0x%08x\n", datagenreg);
                    str[0] = wait_key();
                    datagenreg = datagenreg*16+strtol(str,NULL,16);
                }
                printf("setting reg to 0x%08x\n", datagenreg);

                for(int i=0; i<10000; i++){
                    sc->ram->data[MP_SORTER_INJECT_REGISTER_W] = datagenreg;
                    sc->ram->data[MP_SORTER_INJECT_REGISTER_W] = 0x0;
                    usleep(50);
                }
                break;
            case '8':
                printf("TODO: hit counters:\n");
                /*
                bitbucket issue 93
                for(int i=0; i<36; i++){
                    printf("%i: 0x%08x\n",i,sc->ram->data[0xFFBF]);
                }
                printf("sorter input hit counters:\n");
                for(int i=0; i<12; i++){
                    printf("%i: 0x%08x\n",i,sc->ram->data[MP_HIT_ENA_CNT_SORTER_IN_REGISTER_R + i]);
                }
                printf("sorter output hit counter:\n");
                printf("  0x%08x\n",sc->ram->data[0xFFC3]);
                */
                break;
            case '9':
                trigger0_time       = (sc->ram->data[MP_TRIGGER0_REGISTER_R] >> 1) & 0x1FFFFF;
                trigger0_time_pre   = (sc->ram->data[MP_TRIGGER0_REG_REGISTER_R] >> 1) & 0x1FFFFF;
                trigger1_time       = (sc->ram->data[MP_TRIGGER1_REGISTER_R] >> 1) & 0x1FFFFF;
                trigger1_time_pre   = (sc->ram->data[MP_TRIGGER1_REG_REGISTER_R] >> 1) & 0x1FFFFF;
                printf("Trigger0: %d, trigger0_time_pre: %d, trigger1_time: %d, trigger1_time_pre: %d\n", trigger0_time, trigger0_time_pre, trigger1_time, trigger1_time_pre);
                printf("TriggerFreq: %d, triggerFreq: %d\n", trigger0_time - trigger0_time_pre, trigger1_time - trigger1_time_pre);
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }
        }
    }


};
