/**
 * @file utils.h
 * @brief Utility functions for bit-level parameter setting and ODB indexing.
 *
 * This header provides common utility routines used in frontend configuration
 * and data preparation tasks. These functions support bitfield encoding
 * and MIDAS Online Database (ODB) access.
 *
 * @details
 * Included Functions:
 * - `getODBIdx`: Retrieves the index of a named subkey in a `midas::odb` structure.
 * - `getOffset`: Computes a bit offset for a named subkey in the ODB.
 * - `get_DACs_from_odb`: Writes DAC configuration bits from ODB to the bit pattern buffer.
 * - `get_BiasDACs_from_odb`: Extracts and writes Bias DAC configuration bits for a given ASIC.
 * - `get_ConfDACs_from_odb`: Extracts and writes Configuration DAC bits for a given ASIC.
 * - `get_VDACs_from_odb`: Extracts and writes Voltage DAC bits for a given ASIC.
 * - `InitFEBs`: Initializes all active Front-End Boards (FEBs) using slow control.
 * - `ConfigureASICs`: Configures all enabled ASICs across active FEBs using bit patterns.
 * - `generate_random_pixel_hit_swb`: Generates a simulated pixel hit for test data streams.
 * - `create_dummy_event`: Creates one or more dummy MIDAS events in memory.
 *
 * These utilities simplify frontend implementation by abstracting repetitive
 * logic related to bit encoding and dynamic configuration.
 *
 * @note These functions are performance-sensitive and should be used
 * with care in high-rate paths such as configuration loops.
 */

#include "FEBSlowcontrolInterface.h"
#include "bits_utils.h"

/**
 * @brief Gets the index of a named key in a MIDAS ODB object.
 *
 * Searches the top-level keys in a `midas::odb` structure and returns
 * the index of the key matching the provided name.
 *
 * @param odb The `midas::odb` object representing the configuration section.
 * @param name The name of the subkey to find.
 * @return uint32_t The index of the key if found, otherwise the total count.
 */
uint32_t getODBIdx(midas::odb odb, std::string name) {
    uint32_t idx = 0;
    for (midas::odb& subkey : odb) {
        if (false)
            std::cout << subkey.get_name() << " = " << subkey << " name = " << name << std::endl;
        if (subkey.get_name() == name)
            break;
        idx++;
    }
    return idx;
}

/**
 * @brief Computes the bit offset of a named field in a MIDAS ODB structure.
 *
 * Iterates through subkeys in an ODB group to determine the bit offset of
 * a given field, assuming each key represents a sequential bit region.
 *
 * @param odb The `midas::odb` group containing configuration fields.
 * @param name The name of the target field.
 * @return uint32_t The cumulative bit offset of the named field.
 */
uint32_t getOffset(midas::odb odb, std::string name) {
    uint32_t offset = 0;
    for (midas::odb& subkey : odb) {
        if (false)
            std::cout << subkey.get_name() << " = " << subkey << " name = " << name << std::endl;
        if (subkey.get_name() == name)
            break;
        offset += (uint32_t)subkey;
    }
    return offset;
}

/**
 * @brief Writes DAC configuration bits from ODB to the bit pattern buffer.
 *
 * This function reads DAC values from an ODB configuration and writes them
 * into a byte buffer as bit-encoded values, using the `setParameter` function.
 *
 * @param m_nbits ODB subkey describing bit widths for each DAC parameter.
 * @param m_config ODB subkey containing DAC values per ASIC.
 * @param bitpattern_w Target buffer for encoded configuration bits.
 * @param asicIDx Index of the ASIC to configure.
 * @param firstWord Name of the first DAC parameter to include.
 * @param lastWord Name of the last DAC parameter to include.
 * @param inverted Whether to encode bits in MSB-first (inverted) order.
 */
void get_DACs_from_odb(midas::odb m_nbits, midas::odb m_config, uint8_t* bitpattern_w,
                       uint32_t asicIDx, std::string firstWord, std::string lastWord,
                       bool inverted) {
    // NOTE: we assume here that the order of Nbits will not be changes
    // TOOD: make nbits a struct and not something of the ODB
    uint32_t idx = getODBIdx(m_nbits, firstWord);
    uint32_t offset = getOffset(m_nbits, firstWord);
    bool foundFirstWord = false;
    for (midas::odb& subkey : m_nbits) {
        if (subkey.get_name() == firstWord || foundFirstWord) {
            foundFirstWord = true;
            if (false)
                std::cout << subkey.get_name() << " nbits:" << subkey
                          << " value:" << m_config[subkey.get_name()][asicIDx]
                          << " offset:" << offset << " idx:" << idx << std::endl;
            offset = setParameter(bitpattern_w, m_config[subkey.get_name()][asicIDx], offset,
                                  subkey, inverted);
        }
        if (subkey.get_name() == lastWord)
            break;
    }
}

/**
 * @brief Extracts and writes Bias DAC configuration bits for a given ASIC.
 *
 * Calls `get_DACs_from_odb()` with hardcoded range for Bias DAC fields.
 *
 * @param m_config ODB root configuration node.
 * @param bitpattern_w Target buffer for encoded configuration bits.
 * @param asicIDx Index of the ASIC to configure.
 */
void get_BiasDACs_from_odb(midas::odb m_config, uint8_t* bitpattern_w, uint32_t asicIDx) {
    // TOOD: set first ("VNTimerDel") and last word ("Bandgap_on") as a const
    get_DACs_from_odb(m_config["Nbits"], m_config["BIASDACS"], bitpattern_w, asicIDx, "VNTimerDel",
                      "Bandgap_on", true);
}

/**
 * @brief Extracts and writes Configuration DAC bits for a given ASIC.
 *
 * Calls `get_DACs_from_odb()` with hardcoded range for Conf DAC fields.
 *
 * @param m_config ODB root configuration node.
 * @param bitpattern_w Target buffer for encoded configuration bits.
 * @param asicIDx Index of the ASIC to configure.
 */

void get_ConfDACs_from_odb(midas::odb m_config, uint8_t* bitpattern_w, uint32_t asicIDx) {
    // TOOD: set first ("SelFast") and last word ("ckdivend") as a const
    get_DACs_from_odb(m_config["Nbits"], m_config["CONFDACS"], bitpattern_w, asicIDx, "SelFast",
                      "ckdivend", false);
}

/**
 * @brief Extracts and writes Voltage DAC bits for a given ASIC.
 *
 * Calls `get_DACs_from_odb()` with hardcoded range for VDAC fields.
 *
 * @param m_config ODB root configuration node.
 * @param bitpattern_w Target buffer for encoded configuration bits.
 * @param asicIDx Index of the ASIC to configure.
 */
void get_VDACs_from_odb(midas::odb m_config, uint8_t* bitpattern_w, uint32_t asicIDx) {
    // TOOD: set first ("VCAL") and last word ("ref_Vss") as a const
    get_DACs_from_odb(m_config["Nbits"], m_config["VDACS"], bitpattern_w, asicIDx, "VCAL",
                      "ref_Vss", false);
}

/**
 * @brief Initializes all active Front-End Boards (FEBs) using slow control.
 *
 * Writes unique FPGA IDs and configures LVDS link settings for each active FEB.
 *
 * @param feb_sc Reference to the FEB slow control interface.
 * @param m_settings MIDAS ODB object containing DAQ link configuration.
 * @return FE_SUCCESS on success.
 */
int InitFEBs(FEBSlowcontrolInterface& feb_sc, midas::odb m_settings) {
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        if (!FEBActive)
            continue;
        // set FPGA ID
        feb_sc.FEB_write(febIDx, FPGA_ID_REGISTER_RW, febIDx);
        vector<uint32_t> data(1);
        feb_sc.FEB_read(febIDx, FPGA_ID_REGISTER_RW, data);
        if ((febIDx & 0xffff) == (data[0] & 0xffff))
            cm_msg(MINFO, "InitFEBs()", "Successfully set FEBID of FEB %i to ID %i", febIDx,
                   febIDx);
        feb_sc.FEB_write(febIDx, MP_LVDS_LINK_MASK_REGISTER_W,
                         (uint32_t)m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]);
        feb_sc.FEB_write(
            febIDx, MP_LVDS_LINK_MASK2_REGISTER_W,
            (uint32_t)(((uint64_t)m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]) >> 32));
        feb_sc.FEB_write(febIDx, MP_LVDS_INVERT_0_REGISTER_W,
                         (uint32_t)m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]);
        feb_sc.FEB_write(
            febIDx, MP_LVDS_INVERT_1_REGISTER_W,
            (uint32_t)(((uint64_t)m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]) >> 32));
        feb_sc.FEB_write(febIDx, MP_CTRL_SPI_ENABLE_REGISTER_W, 0x00000000);
        feb_sc.FEB_write(febIDx, MP_CTRL_DIRECT_SPI_ENABLE_REGISTER_W, 0x00000000);
        feb_sc.FEB_write(febIDx, MP_CTRL_SLOW_DOWN_REGISTER_W, 0x0000001F);
    }
    return FE_SUCCESS;
}

/**
 * @brief Sends a reset to all MuPix chips.
 *
 * Sends a reset to all MuPix chips.
 *
 * @param feb_sc Reference to the FEB slow control interface.
 * @param m_settings MIDAS ODB object containing DAQ and config sections.
 * @return FE_SUCCESS on success.
 */
int resetASICs(FEBSlowcontrolInterface& feb_sc, midas::odb m_settings) {
    cm_msg(MINFO, "resetASICs()", "Reset all ASICs");
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        if (!FEBActive)
            continue;
        feb_sc.FEB_write(febIDx, MP_CTRL_RESET_REGISTER_W, 0x00000001);
        sleep(2);
        feb_sc.FEB_write(febIDx, MP_CTRL_RESET_REGISTER_W, 0x00000000);
    }
    return FE_SUCCESS;
}

/**
 * @brief Configures all enabled ASICs across active FEBs using bit patterns.
 *
 * For each ASIC enabled by the ASIC mask, retrieves DAC configurations from the
 * ODB, encodes them into a payload, and sends them to the corresponding FEB.
 *
 * @param feb_sc Reference to the FEB slow control interface.
 * @param m_settings MIDAS ODB object containing DAQ and config sections.
 * @param bitpattern_w Temporary buffer used to build the configuration bitstream.
 * @return FE_SUCCESS if all ASICs configured successfully; error code otherwise.
 */
int ConfigureASICs(FEBSlowcontrolInterface& feb_sc, midas::odb m_settings, uint8_t* bitpattern_w) {
    int status = FE_SUCCESS;
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        uint16_t ASICMask = m_settings["DAQ"]["Links"]["ASICMask"][febIDx];
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        if (!FEBActive) continue;
        for (uint32_t asicMaskIDx = febIDx * N_CHIPS; asicMaskIDx < (febIDx + 1) * N_CHIPS;
             asicMaskIDx++) {
            if (!((ASICMask >> (asicMaskIDx % N_CHIPS)) & 0x1)) continue;
            cm_msg(MINFO, "ConfigureASICs()",
                   "/Settings/Config/ -> globalASIC-%i -> localASIC-%i on FEB-%i", asicMaskIDx,
                   asicMaskIDx % N_CHIPS, febIDx);
            get_BiasDACs_from_odb(m_settings["Config"], bitpattern_w, asicMaskIDx);
            get_ConfDACs_from_odb(m_settings["Config"], bitpattern_w, asicMaskIDx);
            get_VDACs_from_odb(m_settings["Config"], bitpattern_w, asicMaskIDx);

            if (false)
                for (int i = 0; i < 48; i++) printf("i: %i-v: %i\n", i, bitpattern_w[i]);

            // get payload for configuration
            std::vector<uint32_t> payload;
            const uint32_t* bitpattern_ptr = reinterpret_cast<const uint32_t*>(bitpattern_w);
            for (uint32_t i = 0; i < length_32bits; ++i) {
                uint32_t reversed_word = 0;
                for (int j = 0; j < 32; ++j)
                    reversed_word |= ((bitpattern_ptr[i] >> j) & 0b1) << (31 - j);
                payload.push_back(reversed_word);
            }
            if (false)
                for (int i = 0; i < payload.size(); i++) printf("i: %i-v: %i\n", i, payload[i]);

            status = feb_sc.FEB_write(
                febIDx, MP_CTRL_COMBINED_START_REGISTER_W + (asicMaskIDx % N_CHIPS), payload, true);
        }
    }

    return status;
}

uint64_t calculateADCCommand(ADC_Command adcCommand, uint16_t adcDivisionFactor, ADC_Mode adcMode) {
    constexpr uint64_t SteerADC = 0b100000;

    return ((static_cast<uint64_t>(adcMode) & 0xf) << 24)
        | ( static_cast<uint64_t>(adcDivisionFactor & 0x03ff) << 14)
        | ((static_cast<uint64_t>(adcCommand) & 0xf) << 10)
        | (SteerADC << 4);
}

void sendCommand(FEBSlowcontrolInterface& feb_sc, midas::odb m_settings, uint64_t command){
    uint32_t highBits = (command >> 32);
    uint32_t lowBits = (command & 0xffffffff);

    vector<uint32_t> commands(2 * N_CHIPS);
    for (int i = 0; i < 2 * N_CHIPS; i += 2) {
        commands[i] = lowBits;
        commands[i+1] = highBits;
    }

    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        if (!FEBActive) continue;
        feb_sc.FEB_write(febIDx, MP_CTRL_EXT_CMD_START_REGISTER_W, commands);
    }

    // TODO: Test how short this can be, maybe even remove completely
    constexpr auto waitTimeBetweenWrites = std::chrono::milliseconds(10);
    std::this_thread::sleep_for(waitTimeBetweenWrites);
}


void adcContinuousReadout(FEBSlowcontrolInterface& feb_sc, midas::odb m_settings){
    std::cout << "send adc\n";
    sendCommand(feb_sc, m_settings, calculateADCCommand(ADC_Command::Reset, 0x3f0, ADC_Mode::All));
    sendCommand(feb_sc, m_settings, calculateADCCommand(ADC_Command::Configure, 0x3f0, ADC_Mode::All));
    sendCommand(feb_sc, m_settings, calculateADCCommand(ADC_Command::Measure, 0x3f0, ADC_Mode::All));
}

/**
 * @brief Generates a simulated pixel hit for test data streams.
 *
 * Encodes a random chip, column, row, and time-over-threshold (ToT) value
 * into a 32-bit hit word.
 *
 * @param time_stamp Timestamp to embed in the hit word.
 * @return uint32_t Encoded hit data.
 */
uint32_t generate_random_pixel_hit_swb(uint32_t time_stamp) {
    uint32_t tot = rand() % 32;    // 0 to 31
    uint32_t chipID = rand() % 3;  // 0 to 2
    uint32_t col = rand() % 256;   // 0 to 256
    uint32_t row = rand() % 250;   // 0 to 250

    uint32_t hit = (time_stamp << 28) | (chipID << 22) | (row << 14) | (col << 6) | (tot << 1);

    return hit;
}

/**
 * @brief Creates one or more dummy MIDAS events in memory.
 *
 * Fills a provided DMA buffer with synthetic event headers and pixel hits.
 * This simulates what a real event would look like for testing purposes.
 *
 * @param dma_buf_dummy Pointer to the target DMA buffer.
 * @param eventSize Size of a single event (in words).
 * @param nEvents Number of events to create.
 * @param serial_number Starting event serial number (incremented internally).
 * @return Updated serial number after all events are written.
 */
int create_dummy_event(uint32_t* dma_buf_dummy, size_t eventSize, int nEvents, int serial_number) {
    for (int i = 0; i < nEvents; i++) {
        // event header
        dma_buf_dummy[0 + i * eventSize] = 0x00000001;             // Trigger Mask & Event ID
        dma_buf_dummy[1 + i * eventSize] = serial_number++;        // Serial number
        dma_buf_dummy[2 + i * eventSize] = ss_time();              // time
        dma_buf_dummy[3 + i * eventSize] = eventSize * 4 - 4 * 4;  // event size

        dma_buf_dummy[4 + i * eventSize] = eventSize * 4 - 6 * 4;  // all bank size
        dma_buf_dummy[5 + i * eventSize] = 0x31;                   // flags

        // bank DHPS -- hits
        dma_buf_dummy[6 + i * eventSize] =
            'D' << 0 | 'H' << 8 | 'P' << 16 | 'S' << 24;  // bank name
        dma_buf_dummy[7 + i * eventSize] = 0x06;          // bank type TID_DWORD
        dma_buf_dummy[8 + i * eventSize] = 10 * 4;        // data size
        dma_buf_dummy[9 + i * eventSize] = 0x0;           // reserved

        dma_buf_dummy[10 + i * eventSize] = 0x00000000;                                // hit0
        dma_buf_dummy[11 + i * eventSize] = generate_random_pixel_hit_swb(ss_time());  // hit0
        dma_buf_dummy[12 + i * eventSize] = 0x00000000;                                // hit1
        dma_buf_dummy[13 + i * eventSize] = generate_random_pixel_hit_swb(ss_time());  // hit1
        dma_buf_dummy[14 + i * eventSize] = 0x00000000;                                // hit2
        dma_buf_dummy[15 + i * eventSize] = generate_random_pixel_hit_swb(ss_time());  // hit2
        dma_buf_dummy[16 + i * eventSize] = 0x00000000;                                // hit3
        dma_buf_dummy[17 + i * eventSize] = generate_random_pixel_hit_swb(ss_time());  // hit3
        dma_buf_dummy[18 + i * eventSize] = 0x00000000;                                // hit4
        dma_buf_dummy[19 + i * eventSize] = generate_random_pixel_hit_swb(ss_time());  // hit5

        // bank DSIN second FEB
        dma_buf_dummy[20 + i * eventSize] =
            'D' << 0 | 'S' << 8 | 'I' << 16 | 'N' << 24;  // bank name
        dma_buf_dummy[21 + i * eventSize] = 0x6;          // bank type TID_DWORD
        dma_buf_dummy[22 + i * eventSize] = 8 * 4;        // data size
        dma_buf_dummy[23 + i * eventSize] = 0x0;          // reserved

        dma_buf_dummy[24 + i * eventSize] = 0xE80001BC;                       // preamble
        dma_buf_dummy[25 + i * eventSize] = serial_number++;                  // TS0
        dma_buf_dummy[26 + i * eventSize] = 0x0000 & serial_number & 0xFFFF;  // TS1
        dma_buf_dummy[27 + i * eventSize] = 0xFC000000;                       // DS0
        dma_buf_dummy[28 + i * eventSize] = 0xFC000000;                       // DS1
        dma_buf_dummy[29 + i * eventSize] = 0x00000000;                       // stuff
        dma_buf_dummy[30 + i * eventSize] = 0xAFFEAFFE;                       // PADDING
        dma_buf_dummy[31 + i * eventSize] = 0xAFFEAFFE;                       // PADDING
    }

    sleep(1);

    return serial_number;
}
