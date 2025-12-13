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
                         (uint32_t)m_settings["DAQ"]["Links"]["LVDSLinkInvert"][febIDx]);
        feb_sc.FEB_write(
            febIDx, MP_LVDS_INVERT_1_REGISTER_W,
            (uint32_t)(((uint64_t)m_settings["DAQ"]["Links"]["LVDSLinkInvert"][febIDx]) >> 32));
        feb_sc.FEB_write(febIDx, MP_CTRL_SPI_ENABLE_REGISTER_W, 0x00000000);
        feb_sc.FEB_write(febIDx, MP_CTRL_DIRECT_SPI_ENABLE_REGISTER_W, 0x00000000);
        feb_sc.FEB_write(febIDx, MP_CTRL_SLOW_DOWN_REGISTER_W, 0x0000001F);
        uint32_t delay = m_settings["Readout"]["Sorter Delay"][febIDx];
        feb_sc.FEB_write(febIDx, SORTER_COUNTER_REGISTER_R + SORTER_INDEX_DELAY, delay);
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

/**
 * @brief Read TDAC file from a given path.
 *
 * Tries to read a TDAC file from a given path. If the path is not present an empty
 * TDAC configuration (no pixel is masked) is created.
 *
 * @param vec Reference to the bitpattern vector.
 * @param path Path to th file.
 * @return FE_SUCCESS if the file is read; error code otherwise.
 */
int read_tdac_file(vector<uint32_t>& vec, std::string path) {
  std::ifstream file;
  file.open(path);
  if(file.fail()){
    cm_msg(MERROR, "read_tdac_file" , "Could not find tdac file %s", path.c_str());
    vec.clear();
    for(int i = 0; i<256*64; i++){
        vec.push_back(0x47474747); // has to be 47 as it send directly to the chip
        return FE_SUCCESS;
    }
  }
  else {
    vec.resize(256 * 64);
    file.read(reinterpret_cast<char*>(&vec[0]), 256 * 64 * sizeof(uint32_t));
    const uint32_t mask = 0x07070707;
    for (int col = 0; col < 256; ++col) {
        for (int row = 0; row < 62; ++row) {
            uint32_t val = vec[col * 64 + row];
            vec[col * 64 + row] = val ^ mask;
        }
        uint32_t val2 = vec[col * 64 + 62];
        vec[col * 64 + 62] = val2 ^ 0x0707;
        vec[col * 64 + 63] = 0xda00da00 | ((col&0xff) << 16);; // if read from file the last three values need to be inverted.
    }
  }
  file.close();
  return FE_SUCCESS;
}

/**
 * @brief Write TDACs to all enabled ASICs across active FEBs.
 *
 * For each ASIC enabled by the ASIC mask, retrieves TDAC configurations from a TDAC
 * file, encodes them into a payload, and sends them to the corresponding FEB.
 *
 * @param feb_sc Reference to the FEB slow control interface.
 * @param m_settings MIDAS ODB object containing DAQ and config sections.
 * @return FE_SUCCESS if all ASICs configured successfully; error code otherwise.
 */
int ConfigureTDACs(FEBSlowcontrolInterface& feb_sc, midas::odb m_settings) {
    // define variables for TDAC writing
    std::vector<std::vector<uint8_t>> pages_remaining;
    std::vector<std::vector<std::vector<uint32_t>>> tdac_pages;
    std::vector<uint8_t> pages_remaining_this_chip;
    uint32_t pages_remaining_this_feb;
    uint32_t N_DCOLS_PER_PAGE = 8;
    uint32_t PAGESIZE2 = 128*N_DCOLS_PER_PAGE;
    uint8_t N_PAGES_PER_CHIP= 128/N_DCOLS_PER_PAGE;
    uint8_t current_page = 0;
    uint32_t N_free_pages = 0;
    bool allDone = false;
    uint16_t internal_febID = 0;
    uint16_t pos = 0;
    std::map<uint16_t, uint32_t> nextchips;
    std::map<int, int> n_times_per_chip;

    // reset ASICs before writing
    resetASICs(feb_sc, m_settings);

    // read tdac files
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        uint16_t ASICMask = m_settings["DAQ"]["Links"]["ASICMask"][febIDx];
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        if (!FEBActive) continue;
        std::vector<std::vector<uint32_t>> tdac_page_this_feb;
        for (uint32_t asicMaskIDx = febIDx * N_CHIPS; asicMaskIDx < (febIDx + 1) * N_CHIPS;
             asicMaskIDx++) {
            if (!((ASICMask >> (asicMaskIDx % N_CHIPS)) & 0x1)) continue;
            pages_remaining_this_chip.push_back(N_PAGES_PER_CHIP);

            // read TDAC file
            // TODO: we only read the first TDAC file, this is hardcoded change me
            std::string path = m_settings["Config"]["TDACS"]["F0"];
            std::vector<uint32_t> tdac_chip(64*256);
            read_tdac_file(tdac_chip, path);
            cm_msg(MINFO, "ConfigureTDACs()",
                    "TDAC: %s -> globalASIC-%i -> localASIC-%i on FEB-%i",
                    path.c_str(), asicMaskIDx, asicMaskIDx % N_CHIPS, febIDx);
            tdac_page_this_feb.push_back(tdac_chip);
            n_times_per_chip[asicMaskIDx] = 0;
        }
        tdac_pages.push_back(tdac_page_this_feb);
        pages_remaining.push_back(pages_remaining_this_chip);
        pages_remaining_this_chip.clear();
        nextchips[internal_febID] = 0;
        internal_febID++;
    }
    cm_msg(MINFO, "ConfigureTDACs()" , "tdac load completed, start writing tdacs");

    // write tdac to chips
    while (! allDone) {
        allDone = true;
        internal_febID = 0;
        cm_yield(1);

        for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
            uint16_t ASICMask = m_settings["DAQ"]["Links"]["ASICMask"][febIDx];
            bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
            if (!FEBActive) continue;
            pages_remaining_this_feb = 0;
            for (uint32_t asicMaskIDx = febIDx * N_CHIPS; asicMaskIDx < (febIDx + 1) * N_CHIPS;
             asicMaskIDx++) {
                if (!((ASICMask >> (asicMaskIDx % N_CHIPS)) & 0x1)) continue;

                // get number of free tdac pages for this feb
                feb_sc.FEB_read(febIDx, MP_CTRL_N_FREE_PAGES_REGISTER_R, N_free_pages);

                uint32_t n_counter = 0;
                for (auto& n : pages_remaining.at(internal_febID)) {
                    pages_remaining_this_feb += n;
                    ++n_counter;
                }
                if(pages_remaining_this_feb > 0 || N_free_pages < 16)
                    allDone = false;

                // while the feb has space left ..
                while(N_free_pages > 0 && pages_remaining_this_feb > 0){
                    // Write one page for every chip
                    for (uint32_t chip = nextchips[internal_febID]; chip < pages_remaining.at(internal_febID).size(); chip++){
                        if (pages_remaining.at(internal_febID).at(chip) != 0){
                            if(N_free_pages > 0){
                                current_page = N_PAGES_PER_CHIP-pages_remaining.at(internal_febID)[chip];
                                pos = asicMaskIDx % N_CHIPS;
                                std::vector<uint32_t> tdac_page(PAGESIZE2);
                                tdac_page = std::vector<uint32_t>(tdac_pages.at(internal_febID).at(chip).begin() + current_page*PAGESIZE2, tdac_pages.at(internal_febID).at(chip).begin() + (current_page+1)*PAGESIZE2);
                                feb_sc.FEB_write(febIDx, MP_CTRL_TDAC_START_REGISTER_W + pos, tdac_page, true, false);
                                n_times_per_chip[asicMaskIDx] += 1;
                                pages_remaining.at(internal_febID)[chip] = pages_remaining.at(internal_febID)[chip] - 1;
                                pages_remaining_this_feb--;
                                N_free_pages--;
                            }
                            nextchips[internal_febID] = chip + 1;
                            if(nextchips[internal_febID] >= pages_remaining.at(internal_febID).size())
                                nextchips[internal_febID] = 0;
                        } else {
                            break;
                        }
                    }
                }
                internal_febID++;
            }
        }
    }

    cm_msg(MINFO, "ConfigureTDACs", "tdac write completed");

    return FE_SUCCESS;
}

/**
 * @brief Configure injection.
 * Structure of injection
 * 1.) Set VCal(a VDAC) in a different interface: chips for which VCal is set to none Zero will experience the injection
 *     This can however also be accomodated in this interface at some point, for now Chip Injection Selection via VCal
 * 2.) Select the pixel you want to inject:
 *     DISCLAIMER:
 *        Due to chip design choices, always two neighbouring pixels will be injected at the same time. ( Condition; int(col)/2=int(col+1)/2 [Integer Division]
 *        The selection is achieved via a crosshair selection: row and col adresses are set and all combinations of rows and cols will be anabled for injection.
 *        In this first approach we will only select one pixel at a time, ie. one row, one column.
 *        This should probably remain like this, due to the limited driving power of the Injection circuit.
 *      
 *     row and col are enabled via bits in the TEST register. each column houses 7 bits: --> 128x7bit long register
 *     [Enable Injection Row<0>,Enable Injection Row<1>,NCNC,AmpOut,Enable Injection Column, HitBusEnable]-->(Shift direction)-->
 *     The implementation for the characterisation setup can be found here: https://bitbucket.org/mu3e/mupix8_daq/src/master/library/sensors/MuPix11.cpp
 * 
 *  3.) Send Injection Command to trigger injection   [ 4 bit Chip Address | 6 bit Inject Command | 10 bit Duration | zeroes/ones/random ]
 * @param feb_sc Reference to the FEB slow control interface.
 * @param inj_col Reference to the FEB slow control interface.
 * @param inj_row MIDAS ODB object containing DAQ and config sections.
 * @return FE_SUCCESS if all ASICs configured successfully; error code otherwise.
 */
int ConfigureInjectASICs(FEBSlowcontrolInterface& feb_sc, const std::vector<uint8_t>& inj_col, const std::vector<uint8_t>& inj_row){

    // Commands vector, same command to all asics
    vector<uint32_t> commands(2 * N_FEBS_QUAD * N_CHIPS_MAX);

    const uint32_t command_wr_test = 0b101100;          // Write Command Test register
    const uint32_t command_ld_test = 0b001101;          // Load Command Test register
    const uint32_t command_inject  = 0b001000;          // Command to inject ONCE

    // Generic Command word variable
    uint64_t ScCommand = 0xf;
    uint32_t highBits = (ScCommand >> 32);
    uint32_t lowBits = (ScCommand & 0xffffffff);

    const uint8_t col_register_size = 7; //7 bit
    const uint8_t col_register_mask = 0x7F; //7 bit
    vector<uint8_t> TEST_register(128,0);   //all ZEROES

    // From trial and error the bit order seems to get reversed somewhere along the chain. So "Enable Injection Column"
    // (InjEn in internal Note 0052) is bit 1 and "Enable Injection Row<0>", "Enable Injection Row<1>" (EnInjRow<0>,
    // EnInjRow<1> in Note 0052) are bits 6 and 5 respectively (counting from zero).
    for(auto icol:inj_col)
    {
        TEST_register.at(icol/2) = TEST_register.at(icol/2) | (0x1<<1);
    }

    // Convert Adresses to Enable Signals
    for (auto irow:inj_row)
    {
        if((irow/2) < TEST_register.size())
        {
            if(irow%2 == 0)
                TEST_register.at(irow/2) = TEST_register.at(irow/2) | (0x1<<6);
            else if(irow%2 == 1)
                TEST_register.at(irow/2) = TEST_register.at(irow/2) | (0x1<<5);
        }
    }

    // Convert Test register to payload for Commands
    uint8_t register_counter = 0;
    const uint8_t payload_size = 54;
    const uint32_t total_register_size = 896;           //7 bits * 128 columns;
    // Create the payload vector the correct size and fill with zeros
    std::vector<uint64_t> TEST_register_payloads((total_register_size - 1) / payload_size + 1, 0);

    // register length and payload quantisation do not need to align --> zero padding at the beginning might be needed
    uint32_t zero_padding_size = payload_size - (total_register_size%payload_size);

    // ugly bit gymnastics ahead
    for (int32_t i = TEST_register.size()-1; i >= 0; --i, ++register_counter) {
        const unsigned total_bit_position = col_register_size * register_counter + zero_padding_size;
        const unsigned bit_position_this_payload = total_bit_position % payload_size;
        const unsigned payload_counter = total_bit_position / payload_size;

        TEST_register_payloads.at(payload_counter) |= (uint64_t(TEST_register.at(i) & col_register_mask) << bit_position_this_payload);

        if((bit_position_this_payload + col_register_size) > payload_size) {
            // This register stretches in to the next payload, so add the those left over bits now.
            const unsigned bit_overflow_count = bit_position_this_payload + col_register_size - payload_size;
            TEST_register_payloads.at(payload_counter + 1) |= (TEST_register.at(i) >> (col_register_size - bit_overflow_count));
            // Also mask away the extra bits we wrote into the high bits of this payload. Not strictly necessary
            // (they'll be shifted away when the payload gets sent) but it's cleaner for comparison checks.
            TEST_register_payloads.at(payload_counter) &= 0x003FFFFFFFFFFFFF; // Only keep the first payload_size bits
        }
    }

    // Sending Test register Payload and Load register
    // Write Register
    for(auto p: TEST_register_payloads)
    {
        ScCommand = (p << 10) | ( (command_wr_test & 0x3F) << 4 );
        highBits = (ScCommand >> 32);
        lowBits = (ScCommand & 0xffffffff);

        for (int i=0; i < 2 * N_FEBS_QUAD * N_CHIPS_MAX;i+=2)
        {
            commands[i] = lowBits;
            commands[i+1] = highBits;
        }
        feb_sc.FEB_broadcast(MP_CTRL_EXT_CMD_START_REGISTER_W, commands);
    }

    // Load Register
    ScCommand = (0x300 << 10) | ( (command_ld_test & 0x3F) << 4 );
    highBits = (ScCommand >> 32);
    lowBits = (ScCommand & 0xffffffff);

    for (int i=0; i < 2 * N_FEBS_QUAD * N_CHIPS_MAX; i+=2)
    {
        commands[i] = lowBits;
        commands[i+1] = highBits;
    }

    feb_sc.FEB_broadcast(MP_CTRL_EXT_CMD_START_REGISTER_W, commands);

    return FE_SUCCESS;
}

int InjectASICs(FEBSlowcontrolInterface& feb_sc, uint32_t injection_pulse_duration){

    //Commands vector, same command to all asics
    std::vector<uint32_t> commands(2 * N_FEBS_QUAD * N_CHIPS_MAX);

    const uint32_t command_wr_test = 0b101100;          // Write Command Test register
    const uint32_t command_ld_test = 0b001101;          // Load Command Test register
    const uint32_t command_inject  = 0b001000;          // Command to inject ONCE

    /**
     * INJECT
     * COMMENT: As implemented right now, this will inject into each VCAL selected chip with unknown delay,
     *          until detector BROADCAST becomes available.
     */

    const uint64_t ScCommand = ( (injection_pulse_duration & 0x3FF) << 10) | ( (command_inject & 0x3F) << 4 );
    const uint32_t highBits = (ScCommand >> 32);
    const uint32_t lowBits = (ScCommand & 0xffffffff);

    for (int i=0; i < 2 * N_FEBS_QUAD * N_CHIPS_MAX; i+=2)
    {
        commands[i] = lowBits;
        commands[i+1] = highBits;
    }

    feb_sc.FEB_broadcast(MP_CTRL_EXT_CMD_START_REGISTER_W, commands);

    /**
     * END INJECT
     */

    return FE_SUCCESS;
}

int InjectASICsInLoop(FEBSlowcontrolInterface& feb_sc, uint32_t injection_pulse_duration, uint32_t num_repetitions, uint32_t wait_between_pulses){
    const auto pulseWaitTime = std::chrono::milliseconds(wait_between_pulses);

    for(uint32_t i = 0 ; i < num_repetitions ; i++)
    {
        // This method can lock the frontend for quite a long time, depending on the parameters passed. So
        // Print a status report every now and then.
        //if((i % 10) == 9) cm_msg(MINFO, "InjectASICsInLoop" , "Sending injection trigger %u of %u\n", i + 1, num_repetitions);

        int result = InjectASICs(feb_sc, injection_pulse_duration);
        if(result != FE_SUCCESS) return result;
        // Here we sleep because the injection circuit has to recharge (10 ms seems to work)
        std::this_thread::sleep_for(pulseWaitTime);
    }

    return FE_SUCCESS;
}

int FullChipInjection(FEBSlowcontrolInterface& feb_sc, midas::odb m_settings,
    uint8_t min_columns, uint8_t max_columns,
    uint8_t min_rows, uint8_t max_rows,
    uint32_t injection_pulse_duration, uint32_t num_repetitions,
    uint32_t wait_between_pulses)
{
    std::vector<uint8_t> columns(2);
    std::vector<uint8_t> rows(3);

    constexpr auto waitTimeAfterConfigure = std::chrono::milliseconds(1);

    // --- Remainder (overshoot) handling ---
    // length of the scanned ranges
    const uint8_t col_range = max_columns - min_columns;
    const uint8_t row_range = max_rows - min_rows;

    // Double modulo to stick with uint8
    uint8_t r_column = ((col_range % 4) + 1) % 4;
    uint8_t r_row    = ((row_range % 3) + 1) % 3;

    // --- Main regular scan (no overshoot) ---
    // loop will break if next update will overshoot
    for (uint8_t c = min_columns; c <= max_columns - 3 && c <= 255 - 3; c += 4)
    {
        for (uint8_t r = min_rows; r <= max_rows - 2 && r <= 249 - 2; r += 3)
        {
            // ---- Fill columns ----
            for (uint8_t index = 0; index < columns.size(); ++index)
                columns[index] = c + 2 * index;

            // ---- Fill rows ----
            for (uint8_t index = 0; index < rows.size(); ++index)
                rows[index] = r + index;

            // ---- PRINT BEFORE CONFIGURE ----
            uint8_t col_start = columns.front();
            uint8_t col_end   = columns.back();
            uint8_t row_start = rows.front();
            uint8_t row_end   = rows.back();

            // ---- Actual injection ----
            ConfigureInjectASICs(feb_sc, columns, rows);
            std::this_thread::sleep_for(waitTimeAfterConfigure);
            InjectASICsInLoop(feb_sc, injection_pulse_duration, num_repetitions, wait_between_pulses);
            if (r >= 247) break;
        }

        if (c >= 252) break;

        if (!m_settings["DAQ"]["Commands"]["Full chip Injection"])
        {
            return FE_SUCCESS;
        }
    }

    // Computes the tail columns
    std::vector<uint8_t> columns_tail;
    if (r_column == 1)
    {
        columns_tail = { max_columns };
    }

    if (r_column == 2)
    {
        columns_tail = { max_columns - 1};
    }

    else if (r_column == 2)
    {
        columns_tail = { static_cast<uint8_t>(max_columns - 2), max_columns };
    }

    // Computes the tail rows
    std::vector<uint8_t> rows_tail;
    if (r_row == 1)
    {
        rows_tail = { max_rows };
    }
    else if (r_row == 2)
    {
        rows_tail = { static_cast<uint8_t>(max_rows - 1), max_rows };
    }

    // ---------- 1) Right strip: leftover columns, full row blocks ----------
    if (r_column != 0)
    {
        for (uint8_t r = min_rows; r <= max_rows - 2 && r <= 249 - 2; r += 3)
        {
            std::vector<uint8_t> rows_block{r, static_cast<uint8_t>(r + 1), static_cast<uint8_t>(r + 2)};

            ConfigureInjectASICs(feb_sc, columns_tail, rows_block);
            std::this_thread::sleep_for(waitTimeAfterConfigure);
            InjectASICsInLoop(feb_sc, injection_pulse_duration, num_repetitions, wait_between_pulses);
            if (r >= 247) break;
        }
    }

    // ---------- 2) Bottom strip: leftover rows, full column blocks ----------
    if (r_row != 0)
    {
        for (uint8_t c = min_columns;  c <= max_columns - 3 && c <= 255 - 3; c += 4)
        {
            std::vector<uint8_t> columns_block{c, static_cast<uint8_t>(c + 2)};

            ConfigureInjectASICs(feb_sc, columns_block, rows_tail);
            std::this_thread::sleep_for(waitTimeAfterConfigure);
            InjectASICsInLoop(feb_sc, injection_pulse_duration, num_repetitions, wait_between_pulses);
            if (c >= 252) break;
        }
    }

    // ---------- 3) Bottom-right corner: leftover rows AND columns ----------
    if (r_column != 0 && r_row != 0)
    {
        ConfigureInjectASICs(feb_sc, columns_tail, rows_tail);
        std::this_thread::sleep_for(waitTimeAfterConfigure);
        InjectASICsInLoop(feb_sc, injection_pulse_duration, num_repetitions, wait_between_pulses);
    }

    return FE_SUCCESS;
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

    vector<uint32_t> commands(2 * N_FEBS_QUAD * N_CHIPS_MAX);
    for (int i = 0; i < 2 * N_FEBS_QUAD * N_CHIPS_MAX; i += 2) {
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
