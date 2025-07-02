//

#include "FEBSlowcontrolInterface.h"


uint32_t setParameter(uint8_t * bitpattern_w, uint32_t value, size_t offset, size_t nbits, bool inverted) {

    //printf("offset=%lu n=%lu\n", offset, nbits);
    uint32_t mask = 0x01;
    std::vector<uint8_t> bitorder;
    for(uint32_t pos = 0; pos < nbits; pos++)
        if (inverted) bitorder.push_back(nbits-pos-1);
        else bitorder.push_back(pos);
    for(uint32_t pos = 0; pos < nbits; pos++, mask <<= 1) {
        uint32_t n = (offset+bitorder.at(nbits-pos-1))%8;
        uint32_t b = (offset+bitorder.at(nbits-pos-1))/8;
        //printf("b:%3.3u.%1.1u = %u\n", b, n, mask&value);
        if ((mask & value) != 0 ) bitpattern_w[b] |=   1 << n;  // set nth bit
        else                      bitpattern_w[b] &= ~(1 << n); // clear nth bit
    }
    return offset + nbits;
}

uint32_t getODBIdx(midas::odb odb, std::string name) {
    uint32_t idx = 0;
    for (midas::odb& subkey : odb) {
        if (false) std::cout << subkey.get_name() << " = " << subkey << " name = " << name << std::endl;
        if (subkey.get_name() == name) break;
        idx++;
    }
    return idx;
}

uint32_t getOffset(midas::odb odb, std::string name) {
    uint32_t offset = 0;
    for (midas::odb& subkey : odb) {
        if (false) std::cout << subkey.get_name() << " = " << subkey << " name = " << name << std::endl;
        if (subkey.get_name() == name) break;
        offset += (uint32_t) subkey;
    }
    return offset;
}

void get_DACs_from_odb(midas::odb m_nbits, midas::odb m_config, uint8_t * bitpattern_w, size_t asicIDx, std::string firstWord, std::string lastWord, bool inverted) {
    // NOTE: we assume here that the order of Nbits will not be changes
    // TOOD: make nbits a struct and not something of the ODB
    uint32_t idx = getODBIdx(m_nbits, firstWord);
    uint32_t offset = getOffset(m_nbits, firstWord);
    bool foundFirstWord = false;
    for (midas::odb& subkey : m_nbits) {
        if (subkey.get_name() == firstWord || foundFirstWord) {
            foundFirstWord = true;
            if (false) std::cout << subkey.get_name() << " nbits:" << subkey << " value:" << m_config[subkey.get_name()][asicIDx] << " offset:" << offset << " idx:" << idx << std::endl;
            offset = setParameter(bitpattern_w, m_config[subkey.get_name()][asicIDx], offset, subkey, inverted);
        }
        if (subkey.get_name() == lastWord) break;
    }
}

void get_BiasDACs_from_odb(midas::odb m_config, uint8_t * bitpattern_w, size_t asicIDx) {
    // TOOD: set first ("VNTimerDel") and last word ("Bandgap_on") as a const
    get_DACs_from_odb(m_config["Nbits"], m_config["BIASDACS"], bitpattern_w, asicIDx, "VNTimerDel", "Bandgap_on", true);
}

void get_ConfDACs_from_odb(midas::odb m_config, uint8_t * bitpattern_w, size_t asicIDx) {
    // TOOD: set first ("SelFast") and last word ("ckdivend") as a const
    get_DACs_from_odb(m_config["Nbits"], m_config["CONFDACS"], bitpattern_w, asicIDx, "SelFast", "ckdivend", false);
}

void get_VDACs_from_odb(midas::odb m_config, uint8_t * bitpattern_w, size_t asicIDx) {
    // TOOD: set first ("VCAL") and last word ("ref_Vss") as a const
    get_DACs_from_odb(m_config["Nbits"], m_config["VDACS"], bitpattern_w, asicIDx, "VCAL", "ref_Vss", false);
}

int InitFEBs(FEBSlowcontrolInterface & feb_sc, midas::odb m_settings) {
    for (size_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        if (!FEBActive) continue;
        // set FPGA ID
        feb_sc.FEB_write(febIDx, FPGA_ID_REGISTER_RW, febIDx);
        vector<uint32_t> data(1);
        feb_sc.FEB_read(febIDx, FPGA_ID_REGISTER_RW, data);
        if ((febIDx & 0xffff) == (data[0] & 0xffff) )
            cm_msg(MINFO, "InitFEBs()", "Successfully set FEBID of FEB %i to ID %i", febIDx, febIDx);
        feb_sc.FEB_write(febIDx, MP_LVDS_LINK_MASK_REGISTER_W, (uint32_t) m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]);
        feb_sc.FEB_write(febIDx, MP_LVDS_LINK_MASK2_REGISTER_W, (uint32_t) (((uint64_t) m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]) >> 32));
        feb_sc.FEB_write(febIDx, MP_LVDS_INVERT_0_REGISTER_W, (uint32_t) m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]);
        feb_sc.FEB_write(febIDx, MP_LVDS_INVERT_1_REGISTER_W, (uint32_t) (((uint64_t) m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]) >> 32));
        feb_sc.FEB_write(febIDx, MP_CTRL_SPI_ENABLE_REGISTER_W, 0x00000000);
        feb_sc.FEB_write(febIDx, MP_CTRL_DIRECT_SPI_ENABLE_REGISTER_W, 0x00000000);
        feb_sc.FEB_write(febIDx, MP_CTRL_SLOW_DOWN_REGISTER_W, 0x0000001F);
    }
    return FE_SUCCESS;
}

int ConfigureASICs(FEBSlowcontrolInterface & feb_sc, midas::odb m_settings, uint8_t * bitpattern_w) {

    int status = FE_SUCCESS;
    for (size_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        uint16_t ASICMask = m_settings["DAQ"]["Links"]["ASICMask"][febIDx];
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        if (!FEBActive) continue;
        for (size_t asicMaskIDx = febIDx*N_CHIPS; asicMaskIDx < (febIDx+1)*N_CHIPS; asicMaskIDx++) {
            if (!((ASICMask >> asicMaskIDx) & 0x1)) continue;
            cm_msg(MINFO, "ConfigureASICs()", "/Settings/Config/ -> globalASIC-%i -> localASIC-%i on FEB-%i", asicMaskIDx, asicMaskIDx % N_CHIPS, febIDx);
            get_BiasDACs_from_odb(m_settings["Config"], bitpattern_w, asicMaskIDx);
            get_ConfDACs_from_odb(m_settings["Config"], bitpattern_w, asicMaskIDx);
            get_VDACs_from_odb(m_settings["Config"], bitpattern_w, asicMaskIDx);

            if (false) for (int i = 0; i < 48; i++) printf("i: %i-v: %i\n", i, bitpattern_w[i]);

            // get payload for configuration
            std::vector<uint32_t> payload;
            const uint32_t* bitpattern_ptr = reinterpret_cast<const uint32_t*>(bitpattern_w);
            for (uint32_t i = 0; i < length_32bits; ++i) {
                uint32_t reversed_word = 0;
                for (int j = 0; j < 32; ++j)
                    reversed_word |= ((bitpattern_ptr[i] >> j) & 0b1) << (31 - j);
                payload.push_back(reversed_word);
            }
            if (false) for (int i = 0; i < payload.size(); i++) printf("i: %i-v: %i\n", i, payload[i]);

            status = feb_sc.FEB_write(febIDx, MP_CTRL_COMBINED_START_REGISTER_W + (asicMaskIDx % N_CHIPS), payload, true);
        }
    }

    return status;
}
