//

#include "include/base.h"
#include "include/xcvr.h"

#include "../../fe/software/si5345.h"
#include "../../fe/software/si5345_regs1_mupix.h"
#include "../../fe/software/si5345_regs2.h"
si5345_t si5345_1 { SPI_SI_BASE, 0, si5345_regs1_mupix, sizeof(si5345_regs1_mupix) / sizeof(si5345_regs1_mupix[0]) };
si5345_t si5345_2 { SPI_SI_BASE, 1, si5345_regs2, sizeof(si5345_regs2) / sizeof(si5345_regs2[0]) };
//si5345_t si5345 { SPI_SI_BASE, 0 };

#include "../../fe/software/sc.h"
sc_t sc;

#include "../../fe/software/max10_spi.h"
max10_spi_t max10_spi;

#include "../../fe/software/mscb_user.h"
mscb_t mscb;
#include "../../fe/software/reset.h"
#include "../../fe/software/tmpDisplay.h"

//definition of callback function for slow control packets
alt_u16 sc_t::callback(alt_u16 cmd, volatile alt_u32* data, alt_u16 n) {
    //return mupix.callback(cmd,data,n);
}

int main() {
    base_init();

    si5345_2.init();
    usleep(5000000);
    si5345_1.init();
    //mscb.init();
    sc.init();
    volatile sc_ram_t* ram = (sc_ram_t*) AVM_SC_BASE;

    while (1) {
        printf("\n");
        printf("[fe_dummy] -------- menu --------\n");
        printf("TODO: [lol_n/intr_n] S1 status: 0x%08x, S2 status: 0x%08x\n", 0,0); // TODO: find these regs again
        printf("ID: 0x%08x\n", ram->data[FPGA_ID_REGISTER_RW]);

        printf("\n");
        printf("  [1] => Firefly channels\n");
        printf("  [2] => insert sub-detector menu here\n");
        printf("  [3] => sc\n");
        printf("  [4] => si5345_1\n");
        printf("  [5] => si5345_2\n");
        printf("  [6] => mscb\n");
        printf("  [7] => reset system\n");
        printf("  [8] => temperature Display\n");
        printf("  [9] => max10 spi\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
        case '1':
            menu_xcvr((alt_u32*)(AVM_QSFP_BASE | ALT_CPU_DCACHE_BYPASS_MASK));
            break;
        case '2':
            //mupix.menu();
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
            mscb_main();
            break;
        case '7':
            menu_reset();
            break;
        case '8':
            menu_tmpDisplay((alt_u32*)(AVM_QSFP_BASE | ALT_CPU_DCACHE_BYPASS_MASK));
            break;
        case '9':
            max10_spi.menu();
            break;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }

    return 0;
}
