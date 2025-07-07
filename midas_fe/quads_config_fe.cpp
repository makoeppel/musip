/**
 * @file quads_config_fe.cpp
 * @brief MIDAS frontend for configuring and controlling MuPix quads.
 *
 * This frontend is part of the MIDAS data acquisition system. It handles
 * initialization, configuration, and control of MuPix devices using either
 * a real or dummy FEB (Front-End Board) slow control interface. It communicates
 * with the hardware via a `mudaq::MudaqDevice`, optionally utilizing DMA.
 *
 * @details
 * Key responsibilities of this frontend include:
 * - Opening and verifying the MuPix hardware device.
 * - Selecting the appropriate FEB slow control implementation based on compilation flags.
 * - Initializing LVDS bank configurations and bit patterns.
 * - Interfacing with the MIDAS Online Database (ODB) to fetch run-time configuration.
 * - Registering itself with MIDAS using appropriate frontend metadata.
 *
 * Preprocessor directives like `NO_A10_BOARD` are used to determine whether
 * to instantiate a dummy or real FEB control interface, enabling testing on systems
 * without hardware attached.
 *
 * @note Ensure all dependencies (mudaq library, MIDAS, system headers) are present and properly
 * configured.
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

// clang-format off
#include "midas.h"
// clang-format on
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
const char* frontend_name = "Quads Config";
const char* frontend_file_name = __FILE__;
BOOL equipment_common_overwrite = TRUE;

// configuration variables
FEBSlowcontrolInterface* feb_sc;
midas::odb m_settings;
uint8_t bitpattern_mupix[48] = {};
mudaq::DmaMudaqDevice* mup = nullptr;
std::vector<uint32_t> lvds_banks = {};

// runstart
reset reset_protocol;

int init_mudaq(mudaq::MudaqDevice& mu) {
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

#ifdef NO_A10_BOARD
    cm_msg(MINFO, "init_mudaq()", "We are running with NO_A10_BOARD");
    feb_sc = new DummyFEBSlowcontrolInterface(mu);
#else
    feb_sc = new FEBSlowcontrolInterface(mu);
#endif

    return SUCCESS;
}

int write_command_by_id(uint8_t command, uint32_t payload, bool has_payload) {
    uint32_t actual_payload = ((payload & 0xFF) << 24) + ((payload & 0xFF00) << 8) +
                              ((payload & 0xFF0000) >> 8) + ((payload & 0xFF000000) >> 24);
    if (has_payload) {
        mup->write_register(RESET_LINK_RUN_NUMBER_REGISTER_W, actual_payload);
        usleep(1000);  // we sleep here to wait until the command is processed
    }
    // upper 3 bits (31:29) are FEB address:
    // 0 -> 0, 1 -> 1, etc. 7 is all FEBs
    // for the moment we only have 4 possible FEBs connected
    mup->write_register(RESET_LINK_CTL_REGISTER_W, 0xE0000000 | command);
    usleep(500000);  // we sleep here to wait until the command is processed
    mup->write_register(RESET_LINK_CTL_REGISTER_W, 0x0);
    usleep(1000);  // we sleep here to wait until the command is processed

    return 0;
}

int write_command_by_name(const char* name, uint32_t payload = 0, uint16_t address = 0) {
    auto it = reset_protocol.commands.find(name);
    if (it != reset_protocol.commands.end()) {
        if (address == 0) {
            return write_command_by_id(it->second.command, payload, it->second.has_payload);
        } else {
            std::cout << "Addressed commands not yet implemented for A10" << std::endl;
            return -1;
        }
        return 0;
    }

    std::cout << "Unknown command " << name << std::endl;
    return -1;
}

int begin_of_run() {
// bring the FEBs into running
#ifndef NO_A10_BOARD
    midas::odb r("/Runinfo/Run number");
    uint32_t run_number = r;
    mup->write_register(RUN_NR_REGISTER_W, run_number);
    uint32_t start_setup = 0;
    start_setup = SET_RESET_BIT_RUN_START_ACK(start_setup);
    start_setup = SET_RESET_BIT_RUN_END_ACK(start_setup);
    mup->write_register_wait(RESET_REGISTER_W, start_setup, 1000);
    mup->write_register(RESET_REGISTER_W, 0x0);

    // send run start
    write_command_by_name("Abort Run");
    usleep(500000);  // we sleep here to wait until the command is processed
    write_command_by_name("Stop Reset");
    usleep(500000);  // we sleep here to wait until the command is processed
    write_command_by_name("Run Prepare", run_number);
    usleep(500000);  // we sleep here to wait until the command is processed

    uint32_t link_active_from_register;
    uint16_t timeout_cnt = 300;
    uint32_t link_active_from_odb = 0;
    for (int idx = 0; idx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); ++idx)
        if (m_settings["DAQ"]["Links"]["FEBsActive"][idx])
            link_active_from_odb = link_active_from_odb || (1 << idx);
    printf("Waiting for run prepare acknowledge from all FEBs\n");
    // TODO: test this part of checking the run number
    do {
        timeout_cnt--;
        link_active_from_register = mup->read_register_ro(RUN_NR_ACK_REGISTER_R);
        printf("%u  %u %u\n", timeout_cnt, link_active_from_odb, link_active_from_register);
        usleep(10000);
    } while ((link_active_from_register & link_active_from_odb) != link_active_from_odb &&
             (timeout_cnt > 0));

    if (timeout_cnt == 0) {
        cm_msg(MERROR, "quad_fe", "Run %d start denied - check if FEBs alive", run_number);
        return CM_TRANSITION_CANCELED;
    }
    write_command_by_name("Sync");
    usleep(500000);  // we sleep here to wait until the command is processed
    write_command_by_name("Start Run");
#endif

    return SUCCESS;
}

int end_of_run() {
    // first we stop the FEBs
    write_command_by_name("End Run");
    return SUCCESS;
}

int frontend_exit_user() { return SUCCESS; }

int quad_loop() { return SUCCESS; }

void sc_settings_changed(midas::odb o) {
    std::string name = o.get_name();

    cm_msg(MINFO, "sc_settings_changed", "Setting changed (%s)", name.c_str());

    if (name == "MupixConfig" && o) {
        ConfigureASICs(*feb_sc, m_settings, bitpattern_mupix);
        o = false;
    }

    // TODO: this can be done in the frontend loop all the time
    if (name == "InitFEBs" && o) {
        InitFEBs(*feb_sc, m_settings);
        o = false;
    }
}

int frontend_init() {
    // create ODB and setup watch functions
    settings.connect_and_fix_structure("/Equipment/Quads Config/Settings");
    settings.watch(sc_settings_changed);
    m_settings.connect("/Equipment/Quads Config/Settings");

    // end and start of run
    install_begin_of_run(begin_of_run);
    install_end_of_run(end_of_run);
    install_frontend_exit(frontend_exit_user);
    install_frontend_loop(quad_loop);

    // init dma and mudaq device
    mup = new mudaq::DmaMudaqDevice("/dev/mudaq0");
    int status = init_mudaq(*mup);
    if (status != SUCCESS)
        return FE_ERR_DRIVER;

    // Set our transition sequence. The default is 500.
    cm_set_transition_sequence(TR_START, 400);

    // Set our transition sequence. The default is 500. Setting it
    //  to 700 means we are called AFTER most other clients.
    cm_set_transition_sequence(TR_STOP, 600);

    // reset runcontrol
    // we write abort run
    mup->write_register(RESET_LINK_CTL_REGISTER_W, 0x0);
    usleep(500000);  // we sleep here to wait until the command is processed
    mup->write_register(RESET_LINK_CTL_REGISTER_W,
                        0xE0000000 | reset_protocol.commands.find("Abort Run")->second.command);
    usleep(500000);  // we sleep here to wait until the command is processed
    mup->write_register(RESET_LINK_CTL_REGISTER_W, 0x0);
    usleep(500000);  // we sleep here to wait until the command is processed
    mup->write_register(RESET_LINK_CTL_REGISTER_W,
                        0xE0000000 | reset_protocol.commands.find("Stop Reset")->second.command);
    usleep(500000);  // we sleep here to wait until the command is processed
    mup->write_register(RESET_LINK_CTL_REGISTER_W, 0x0);

    InitFEBs(*feb_sc, m_settings);

    return SUCCESS;
}

int read_sc_event(char* pevent, int off) {
    // TODO: move this to the quad_loop
    // fill lvds bank
    lvds_banks.clear();
    uint32_t nlinks = 36;
    uint32_t offset = 1;
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        lvds_banks.push_back(febIDx);
        lvds_banks.push_back(nlinks);
        if (!FEBActive) {
            for (uint32_t i = 0; i < nlinks; i++) {
                lvds_banks.push_back(0);
                lvds_banks.push_back(0);
                lvds_banks.push_back(0);
                lvds_banks.push_back(0);
            }
        } else {
            std::vector<uint32_t> status(offset + (nlinks * 4));
            feb_sc->FEB_read(febIDx, LVDS_STATUS_START_REGISTER_W, status, false);
            for (uint32_t i = 0; i < nlinks; i++) {
                lvds_banks.push_back(status[offset + i * 4]);
                lvds_banks.push_back(status[offset + i * 4 + 1]);
                lvds_banks.push_back(status[offset + i * 4 + 2]);
                lvds_banks.push_back(status[offset + i * 4 + 3]);
            }
        }
    }

    // create bank, pdata
    bk_init32a(pevent);
    DWORD* pdata = NULL;

    // create a bank with the lvds status
    bk_create(pevent, "PCLS", TID_DWORD, (void**)&pdata);
    for (auto data : lvds_banks) *pdata++ = data;
    bk_close(pevent, pdata);

    return bk_size(pevent);
}

EQUIPMENT equipment[] = {{
                             "Quads Config",                    /* equipment name */
                             {1, 0,                             /* event ID, trigger mask */
                              "SYSTEM",                         /* event buffer */
                              EQ_PERIODIC,                      /* equipment type */
                              0,                                /* event source */
                              "MIDAS",                          /* format */
                              TRUE,                             /* enabled */
                              RO_RUNNING | RO_STOPPED | RO_ODB, /* read always, except during
                                                                   transistions and update ODB */
                              1000,                             /* read every 1 sec */
                              0, /* stop run after this event limit */
                              0, /* number of sub events */
                              1, /* log history every event */
                              "", "", ""},
                             read_sc_event, /* readout routine */
                         },
                         {""}};
