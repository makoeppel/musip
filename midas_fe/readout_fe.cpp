/**
 * @file readout_fe.cpp
 * @brief MIDAS frontend for MUPIX data readout and DMA handling.
 *
 * This frontend handles the real-time data acquisition for MUPIX devices,
 * using direct memory access (DMA) to collect data blocks and transfer them
 * to MIDAS events. It sets up necessary buffers, device interfaces, and ODB
 * configuration to support robust data streaming.
 *
 * @details
 * Key functionalities:
 * - Initializes and maps a DMA buffer for high-throughput data acquisition.
 * - Manages device communication through `mudaq::DmaMudaqDevice`.
 * - Handles multiple event streams via software buffering (`mevents`).
 * - Provides run-time configuration through MIDAS Online Database (ODB).
 * - Supports both real hardware and dummy simulation via preprocessor flags.
 *
 * This file complements `quads_config_fe.cpp` by performing the actual
 * data acquisition, while `quads_config_fe.cpp` handles initialization
 * and configuration.
 *
 * @note Define `NO_A10_BOARD` to build without hardware-specific mappings.
 *
 * @author
 * Marius Snella Köppel
 * @date
 * 2025-07-04
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

#include <iomanip>
#include <iostream>
#include <list>
#include <sstream>
#include <string>

// clang-format off
#include "midas.h"
// clang-format on
#include <chrono>

#include "DummyFEBSlowcontrolInterface.h"
#include "FEBSlowcontrolInterface.h"
#include "mcstd.h"
#include "mfe.h"
#include "missing_hardware.h"
#include "msystem.h"
#include "mudaq_device.h"
#include "odb_setup.h"
#include "odbxx.h"
#include "utils.h"

// MIDAS settings
const char* frontend_name = "Readout";
const char* frontend_file_name = __FILE__;
BOOL equipment_common_overwrite = TRUE;

// Readout variables
volatile uint32_t* dma_buf;
uint32_t* dma_buf_local;
uint32_t reset_regs = 0;
uint16_t eventID_data = 301;
uint32_t readout_state_regs = 0;
bool use_software_dummy = false;
uint32_t n_mevents = 0;
uint32_t readout_timeout = 1000;
uint32_t use_timeout = true;
uint32_t cnt_loop = 0;
mudaq::DmaMudaqDevice* mup = nullptr;
mudaq::DmaMudaqDevice::DataBlock block;
std::vector<uint32_t> lvds_banks;
std::map<uint64_t, std::list<mevent_t>> mevents;
midas::odb m_settings;
bool saw_readout_enabled = false;

static void print_swb_counters(mudaq::DmaMudaqDevice& mu) {
    // counter / rate
    // 0-3: input link subheader cnt / rate
    // 4-7: input link hit cnt / rate
    // 8-11: input link package cnt / rate
    // 12: mux word cnt / rate
    printf("Input subheader (cnt / rate (Hz))\n");
    for (int i = 0; i <= 3; ++i) {
        mu.write_register(SWB_COUNTER_REGISTER_W, i);
        uint32_t cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R);
        uint32_t rate = mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);
        printf("Link:%i %i / %i\n", i, cnt, rate);
    }
    printf("Input hit (cnt / rate (Hz))\n");
    for (int i = 4; i <= 7; ++i) {
        mu.write_register(SWB_COUNTER_REGISTER_W, i);
        uint32_t cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R);
        uint32_t rate = mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);
        printf("Link:%i %i / %i\n", i, cnt, rate);
    }
    printf("Input package (cnt / rate (Hz))\n");
    for (int i = 8; i <= 11; ++i) {
        mu.write_register(SWB_COUNTER_REGISTER_W, i);
        uint32_t cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R);
        uint32_t rate = mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);
        printf("Link:%i %i / %i\n", i, cnt, rate);
    }
    mu.write_register(SWB_COUNTER_REGISTER_W, 12);
    uint32_t cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R);
    uint32_t rate = mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);
    printf("MUX out (cnt / rate (Hz)):%i / %i\n", cnt, rate);

    printf("DMA hit cnt out: %i \n",
           mu.read_register_ro(EVENT_BUILD_IDLE_NOT_HEADER_R) * 4);  // hit cnt to DMA
    printf("DMA hit rate out: %i \n",
           mu.read_register_ro(EVENT_BUILD_TAG_FIFO_FULL_R));  // fifo rate to DMA
    printf("DMA skip hit cnt: %i \n",
           mu.read_register_ro(EVENT_BUILD_SKIP_EVENT_DMA_R) * 4);  // hit drop DMA busy
    printf("DMA FIFO full: %i \n", mu.read_register_ro(BUFFER_STATUS_REGISTER_R));  // fifo full cnt
}

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
    // setup readout state register
    readout_state_regs = 0;

    // get copy of setting
    m_settings.connect("/Equipment/Quads/Settings");

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
    if ((bool)m_settings["Readout"]["Datagen Enable"]) {
        // setup data generator
        cm_msg(MINFO, "readout_fe", "Use datagenerator with divider register %i",
               (int)m_settings["Readout"]["Datagen Divider"]);
        mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W,
                          (int)m_settings["Readout"]["Datagen Divider"]);
        readout_state_regs = SET_USE_BIT_GEN_LINK(readout_state_regs);
    }
#endif

    if ((bool)m_settings["Readout"]["use_merger"]) {
        // readout merger
        cm_msg(MINFO, "readout_fe", "Use Time Merger");
        readout_state_regs = SET_USE_BIT_MERGER(readout_state_regs);
    } else {
        // readout stream
        cm_msg(MINFO, "readout_fe", "Use Stream Merger");
        readout_state_regs = SET_USE_BIT_STREAM(readout_state_regs);
    }
    readout_state_regs = SET_USE_BIT_GENERIC(readout_state_regs);
    use_software_dummy = (bool)m_settings["Readout"]["Software dummy"];
    n_mevents = (int)m_settings["Readout"]["n_mevents"];

#ifdef NO_A10_BOARD

#else
    // write readout register
    mu.write_register(SWB_READOUT_STATE_REGISTER_W, readout_state_regs);

    // request to read blocks of 256 bits
    mu.write_register(GET_N_DMA_WORDS_REGISTER_W,
                      (int)m_settings["Readout"]["max_requested_words"]);

    // set event id for this frontend
    mu.write_register(FARM_EVENT_ID_REGISTER_W, eventID_data);

    // link masks
    mu.write_register(SWB_GENERIC_MASK_REGISTER_W, (int)m_settings["Readout"]["mask_n_generic"]);

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

int create_midas_events(uint32_t* dmaBuffer, uint32_t dmaBufSize, int rbh) {
    // dmaBufSize is passed as maxidx, so the valid number of uint32_t words is dmaBufSize + 1
    const uint32_t n_u32 = dmaBufSize + 1;

    if (dmaBuffer == nullptr || n_u32 < 2)
        return SUCCESS;

    // Need pairs of uint32_t to form one uint64_t
    const uint32_t n_u32_even = n_u32 & ~1U;
    const uint32_t n_u64 = n_u32_even / 2;

    if (n_u64 == 0)
        return SUCCESS;

    static constexpr uint64_t kTimestampMask = (1ULL << 39) - 1ULL;  // bits 0..38
    static constexpr uint64_t kFrameTicks = 2000ULL;                 // 16 us / 8 ns

    struct HitWord {
        uint64_t word;
        uint64_t ts;
        uint64_t frame;
    };

    std::vector<HitWord> hits;
    hits.reserve(n_u64);

    // Rebuild 64-bit words from DMA buffer
    // Assumption: dmaBuffer[0]=low32, dmaBuffer[1]=high32
    for (uint32_t i = 0; i < n_u32_even; i += 2) {
        uint64_t word =
            static_cast<uint64_t>(dmaBuffer[i]) | (static_cast<uint64_t>(dmaBuffer[i + 1]) << 32);

        uint64_t ts = word & kTimestampMask;
        uint64_t frame = ts / kFrameTicks;

        hits.push_back({word, ts, frame});
    }

    // Sort by timestamp
    std::sort(hits.begin(), hits.end(),
              [](const HitWord& a, const HitWord& b) { return a.ts < b.ts; });

    // Reserve ONE MIDAS event
    void* p = nullptr;
    int status = rb_get_wp(rbh, &p, 10);
    if (status == DB_TIMEOUT)
        return DB_TIMEOUT;
    if (status != DB_SUCCESS) {
        cm_msg(MERROR, "create_midas_events", "rb_get_wp failed with status %d", status);
        return status;
    }

    char* event = reinterpret_cast<char*>(p);

    auto eventHeader = reinterpret_cast<EVENT_HEADER*>(event);
    bm_compose_event_threadsafe(eventHeader, eventID_data, 0, 0, &equipment[0].serial_number);

    auto bankHeader = reinterpret_cast<BANK_HEADER*>(eventHeader + 1);
    bk_init32a(bankHeader);

    // Walk frame-by-frame and create one bank per 16us frame
    size_t i = 0;
    uint32_t bank_idx = 0;

    while (i < hits.size()) {
        const uint64_t frame_id = hits[i].frame;

        size_t j = i + 1;
        while (j < hits.size() && hits[j].frame == frame_id) ++j;

        const size_t frame_nhits = j - i;

        // Need unique 4-char bank name
        // Supports up to 1000 banks in one event: H000..H999
        if (bank_idx > 999) {
            cm_msg(MERROR, "create_midas_events",
                   "Too many 16us frames in one event (%u). Max supported with H000..H999 is 1000.",
                   bank_idx);
            break;
        }

        char bank_name[5];
        std::snprintf(bank_name, sizeof(bank_name), "H%03u", bank_idx);

        uint32_t* data = nullptr;
        bk_create(bankHeader, bank_name, TID_UINT32, reinterpret_cast<void**>(&data));

        // Store 64-bit words as two uint32_t words: low32, high32
        for (size_t k = 0; k < frame_nhits; ++k) {
            const uint64_t w = hits[i + k].word;
            data[2 * k] = static_cast<uint32_t>(w & 0xFFFFFFFFULL);
            data[2 * k + 1] = static_cast<uint32_t>((w >> 32) & 0xFFFFFFFFULL);
        }

        bk_close(bankHeader, data + 2 * frame_nhits);

        ++bank_idx;
        i = j;
    }

    eventHeader->data_size = bk_size(bankHeader);
    rb_increment_wp(rbh, sizeof(EVENT_HEADER) + eventHeader->data_size);

    return SUCCESS;
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

    // timeout for DMA
    bool timeout = false;

    // dummy buffer for test data
    int nEvents = 5000;
    size_t eventSize = 32;                                             // in 4-byte words
    size_t dmaBufSize_dummy = nEvents * eventSize * sizeof(uint32_t);  // buffer size in bytes
    std::unique_ptr<uint32_t[]> dma_buf_dummy(static_cast<uint32_t*>(malloc(dmaBufSize_dummy)));

    // actuall readout loop
    while (is_readout_thread_enabled()) {
        std::chrono::steady_clock::time_point begin = std::chrono::steady_clock::now();

        // don't readout events if we are not running
        if (!readout_enabled()) {
            // we start from zero again
            serial_number = 0;
            // printf("Not running!\n");
            //  do not produce events when run is stopped
            ss_sleep(10);  // don't eat all CPU
            continue;
        }

        // start dma
        if (!timeout)
            mu.enable_continous_readout(0);
        // wait for requested data
        cnt_loop = 0;
        timeout = false;
        while ((mu.read_register_ro(EVENT_BUILD_STATUS_REGISTER_R) & 1) == 0) {
            if (use_timeout && cnt_loop++ >= readout_timeout) {
                timeout = true;
                break;
            }
            if (!readout_enabled())
                break;  // TODO: we break here hard later the firmware should stop at run end
            ss_sleep(10);
        }

        // dont read from the buffer if the status is not done
        if (timeout)
            continue;

        // disable dma
        mu.disable();

        // get written words from FPGA in bytes
        uint32_t size_dma_buf = mu.last_endofevent_addr() * 256 / 8;
        uint32_t maxidx = (mu.last_endofevent_addr() + 1) * 8 - 1;
        uint32_t last_written = mu.last_written_addr();

        std::chrono::steady_clock::time_point end = std::chrono::steady_clock::now();
        std::cout << "Time difference (DMA) = "
                  << std::chrono::duration_cast<std::chrono::microseconds>(end - begin).count()
                  << "[µs]" << std::endl;

        begin = std::chrono::steady_clock::now();

        print_swb_counters(mu);
        uint32_t maxwords = (uint32_t)m_settings["Readout"]["max_requested_words"];
        printf("0x%08x 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x\n", mu.last_written_addr(),
               mu.last_endofevent_addr(), maxidx, size_dma_buf, maxwords, maxwords * 8);

        // std::cout << std::endl;
        // for(int i=0; i < 20; i++)
        //     std::cout << std::hex << i << " 0x" <<  dma_buf[i] << " ";
        // std::cout << std::endl;
        // printf("last_written\n");
        // for(int i=0; i < 20; i++)
        //     std::cout << std::hex << last_written+i << " 0x" <<  dma_buf[last_written+i] << " ";
        std::cout << std::endl;
        for (int i = -20; i < 20; i++)
            std::cout << std::hex << maxwords * 8 + i << " 0x" << dma_buf[maxwords * 8 + i]
                      << std::endl;
        // printf("maxidx\n");
        // for(int i=0; i < 20; i++)
        //     std::cout << std::hex << 0x3fbfff+i << " 0x" <<  dma_buf[0x3fbfff+i] << " ";
        // std::cout << std::endl;
        // int not_null = 0;
        // for(int i=maxwords*8; i >= 0; i--) {
        //     if (dma_buf[i] != 0) {
        //         std::cout << std::hex << i << " 0x" <<  dma_buf[i] << std::endl;
        //         not_null = i;
        //         break;
        //     }
        // }
        // for(int i=-20; i < 20; i++)
        //     std::cout << std::hex << not_null+i << " 0x" <<  dma_buf[not_null+i] << std::endl;
        // int not_one = 0;
        // for(int i=not_null; i >= 0; i--) {
        //     if (dma_buf[i] != 0xFFFFFFFF) {
        //         std::cout << std::hex << i << " 0x" <<  dma_buf[i] << std::endl;
        //         not_one = i;
        //         break;
        //     }
        // }
        // for(int i=-20; i < 20; i++)
        //     std::cout << std::hex << not_one+i << " 0x" <<  dma_buf[not_one+i] << std::endl;

        // std::cout << std::endl;

        // for(int i=0; i < 10; i++)
        //     std::cout << std::hex << " 0x" <<  dma_buf[i] << " ";
        // std::cout << std::endl;
        // std::cout << std::endl;

        // while ( true ) {};

        if (size_dma_buf > MUDAQ_DMABUF_DATA_LEN) {
            cm_msg(MERROR, "ro_swb_fe", "Read invalid DMA buffer size %i!\n", size_dma_buf);
            continue;
        }
        // [AK] NOTE: use direct copy as memcpy does not arantee
        //            non-optimization for volatile
        for (uint32_t i = 0; i < size_dma_buf / 4; i++) {
            dma_buf_local[i] = dma_buf[i];
        }

        // create MIDAS events
        create_midas_events(dma_buf_local, maxidx, rbh);

        end = std::chrono::steady_clock::now();
        std::cout << "Time difference (EVENT) = "
                  << std::chrono::duration_cast<std::chrono::microseconds>(end - begin).count()
                  << "[µs]" << std::endl;

        printf("0x%08x\n", mu.read_register_ro(EVENT_BUILD_IDLE_NOT_HEADER_R));
        printf("0x%08x\n", mu.read_register_ro(BUFFER_STATUS_REGISTER_R));
    }

    return SUCCESS;
}

int frontend_init() {
    // get copy of setting
    m_settings.connect("/Equipment/Quads/Settings");

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
    // set_cache_size("SYSTEM", 10000000);

    return SUCCESS;
}

EQUIPMENT equipment[] = {{
                             "Readout",     /* equipment name */
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
