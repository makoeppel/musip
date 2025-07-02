//

#include "registers.h"
#include <map>

/* Emulate the hardware */
//#define NO_A10_BOARD 1

/* Maximum number of incoming LVDS data links per FEB */
constexpr uint32_t MAX_LVDS_LINKS_PER_FEB = 36;

/* Maximum number of total FEBs */
constexpr uint32_t N_FEBS = 4;

/* Maximum number of chips FEBs */
constexpr uint32_t  N_CHIPS = 8;

/* DMA constants */
constexpr size_t dma_buf_size = MUDAQ_DMABUF_DATA_LEN;
constexpr uint32_t dma_buf_nwords = dma_buf_size/sizeof(uint32_t);
constexpr uint32_t max_requested_words = dma_buf_nwords/2;

/* Link constants */
constexpr uint32_t MAX_SLOWCONTROL_MESSAGE_SIZE = 100-4;
constexpr uint32_t MAX_SLOWCONTROL_WRITE_MESSAGE_SIZE = (1<<16)-1;

/* Configuration payload length */
constexpr uint32_t length_32bits = 12;
constexpr uint32_t length = length_32bits*4;

// readout event structure
struct mevent_t {
    struct dsin_t {
        uint32_t header;
        uint32_t ts_high;
        uint16_t package_counter, ts_low;
        uint32_t debug0;
        uint32_t debug1;
        uint16_t subheader_overflow, __zero0;
        uint16_t shead_cnt; uint8_t header_cnt, __zero1;
        uint32_t __AFFEAFFE[1];
    };

    dsin_t dsin {};
    std::vector<uint64_t> hits;
    std::string hits_name = "----";
};

struct resetcommand {
    const uint8_t command;
    bool has_payload;
};

struct reset {
    const std::map<std::string, resetcommand> commands = {
        {"Run Prepare",     {0x10, true}},
        {"Sync",            {0x11, false}},
        {"Start Run",       {0x12, false}},
        {"End Run",         {0x13, false}},
        {"Abort Run",       {0x14, false}},
        {"Start Link Test", {0x20, true}},
        {"Stop Link Test",  {0x21, false}},
        {"Start Sync Test", {0x24, true}},
        {"Stop Sync Test",  {0x25, false}},
        {"Test Sync",       {0x26, true}},
        {"Reset",           {0x30, true}},
        {"Stop Reset",      {0x31, true}},
        {"Enable",          {0x32, false}},
        {"Disable",         {0x33, false}},
        {"Address",         {0x40, true}}
    };
};
