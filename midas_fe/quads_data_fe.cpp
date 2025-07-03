
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

#include <iostream>
#include <list>

// clang-format off
#include "midas.h"
// clang-format on
#include "mcstd.h"
#include "mfe.h"
#include "msystem.h"
#include "odbxx.h"

#define FMT_HEADER_ONLY
#include <fmt/core.h>

#include "DummyFEBSlowcontrolInterface.h"
#include "FEBSlowcontrolInterface.h"
#include "missing_hardware.h"
#include "mudaq_device.h"
#include "odb_setup.h"
#include "utils.h"

// MIDAS settings
const char* frontend_name = "Quads Data";
const char* frontend_file_name = __FILE__;
BOOL equipment_common_overwrite = TRUE;

// Readout variables
volatile uint32_t* dma_buf;
uint32_t* dma_buf_local;
uint32_t reset_regs = 0;
uint16_t eventID_data = 2;
uint32_t readout_state_regs = 0;
bool use_software_dummy = false;
uint32_t n_mevents = 0;
mudaq::DmaMudaqDevice* mup = nullptr;
mudaq::DmaMudaqDevice::DataBlock block;
std::vector<uint32_t> lvds_banks;
std::map<uint64_t, std::list<mevent_t>> mevents;
midas::odb m_settings;
bool saw_readout_enabled = false;

int init_mudaq(mudaq::MudaqDevice& mu) {
#ifdef NO_A10_BOARD
#else
    int fd = open("/dev/mudaq0_dmabuf", O_RDWR);
    if (fd < 0) {
        printf("fd = %d\n", fd);
        return FE_ERR_DRIVER;
    }
    dma_buf = reinterpret_cast<uint32_t*>(
        mmap(nullptr, MUDAQ_DMABUF_DATA_LEN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0));
#endif

    if (dma_buf == MAP_FAILED) {
        cm_msg(MERROR, "frontend_init", "mmap failed: dmabuf = %p\n", MAP_FAILED);
        return FE_ERR_DRIVER;
    }
    dma_buf_local = new (std::align_val_t(8)) uint32_t[MUDAQ_DMABUF_DATA_LEN];

    // open mudaq
    if (!mu.open()) {
        std::cout << "Could not open device " << std::endl;
        cm_msg(MERROR, "frontend_init", "Could not open device");
        return FE_ERR_DRIVER;
    }

    // check mudaq
    if (!mu.is_ok())
        return FE_ERR_DRIVER;
    else {
        cm_msg(MINFO, "frontend_init", "Mudaq device is ok");
    }

    // switch off the data generator (just in case ..)
    mu.write_register(DATAGENERATOR_REGISTER_W, 0x0);
    usleep(2000);

    // set DMA_CONTROL_W
    mu.write_register(DMA_CONTROL_W, 0x0);

    return SUCCESS;
}

int begin_of_run() {
#ifdef NO_A10_BOARD

#else
    mudaq::DmaMudaqDevice& mu = *mup;

    // set all in reset
    mu.write_register_wait(RESET_REGISTER_W, reset_regs, 100);

    // empty dma buffer
    for (uint32_t i = 0; i < dma_buf_nwords; i++) dma_buf[i] = 0;
#endif

#ifdef NO_A10_BOARD

#else
    if (m_settings["Readout"]["Datagen Enable"]) {
        // setup data generator
        cm_msg(MINFO, "quad_fe", "Use datagenerator with divider register %i",
               (int)stream_settings["Datagen Divider"]);
        mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, stream_settings["Datagen Divider"]);
        readout_state_regs = SET_USE_BIT_GEN_LINK(readout_state_regs);
    }
#endif

    // setup readout state register
    readout_state_regs = 0;
    if (m_settings["Readout"]["use_merger"]) {
        // readout merger
        cm_msg(MINFO, "quad_fe", "Use Time Merger");
        readout_state_regs = SET_USE_BIT_MERGER(readout_state_regs);
    } else {
        // readout stream
        cm_msg(MINFO, "quad_fe", "Use Stream Merger");
        readout_state_regs = SET_USE_BIT_STREAM(readout_state_regs);
    }
    readout_state_regs = SET_USE_BIT_GENERIC(readout_state_regs);
    use_software_dummy = m_settings["Readout"]["Software dummy"];
    n_mevents = m_settings["Readout"]["n_mevents"];

#ifdef NO_A10_BOARD

#else
    // write readout register
    mu.write_register(SWB_READOUT_STATE_REGISTER_W, readout_state_regs);

    // request to read dma_buffer_size / 2 (count in blocks of 256 bits)
    mu.write_register(GET_N_DMA_WORDS_REGISTER_W,
                      m_settings["Readout"]["max_requested_words"] / (256 / 32));

    // set event id for this frontend
    mu.write_register(FARM_EVENT_ID_REGISTER_W, eventID_data);

    // link masks
    mu.write_register(SWB_GENERIC_MASK_REGISTER_W, stream_settings["mask_n_generic"]);

    // release reset
    mu.write_register_wait(RESET_REGISTER_W, 0x0, 100);
#endif

    mevents.clear();

    saw_readout_enabled = false;

    return SUCCESS;
}

int end_of_run() { return SUCCESS; }

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

int create_midas_events(uint32_t* dmaBuffer, uint32_t dmaBufSize, int rbh, uint32_t idx) {
    // unpack event data
    EVENT_HEADER* eh = reinterpret_cast<EVENT_HEADER*>(dmaBuffer + idx);
    BANK_HEADER* bh = reinterpret_cast<BANK_HEADER*>(eh + 1);

    if (dmaBuffer[idx + 4] + 8 != eh->data_size)
        return -1;

    mevent_t mevent;
    int n_dsin_bank = 0;
    int n_hits_bank = 0;

    // loop over the banks, we define a global idx for start/end of the data and
    // an local offset
    uint32_t bank_offset = idx + 6;
    while (bank_offset - idx < bh->data_size / 4) {
        if (bank_offset >= dmaBufSize)
            return -1;

        BANK32A* b32a = reinterpret_cast<BANK32A*>(dmaBuffer + bank_offset);
        uint32_t bank_data_start = bank_offset + 4;
        uint32_t bank_data_end = bank_offset + b32a->data_size / 4 + 3;

        // check end value if its bigger then the RAM
        // which holds one MIDAS Event on the FPGA
        // 2^addr x 64bit / 8 = 16384 bytes
        if ((bank_data_end - bank_data_start) > 16384) {
            cm_msg(MERROR, "create_midas_events()",
                   "Event size %i bytes is bigger then max RAM size 16384 bytes on "
                   "FPGA!\n",
                   bank_data_end - bank_data_start);
            break;
        }

        // read DSIN and *HIT banks
        // and store them in `mevents`
        std::string bank_name = "----";
        memcpy(bank_name.data(), b32a->name, 4);
        if (bank_name == "DSIN") {
            n_dsin_bank += 1;
            memcpy(&mevent.dsin, b32a + 1, std::min<size_t>(sizeof(mevent.dsin), b32a->data_size));
        } else if (bank_name == "PHIT" || bank_name == "FHIT" || bank_name == "THIT" ||
                   bank_name == "DHPS" || bank_name == "DHFS" || bank_name == "DHTD") {
            n_hits_bank += 1;
            mevent.hits_name = bank_name;
            if (b32a->data_size % sizeof(uint64_t) != 0) {
                cm_msg(MERROR, "create_midas_events()", "invalid b32a->data_size = %d\n",
                       int(b32a->data_size));
            }
            size_t n = b32a->data_size / sizeof(mevent.hits[0]);
            mevent.hits.resize(n);
            memcpy(mevent.hits.data(), b32a + 1, n * sizeof(mevent.hits[0]));
        } else {
            cm_msg(MERROR, "create_midas_events()", "unexpected bank '%s'\n", bank_name.c_str());
        }

        bank_offset += b32a->data_size / 4 + 4;
    }

    if (n_dsin_bank == 0)
        cm_msg(MERROR, "create_midas_events()", "no dsin bank in dmabuf event\n");
    else if (n_dsin_bank > 1)
        cm_msg(MERROR, "create_midas_events()", "%d dsin banks in dmabuf event\n", n_dsin_bank);
    if (n_hits_bank == 0)
        cm_msg(MERROR, "create_midas_events()", "no hits bank in dmabuf event\n");
    else if (n_hits_bank > 1)
        cm_msg(MERROR, "create_midas_events()", "%d hits banks in dmabuf event\n", n_dsin_bank);

    uint64_t ts = (uint64_t(mevent.dsin.ts_high) << 16) | mevent.dsin.ts_low;
    if (n_dsin_bank > 0 && ts == 0) {
        cm_msg(MERROR, "create_midas_events()", "dsin.ts is zero\n");
        printf("dsin.ts is zero\n");
        for (int i = 0; i < sizeof(mevent.dsin) / 4; i++) {
            printf("%08X ", reinterpret_cast<uint32_t*>(&mevent.dsin)[i]);
        }
        printf("\n");
    }

    mevents[ts].push_back(mevent);
    if (mevents[ts].size() > 10) {
        cm_msg(MERROR, "create_midas_events()",
               "mevents.size() = %d and mevents[ts].size() = %d > 10\n", int(mevents.size()),
               int(mevents[ts].size()));
    }

    // wait until enough `ts` entries for 100 DSIN/HITS bank pairs
    if (mevents.size() < n_mevents) {
        return eh->data_size / 4 + 4;
    }

    // create MIDAS event
    void* event = nullptr;
    int status = 0;
    do {
        if (!is_readout_thread_enabled())
            return -1;
        if (!readout_enabled()) {
            if (saw_readout_enabled)
                cm_msg(MERROR, "create_midas_events()", "we are not running");
            saw_readout_enabled = true;
            return -1;
        }
        status = rb_get_wp(rbh, &event, 0);
        if (status == DB_TIMEOUT) {
            ss_sleep(10);
        } else if (status != DB_SUCCESS)
            return -1;
    } while (status == DB_TIMEOUT);
    if (!event) {
        cm_msg(MERROR, "create_midas_events()", "unexpected nullptr from rb_get_wp\n");
        return -1;
    }

    auto eventHeader = reinterpret_cast<EVENT_HEADER*>(event);
    bm_compose_event_threadsafe(eventHeader, eventID_data, 0, 0, &equipment[0].serial_number);
    auto bankHeader = reinterpret_cast<BANK_HEADER*>(eventHeader + 1);
    bk_init32a(bankHeader);  // create MIDAS bank

    // consume `mevents`
    // NOTE: last entry may not be finished -> keep it
    for (int i = 0; mevents.size() > 1 && i < 100; i++) {
        mevent_t::dsin_t dsin = mevents.begin()->second.front().dsin;
        // check dsin
        for (auto& mevent : mevents.begin()->second) {
            if (mevent.dsin.package_counter != dsin.package_counter) {
                cm_msg(MERROR, "create_midas_events()", "mismatch in dsin.package_counter\n");
            }
        }

        {  // - write DSIN bank
            char* data = nullptr;
            std::string bank_name = fmt::format("DS{:02d}", i);
            bk_create(bankHeader, bank_name.c_str(), TID_UINT32, reinterpret_cast<void**>(&data));
            memcpy(data, &dsin, sizeof(dsin));
            data += sizeof(dsin);
            bk_close(bankHeader, data);
        }
        {  // - write *HIT bank
            char* data = nullptr;
            std::string bank_name =
                mevents.begin()->second.front().hits_name.substr(2, 2) + fmt::format("{:02d}", i);
            bk_create(bankHeader, bank_name.c_str(), TID_UINT32, reinterpret_cast<void**>(&data));
            for (auto& mevent : mevents.begin()->second) {
                size_t bytes = mevent.hits.size() * sizeof(mevent.hits[0]);
                memcpy(data, mevent.hits.data(), bytes);
                data += bytes;
            }
            bk_close(bankHeader, data);
        }
        mevents.erase(mevents.begin());
    }

    eventHeader->data_size = bk_size(bankHeader);
    rb_increment_wp(rbh, sizeof(EVENT_HEADER) + eventHeader->data_size);  // in byte length

    return eh->data_size / 4 + 4;
}

int read_stream_thread(void*) {
    // get mudaq
    mudaq::DmaMudaqDevice& mu = *mup;

    // tell framework that we are alive
    signal_readout_thread_active(0, TRUE);

    // obtain ring buffer for inter-thread data exchange
    int rbh = get_event_rbh(0);
    int status;

    // serial number on the FPGA
    uint32_t serial_number = 0;

    // dummy buffer for test data
    int nEvents = 5000;
    size_t eventSize = 32;                                             // in 4-byte words
    size_t dmaBufSize_dummy = nEvents * eventSize * sizeof(uint32_t);  // buffer size in bytes
    std::unique_ptr<uint32_t[]> dma_buf_dummy(static_cast<uint32_t*>(malloc(dmaBufSize_dummy)));

    // actuall readout loop
    while (is_readout_thread_enabled()) {
        // don't readout events if we are not running
        if (!readout_enabled()) {
            // we start from zero again
            serial_number = 0;
            // printf("Not running!\n");
            //  do not produce events when run is stopped
            ss_sleep(10);  // don't eat all CPU
            continue;
        }

        // get midas buffer
        uint32_t* pdata;
        // obtain buffer space with 10 ms timeout
        status = rb_get_wp(rbh, reinterpret_cast<void**>(&pdata), 10);

        // just try again if buffer has no space
        if (status == DB_TIMEOUT) {
            // printf("WARNING: DB_TIMEOUT\n");
            ss_sleep(10);  // don't eat all CPU
            continue;
        }

        // stop if there is an error in the ODB
        if (status != DB_SUCCESS) {
            printf("ERROR: rb_get_wp -> rb_status != DB_SUCCESS\n");
            break;
        }

        if (use_software_dummy) {
            // emulate the FPGA event in software
            serial_number =
                create_dummy_event(dma_buf_dummy.get(), eventSize, nEvents, serial_number);

            // memcpy(pdata, dma_buf_dummy.get(), dmaBufSize_dummy);
            // rb_increment_wp(rbh, dmaBufSize_dummy);

            // create MIDAS events
            uint32_t idx = 0;
            int off = 0;
            while (idx < dmaBufSize_dummy) {
                off = create_midas_events(dma_buf_dummy.get(), dmaBufSize_dummy, rbh, idx);
                if (off == -1)
                    break;
                idx += off;
            }
        }
    }
    return SUCCESS;
}

int frontend_init() {
    m_settings.connect("/Equipment/Quads Config/Settings");

    // setup max event size
    set_max_event_size(dma_buf_size);

    // end and start of run
    install_begin_of_run(begin_of_run);
    install_end_of_run(end_of_run);
    install_frontend_exit(frontend_exit_user);

    // init dma and mudaq device
    mup = new mudaq::DmaMudaqDevice("/dev/mudaq0");
    int status = init_mudaq(*mup);
    if (status != SUCCESS)
        return FE_ERR_DRIVER;
    // switch off and reset DMA for now
    mup->disable();

    // set reset registers
    reset_regs = SET_RESET_BIT_DATA_PATH(reset_regs);
    reset_regs = SET_RESET_BIT_DATAGEN(reset_regs);
    reset_regs = SET_RESET_BIT_SWB_TIME_MERGER(reset_regs);
    reset_regs = SET_RESET_BIT_SWB_STREAM_MERGER(reset_regs);

    // create ring buffer for readout thread
    create_event_rb(0);

    // create readout thread
    ss_thread_create(read_stream_thread, NULL);

    // Set our transition sequence. The default is 500.
    cm_set_transition_sequence(TR_START, 300);

    // Set our transition sequence. The default is 500. Setting it
    //  to 700 means we are called AFTER most other clients.
    cm_set_transition_sequence(TR_STOP, 700);

    // set write cache to 10MB
    set_cache_size("SYSTEM", 10000000);

    return SUCCESS;
}

EQUIPMENT equipment[] = {{
                             "Quads Data",     /* equipment name */
                             {eventID_data, 0, /* event ID, trigger mask */
                              "SYSTEM",        /* event buffer */
                              EQ_USER,         /* equipment type */
                              0,               /* event source */
                              "MIDAS",         /* format */
                              TRUE,            /* enabled */
                              RO_RUNNING,      /* read always, except during
                                                  transistions and update ODB */
                              1000,            /* read every 1 sec */
                              0,               /* stop run after this event limit */
                              0,               /* number of sub events */
                              0,               /* log history every event */
                              "", "", ""},
                             NULL, /* readout routine */
                         },
                         {""}};
