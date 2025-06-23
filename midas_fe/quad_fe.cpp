
#include <stdio.h>
#include <stdlib.h>

#include <iostream>
#include <list>
#include <unistd.h>

#include "midas.h"
#include "odbxx.h"
#include "msystem.h"
#include "mcstd.h"
#include "mfe.h"

#include "constants.h"
#include "registers.h"
#include "util.h"
#include "mudaq_device.h"


// MIDAS settings
const char *frontend_name = "Quads";
const char *frontend_file_name = __FILE__;
BOOL equipment_common_overwrite = TRUE;

// Readout variables
volatile uint32_t *dma_buf;
uint32_t* dma_buf_local;
uint32_t reset_regs = 0;
uint32_t readout_state_regs = 0;
bool use_software_dummy = false;
mudaq::DmaMudaqDevice* mup = nullptr;
mudaq::DmaMudaqDevice::DataBlock block;

// configuration variables
midas::odb m_settings;
uint8_t bitpattern_mupix[48] = {};


int frontend_init() {

    settings.connect_and_fix_structure("/Equipment/Quads/Settings");
    return SUCCESS;

    // // setup max event size
    // set_max_event_size(dma_buf_size);

    // // end and start of run
    // install_begin_of_run(begin_of_run);
    // install_end_of_run(end_of_run);
    // install_frontend_exit(frontend_exit_user);
    // install_frontend_loop(quad_loop);

    // // setup odb and watches
    // setup_odb();

    // // init dma and mudaq device
    // #ifdef NO_A10_BOARD

    // #else
    //     int status = init_mudaq();
    //     if (status != SUCCESS) return FE_ERR_DRIVER;
    // #endif

    // usleep(5000);

    // // set reset registers
    // reset_regs = SET_RESET_BIT_DATA_PATH(reset_regs);
    // reset_regs = SET_RESET_BIT_DATAGEN(reset_regs);
    // reset_regs = SET_RESET_BIT_SWB_TIME_MERGER(reset_regs);
    // reset_regs = SET_RESET_BIT_SWB_STREAM_MERGER(reset_regs);

    // // create ring buffer for readout thread
    // create_event_rb(0);

    // // create readout thread
    // ss_thread_create(read_stream_thread, NULL);

    // //Set our transition sequence. The default is 500.
    // cm_set_transition_sequence(TR_START, 300);

    // //Set our transition sequence. The default is 500. Setting it
    // // to 700 means we are called AFTER most other clients.
    // cm_set_transition_sequence(TR_STOP, 700);

    // // set write cache to 10MB
    // set_cache_size("SYSTEM", 10000000);

    // // set if we are in software mode
    // odb stream_settings;
    // stream_settings.connect(path_s);
    // use_software_dummy = stream_settings["Software dummy"];
    // use_fpga_events = stream_settings["Use FPGA Events"];

    // return SUCCESS;
}

int frontend_exit_user() {
    #ifdef NO_A10_BOARD

    #else
        if (mup) {
            mup->disable();
            mup->close();
            delete mup;
        }
    #endif

    return SUCCESS;
}

int read_sc_event(char *pevent, INT)
{

    // create bank, pdata
    bk_init32a(pevent);
    DWORD *pdata = NULL;

    //scbanks.read(pevent, pdata);

    return bk_size(pevent);

}

EQUIPMENT equipment[] = {
    {"Quads",         /* equipment name */
    {1, 0,                    /* event ID, trigger mask */
        "SYSTEM",                  /* event buffer */
        EQ_PERIODIC,               /* equipment type */
        0,                         /* event source */
        "MIDAS",                   /* format */
        TRUE,                      /* enabled */
        RO_RUNNING | RO_STOPPED | RO_ODB,        /* read always, except during transistions and update ODB */
        1000,                      /* read every 1 sec */
        0,                         /* stop run after this event limit */
        0,                         /* number of sub events */
        1,                         /* log history every event */
        "", "", ""},
        read_sc_event,             /* readout routine */
    }, {""}
};
