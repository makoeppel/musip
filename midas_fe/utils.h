//

#include "FEBSlowcontrolInterface.h"


uint32_t setParameter(uint8_t * bitpattern_w, uint32_t value, uint32_t offset, uint32_t nbits, bool inverted) {

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

void get_DACs_from_odb(midas::odb m_nbits, midas::odb m_config, uint8_t * bitpattern_w, uint32_t asicIDx, std::string firstWord, std::string lastWord, bool inverted) {
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

void get_BiasDACs_from_odb(midas::odb m_config, uint8_t * bitpattern_w, uint32_t asicIDx) {
    // TOOD: set first ("VNTimerDel") and last word ("Bandgap_on") as a const
    get_DACs_from_odb(m_config["Nbits"], m_config["BIASDACS"], bitpattern_w, asicIDx, "VNTimerDel", "Bandgap_on", true);
}

void get_ConfDACs_from_odb(midas::odb m_config, uint8_t * bitpattern_w, uint32_t asicIDx) {
    // TOOD: set first ("SelFast") and last word ("ckdivend") as a const
    get_DACs_from_odb(m_config["Nbits"], m_config["CONFDACS"], bitpattern_w, asicIDx, "SelFast", "ckdivend", false);
}

void get_VDACs_from_odb(midas::odb m_config, uint8_t * bitpattern_w, uint32_t asicIDx) {
    // TOOD: set first ("VCAL") and last word ("ref_Vss") as a const
    get_DACs_from_odb(m_config["Nbits"], m_config["VDACS"], bitpattern_w, asicIDx, "VCAL", "ref_Vss", false);
}

int InitFEBs(FEBSlowcontrolInterface & feb_sc, midas::odb m_settings) {
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
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
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        uint16_t ASICMask = m_settings["DAQ"]["Links"]["ASICMask"][febIDx];
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        if (!FEBActive) continue;
        for (uint32_t asicMaskIDx = febIDx*N_CHIPS; asicMaskIDx < (febIDx+1)*N_CHIPS; asicMaskIDx++) {
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

uint32_t generate_random_pixel_hit_swb(uint32_t time_stamp) {
   uint32_t tot = rand() % 32;  // 0 to 31
   uint32_t chipID = rand() % 3;// 0 to 2
   uint32_t col = rand() % 256; // 0 to 256
   uint32_t row = rand() % 250; // 0 to 250

   uint32_t hit = (time_stamp << 28) | (chipID << 22) | (row << 14) | (col << 6) | (tot << 1);

   return hit;
}

int create_dummy_event(uint32_t * dma_buf_dummy, size_t eventSize, int nEvents, int serial_number) {

    for (int i = 0; i < nEvents; i++) {
        // event header
        dma_buf_dummy[ 0 + i * eventSize] = 0x00000001;           // Trigger Mask & Event ID
        dma_buf_dummy[ 1 + i * eventSize] = serial_number++;      // Serial number
        dma_buf_dummy[ 2 + i * eventSize] = ss_time();            // time
        dma_buf_dummy[ 3 + i * eventSize] = eventSize * 4 - 4 * 4;// event size

        dma_buf_dummy[ 4 + i * eventSize] = eventSize * 4 - 6 * 4;// all bank size
        dma_buf_dummy[ 5 + i * eventSize] = 0x31;                 // flags

        // bank DHPS -- hits
        dma_buf_dummy[ 6 + i * eventSize] = 'D' << 0 | 'H' << 8 | 'P' << 16 | 'S' << 24;// bank name
        dma_buf_dummy[ 7 + i * eventSize] = 0x06;                                       // bank type TID_DWORD
        dma_buf_dummy[ 8 + i * eventSize] = 10 * 4;                                     // data size
        dma_buf_dummy[ 9 + i * eventSize] = 0x0;                                        // reserved

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
        dma_buf_dummy[20 + i * eventSize] = 'D' << 0 | 'S' << 8 | 'I' << 16 | 'N' << 24;// bank name
        dma_buf_dummy[21 + i * eventSize] = 0x6;                                       // bank type TID_DWORD
        dma_buf_dummy[22 + i * eventSize] = 8 * 4;                                     // data size
        dma_buf_dummy[23 + i * eventSize] = 0x0;                                       // reserved

        dma_buf_dummy[24 + i * eventSize] = 0xE80001BC;                              // preamble
        dma_buf_dummy[25 + i * eventSize] = serial_number++;                         // TS0
        dma_buf_dummy[26 + i * eventSize] = 0x0000 & serial_number & 0xFFFF;         // TS1
        dma_buf_dummy[27 + i * eventSize] = 0xFC000000;                              // DS0
        dma_buf_dummy[28 + i * eventSize] = 0xFC000000;                              // DS1
        dma_buf_dummy[29 + i * eventSize] = 0x00000000;                              // stuff
        dma_buf_dummy[30 + i * eventSize] = 0xAFFEAFFE;                              // PADDING
        dma_buf_dummy[31 + i * eventSize] = 0xAFFEAFFE;                              // PADDING
    }

    sleep(1);

    return serial_number;
}
