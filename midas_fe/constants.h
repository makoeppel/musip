/**
 * @file constants.h
 * @brief Definitions of project-wide constants and event data structures.
 *
 * This header centralizes configuration constants used across the MuPix MIDAS
 * frontend, including parameters for DMA buffering, FEB and chip limits,
 * slow control protocol constraints, and data format definitions.
 *
 * It also declares the `mevent_t` structure, which defines the format for
 * decoded readout events from MuPix hardware.
 *
 * @details
 * Constants include:
 * - Maximum LVDS links per FEB
 * - Number of FEBs and chips
 * - DMA buffer sizing and usage
 * - Maximum message sizes for slow control
 * - Configuration payload lengths
 *
 * These constants provide a consistent interface across the data and control
 * subsystems of the DAQ framework.
 */

#pragma once

#include <array>
#include <map>
#include <string>
#include <vector>

#include "registers.h"

/* Maximum number of incoming LVDS data links per FEB */
constexpr uint32_t MAX_LVDS_LINKS_PER_FEB = 36;

/* Maximum number of total FEBs */
constexpr uint32_t N_FEBS = 4;

/* Maximum number of quad FEBs */
constexpr uint32_t N_FEBS_QUAD = 4;

/* Maximum number of mutrigs FEBs */
constexpr uint32_t N_MUTRIGS_PER_FEB = 4;

/* Maximum number of mutrigs channels */
constexpr uint32_t NMUTRIGCHANNELS = 32;

/* Maximum number of quad chips FEBs */
constexpr uint32_t N_CHIPS = 8;

/* Maximum number of chips FEBs */
constexpr uint32_t N_CHIPS_MAX = 12;

/* Number bytes mupix config */
constexpr uint32_t N_BYTES_MUPIX = 48;

/* Number bytes mutrig config */
constexpr uint32_t N_BYTES_MUTRIG = 333;

/* Number bit mutrig config */
constexpr uint32_t N_BITS_MUTRIG = 2662;

/* DMA constants */
constexpr size_t dma_buf_size = MUDAQ_DMABUF_DATA_LEN;
constexpr uint32_t dma_buf_nwords = dma_buf_size / sizeof(uint32_t);
// NOTE: this is a default value which fits the requiered conditions of the DMA engine
// we request 256bit words with this number and overall they have to be dividable by 4 KibiByte
// 0x80000 = 524288 -> 524288 x 256 = 134217728 -> 16384 KibiByte
constexpr uint32_t max_requested_words = 0x80000;

/* Link constants */
constexpr uint32_t MAX_SLOWCONTROL_MESSAGE_SIZE = 100 - 4;
constexpr uint32_t MAX_SLOWCONTROL_WRITE_MESSAGE_SIZE = (1 << 16) - 1;

/* Configuration payload length */
constexpr uint32_t length_32bits = 12;
constexpr uint32_t length = length_32bits * 4;

/* Configuration for ADC */
enum class ADC_Mode : uint8_t { Single = 0b0100, Sequence = 0b0010, All = 0b0001 };
enum class ADC_Command : uint8_t { Reset = 0b1000, Configure = 0b0100, Measure = 0b0010 };
enum class ADC_Mux_Address : uint8_t {
    ref_vssa = 0,
    Baseline = 1,
    blpix = 2,
    thpix = 3,
    blpix_2 = 4,
    ThLow = 5,
    ThHigh = 6,
    TEST_OUT = 7,
    vssa = 8,
    thpix_2 = 9,
    VCAL = 10,
    VTemp1 = 11,
    VTemp2 = 12
};
constexpr uint32_t nadcvals = 13;
const std::array<const std::string, 13> adcnames = {
    "Ref_VSSA", "Baseline", "blpix",   "thpix", "blpix_2", "ThLow", "ThHigh",
    "TestOut",  "VSSA",     "thpix_2", "VCAL",  "VTemp1",  "VTemp2"};

// readout event structure
struct mevent_t {
    struct dsin_t {
        uint32_t header;
        uint32_t ts_high;
        uint16_t package_counter, ts_low;
        uint32_t debug0;
        uint32_t debug1;
        uint16_t subheader_overflow, __zero0;
        uint16_t shead_cnt;
        uint8_t header_cnt, __zero1;
        uint32_t __AFFEAFFE[1];
    };

    dsin_t dsin{};
    std::vector<uint64_t> hits_pixel;
    std::vector<uint64_t> hits_fibre;
    std::vector<uint64_t> hits_tile;
    std::string hits_name_pixel = "----";
    std::string hits_name_fibre = "----";
    std::string hits_name_tile = "----";
};

struct resetcommand {
    const uint8_t command;
    bool has_payload;
};

struct reset {
    const std::map<std::string, resetcommand> commands = {
        {"Run Prepare", {0x10, true}},     {"Sync", {0x11, false}},
        {"Start Run", {0x12, false}},      {"End Run", {0x13, false}},
        {"Abort Run", {0x14, false}},      {"Start Link Test", {0x20, true}},
        {"Stop Link Test", {0x21, false}}, {"Start Sync Test", {0x24, true}},
        {"Stop Sync Test", {0x25, false}}, {"Test Sync", {0x26, true}},
        {"Reset", {0x30, true}},           {"Stop Reset", {0x31, true}},
        {"Enable", {0x32, false}},         {"Disable", {0x33, false}},
        {"Address", {0x40, true}}};
};

/*Timing detector common commands (mutrig)*/
constexpr uint16_t FEB_REPLY_SUCCESS = 0x0000;
constexpr uint16_t FEB_REPLY_ERROR = 0x0001;
constexpr uint16_t CMD_MUTRIG_ASIC_CFG = 0x0110; // configure ASIC # with pattern in payload. ASIC number is cmd&0x000F
/*commands 0x0110 ... 0x011f reserved*/
constexpr uint16_t CMD_MUTRIG_ASIC_OFF = 0x0130; // configure all off builtin pattern
constexpr uint16_t CMD_MUTRIG_CNT_RESET = 0x0160;
constexpr uint16_t CMD_TILE_TMB_INIT = 0x0200; // set necescary initial values on the TMB
constexpr uint16_t CMD_TILE_ASIC_PWR = 0x0210; // Power and configure ASIC, asics (payload[0]&0x1fff) will be powered on
constexpr uint16_t CMD_TILE_ASIC_PWROR = 0x0220; // ASIC power override (payload[0]&0x1fff) -> Analog supplies ; (payload[1]&0x1fff) -> Digital supplies
constexpr uint16_t CMD_TILE_TEMPERATURES_READ = 0x0230; // read out the Temperature of all sensors on the TMB
constexpr uint16_t CMD_TILE_POWERMONITORS_READ = 0x0240; // read out all powermonitors on the TMB
constexpr uint16_t CMD_TILE_TMB_STATUS = 0x0250; // read out the status of the Powermonitor
constexpr uint16_t CMD_TILE_INJECTION_SETTING = 0x0260; // change test pulse setting base on last bit: 0 -> off, 1 -> on
constexpr uint16_t CMD_TILE_TEMPERATURES_READ_IDS= 0x0270; // read out the Temperature sensor IDs of all sensors on the TMB
constexpr size_t N_TMB_MATRIX_TEMPERATURES = 26;
constexpr size_t N_TxTM_VALUES = 26;
constexpr size_t N_TMB_TEMPERATURES_VALUES = 26+1;
constexpr size_t N_TMB_TEMPERATURE_IDS_VALUES = 26*2+1;
constexpr float TMB_TEMPERATURE_FACTOR = 0.0078125;
constexpr size_t N_TMB_STATUS_VALUES = 4;
