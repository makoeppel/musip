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
        std::cout << subkey.get_name() << " = " << subkey << " name = " << name << std::endl;
        if (subkey.get_name() == name) break;
        idx++;
    }
    return idx;
}

uint32_t getOffset(midas::odb odb, std::string name) {
    uint32_t offset = 0;
    for (midas::odb& subkey : odb) {
        std::cout << subkey.get_name() << " = " << subkey << " name = " << name << std::endl;
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
            std::cout << subkey.get_name() << " nbits:" << subkey << " value:" << m_config[subkey.get_name()][asicIDx] << " offset:" << offset << " idx:" << idx << std::endl;
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

int InitFEBs(FEBSlowcontrolInterface * feb_sc, midas::odb m_settings) {
    for (size_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        feb_sc->FEB_write(febIDx, MP_LVDS_LINK_MASK_REGISTER_W, (uint32_t) m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]);
        feb_sc->FEB_write(febIDx, MP_LVDS_LINK_MASK2_REGISTER_W, (uint32_t) (((uint64_t) m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]) >> 32));
        feb_sc->FEB_write(febIDx, MP_LVDS_INVERT_0_REGISTER_W, (uint32_t) m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]);
        feb_sc->FEB_write(febIDx, MP_LVDS_INVERT_1_REGISTER_W, (uint32_t) (((uint64_t) m_settings["DAQ"]["Links"]["LVDSLinkMask"][febIDx]) >> 32));
        feb_sc->FEB_write(febIDx, MP_CTRL_SPI_ENABLE_REGISTER_W, 0x00000000);
        feb_sc->FEB_write(febIDx, MP_CTRL_DIRECT_SPI_ENABLE_REGISTER_W, 0x00000000);
        feb_sc->FEB_write(febIDx, MP_CTRL_SLOW_DOWN_REGISTER_W, 0x0000001F);
    }
    return FE_SUCCESS;
}

int ConfigureASICs(midas::odb m_settings, uint8_t * bitpattern_w){

    int status = FE_SUCCESS;
    for (size_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        uint16_t ASICMask = m_settings["DAQ"]["Links"]["ASICMask"][febIDx];
        printf("%i %i \n", febIDx, ASICMask);
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        if (!FEBActive) continue;
        for (size_t asicMaskIDx = febIDx*N_CHIPS; asicMaskIDx < (febIDx+1)*N_CHIPS; asicMaskIDx++) {
            if (!((ASICMask >> asicMaskIDx) & 0x1)) continue;
            cm_msg(MINFO, "ConfigureASICs()", "/Settings/Config/ -> globalASIC-%i -> localASIC-%i on FEB-%i", asicMaskIDx, asicMaskIDx % N_CHIPS, febIDx);
            get_BiasDACs_from_odb(m_settings["Config"], bitpattern_w, asicMaskIDx);
            get_ConfDACs_from_odb(m_settings["Config"], bitpattern_w, asicMaskIDx);
            get_VDACs_from_odb(m_settings["Config"], bitpattern_w, asicMaskIDx);
            for (int i = 0; i < 48; i++)
                printf("i: %i-v: %i\n", i, bitpattern_w[i]);
        }
    }

    // // iterate over ASICs
    // for (auto feb : febs){
    //     for(auto asic : feb.GetActiveASICs()){
    //         uint32_t sc_status;

    //         uint16_t chipid = feb.GetGlobalASICIndex(asic);

    //         // TODO: Dont like this 999 special code, fix
    //         if ( MupixChipToConfigure != 999 && chipid != MupixChipToConfigure ) continue;
    //         if ( !feb.IsScEnabled() ) continue;

    //         // reset config
    //         config.reset();

    //         // structs from ODB
    //         odb modedacs(pixel_odb_prefix + "/Settings/MODES/" + std::to_string(chipid), true);
    //         std::string power_mode = modedacs["PowerMode"];
    //         std::string threshold_mode = modedacs["ThresholdMode"];

    //         odb biasdacs(pixel_odb_prefix + "/Settings/BIASDACS/" + std::to_string(chipid), true);
    //         config.Parse_BiasDACs_from_odb(biasdacs);

    //         odb confdacs(pixel_odb_prefix + "/Settings/CONFDACS/" + std::to_string(chipid), true);
    //         config.Parse_ConfDACs_from_odb(confdacs);

    //         odb coldacs(pixel_odb_prefix +"/Settings/VDACS/" + std::to_string(chipid), true);
    //         config.Parse_VDACs_from_odb(coldacs);

    //         if (power_mode == "Minimum") { //Minimum power
    //             config.setParameter("VNPix", 0);
    //             config.setParameter("VNFollPix", 0);
    //             config.setParameter("VNOutPix", 0);
    //             config.setParameter("VPComp1", 0);
    //             config.setParameter("VPComp2", 0);
    //             config.setParameter("VNDcl", 0);
    //             config.setParameter("VPDcl", 0);
    //             config.setParameter("VNLVDS", 0);
    //         }
    //         else if (power_mode == "OnlyClock") { //Intermediate between min and SC: only clock, no LVDS
    //             config.setParameter("VNPix", 0);
    //             config.setParameter("VNFollPix", 0);
    //             config.setParameter("VNOutPix", 0);
    //             config.setParameter("VPComp1", 0);
    //             config.setParameter("VPComp2", 0);
    //             config.setParameter("VNLVDS", 0);
    //         }
    //         else if (power_mode == "SC") { // Slow control only
    //             config.setParameter("VNPix", 0);
    //             config.setParameter("VNFollPix", 0);
    //             config.setParameter("VNOutPix", 0);
    //             config.setParameter("VPComp1", 0);
    //             config.setParameter("VPComp2", 0);
    //         }
    //         else if (power_mode == "SC_Analog") { //SC and analog circuits
    //             config.setParameter("VNOutPix", 0);
    //             config.setParameter("VPComp1", 0);
    //             config.setParameter("VPComp2", 0);
    //         }
    //         else if (power_mode == "SC_LineDriver") { // Slow and analog circuits and line driver
    //             config.setParameter("VPComp1", 0);
    //             config.setParameter("VPComp2", 0);
    //         }

    //         if (threshold_mode == "High") {
    //             config.setParameter("ThHigh", 200);
    //             config.setParameter("ThLow", 199);
    //         }
    //         else if (threshold_mode == "Medium") {
    //             config.setParameter("ThHigh", 125);
    //             config.setParameter("ThLow", 124);
    //         }
    //         cm_msg1(MINFO, "switch", "MupixFEB::ConfigureASICs()", "%s/Settings/*DACS/%i -> globalASIC-%i -> localASIC-%i on FEB-%i(maxASICs=%i,startIDx=%i). Power mode: %s, Threshold mode: %s", pixel_odb_prefix.c_str(), chipid, chipid, asic, feb.SB_Port(), feb.GetMaxASICs(), feb.GetASICStartIndex(), power_mode.c_str(), threshold_mode.c_str());

    //         uint32_t bitpattern_m;
    //         vector<vector<uint32_t> > payload_m;
    //         vector<uint32_t> payload;

    //         // TODO: Get rid of the exception here
    //         try {
    //             payload_m.push_back(vector<uint32_t>(reinterpret_cast<uint32_t*>(config.bitpattern_w),
    //             reinterpret_cast<uint32_t*>(config.bitpattern_w)+config.length_32bits));

    //             for(uint32_t j = 0; j<payload_m.at(0).size();j++){
    //                 bitpattern_m=0;
    //                 for(short i=0; i<32; i++){
    //                     bitpattern_m|= ((payload_m.at(0).at(j)>>i) & 0b1)<<(31-i);
    //                 }
    //                 payload.push_back(bitpattern_m);
    //             }

    //             sc_status = feb_sc.FEB_write(feb, MP_CTRL_COMBINED_START_REGISTER_W + asic, payload,true);

    //         } catch(std::exception& e) {
    //             cm_msg1(MERROR, equipment_name.c_str(), "setup_mupix", "Communication error while configuring MuPix %d: %s", chipid, e.what());
    //             set_equipment_status(equipment_name.c_str(), "SB-FEB Communication error", "red");
    //             status = FE_ERR_HW;
    //             break;
    //         }

    //         if(sc_status!=FEBSlowcontrolInterface::ERRCODES::OK){
    //             //configuration mismatch, report and break foreach-loop
    //             set_equipment_status(equipment_name.c_str(),  "MuPix config failed", "red");
    //             cm_msg1(MERROR, equipment_name.c_str(), "setup_mupix", "MuPix configuration error for ASIC %i", chipid);
    //             status = FE_ERR_HW;
    //             break;
    //         }

    //         // reset lvds links
    //         feb_sc.FEB_write(feb, MP_RESET_LVDS_N_REGISTER_W, 0x0);
    //         feb_sc.FEB_write(feb, MP_RESET_LVDS_N_REGISTER_W, 0x1);
    //     } // asic loop
    // } // feb loop

    return status;
}
