
#include <stdio.h>
#include <stdlib.h>

#include <iostream>
#include <list>
#include <unistd.h>
#include <sys/mman.h>

#include "midas.h"
#include "odbxx.h"
#include "msystem.h"
#include "mcstd.h"
#include "mfe.h"

#include "utils.h"
#include "odb_setup.h"
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
FEBSlowcontrolInterface * feb_sc;
midas::odb m_settings;
uint8_t bitpattern_mupix[48] = {};


int init_mudaq(mudaq::MudaqDevice & mu) {
    int fd = open("/dev/mudaq0_dmabuf", O_RDWR);
    if(fd < 0) {
        printf("fd = %d\n", fd);
        return FE_ERR_DRIVER;
    }
    dma_buf = reinterpret_cast<uint32_t*>(mmap(nullptr, MUDAQ_DMABUF_DATA_LEN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0));
    if(dma_buf == MAP_FAILED) {
        cm_msg(MERROR, "frontend_init" , "mmap failed: dmabuf = %p\n", MAP_FAILED);
        return FE_ERR_DRIVER;
    }
    dma_buf_local = new(std::align_val_t(8)) uint32_t[MUDAQ_DMABUF_DATA_LEN];

    // open mudaq
    if ( !mu.open() ) {
        std::cout << "Could not open device " << std::endl;
        cm_msg(MERROR, "frontend_init" , "Could not open device");
        return FE_ERR_DRIVER;
    }

    // check mudaq
    if ( !mu.is_ok() )
        return FE_ERR_DRIVER;
    else {
        cm_msg(MINFO, "frontend_init" , "Mudaq device is ok");
    }

    // switch off the data generator (just in case ..)
    mu.write_register(DATAGENERATOR_REGISTER_W, 0x0);
    usleep(2000);

    // set DMA_CONTROL_W
    mu.write_register(DMA_CONTROL_W, 0x0);

    feb_sc = new FEBSlowcontrolInterface(mu);

    return SUCCESS;
}

int begin_of_run()
{
    return SUCCESS;
}

int end_of_run()
{
    return SUCCESS;
}

int frontend_exit_user()
{
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

int quad_loop()
{

   return SUCCESS;
}

int read_stream_thread(void *)
{
    // get mudaq
    mudaq::DmaMudaqDevice & mu = *mup;

    // tell framework that we are alive
    signal_readout_thread_active(0, TRUE);

    // obtain ring buffer for inter-thread data exchange
    int rbh = get_event_rbh(0);
    int status;

    // serial number on the FPGA
    uint32_t serial_number = 0;

    // actuall readout loop
    while(is_readout_thread_enabled()) {

        // don't readout events if we are not running
        if (!readout_enabled()) {
            // we start from zero again
            serial_number = 0;
            //printf("Not running!\n");
            // do not produce events when run is stopped
            ss_sleep(10);// don't eat all CPU
            continue;
        }
    }
    return SUCCESS;
}

void sc_settings_changed(midas::odb o)
{
    std::string name = o.get_name();

    cm_msg(MINFO, "sc_settings_changed", "Setting changed (%s)", name.c_str());

    if (name == "MupixConfig" && o) {
        ConfigureASICs(*feb_sc, m_settings, bitpattern_mupix);
        o = false;
    }

    // TODO: this can be done in the frontend loop all the time
    if (name == "InitFEBs" && o) {
        InitFEBs(*feb_sc, m_settings);
        o = false;
    }

}

int frontend_init() {

    // create ODB and setup watch functions
    settings.connect_and_fix_structure("/Equipment/Quads/Settings");
    settings.watch(sc_settings_changed);
    m_settings.connect("/Equipment/Quads/Settings");

    // setup max event size
    set_max_event_size(dma_buf_size);

    // end and start of run
    install_begin_of_run(begin_of_run);
    install_end_of_run(end_of_run);
    install_frontend_exit(frontend_exit_user);
    install_frontend_loop(quad_loop);

    // init dma and mudaq device
    #ifdef NO_A10_BOARD

    #else
        mup = new mudaq::DmaMudaqDevice("/dev/mudaq0");
        int status = init_mudaq(*mup);
        if (status != SUCCESS) return FE_ERR_DRIVER;
        // switch off and reset DMA for now
        mup->disable();
    #endif

    // create ring buffer for readout thread
    //create_event_rb(0);

    // create readout thread
    ss_thread_create(read_stream_thread, NULL);

    //Set our transition sequence. The default is 500.
    cm_set_transition_sequence(TR_START, 300);

    //Set our transition sequence. The default is 500. Setting it
    // to 700 means we are called AFTER most other clients.
    cm_set_transition_sequence(TR_STOP, 700);

    // set write cache to 10MB
    // TODO: update MIDAS for this
    //set_cache_size("SYSTEM", 10000000);

    InitFEBs(*feb_sc, m_settings);

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
