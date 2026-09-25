//

#include "include/base.h"
#include "include/xcvr.h"

#include "../../fe/software/si5345.h"
#include "../../fe/software/si5345_regs1_mupix.h"
#include "../../fe/software/si5345_regs2.h"
//#include "../../fe/software/si5345_regs2_free.h" //For internal clock of FEB
si5345_t si5345_1 { SPI_SI_BASE, 0, si5345_regs1_mupix, sizeof(si5345_regs1_mupix) / sizeof(si5345_regs1_mupix[0]) };
si5345_t si5345_2 { SPI_SI_BASE, 1, si5345_regs2, sizeof(si5345_regs2) / sizeof(si5345_regs2[0]) };
//si5345_t si5345_2 { SPI_SI_BASE, 1, si5345_regs2_free, sizeof(si5345_regs2_free) / sizeof(si5345_regs2_free[0]) }; //For internal clock of FEB
//si5345_t si5345 { SPI_SI_BASE, 0 };

#include "../../fe/software/sc.h"
sc_t sc;

//#include "../../fe/software/mscb_user.h"
//mscb_t mscb;
#include "../../fe/software/reset.h"

#include "mupix.h"
#include "mp_datapath.h"
#include "../../fe/software/tmpDisplay.h"

mupix_t mupix(&sc);
mupix_datapath_t mupix_datapath(&sc);
//definition of callback function for slow control packets
alt_u16 sc_t::callback(alt_u16 cmd, volatile alt_u32* data, alt_u16 n) {
    return mupix.callback(cmd,data,n);
}

int main() {
    base_init();

    si5345_2.init();
    usleep(5000000);
    si5345_1.init();
    //mscb.init();
    sc.init();
    volatile sc_ram_t* ram = (sc_ram_t*) AVM_SC_BASE;
    ram->data[FPGA_ID_REGISTER_RW] = 0;

    while (1) {
        printf("\n");
        printf("[fe_mupix] -------- menu --------\n");
        printf("ID: 0x%08x\n", ram->data[FPGA_ID_REGISTER_RW]);

        printf("\n");
        printf("  [1] => Firefly channels\n");
        printf("  [2] => mupix\n");
        printf("  [3] => sc\n");
        printf("  [4] => si5345_1\n");
        printf("  [5] => si5345_2\n");
        printf("  [6] => mscb\n");
        printf("  [7] => reset system\n");
        printf("  [8] => datapath\n");
        printf("  [9] => temperature Display\n");
        printf("  [f] => toggleFEBID\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
        case '1':
            menu_xcvr((alt_u32*)((AVM_SC_BASE + 4*0xFF00) | ALT_CPU_DCACHE_BYPASS_MASK));
            break;
        case '2':
            mupix.menu();
            break;
        case '3':
            sc.menu();
            break;
        case '4':
            si5345_1.menu();
            break;
        case '5':
            si5345_2.menu();
            break;
        case '6':
            printf("mscb not active to save memory\n");
            //mscb_main();
            break;
        case '7':
            menu_reset();
            break;
        case '8':
            mupix_datapath.menu();
            break;
        case '9':
            menu_tmpDisplay((alt_u32*)(AVM_QSFP_BASE | ALT_CPU_DCACHE_BYPASS_MASK));
            break;
        case 'f':
            ram->data[FPGA_ID_REGISTER_RW] ^= 1UL << 0;
        break;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }

    return 0;
}
