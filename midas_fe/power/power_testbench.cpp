/********************************************************************\

  Name:         power.cpp
  Created by:   Frederik Wauters

  Contents:     frontend to control to main Genesys power supplies
                lab supplies are also be added
                One daisy chain of Genesys supplies is one "equipment" as it has a single IP address
and "channels" to select A single HAMEG is one equipment to follow the same structure This Midas
frontend instantiates custum C++ drivers which also take care of the ODB The type of driver is
derived from the equipment name

  $Id$

\********************************************************************/

#include <stdio.h>
#include <iostream>
#include <thread>
#include <chrono>
#include <future>
#include "midas.h"
#include "mfe.h"
#include "mscb.h"
#include "history.h"
#include "odbxx.h"
#include "class/multi.h"
#include "class/generic.h"
#include "device/mscbdev.h"
#include "device/mscbhvr.h"
#include "GenesysDriver.h"
#include "HMP4040Driver.h"
#include "Keithley2611BDriver.h"
#include "Keithley2612ADriver.h"
#include "Keithley2450Driver.h"
#include "Keithley2400Driver.h"
#include "Keithley6487Driver.h"
#include "mstrlcpy.h"
using midas::odb;

/*-- Globals -------------------------------------------------------*/

/* The frontend name (client name) as seen by other MIDAS clients   */
const char* frontend_name = "Power Frontend TestBench";
/* The frontend file name, don't change it */
const char* frontend_file_name = __FILE__;

/* frontend_loop is called periodically if this variable is TRUE    */
BOOL frontend_call_loop = FALSE;

/* Overwrite equipment struct in ODB from values in code*/
BOOL equipment_common_overwrite = TRUE;

/* a frontend status page is displayed with this frequency in ms    */
INT display_period = 1000;

/* maximum event size produced by this frontend */
INT max_event_size = 10000;

/* maximum event size for fragmented events (EQ_FRAGMENTED) */
INT max_event_size_frag = 5 * 1024 * 1024;

/* buffer size to hold events */
INT event_buffer_size = 10 * 10000;

std::vector<PowerDriver*> drivers;

/*-- Function declarations -----------------------------------------*/

INT frontend_init();
INT frontend_exit();
INT begin_of_run(INT run_number, char* error);
INT end_of_run(INT run_number, char* error);
INT pause_run(INT run_number, char* error);
INT resume_run(INT run_number, char* error);
INT frontend_loop();
/*
INT read_genesys_power(char *pevent, INT off);*/
INT read_hameg_power(char* pevent, INT off, std::string eq_name, std::string lvh_num);

INT read_keithley_power0(char* pevent, INT off);
INT read_keithley_power1(char* pevent, INT off);

INT read_hameg_power0(char* pevent, INT off);
INT read_hameg_power1(char* pevent, INT off);
INT read_hameg_power2(char* pevent, INT off);
/*
INT read_hameg_power3(char *pevent, INT off);
INT read_hameg_power4(char *pevent, INT off);
INT read_hameg_power5(char *pevent, INT off);
INT read_hameg_power6(char *pevent, INT off);
INT read_hameg_power7(char *pevent, INT off);
INT read_hameg_power8(char *pevent, INT off);
*/

INT read_power(float* pdata, const std::string& eqn);

void setup_history();

/*-- Equipment list ------------------------------------------------*/

/* device driver list */
DEVICE_DRIVER mscb_driver[] = {{"Output", mscbdev, 0, nullptr, DF_OUTPUT | DF_MULTITHREAD},
                               {"Input", mscbdev, 0, nullptr, DF_INPUT | DF_MULTITHREAD},
                               {""}};

EQUIPMENT equipment[] = {

    // {"HVSUPPLY0",                       /* equipment name */
    //     {121, 0,                       /* event ID, trigger mask */
    //     "SYSTEM",                  /* event buffer */
    //     EQ_PERIODIC,                   /* equipment type */
    //     0,                         /* event source */
    //     "MIDAS",                   /* format */
    //     TRUE,                      /* enabled */
    //     RO_STOPPED | RO_RUNNING | RO_PAUSE,        /* all, but not write to odb */
    //     1000,                     /* read every 0.2 sec */
    //     0,                         /* stop run after this event limit */
    //     0,                         /* number of sub events */
    //     1,                         /* log history every event */
    //     "", "", ""} ,                  /* device driver list */
    //     read_keithley_power0,
    // },

    // {"HVSUPPLY1",                       /* equipment name */
    //     {122, 0,                       /* event ID, trigger mask */
    //     "SYSTEM",                  /* event buffer */
    //     EQ_PERIODIC,                   /* equipment type */
    //     0,                         /* event source */
    //     "MIDAS",                   /* format */
    //     TRUE,                      /* enabled */
    //     RO_STOPPED | RO_RUNNING | RO_PAUSE,        /* all, but not write to odb */
    //     1000,                     /* read every 0.2 sec */
    //     0,                         /* stop run after this event limit */
    //     0,                         /* number of sub events */
    //     1,                         /* log history every event */
    //     "", "", ""} ,                  /* device driver list */
    //     read_keithley_power0,
    // },

    // {"HVSUPPLY1",                       /* equipment name */
    //     {122, 0,                       /* event ID, trigger mask */
    //     "SYSTEM",                  /* event buffer */
    //     EQ_PERIODIC,                   /* equipment type */
    //     0,                         /* event source */
    //     "MIDAS",                   /* format */
    //     TRUE,                      /* enabled */
    //     RO_STOPPED | RO_RUNNING | RO_PAUSE,        /* all, but not write to odb */
    //     1000,                     /* read every 0.2 sec */
    //     0,                         /* stop run after this event limit */
    //     0,                         /* number of sub events */
    //     1,                         /* log history every event */
    //     "", "", ""} ,                  /* device driver list */
    //     read_keithley_power1,
    // },

    {
        "LVSUPPLY0",                         /* equipment name */
        {120, 0,                             /* event ID, trigger mask */
         "SYSTEM",                           /* event buffer */
         EQ_PERIODIC,                        /* equipment type */
         0,                                  /* event source */
         "MIDAS",                            /* format */
         TRUE,                               /* enabled */
         RO_STOPPED | RO_RUNNING | RO_PAUSE, /* all, but not write to odb */
         1000,                               /* read every 1 sec */
         0,                                  /* stop run after this event limit */
         0,                                  /* number of sub events */
         1,                                  /* log history every event */
         "", "", ""},                        /* device driver list */
        read_hameg_power0,
    },

    {
        "LVSUPPLY1",                         /* equipment name */
        {121, 0,                             /* event ID, trigger mask */
         "SYSTEM",                           /* event buffer */
         EQ_PERIODIC,                        /* equipment type */
         0,                                  /* event source */
         "MIDAS",                            /* format */
         TRUE,                               /* enabled */
         RO_STOPPED | RO_RUNNING | RO_PAUSE, /* all, but not write to odb */
         1000,                               /* read every 10 sec */
         0,                                  /* stop run after this event limit */
         0,                                  /* number of sub events */
         1,                                  /* log history every event */
         "", "", ""},                        /* device driver list */
        read_hameg_power1,
    },

    //    {"LVSUPPLY2",                       /* equipment name */
    //        {122, 0,                       /* event ID, trigger mask */
    //        "SYSTEM",                  /* event buffer */
    //        EQ_PERIODIC,                   /* equipment type */
    //        0,                         /* event source */
    //        "MIDAS",                   /* format */
    //        TRUE,                      /* enabled */
    //        RO_STOPPED | RO_RUNNING | RO_PAUSE,        /* all, but not write to odb */
    //        10000,                     /* read every 10 sec */
    //        0,                         /* stop run after this event limit */
    //        0,                         /* number of sub events */
    //        1,                         /* log history every event */
    //        "", "", ""} ,                  /* device driver list */
    //        read_hameg_power2,
    //    },

    //    {"HAMEG3",                       /* equipment name */
    //        {123, 0,                       /* event ID, trigger mask */
    //        "SYSTEM",                  /* event buffer */
    //        EQ_PERIODIC,                   /* equipment type */
    //        0,                         /* event source */
    //        "MIDAS",                   /* format */
    //        TRUE,                      /* enabled */
    //        RO_STOPPED | RO_RUNNING | RO_PAUSE,        /* all, but not write to odb */
    //        10000,                     /* read every 10 sec */
    //        0,                         /* stop run after this event limit */
    //        0,                         /* number of sub events */
    //        1,                         /* log history every event */
    //        "", "", ""} ,                  /* device driver list */
    //        read_hameg_power3,
    //    },

    //    {"HAMEG4",                       /* equipment name */
    //        {124, 0,                       /* event ID, trigger mask */
    //        "SYSTEM",                  /* event buffer */
    //        EQ_PERIODIC,                   /* equipment type */
    //        0,                         /* event source */
    //        "MIDAS",                   /* format */
    //        TRUE,                      /* enabled */
    //        RO_STOPPED | RO_RUNNING | RO_PAUSE,        /* all, but not write to odb */
    //        10000,                     /* read every 10 sec */
    //        0,                         /* stop run after this event limit */
    //        0,                         /* number of sub events */
    //        1,                         /* log history every event */
    //        "", "", ""} ,                  /* device driver list */
    //        read_hameg_power4,
    //    },

    //    {"HAMEG5",                       /* equipment name */
    //        {125, 0,                       /* event ID, trigger mask */
    //        "SYSTEM",                  /* event buffer */
    //        EQ_PERIODIC,                   /* equipment type */
    //        0,                         /* event source */
    //        "MIDAS",                   /* format */
    //        TRUE,                      /* enabled */
    //        RO_STOPPED | RO_RUNNING | RO_PAUSE,        /* all, but not write to odb */
    //        10000,                     /* read every 10 sec */
    //        0,                         /* stop run after this event limit */
    //        0,                         /* number of sub events */
    //        1,                         /* log history every event */
    //        "", "", ""} ,                  /* device driver list */
    //        read_hameg_power5,
    //    },

    //{"HAMEG6",                       /* equipment name */
    //    {126, 0,                       /* event ID, trigger mask */
    //    "SYSTEM",                  /* event buffer */
    //    EQ_PERIODIC,                   /* equipment type */
    //    0,                         /* event source */
    //    "MIDAS",                   /* format */
    //    TRUE,                      /* enabled */
    //    RO_STOPPED | RO_RUNNING | RO_PAUSE,        /* all, but not write to odb */
    //    10000,                     /* read every 10 sec */
    //    0,                         /* stop run after this event limit */
    //    0,                         /* number of sub events */
    //    1,                         /* log history every event */
    //    "", "", ""} ,                  /* device driver list */
    //    read_hameg_power6,
    //},

    //    {"HAMEG7",                       /* equipment name */
    //        {127, 0,                       /* event ID, trigger mask */
    //        "SYSTEM",                  /* event buffer */
    //        EQ_PERIODIC,                   /* equipment type */
    //        0,                         /* event source */
    //        "MIDAS",                   /* format */
    //        TRUE,                      /* enabled */
    //        RO_STOPPED | RO_RUNNING | RO_PAUSE,        /* all, but not write to odb */
    //        10000,                     /* read every 10 sec */
    //        0,                         /* stop run after this event limit */
    //        0,                         /* number of sub events */
    //        1,                         /* log history every event */
    //        "", "", ""} ,                  /* device driver list */
    //        read_hameg_power7,
    //    },

    {""}  // why is there actually this empty one here? FW

};

/*-- Function to define MSCB variables in a convenient way ---------*/

void mscb_define(std::string eq, std::string devname, DEVICE_DRIVER* driver, std::string submaster,
                 int address, unsigned char var_index, std::string name, double threshold,
                 double factor, double offset) {
    midas::odb::set_debug(false);
    midas::odb dev = {{"Device", std::string(255, '\0')},
                      {"Pwd", std::string(31, '\0')},
                      {"MSCB Address", 0},
                      {"MSCB Index", (UINT8)0}};
    dev.connect("/Equipment/" + eq + "/Settings/Devices/" + devname);

    if (!submaster.empty()) {
        if (dev["Device"] == std::string(""))
            dev["Device"] = submaster;
        else if (dev["Device"] != submaster) {
            cm_msg(MERROR, "mscb_define", "Device \"%s\" defined with different submasters",
                   devname.c_str());
            return;
        }
    } else if (dev["Device"] == std::string("")) {
        cm_msg(MERROR, "mscb_define", "Device \"%s\" defined without submaster name",
               devname.c_str());
        return;
    }

    // find device in device driver
    int dev_index;
    for (dev_index = 0; driver[dev_index].name[0]; dev_index++)
        if (equal_ustring(driver[dev_index].name, devname.c_str()))
            break;

    if (!driver[dev_index].name[0]) {
        cm_msg(MERROR, "mscb_define", "Device \"%s\" not present in device driver list",
               devname.c_str());
        return;
    }

    int chn_index = driver[dev_index].channels;

    dev.set_auto_enlarge_array(true);
    dev["MSCB Address"][chn_index] = address;
    dev["MSCB Index"][chn_index] = var_index;

    midas::odb settings;
    settings.connect("/Equipment/" + eq + "/Settings");
    settings.set_auto_enlarge_array(true);
    settings.set_preserve_string_size(true);

    if (driver[dev_index].flags & DF_INPUT) {
        if (chn_index == 0)
            settings["Update Threshold"] = (float)threshold;
        else
            settings["Update Threshold"][chn_index] = (float)threshold;
    }

    std::string fn(devname + " Factor");
    std::string on(devname + " Offset");
    if (chn_index == 0) {
        settings[fn] = (float)factor;
        settings[on] = (float)offset;
    } else {
        settings[fn][chn_index] = (float)factor;
        settings[on][chn_index] = (float)offset;
    }

    if (!name.empty()) {
        std::string sk = "Names " + devname;
        if (chn_index == 0) {
            settings[sk] = std::string(31, ' ');
            settings[sk] = name;
        } else
            settings[sk][chn_index] = &name;
    }

    // increment number of channels for this driver
    driver[dev_index].channels++;

    // setup custom page
    odb custom("/Custom");
    custom["Pixel Test"] = "transfer/main.html";
}

/*-- Error dispatcher causing communication alarm -------------------*/

void scfe_error(const char* error) {
    char str[256];

    mstrlcpy(str, error, sizeof(str));
    cm_msg(MERROR, "scfe_error", "%s", str);
    al_trigger_alarm("MSCB", str, "MSCB Alarm", "Communication Problem", AT_INTERNAL);
}

/*-- Frontend Init -------------------------------------------------*/

INT frontend_init() {
    // distribution control with SCS3000

    /* set error dispatcher for alarm functionality */
    mfe_set_error(scfe_error);

    /* set maximal retry count */
    mscb_set_max_retry(100);

    /*---- set correct ODB device addresses ----*/

    /*mscb_define("PowerDistribution", "Output",  mscb_driver, "mscb401.psi.ch", 65535, 26, "Enable
    channel 1", 0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Output",  mscb_driver,
    "mscb401.psi.ch", 65535, 27, "Enable channel 2", 0.1, 1.0, 0.0);
    mscb_define("PowerDistribution", "Output",  mscb_driver, "mscb401.psi.ch", 65535, 28, "Enable
    channel 3", 0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Output",  mscb_driver,
    "mscb401.psi.ch", 65535, 30, "Enable channel 4", 0.1, 1.0, 0.0);
    mscb_define("PowerDistribution", "Output",  mscb_driver, "mscb401.psi.ch", 65535, 34, "Enable
    channel 5", 0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Output",  mscb_driver,
    "mscb401.psi.ch", 65535, 35, "Enable channel 6", 0.1, 1.0, 0.0);
    mscb_define("PowerDistribution", "Output",  mscb_driver, "mscb401.psi.ch", 65535, 36, "Enable
    channel 7", 0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Output",  mscb_driver,
    "mscb401.psi.ch", 65535, 37, "Enable channel 8", 0.1, 1.0, 0.0);

    mscb_define("PowerDistribution", "Output",  mscb_driver, "mscb401.psi.ch", 65535, 25, "Reset
    ch1-4", 0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Output",  mscb_driver,
    "mscb401.psi.ch", 65535, 33, "Reset ch5-8", 0.1, 1.0, 0.0);

    mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch", 65535, 1, "OC ch1",
    0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch", 65535,
    2, "OC ch2", 0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Input",  mscb_driver,
    "mscb401.psi.ch", 65535, 3, "OC ch3", 0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Input",
    mscb_driver, "mscb401.psi.ch", 65535, 4, "OC ch4", 0.1, 1.0, 0.0);
    mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch", 65535, 9, "OC ch5",
    0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch", 65535,
    10, "OC ch6", 0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Input",  mscb_driver,
    "mscb401.psi.ch", 65535, 11, "OC ch7", 0.1, 1.0, 0.0); mscb_define("PowerDistribution", "Input",
    mscb_driver, "mscb401.psi.ch", 65535, 12, "OC ch8", 0.1, 1.0, 0.0);

    mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch", 65535, 17, "Current
    ch1", 0.01, 5.0, 0.0); mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch",
    65535, 18, "Current ch2", 0.01, 5.0, 0.0); mscb_define("PowerDistribution", "Input",
    mscb_driver, "mscb401.psi.ch", 65535, 19, "Current ch3", 0.01, 5.0, 0.0);
    mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch", 65535, 20, "Current
    ch4", 0.01, 5.0, 0.0); mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch",
    65535, 42, "Current ch5", 0.01, 5.0, 0.0); mscb_define("PowerDistribution", "Input",
    mscb_driver, "mscb401.psi.ch", 65535, 43, "Current ch6", 0.01, 5.0, 0.0);
    mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch", 65535, 44, "Current
    ch7", 0.01, 5.0, 0.0); mscb_define("PowerDistribution", "Input",  mscb_driver, "mscb401.psi.ch",
    65535, 45, "Current ch8", 0.01, 5.0, 0.0);*/

    // Get N equipments
    unsigned int nEq = sizeof(equipment) / sizeof(equipment[0]);
    if (nEq < 2) {
        cm_msg(MINFO, "power_fe", "No Equipment defined");
        return FE_ERR_DISABLED;
    }
    for (unsigned int i = 0; i < nEq - 1; i++)
        cm_msg(MINFO, "power_fe", "Init 'Equipment' nr %d name = %s, event ID = %d", i,
               equipment[i].name, equipment[i].info.event_id);

    //  allow equipment name starts to recognize supply type
    std::vector<std::string> genysis_names = {"Gen", "gen", "tdk", "TDK"};
    std::vector<std::string> hameg_names = {"HMP", "hmp", "ham", "HAM", "Lab", "lab", "LVS"};
    std::vector<std::string> keithley_names = {"Kei", "kei", "KEI", "HVS"};

    for (unsigned int eqID = 0; eqID < nEq - 1; eqID++) {
        std::cout << "start init Equipment id " << eqID << std::endl;

        std::string name(equipment[eqID].name);
        std::string shortname = name.substr(0, 3);

        midas::odb driver_settings;
        driver_settings.connect("/Equipment/" + name + "/Settings");
        std::string driver_name = driver_settings["DriverName"];

        // identify type and instatiate driver
        if (std::find(genysis_names.begin(), genysis_names.end(), shortname) !=
            genysis_names.end()) {
            drivers.emplace_back(new GenesysDriver(equipment[eqID].name, &equipment[eqID].info));
        } else if (std::find(hameg_names.begin(), hameg_names.end(), shortname) !=
                   hameg_names.end()) {
            if (driver_name == "HMP4040")
                drivers.emplace_back(
                    new HMP4040Driver(equipment[eqID].name, &equipment[eqID].info));
            else {
                std::cout << "Driver name " << driver_settings["DriverName"]
                          << " not recognized. Set to default = HMP4040\n";
                drivers.emplace_back(
                    new HMP4040Driver(equipment[eqID].name, &equipment[eqID].info));
            }
        } else if (std::find(keithley_names.begin(), keithley_names.end(), shortname) !=
                   keithley_names.end()) {
            if (driver_name == "Keithley2450")
                drivers.emplace_back(
                    new Keithley2450Driver(equipment[eqID].name, &equipment[eqID].info));
            else if (driver_name == "Keithley2400")
                drivers.emplace_back(
                    new Keithley2400Driver(equipment[eqID].name, &equipment[eqID].info));
            else if (driver_name == "Keithley2611B")
                drivers.emplace_back(
                    new Keithley2611BDriver(equipment[eqID].name, &equipment[eqID].info));
            else if (driver_name == "Keithley6487")
                drivers.emplace_back(
                    new Keithley6487Driver(equipment[eqID].name, &equipment[eqID].info));
            else {
                std::cout << "Driver name " << driver_settings["DriverName"]
                          << " not recognized. Set to default = Keithley2611B\n";
                drivers.emplace_back(
                    new Keithley2611BDriver(equipment[eqID].name, &equipment[eqID].info));
            }
        } else if (name == std::string("PowerDistribution")) {
            // do nothing, also no warning
            continue;
        } else {
            cm_msg(MINFO, "power_fe", "Init 'Equipment' nr %d name = %s not recognized", eqID,
                   equipment[eqID].name);
            continue;
        }

        // initialize
        std::cout << "initialize equipment " << equipment[eqID].name << std::endl;
        set_equipment_status(equipment[eqID].name, "Initializing...", "yellowLight");
        equipment[eqID].status = drivers.at(eqID)->ConnectODB();
    }

    for (unsigned int eqID = 0; eqID < nEq - 1; eqID++) {
        std::string name(equipment[eqID].name);

        if (equipment[eqID].status == FE_ERR_ODB) {
            set_equipment_status(equipment[eqID].name, "ODB Error", "redLight");
            cm_msg(MERROR, "initialize_equipment", "Equipment %s disabled because of %s",
                   equipment[eqID].name, "ODB ERROR");
            continue;
        }
        if (!drivers.at(eqID)->Enabled())  // cross check before doing something
        {
            set_equipment_status(equipment[eqID].name, "Disabled", "redLight");
            continue;
        }

        equipment[eqID].status = drivers.at(eqID)->Connect();
        if (equipment[eqID].status != FE_SUCCESS) {
            set_equipment_status(equipment[eqID].name, "Connection Error", "redLight");
            cm_msg(MERROR, "initialize_equipment", "Equipment %s disabled because of %s",
                   equipment[eqID].name, "CONNECTION ERROR");
            continue;
        }

        equipment[eqID].status = drivers.at(eqID)->Init();
        if (equipment[eqID].status != FE_SUCCESS) {
            set_equipment_status(equipment[eqID].name, "DRIVER Error", "redLight");
            cm_msg(MERROR, "initialize_equipment", "Equipment %s disabled because of %s",
                   equipment[eqID].name, "DRIVER ERROR");
            continue;
        } else {
            drivers.at(eqID)->SetInitialized();
            drivers.at(eqID)->Print();
            std::cout << " read setting " << equipment[eqID].info.read_on << std::endl;
            set_equipment_status(equipment[eqID].name, "Ok", "greenLight");
        }
        // And start the threaded reading
        drivers.at(eqID)->StartReading();
    }

    setup_history();

    ss_sleep(5000);

    // Equipment ready

    return CM_SUCCESS;
}

/*-- Frontend Exit -------------------------------------------------*/

INT frontend_exit() {
    for (auto& d : drivers) {
        delete d;
    }
    // gendriver->Print();
    ss_sleep(1000);
    return CM_SUCCESS;
}

INT read_power(float* pdata, const std::string& eq_name) {
    INT error = CM_SUCCESS;
    for (const auto& d : drivers) {
        if (!d->Initialized())
            continue;

        if (d->GetName() != eq_name)
            continue;
        error = d->GetReadStatus();
        if (error == FE_SUCCESS) {
            std::vector<float> voltage = d->GetVoltage();
            std::vector<float> current = d->GetCurrent();
            if (voltage.size() != current.size()) {
                continue;
                cm_msg(MERROR, "read_power", "Number of channel reads not consistent");
            }
            for (unsigned int iChannel = 0; iChannel < voltage.size(); iChannel++) {
                *pdata++ = voltage.at(iChannel);
                *pdata++ = current.at(iChannel);
            }
            // And start the next read
            d->StartReading();
            d->ResetNReadFaults();
        } else {
            cm_msg(MERROR, "power read", "Error in read: %d", error);
            d->AddReadFault();
            // And start the next read
            d->StartReading();
            return 0;
        }
        if (d->GetNReadFaults() >= 3) {
            d->UnsetInitialized();
            set_equipment_status(d->GetName().c_str(), "Read Error", "redLight");
        }
    }
    return error;
}

INT read_hameg_power(char* pevent, INT off [[maybe_unused]], std::string eq_name,
                     std::string lvh_num) {
    /* init bank structure */
    bk_init32a(pevent);
    float* pdata;
    std::string LVH_str = "LVH";
    LVH_str.append(lvh_num);

    bk_create(pevent, LVH_str.c_str(), TID_FLOAT, (void**)&pdata);
    read_power(pdata, eq_name);
    // printf("creating bank %s\n",LVH_str.c_str());
    bk_close(pevent, pdata);
    return bk_size(pevent);
}

INT read_hameg_power0(char* pevent, INT off) {
    return read_hameg_power(pevent, off, "LVSUPPLY0", "0");
}

INT read_hameg_power1(char* pevent, INT off) {
    return read_hameg_power(pevent, off, "LVSUPPLY1", "1");
}

INT read_hameg_power2(char* pevent, INT off) {
    return read_hameg_power(pevent, off, "HAMEG2", "2");
}

/*

INT read_hameg_power3(char *pevent, INT off)
{
  return read_hameg_power(pevent, off, "HAMEG3", "3");
}

INT read_hameg_power4(char *pevent, INT off)
{
  return read_hameg_power(pevent, off, "HAMEG4", "4");
}

INT read_hameg_power5(char *pevent, INT off)
{
  return read_hameg_power(pevent, off, "HAMEG5", "5");
}

INT read_hameg_power6(char *pevent, INT off)
{
  return read_hameg_power(pevent, off, "HAMEG6", "6");
}

INT read_hameg_power7(char *pevent, INT off)
{
  return read_hameg_power(pevent, off, "HAMEG7", "7");
}


INT read_hameg_power8(char *pevent, INT off)
{
  return read_hameg_power(pevent, off, "HAMEG8", "8");
}
*/

INT read_keithley_power0(char* pevent, INT off) {
    return read_hameg_power(pevent, off, "HVSUPPLY0", "0");
}

INT read_keithley_power1(char* pevent, INT off) {
    return read_hameg_power(pevent, off, "HVSUPPLY1", "1");
}

INT frontend_loop() { return SUCCESS; }

//*************** Not used ******************//

/*-- Dummy routines ------------------------------------------------*/

INT poll_event(INT source [[maybe_unused]], INT count [[maybe_unused]],
               BOOL test [[maybe_unused]]) {
    return 1;
}

INT interrupt_configure(INT cmd [[maybe_unused]], INT source [[maybe_unused]],
                        POINTER_T adr [[maybe_unused]]) {
    return 1;
}

/*-- Frontend Loop -------------------------------------------------*/

/*-- Begin of Run --------------------------------------------------*/
INT begin_of_run(INT run_number [[maybe_unused]], char* error [[maybe_unused]]) {
    return CM_SUCCESS;
}

/*-- End of Run ----------------------------------------------------*/
INT end_of_run(INT run_number [[maybe_unused]], char* error [[maybe_unused]]) { return CM_SUCCESS; }

/*-- Pause Run -----------------------------------------------------*/
INT pause_run(INT run_number [[maybe_unused]], char* error [[maybe_unused]]) { return CM_SUCCESS; }

/*-- Resume Run ----------------------------------------------------*/
INT resume_run(INT run_number [[maybe_unused]], char* error [[maybe_unused]]) { return CM_SUCCESS; }

/*-- Set up history panels-----------------------------------------------*/
void setup_history() {
    for (const auto& d : drivers) {
        if (!d->Initialized())
            continue;

        std::string name = d->GetName();
        size_t nchannels = d->GetVoltage().size();
        std::vector<std::string> cnames;
        std::vector<std::string> vnames;
        for (unsigned int i = 0; i < nchannels; i++) {
            cnames.push_back(std::string(name + std::string(":Current[") + std::to_string(i) +
                                         std::string("]")));
            vnames.push_back(std::string(name + std::string(":Voltage[") + std::to_string(i) +
                                         std::string("]")));
        }

        hs_define_panel("Power", std::string(name + std::string(" Currents")).c_str(), cnames);
        hs_define_panel("Power", std::string(name + std::string(" Voltages")).c_str(), vnames);
    }
}
