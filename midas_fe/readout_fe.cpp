/**
 * @file readout_fe.cpp
 * @brief MIDAS frontend for MUPIX data  and DMA handling.
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

#include <iostream>
#include <list>
#include <string>
#include <thread>

// clang-format off
#include "midas.h"
// clang-format on
#include <chrono>

#include "mcstd.h"
#include "mfe.h"
#include "missing_hardware.h"
#include "msystem.h"
#include "mudaq_device.h"
#include "odbxx.h"

// MIDAS settings
const char* frontend_name = "Readout";
const char* frontend_file_name = __FILE__;
BOOL equipment_common_overwrite = TRUE;

//  variables
uint8_t* dma_buf;
constexpr size_t dma_buf_size = MUDAQ_DMABUF_DATA_LEN;
uint32_t reset_regs = 0;
uint16_t eventID_data = 301;
uint32_t readout_state_regs = 0;
bool use_software_dummy = false;
uint32_t readout_timeout = 1000;
uint32_t use_timeout = true;
uint32_t cnt_loop = 0;
mudaq::DmaMudaqDevice* mup = nullptr;
mudaq::DmaMudaqDevice::DataBlock block;
std::vector<uint32_t> lvds_banks;
midas::odb m_settings;

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
        uint32_t rate = 0;
        printf("Link:%i %i / %i\n", i, cnt, rate);
    }
    printf("Input hit (cnt / rate (Hz))\n");
    for (int i = 4; i <= 7; ++i) {
        mu.write_register(SWB_COUNTER_REGISTER_W, i);
        uint32_t cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R);
        uint32_t rate = 0;
        printf("Link:%i %i / %i\n", i, cnt, rate);
    }
    printf("Input package (cnt / rate (Hz))\n");
    for (int i = 8; i <= 11; ++i) {
        mu.write_register(SWB_COUNTER_REGISTER_W, i);
        uint32_t cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R);
        uint32_t rate = 0;
        printf("Link:%i %i / %i\n", i, cnt, rate);
    }
    mu.write_register(SWB_COUNTER_REGISTER_W, 12);
    uint32_t cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R);
    uint32_t rate = 0;
    printf("MUX out (cnt / rate (Hz)):%i / %i\n", cnt, rate);

    printf("DMA hit cnt out: %i \n",
           mu.read_register_ro(EVENT_BUILD_IDLE_NOT_HEADER_R) * 4);  // hit cnt to DMA
    printf("DMA hit rate out: %i \n",
           mu.read_register_ro(EVENT_BUILD_TAG_FIFO_FULL_R));  // fifo rate to DMA
    printf("DMA skip hit cnt: %i \n",
           mu.read_register_ro(EVENT_BUILD_SKIP_EVENT_DMA_R) * 4);  // hit drop DMA busy
    printf("DMA FIFO full: %i \n", mu.read_register_ro(BUFFER_STATUS_REGISTER_R));  // fifo full cnt
}

uint64_t generate_random_pixel_hit_swb(bool print) {
    uint8_t chipID = rand() % 16;// 0 to 15
    uint8_t col = rand() % 256;  // 0 to 255
    uint8_t row = rand() % 250;  // 0 to 249
    uint32_t time = rand();
    uint64_t hit =
        ((uint64_t)(0 & 0x1) << 63) |
        ((uint64_t)(chipID & 0x3) << 61) |
        ((uint64_t)(col & 0xF) << 47) |
        ((uint64_t)(row & 0xF) << 39) |
        (uint64_t)time;

    return hit;
}

int init_mudaq(mudaq::MudaqDevice& mu) {
#ifdef NO_A10_BOARD
#else
    int fd = open("/dev/mudaq0_dmabuf", O_RDWR);
    if (fd < 0) {
        printf("fd = %d\n", fd);
        return FE_ERR_DRIVER;
    }
    dma_buf = reinterpret_cast<uint8_t*>(
        mmap(nullptr, MUDAQ_DMABUF_DATA_LEN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0));
#endif

    if (dma_buf == MAP_FAILED) {
        cm_msg1(MERROR, "quads", "frontend_init", "mmap failed: dmabuf = %p\n", MAP_FAILED);
        return FE_ERR_DRIVER;
    }

    // open mudaq
    if (!mu.open()) {
        std::cout << "Could not open device " << std::endl;
        cm_msg1(MERROR, "quads", "frontend_init", "Could not open device");
        return FE_ERR_DRIVER;
    }

    // check mudaq
    if (!mu.is_ok())
        return FE_ERR_DRIVER;
    else {
        cm_msg1(MINFO, "quads", "frontend_init", "Mudaq device is ok");
    }

    // switch off the data generator (just in case ..)
    mu.write_register(DATAGENERATOR_REGISTER_W, 0x0);
    usleep(2000);

    return SUCCESS;
}

int begin_of_run() {
    // setup  state register
    readout_state_regs = 0;

    // get copy of setting
    m_settings.connect("/Equipment/Quads/Settings");

#ifdef NO_A10_BOARD

#else
    mudaq::DmaMudaqDevice& mu = *mup;

    // set all in reset
    mu.write_register_wait(RESET_REGISTER_W, reset_regs, 100);

    // empty dma buffer
    memset(dma_buf, 0, dma_buf_size);
#endif

#ifdef NO_A10_BOARD

#else
    if ((bool)m_settings["Readout"]["Datagen Enable"]) {
        // setup data generator
        cm_msg1(MINFO, "quads", "readout_fe", "Use datagenerator");
        uint32_t nreqPkg = 0xFFFF, nreqSH = 16, nreqHits = 1;
        mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, (nreqPkg << 16) | (nreqHits << 8) | (nreqSH << 0));
        // start generator
        mu.write_register(SWB_READOUT_STATE_REGISTER_W, 0);
        uint32_t readout_state_regs = 0;
        readout_state_regs = SET_USE_BIT_GEN_LINK(readout_state_regs);
    }
#endif
    use_software_dummy = (bool) m_settings["Readout"]["Software dummy"];

#ifdef NO_A10_BOARD

#else
    // write readout register
    mu.write_register(SWB_READOUT_STATE_REGISTER_W, readout_state_regs);

    // link masks
    mu.write_register(SWB_GENERIC_MASK_REGISTER_W, (int) m_settings["Readout"]["mask_n_generic"]);

    // release reset
    mu.write_register_wait(RESET_REGISTER_W, 0x0, 100);
#endif

    return SUCCESS;
}

int end_of_run() {
    return SUCCESS;
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

int create_midas_events(const uint64_t* hits, size_t nHits, int rbh) {
    if(!hits) return -1;
    if(nHits == 0) return -1;

    // create MIDAS event
    void* event = nullptr;
    int status = 0;
    do {
        status = rb_get_wp(rbh, &event, 0);
        if(status == DB_TIMEOUT) {
            ss_sleep(10);
            continue;
        }
        if(status != DB_SUCCESS) {
            cm_msg1(MERROR, "quads", "create_midas_events", "rb_get_wp -> status = %d != DB_SUCCESS\n", status);
            return -1;
        }
        if(event == nullptr) {
            cm_msg1(MERROR, "quads", "create_midas_events", "rb_get_wp -> event = nullptr\n");
            return -1;
        }
    } while(status != DB_SUCCESS);
    auto eventHeader = reinterpret_cast<EVENT_HEADER*>(event);
    bm_compose_event_threadsafe(eventHeader, eventID_data, 0, 0, &equipment[0].serial_number);
    auto bankHeader = reinterpret_cast<BANK_HEADER*>(eventHeader + 1);
    bk_init32a(bankHeader); // create MIDAS bank

    uint64_t* data = nullptr;
    std::string bank_name = "H000";
    bk_create(bankHeader, bank_name.c_str(), TID_UINT32, reinterpret_cast<void**>(&data));
    size_t nFF = 0, nSH = 0, nH = 0;
    for(size_t i = 0; i < nHits; i++) {
        auto hit = hits[i];

        if(hit == UINT64_MAX) {
            // filler
            nFF += 1;
            continue;
        }
        if((hit >> 62) == 0b11) {
            // debug
            nFF += 1;
            //continue;
        }
        if((hit >> 62) == 0b00) {
            // subheaders
            nSH += 1;
            //continue;
        }
        else {
            nH += 1;
        }

        *data = hit;
        data += 1;
    }
    if(nSH > 0 || nH > 0) printf("create_midas_events: nFF = %d, nSH = %d, nHits = %d\n", nFF, nSH, nH);
    bk_close(bankHeader, data);

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

    // dummy buffer for test data
    int nHits = 5000;
    std::vector<uint64_t> dma_buf_dummy64;

    // disable DMA
    mu.enable_continous_readout(0);

    // dmabuf ring-buffer write/read pointers (bytes)
    size_t rb_wptr = 0, rb_rptr = 0;
    constexpr size_t RB_SIZE = MUDAQ_DMABUF_DATA_LEN;

    // timeout
    auto clock_start = std::chrono::steady_clock::now(), clock_end = clock_start;
    int rb_full = 0;
    auto rb_full_clock = std::chrono::steady_clock::now();

    // readout loop
    for(int readout_enabled_prev = 0;;) {
        int readout_enabled_cur = is_readout_thread_enabled() && readout_enabled();
        if(readout_enabled_prev == 1 && readout_enabled_cur == 0) {
            // stop generator
            printf("read_stream_thread: stop generator\n");
            mu.write_register(SWB_READOUT_STATE_REGISTER_W, 0);
            mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, 0);
            mu.write_register(SWB_GENERIC_MASK_REGISTER_W, 0);
        }
        if(!readout_enabled() || !is_readout_thread_enabled()) {
            // wait for dma flush
            if(std::chrono::steady_clock::now() > clock_end + std::chrono::milliseconds(500)) {
                // disable dma
                if(mu.read_register_rw(DMA_REGISTER_W) != 0) {
                    printf("read_stream_thread: disable DMA\n");
                    mu.write_register(DMA_REGISTER_W, 0);
                }
                if(!is_readout_thread_enabled()) {
                    // exit readout loop
                    break;
                }
                ss_sleep(10);
                continue;
            }
        }
        if(readout_enabled_prev == 0 && readout_enabled_cur == 1) {
            // enable dma while running
            printf("read_stream_thread: enable DMA\n");
            mu.write_register(DMA_REGISTER_W, 1);
        }
        readout_enabled_prev = readout_enabled_cur;

        // we generate the events in software
        if (use_software_dummy) {
            // create dummy hits
            uint64_t first_hit = generate_random_pixel_hit_swb(true);
            dma_buf_dummy64.push_back(first_hit);

            for(int i = 0; i < nHits; i++) {
                dma_buf_dummy64.push_back(generate_random_pixel_hit_swb(false));
            }

            // printf("hit64:hit32: %llx %x %x\n", dma_buf_dummy64[0], dma_buf_dummy32[0], dma_buf_dummy32.data()[0]);

            // create MIDAS events
            create_midas_events(dma_buf_dummy64.data(), dma_buf_dummy64.size(), rbh);
            dma_buf_dummy64.clear();
            ss_sleep(300); // limit data rate
            continue;
        }

        // update ring-buffer write pointer
        if(auto wptr = sizeof(uint32_t) * mu.last_written_addr(); rb_wptr != wptr) {
            rb_wptr = wptr;
            //printf("read_stream_thread: rptr/wptr = (%d)%08X/%08X\n", rb_rptr / RB_SIZE, rb_rptr % RB_SIZE, rb_wptr % RB_SIZE);
        }

        // NOTE: maximum block size is 256 kB
        uint64_t hits[256*1024/sizeof(uint64_t)];

        uint32_t rb_used = (rb_wptr % RB_SIZE - rb_rptr % RB_SIZE) % RB_SIZE;
        if(rb_used + 2*sizeof(hits) >= RB_SIZE) {
            rb_full += 1;
            if(std::chrono::steady_clock::now() > rb_full_clock + std::chrono::milliseconds(1000)) {
                //printf("read_stream_thread: ring-buffer is full\n");
                cm_msg1(MERROR, "quads", "read_stream_thread", "ring-buffer is full (%d times)\n", rb_full);
                rb_full = 0;
                rb_full_clock = std::chrono::steady_clock::now();
            }
        }

        // request more dma transfers
        // NOTE: `GET_N_DMA_WORDS_REGISTER_W` is used to request more data on-the-fly,
        //       i.e. one can request more data from `*_event_builder` while DMA readout is active
        // - in `farm_event_builder` `N_DMA_WORDS` counts in units of 512 kB
        // - in `hit_event_builder` `N_DMA_WORDS` counts in units of 256 bits
        if(rb_used + sizeof(hits) < RB_SIZE) {
            auto nWords = (rb_rptr + RB_SIZE - sizeof(hits)) / (256/8);
            //rwDMA_N_WORDS(nWords);
            mu.write_register(GET_N_DMA_WORDS_REGISTER_W, nWords);
        }

        if(rb_used < sizeof(hits)) {
            ss_sleep(10);
            continue;
        }
        memcpy(hits, dma_buf + rb_rptr % RB_SIZE, sizeof(hits));
        rb_rptr += sizeof(hits);

        clock_end = std::chrono::steady_clock::now();

        // create MIDAS events
        auto clock_start_create_event = std::chrono::steady_clock::now();
        if ( SUCCESS == create_midas_events(hits, sizeof(hits)/sizeof(hits[0]), rbh) ) {
            auto clock_end_create_event = std::chrono::steady_clock::now();
            auto dma_time = std::chrono::duration<double>(clock_end - clock_start).count();
            printf("nHits %i time %i\n", sizeof(hits)/sizeof(hits[0]), dma_time);
            m_settings["Readout"]["HitRate"] = (double) sizeof(hits)/sizeof(hits[0]) / (dma_time / 1e6);
        }
    }

    // disable dma
    mu.disable();
    // tell framework that we finished
    signal_readout_thread_active(0, FALSE);

    return SUCCESS;
}

int frontend_init() {

    // get copy of setting
    m_settings.connect("/Equipment/Quads/Settings");

    // setup max event size
    set_max_event_size(2*1024*1024);

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

    // create ring buffer for  thread
    create_event_rb(0);

    // create  thread
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
                             NULL, /*  routine */
                         },
                         {""}};
