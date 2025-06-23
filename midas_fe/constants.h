//

#include "registers.h"
#include <map>

/* Emulate the hardware */
#define NO_A10_BOARD 1

/* Maximum number of frontenboards */
constexpr uint32_t MAX_N_FRONTENDBOARDS = 128;

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


// Map /Equipment/Quads/Settings
midas::odb settings = {
    {"Readout", {
        {"Datagen Divider", 1000},
        {"Software dummy", false},
        {"Datagen Enable", false},
        {"mask_n_generic", 0x0},
        {"use_merger", false},
        {"max_requested_words", max_requested_words}
        {"MupixConfig", false},
        {"MupixTDACConfig", false},
        {"ResetASICs", false},
        {"DataGenEnable", false},
        {"DataGenDisable", false},
        {"DataGenBeforeSorter", false},
        {"DataGenAfterSorter", false},
        {"DataGenSync", false},
        {"DataGenFullSteam", false},
        {"DataGenRate", 0},
        {"ResetCounters", 0},
    }},
    {"DAQ", {
        {"Commands", {
            {"Load Firmware", false},
            {"Firmware File", ""},
            {"Firmware FEB ID", 0},
            {"FirmwareLoadProgress", 0.0},
            {"Reset Counters", false},
            {"Set Bypass", false},
            {"Unset Bypass", false},
            {"Set FEBs into running", false},
            {"Set FEBs into idle", false}
        }},
        {"Links", {
            {"LVDSLinkMask", std::array<bool, MAX_LVDS_LINKS_PER_FEB*N_FEBS>{true}},
            {"LVDSLinkInvert", std::array<bool, MAX_LVDS_LINKS_PER_FEB*N_FEBS>{false}},
            {"ASICMask", std::array<bool, N_CHIPS*N_FEBS>{false}},
            {"FEBsActive", std::array<bool, N_FEBS>{false}},
            {"Mapping",  {
                1,2,3,4,5,6,7,90,91,92,93,
                8,9,10,11,12,13,14,15,90,91,92,93,
                99,99,99,99,99,99,99,99,99,99,99,99,
                99,99,99,99,99,99,99,99,99,99,99,99
            }},
        }},
    }},
    {"Config", {
        {"BIASDACS", {
            // PLL
            {"VNVCO", std::array<uint32_t, N_CHIPS*N_FEBS>{23}},
            {"VPVCO", std::array<uint32_t, N_CHIPS*N_FEBS>{22}},
            {"VNTimerDel", std::array<uint32_t, N_CHIPS*N_FEBS>{20}},
            {"VPTimerDel", std::array<uint32_t, N_CHIPS*N_FEBS>{10}},
            {"VPPump", std::array<uint32_t, N_CHIPS*N_FEBS>{30}},
            {"VNLVDSDel", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"VNLVDS", std::array<uint32_t, N_CHIPS*N_FEBS>{16}},
            {"VPDcl", std::array<uint32_t, N_CHIPS*N_FEBS>{30}},
            {"VNDelPreEmp", std::array<uint32_t, N_CHIPS*N_FEBS>{32}},
            {"VPDelPreEmp", std::array<uint32_t, N_CHIPS*N_FEBS>{32}},
            {"VNDcl", std::array<uint32_t, N_CHIPS*N_FEBS>{10}},
            {"VNDelDcl", std::array<uint32_t, N_CHIPS*N_FEBS>{32}},
            {"VPDelDcl", std::array<uint32_t, N_CHIPS*N_FEBS>{32}},
            {"VNDelDclMux", std::array<uint32_t, N_CHIPS*N_FEBS>{32}},
            {"VPDelDclMux", std::array<uint32_t, N_CHIPS*N_FEBS>{32}},
            {"VNDel", std::array<uint32_t, N_CHIPS*N_FEBS>{10}},
            {"VNRegC", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            // Pixel
            {"VNPix", std::array<uint32_t, N_CHIPS*N_FEBS>{10}},
            {"VPLoadPix", std::array<uint32_t, N_CHIPS*N_FEBS>{5}},
            {"VNFBPix", std::array<uint32_t, N_CHIPS*N_FEBS>{3}},
            {"VNFollPix", std::array<uint32_t, N_CHIPS*N_FEBS>{5}},
            {"VNOutPix", std::array<uint32_t, N_CHIPS*N_FEBS>{5}},
            {"VPComp1", std::array<uint32_t, N_CHIPS*N_FEBS>{5}},
            {"VPComp2", std::array<uint32_t, N_CHIPS*N_FEBS>{5}},
            {"VNBiasPix", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"BLResDig", std::array<uint32_t, N_CHIPS*N_FEBS>{6}},
            {"BLResPix", std::array<uint32_t, N_CHIPS*N_FEBS>{6}},
            {"VNPix2", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"VNComp", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"VNDAC", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"VPDAC", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            // General
            {"ThRes", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"BiasBlock_on", std::array<uint32_t, N_CHIPS*N_FEBS>{5}},
            {"Bandgap_on", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"VPFoll", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"VNHB", std::array<uint32_t, N_CHIPS*N_FEBS>{0}}
        }},
        {"CONFDACS", {
            {"TestOut", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"AlwaysEnable", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"En2thre", std::array<uint32_t, N_CHIPS*N_FEBS>{1}},
            {"EnPLL", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"SelFast", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"count_sheep", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"NC1", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"disable_HB", std::array<uint32_t, N_CHIPS*N_FEBS>{1}},
            {"conf_res_n", std::array<uint32_t, N_CHIPS*N_FEBS>{1}},
            {"RO_res_n", std::array<uint32_t, N_CHIPS*N_FEBS>{1}},
            {"Ser_res_n", std::array<uint32_t, N_CHIPS*N_FEBS>{1}},
            {"Aur_res_n", std::array<uint32_t, N_CHIPS*N_FEBS>{1}},
            {"NC2", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"Tune_Reg_L", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"NC3", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"Tune_Reg_R", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"NC4", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"SelSlow", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"SelEx", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"invert", std::array<uint32_t, N_CHIPS*N_FEBS>{1}},
            {"slowdownlDColEnd", std::array<uint32_t, N_CHIPS*N_FEBS>{7}},
            {"EnSync_SC", std::array<uint32_t, N_CHIPS*N_FEBS>{1}},
            {"NC5", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"linksel", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"tsphase", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"sendcounter", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"resetckdivend", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"NC6", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"maxcycend", std::array<uint32_t, N_CHIPS*N_FEBS>{63}},
            {"slowdownend", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"timerend", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"ckdivend2", std::array<uint32_t, N_CHIPS*N_FEBS>{15}},
            {"ckdivend", std::array<uint32_t, N_CHIPS*N_FEBS>{0}}
        }},
        {"VDACS", {
            {"BLPix", std::array<uint32_t, N_CHIPS*N_FEBS>{60}},
            {"ThHigh", std::array<uint32_t, N_CHIPS*N_FEBS>{135}},
            {"ThLow", std::array<uint32_t, N_CHIPS*N_FEBS>{134}},
            {"Baseline", std::array<uint32_t, N_CHIPS*N_FEBS>{112}},
            {"ref_Vss", std::array<uint32_t, N_CHIPS*N_FEBS>{169}},
            {"VCAL", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"ThPix", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"ThHigh2", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"ThLow2", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
            {"VDAC1", std::array<uint32_t, N_CHIPS*N_FEBS>{0}},
        }},
        {"Nbits", {
            // BIASDACS
            {"VNTimerDel", 6},
            {"VPTimerDel", 6},
            {"VNDAC", 6},
            {"VPFoll", 6},
            {"VNComp", 6},
            {"VNHB", 6},
            {"VPComp2", 6},
            {"VPPump", 6},
            {"VNLVDSDel", 6},
            {"VNLVDS", 6},
            {"VNDcl", 6},
            {"VPDcl", 6},
            {"VNDelPreEmp", 6},
            {"VPDelPreEmp", 6},
            {"VNDelDcl", 6},
            {"VPDelDcl", 6},
            {"VNDelDclMux", 6},
            {"VPDelDclMux", 6},
            {"VNVCO", 6},
            {"VPVCO", 6},
            {"VNOutPix", 6},
            {"VPLoadPix", 6},
            {"VNBiasPix", 6},
            {"BLResDig", 6},
            {"VNPix2", 6},
            {"VPDAC", 6},
            {"VPComp1", 6},
            {"VNDel", 6},
            {"VNRegC", 6},
            {"VNFollPix", 6},
            {"VNFBPix", 6},
            {"VNPix", 6},
            {"ThRes", 6},
            {"BLResPix", 6},
            {"BiasBlock_on", 3},
            {"Bandgap_on", 1},
            // here all inverse?
            // CONFDACS
            {"SelFast", 1},
            {"count_sheep", 1},
            {"NC1", 5},
            {"TestOut", 4},
            {"disable_HB", 1},
            {"conf_res_n", 1},
            {"RO_res_n", 1},
            {"Ser_res_n", 1},
            {"Aur_res_n", 1},
            {"NC2", 1},
            {"Tune_Reg_L", 6},
            {"NC3", 1},
            {"Tune_Reg_R", 6},
            {"AlwaysEnable", 1},
            {"En2thre", 1},
            {"NC4", 4},
            {"EnPLL", 1},
            {"SelSlow", 1},
            {"SelEx", 1},
            {"invert", 1},
            {"slowdownlDColEnd", 5},
            {"EnSync_SC", 1},
            {"NC5", 3},
            {"linksel", 2},
            {"tsphase", 6},
            {"sendcounter", 1},
            {"resetckdivend", 4},
            {"NC6", 2},
            {"maxcycend", 6},
            {"slowdownend", 4},
            {"timerend", 4},
            {"ckdivend2", 6},
            {"ckdivend", 6},
            // VDACS
            {"VCAL", 8},
            {"BLPix", 8},
            {"ThPix", 8},
            {"ThHigh", 8},
            {"ThLow", 8},
            {"ThHigh2", 8},
            {"ThLow2", 8},
            {"Baseline", 8},
            {"VDAC1", 8},
            {"ref_Vss", 8}
        }},
        {"TDACS", {
            {"F0", ""},
            {"F1", ""},
            {"F2", ""},
            {"F3", ""},
            {"H0", ""},
            {"H1", ""},
            {"H2", ""},
            {"H3", ""}
        }}
    }}
};

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
