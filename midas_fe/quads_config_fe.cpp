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
const char* frontend_name = "Quads";
const char* frontend_file_name = __FILE__;
BOOL equipment_common_overwrite = TRUE;

// configuration variables
FEBSlowcontrolInterface* feb_sc;
midas::odb m_settings;
uint8_t bitpattern_mupix[N_BYTES_MUPIX] = {};
uint8_t bitpattern_mutrig[N_BYTES_MUTRIG] = {};
mudaq::DmaMudaqDevice* mup = nullptr;
std::vector<uint32_t> lvds_banks = {};
std::vector<uint32_t> matrix_banks = {};
std::vector<uint32_t> adc_banks = {};
std::vector<uint32_t> counters_XXCR = {};
std::vector<uint32_t> counters_XXCH = {};
std::vector<uint32_t> counters_XXCF = {};
std::vector<uint32_t> counters_XXCE = {};
std::vector<uint32_t> counters_XXCP = {};
std::vector<uint32_t> values_XXSM = {};
std::vector<float> values_XXTM = {};

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

void init_banks() {
    midas::odb link_settings("/Equipment/Quads/Settings", true);

    // setup PCLS bank
    std::string namename = std::string("Names PCLS");
    std::vector<std::string> names;
    for (uint32_t i = 0; i < N_FEBS; i++) {
        names.push_back("FEB" + std::to_string(i));
        names.push_back("FEB" + std::to_string(i) + " N LVDS Links");
        for (uint32_t j = 0; j < MAX_LVDS_LINKS_PER_FEB; j++) {
            names.push_back("F" + std::to_string(i) + "L" + std::to_string(j) + " Status");
            names.push_back("F" + std::to_string(i) + "L" + std::to_string(j) +
                            " Disparity Errors");
            names.push_back("F" + std::to_string(i) + "L" + std::to_string(j) + " 8b/10b Errors");
            names.push_back("F" + std::to_string(i) + "L" + std::to_string(j) + " Num Hits LVDS");
        }
    }
    link_settings[namename] = names;

    namename = std::string("Names PVSC");
    names.clear();
    for (uint32_t i = 0; i < N_FEBS; i++) {
        for (uint32_t j = 0; j < N_CHIPS; j++) {
            std::string index = std::to_string(i * N_CHIPS + j);
            names.push_back(index + " ID upper");
            names.push_back(index + " ID lower");
            for (uint32_t k = 0; k < nadcvals; k++) {
                std::string s = index + " " + adcnames[k];
                names.push_back(s);
            }
        }
    }
    link_settings[namename] = names;
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

    std::vector<std::string> names{
        "MupixConfig",
        "InitFEBs",
        "ResetASICs",
        "ADC Continuous Readout",
        "Run Cycle FEB",
        "MupixTDACConfig",
        "Configure injection",
        "Trigger injection loop",
        "Full chip Injection",
        "init_tmb",
        "override_power_moduleid",
        "module_power_mask",
        "module_power",
        "MutrigConfig",
        "DataGenEnable",
        "DataGenDisable"
    };

    bool found = (std::find(names.begin(), names.end(), name) != names.end());

    if (o && found){

        cm_msg(MINFO, "sc_settings_changed", "Setting changed (%s)", name.c_str());

        if (name == "MupixConfig" && o) {
            ConfigureASICs(*feb_sc, m_settings, bitpattern_mupix);
        }

        // TODO: this can be done in the frontend loop all the time
        if (name == "InitFEBs" && o) {
            InitFEBs(*feb_sc, m_settings);
        }

        if (name == "ResetASICs" && o) {
            resetASICs(*feb_sc, m_settings);
        }

        if (name == "ADC Continuous Readout" && o) {
            adcContinuousReadout(*feb_sc, m_settings);
        }

        if (name == "Run Cycle FEB" && o) {
            // send run start
            write_command_by_name("Abort Run");
            usleep(500000);  // we sleep here to wait until the command is processed
            write_command_by_name("Stop Reset");
            usleep(500000);  // we sleep here to wait until the command is processed
            write_command_by_name("Run Prepare", run_number);
            usleep(500000);  // we sleep here to wait until the command is processed
            write_command_by_name("Sync");
            usleep(500000);  // we sleep here to wait until the command is processed
            write_command_by_name("Start Run");
        }

        if (name == "MupixTDACConfig" && o) {
            ConfigureTDACs(*feb_sc, m_settings);
        }

        if (name == "Configure injection" && o) {
            const std::vector<uint8_t> columns = m_settings["DAQ"]["Commands"]["Injection columns"];
            const std::vector<uint8_t> rows = m_settings["DAQ"]["Commands"]["Injection rows"];
            if (ConfigureInjectASICs(*feb_sc, columns, rows) != FE_SUCCESS)
                cm_msg(MERROR, "on_settings_changed", "injection configuration failed!");
        }

        if (name == "Trigger injection" && o) {
            const uint32_t injection_pulse_duration =
                m_settings["DAQ"]["Commands"]["Injection pulse duration"];
            if (InjectASICs(*feb_sc, injection_pulse_duration) != FE_SUCCESS)
                cm_msg(MERROR, "on_settings_changed", "injection trigger failed!");
        }

        if (name == "Trigger injection loop" && o) {
            const uint32_t injection_pulse_duration =
                m_settings["DAQ"]["Commands"]["Injection pulse duration"];
            const uint32_t num_repetitions = m_settings["DAQ"]["Commands"]["Number of pulses"];
            const uint32_t wait_between_pulses =
                m_settings["DAQ"]["Commands"]["Wait time between pulses (ms)"];
            if (InjectASICsInLoop(*feb_sc, injection_pulse_duration, num_repetitions,
                                wait_between_pulses) != FE_SUCCESS)
                cm_msg(MERROR, "on_settings_changed", "injection trigger loop failed!");
        }

        if (name == "Full chip Injection" && o) {
            const uint8_t min_columns = m_settings["DAQ"]["Commands"]["Injection min column"];
            const uint8_t max_columns = m_settings["DAQ"]["Commands"]["Injection max column"];
            const uint8_t min_rows = m_settings["DAQ"]["Commands"]["Injection min rows"];
            const uint8_t max_rows = m_settings["DAQ"]["Commands"]["Injection max rows"];
            const uint32_t injection_pulse_duration =
                m_settings["DAQ"]["Commands"]["Injection pulse duration"];
            const uint32_t num_repetitions = m_settings["DAQ"]["Commands"]["Number of pulses"];
            const uint32_t wait_between_pulses =
                m_settings["DAQ"]["Commands"]["Wait time between pulses (ms)"];
            if (FullChipInjection(*feb_sc, m_settings, min_columns, max_columns, min_rows, max_rows,
                                injection_pulse_duration, num_repetitions,
                                wait_between_pulses) != FE_SUCCESS)
                cm_msg(MERROR, "on_settings_changed", "injection configuration failed!");
        }

        if(name == "init_tmb" && o){
            TMBinit(*feb_sc, m_settings);
        }

        if( name == "override_power_moduleid" && o){
            UpdatePowerOverride(*feb_sc, m_settings);
        }

        if( (name == "module_power_mask" || name == "module_power") && o){
            UpdatePower(*feb_sc, m_settings);
        }

        if ( name == "MutrigConfig" && o) {
            ConfigureMuTRiGASICs(*feb_sc, m_settings, bitpattern_mutrig);
        }

        if (name == "DataGenEnable" && o) {
            midas::odb commands = m_settings["DAQ"]["Commands"];
            for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
                bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
                bool FEBsIsQuads = m_settings["DAQ"]["Links"]["FEBsQuads"][febIDx];
                if (FEBActive && FEBsIsQuads) {
                    uint32_t datagensetting =   0x1 << 31 | // data generator generates hits
                                                0x1 << 17 | // data generator before the sorter
                                                0x1 << 16 | // use hits from generator
                                                (bool) commands["DataGenSync"] << 5 | // all FEBs have same start
                                                (bool) commands["DataGenFullSteam"] << 4 | \
                                                ((uint8_t) commands["DataGenRate"] & 0xF);
                    //std::cout << std::hex << datagensetting << std::endl;
                    feb_sc->FEB_write(febIDx, MP_DATA_GEN_CONTROL_REGISTER_W, datagensetting);
                }
            }

            cm_msg(MINFO, "on_settings_changed()" , "enable data generator on the FPGA");
        }

        if (name == "DataGenDisable" && o) {
            for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
                bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
                bool FEBsIsQuads = m_settings["DAQ"]["Links"]["FEBsQuads"][febIDx];
                if (FEBActive && FEBsIsQuads)
                    feb_sc->FEB_write(febIDx, MP_DATA_GEN_CONTROL_REGISTER_W, 0x0);
            }

            cm_msg(MINFO, "on_settings_changed()" , "disable data generator on the FPGA");

        }

        o = false;
    }

}

int frontend_init() {
    // create ODB copy for settings
    settings.connect_and_fix_structure("/Equipment/Quads/Settings/");
    m_settings.connect("/Equipment/Quads/Settings");

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

    // init banks
    init_banks();

    // start ADC readout
    adcContinuousReadout(*feb_sc, m_settings);

    // create watch
    settings["DAQ/Commands"].watch(sc_settings_changed);

    return SUCCESS;
}

int read_sc_event(char* pevent, int off) {
    // TODO: move this to the quad_loop
    // fill lvds bank
    lvds_banks.clear();
    uint32_t offset = 1;
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        bool FEBsIsQuads = m_settings["DAQ"]["Links"]["FEBsQuads"][febIDx];
        lvds_banks.push_back(febIDx);
        lvds_banks.push_back(MAX_LVDS_LINKS_PER_FEB);
        if (FEBActive && FEBsIsQuads) {
            std::vector<uint32_t> status(offset + (MAX_LVDS_LINKS_PER_FEB * 4));
            feb_sc->FEB_read(febIDx, LVDS_STATUS_START_REGISTER_W, status, false);
            for (uint32_t i = 0; i < MAX_LVDS_LINKS_PER_FEB; i++) {
                lvds_banks.push_back(status[offset + i * 4]);
                lvds_banks.push_back(status[offset + i * 4 + 1]);
                lvds_banks.push_back(status[offset + i * 4 + 2]);
                lvds_banks.push_back(status[offset + i * 4 + 3]);
            }
        } else {
            for (uint32_t i = 0; i < MAX_LVDS_LINKS_PER_FEB; i++) {
                lvds_banks.push_back(0);
                lvds_banks.push_back(0);
                lvds_banks.push_back(0);
                lvds_banks.push_back(0);
            }
        }
    }

    // fill matrix bank
    matrix_banks.clear();
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        bool FEBsIsQuads = m_settings["DAQ"]["Links"]["FEBsQuads"][febIDx];
        matrix_banks.push_back(febIDx);
        matrix_banks.push_back(MAX_LVDS_LINKS_PER_FEB);
        if (FEBActive && FEBsIsQuads) {
            std::vector<uint32_t> data(1);
            feb_sc->FEB_read(febIDx, MP_IS_A_0_REGISTER_R, data);
            matrix_banks.push_back(data[0]);
            feb_sc->FEB_read(febIDx, MP_IS_A_1_REGISTER_R, data);
            matrix_banks.push_back(data[0]);
            feb_sc->FEB_read(febIDx, MP_IS_B_0_REGISTER_R, data);
            matrix_banks.push_back(data[0]);
            feb_sc->FEB_read(febIDx, MP_IS_B_1_REGISTER_R, data);
            matrix_banks.push_back(data[0]);
            feb_sc->FEB_read(febIDx, MP_IS_C_0_REGISTER_R, data);
            matrix_banks.push_back(data[0]);
            feb_sc->FEB_read(febIDx, MP_IS_C_1_REGISTER_R, data);
            matrix_banks.push_back(data[0]);
        } else {
            matrix_banks.push_back(0);
            matrix_banks.push_back(0);
            matrix_banks.push_back(0);
            matrix_banks.push_back(0);
            matrix_banks.push_back(0);
            matrix_banks.push_back(0);
        }
    };

    // fill ADC bank
    adc_banks.clear();
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        bool FEBsIsQuads = m_settings["DAQ"]["Links"]["FEBsQuads"][febIDx];
        if (FEBActive && FEBsIsQuads) {
            vector<uint32_t> adcdata(N_CHIPS * 4 * 3);
            feb_sc->FEB_read(febIDx, MP_READBACK_MEMS_START_REGISTER_R, adcdata);
            for (uint32_t c = 0; c < N_CHIPS * 3; c += 3) {
                adc_banks.push_back((c / 3 >> 8) & 0xFF);
                adc_banks.push_back((c / 3) & 0xFF);
                adc_banks.push_back((adcdata[0 + 4 * c] & 0xFF));
                adc_banks.push_back(((adcdata[0 + 4 * c] >> 8) & 0xFF));
                adc_banks.push_back(((adcdata[0 + 4 * c] >> 16) & 0xFF));
                adc_banks.push_back(((adcdata[0 + 4 * c] >> 24) & 0xFF));
                adc_banks.push_back((adcdata[1 + 4 * c] & 0xFF));
                adc_banks.push_back(((adcdata[1 + 4 * c] >> 8) & 0xFF));
                adc_banks.push_back(((adcdata[1 + 4 * c] >> 16) & 0xFF));
                adc_banks.push_back(((adcdata[1 + 4 * c] >> 24) & 0xFF));
                adc_banks.push_back((adcdata[2 + 4 * c] & 0xFF));
                adc_banks.push_back(((adcdata[2 + 4 * c] >> 8) & 0xFF));
                adc_banks.push_back(((adcdata[2 + 4 * c] >> 16) & 0xFF));
                adc_banks.push_back(((adcdata[2 + 4 * c] >> 24) & 0xFF));
                adc_banks.push_back((adcdata[3 + 4 * c] & 0xFF));
            }
        } else {
            for (uint32_t c = 0; c < N_CHIPS * 3; c += 3) {
                adc_banks.push_back((c / 3 >> 8) & 0xFF);
                adc_banks.push_back((c / 3) & 0xFF);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
                adc_banks.push_back(0);
            }
        }
    }

    // fill counter banks
    counters_XXCH.clear();
    counters_XXCF.clear();
    counters_XXCE.clear();
    counters_XXCR.clear();
    counters_XXCP.clear();
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        bool FEBsIsMutrig = m_settings["DAQ"]["Links"]["FEBsMutrig"][febIDx];
        if (FEBActive && FEBsIsMutrig) {

            // TODO: +2 should be fixed in firmware
            std::vector<uint32_t> counter(2+N_MUTRIGS_PER_FEB*64);
            feb_sc->FEB_read(febIDx, MUTRIG_CNT_ADDR_REGISTER_R, counter, true);

            // reset counter address
            feb_sc->FEB_write(febIDx, MUTRIG_CTRL_RESET_REGISTER_W, 0x10);
            feb_sc->FEB_write(febIDx, MUTRIG_CTRL_RESET_REGISTER_W, 0x0);

            for(int asic = 0; asic < N_MUTRIGS_PER_FEB; asic++) {
                counters_XXCH.push_back(counter[2+asic*64+3]);
                counters_XXCE.push_back(counter[2+asic*64+6]);
                counters_XXCF.push_back(counter[2+asic*64+7]);
                for ( size_t ch = 0; ch < NMUTRIGCHANNELS; ch++ )
                    counters_XXCR.push_back(counter[2+asic*64+8+ch]);

                uint16_t finetime_extended_cur = counter[2+asic*64+55] & 0xFF;
                uint16_t finetime_extended_last = counter[2+asic*64+54] & 0xFF;
                uint16_t time8ns_cur = counter[2+asic*64+55] >> 8;
                uint16_t time8ns_last = counter[2+asic*64+54] >> 8;

                if ((time8ns_cur * 160 + finetime_extended_cur) >= (time8ns_last * 160 + finetime_extended_last))
                    counters_XXCP.push_back((time8ns_cur * 160 + finetime_extended_cur) - (time8ns_last * 160 + finetime_extended_last));
                else counters_XXCP.push_back(0);
            }
        } else { // fill with zero to keep the size
            for(int asic = 0; asic < N_MUTRIGS_PER_FEB; asic++) {
                counters_XXCH.push_back(0);
                counters_XXCE.push_back(0);
                counters_XXCF.push_back(0);
                for ( size_t ch = 0; ch < NMUTRIGCHANNELS; ch++ )
                    counters_XXCR.push_back(0);
                counters_XXCP.push_back(0);
            }
        }
    }

    // fill mutrig temp banks
    values_XXTM.clear();
    std::vector<uint32_t> rval(N_TMB_MATRIX_TEMPERATURES, -1);
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        bool FEBsIsMutrig = m_settings["DAQ"]["Links"]["FEBsMutrig"][febIDx];
        int rpc_ret = -17;
        if (FEBsIsMutrig)
            rpc_ret = feb_sc->FEBsc_NiosRPC(febIDx, CMD_TILE_TEMPERATURES_READ, {});
        if (FEBActive && rpc_ret != -17) {
            feb_sc->FEB_read(febIDx, FEBSlowcontrolInterface::OFFSETS::FEBsc_RPC_DATAOFFSET, rval);

            // store and scale temperatures
            for (size_t idx=0; idx < N_TMB_MATRIX_TEMPERATURES; idx++) {
                float fval = TMB_TEMPERATURE_FACTOR * to_signed_16b(rval[idx+1]);
                if( ((rval[0]>>(idx)) & 0x01) == 0)
                    fval = 0;
                //printf("XXTM idx = %lu gid=%lu : %x --> %f\n",idx,gID,rval[idx+1],fval);
                values_XXTM.push_back(fval);
            }
        } else {
            for (size_t idx=0; idx < N_TMB_MATRIX_TEMPERATURES; idx++)
                values_XXTM.push_back(0xFFFFFFFF);
        }
    }

    // fill TMB status
    values_XXSM.clear();
    std::vector<uint32_t> rval_SM(N_TMB_STATUS_VALUES, -1);
    for (uint32_t febIDx = 0; febIDx < m_settings["DAQ"]["Links"]["FEBsActive"].size(); febIDx++) {
        bool FEBActive = m_settings["DAQ"]["Links"]["FEBsActive"][febIDx];
        bool FEBsIsMutrig = m_settings["DAQ"]["Links"]["FEBsMutrig"][febIDx];
        int rpc_ret = -17;
        if (FEBsIsMutrig)
            rpc_ret = feb_sc->FEBsc_NiosRPC(febIDx, CMD_TILE_TMB_STATUS, {});
        if (FEBActive && rpc_ret != -17) {
            feb_sc->FEB_read(febIDx, FEBSlowcontrolInterface::OFFSETS::FEBsc_RPC_DATAOFFSET, rval_SM);
            values_XXSM.push_back(rval_SM[0]);
            values_XXSM.push_back(rval_SM[1]);
            values_XXSM.push_back((int)roundf(TMB_TEMPERATURE_FACTOR * to_signed_16b(rval_SM[2]) * 100));
            values_XXSM.push_back((int)roundf(TMB_TEMPERATURE_FACTOR * to_signed_16b(rval_SM[3]) * 100));
        } else {
            for (size_t idx=0; idx < N_TMB_MATRIX_TEMPERATURES; idx++) {
                values_XXSM.push_back(0);
                values_XXSM.push_back(0);
                values_XXSM.push_back(0xFFFFFFFF);
                values_XXSM.push_back(0xFFFFFFFF);
            }
        }
    }

    MuTRiGResetLVDSAddr(*feb_sc, m_settings);

    // create bank, pdata
    bk_init32a(pevent);
    DWORD* pdata = NULL;

    // create a bank with the lvds status
    bk_create(pevent, "PCLS", TID_DWORD, (void**)&pdata);
    for (auto data : lvds_banks) *pdata++ = data;
    bk_close(pevent, pdata);

    // create a bank with the matrix status
    bk_create(pevent, "PCMS", TID_DWORD, (void**)&pdata);
    for (auto data : matrix_banks) *pdata++ = data;
    bk_close(pevent, pdata);

    // create a bank with the ADC status
    BYTE* pbyte = NULL;
    bk_create(pevent, "PVSC", TID_BYTE, (void**)&pbyte);
    for (auto data : adc_banks) *pbyte++ = data;
    bk_close(pevent, pbyte);

    // create a bank with the channel rate of the mutrig
    bk_create(pevent, "MTCR", TID_DWORD, (void**)&pdata);
    for (auto data : counters_XXCR) *pdata++ = data;
    bk_close(pevent, pdata);

    // create a bank with the hit rate of the mutrig
    bk_create(pevent, "MTCH", TID_DWORD, (void**)&pdata);
    for (auto data : counters_XXCH) *pdata++ = data;
    bk_close(pevent, pdata);

    // create a bank with the frame rate of the mutrig
    bk_create(pevent, "MTCF", TID_DWORD, (void**)&pdata);
    for (auto data : counters_XXCF) *pdata++ = data;
    bk_close(pevent, pdata);

    // create a bank with the CRC errors of the mutrig
    bk_create(pevent, "MTCE", TID_DWORD, (void**)&pdata);
    for (auto data : counters_XXCE) *pdata++ = data;
    bk_close(pevent, pdata);

    // create a bank with some time checks of the mutrig
    bk_create(pevent, "MTCP", TID_DWORD, (void**)&pdata);
    for (auto data : counters_XXCP) *pdata++ = data;
    bk_close(pevent, pdata);

    // create a bank with temperatures of the TMB
    float* pfloat = NULL;
    bk_create(pevent, "MTTM", TID_DWORD, (void**)&pfloat);
    for (auto data : values_XXTM) *pfloat++ = data;
    bk_close(pevent, pfloat);

    // create a bank with the TMB status
    bk_create(pevent, "MTSM", TID_DWORD, (void**)&pdata);
    for (auto data : values_XXSM) *pdata++ = data;
    bk_close(pevent, pdata);

    return bk_size(pevent);
}

EQUIPMENT equipment[] = {{
                             "Quads",                           /* equipment name */
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
