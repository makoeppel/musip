//

#include "Keithley6487Driver.h"
#include <thread>

Keithley6487Driver::Keithley6487Driver() {}

Keithley6487Driver::~Keithley6487Driver() {}

Keithley6487Driver::Keithley6487Driver(std::string n, EQUIPMENT_INFO* inf)
 : PowerDriver(n, inf) {
    std::cout << " Keithley6487 driver with " << instrumentID.size() << " channels instantiated." << std::endl;
}

INT Keithley6487Driver::ConnectODB() {
    InitODBArray();
    PowerDriver::ConnectODB();

    settings["port"](5025);
    settings["reply timout"](300);
    settings["min reply"](2); // minimum reply , 2 chars , not 3 (not fully figured out why)
    settings["ESR"](0);
    settings["Max Voltage"](200);

    // Placeholder?
    if (false) { return FE_ERR_ODB; }
    return FE_SUCCESS;
}

void Keithley6487Driver::InitODBArray() {
    // Only one channel available
    midas::odb settings_array = {{"Channel Names", std::array<std::string, 1>()}};
    settings_array.connect("/Equipment/" + name + "/Settings");
}

bool Keithley6487Driver::AskPermissionToTurnOn(int /*channel*/) {//extra check whether it is safe to tunr on supply;
    return true;
}

INT Keithley6487Driver::Init() {
    INT err;
    usb = settings["USB_PORT"];
    client->SetDefaultWaitTime(500);

    // Global reset if requested
    if (settings["Global Reset On FE Start"]) {
        if (client->Write("*RST\n")) {
            cm_msg(MINFO, "Init KEITHLEY 6487 supply ... ", "init global reset of %s", usb.c_str());
        } else {
            cm_msg(MERROR, "Init KEITHLEY 6487 supply ... ", "could not global reset %s", usb.c_str());
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
    }

    // Cant actually beep :(
    if (!client->Write(GenerateCommand(COMMAND_TYPE::Beep, 0))) {
        cm_msg(MERROR, "Init KEITHLEY 6487 supply ... ", "could not beep %s", usb.c_str());
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    // Channel selection not relevant for HAMEG supply to read ID
    // "-1" is a trick not to select a channel before the query
    idCode = ReadIDCode(-1, err);
    std::cout << "ID code: " << idCode << std::endl;

    std::vector<std::string> init({"*RST\n"});
    init.push_back("FUNC 'CURR'\n");
    init.push_back("SYST:ZCH ON\n");
    init.push_back("CURR:RANG 2e-9\n");
    init.push_back("INIT\n");
    init.push_back("SYST:ZCOR:STAT OFF\n");
    init.push_back("SYST:ZCOR:ACQ\n");
    init.push_back("SYST:ZCOR ON\n");
    init.push_back("CURR:RANG:AUTO ON\n");
    init.push_back("SYST:ZCH OFF\n");
    init.push_back("SOUR:VOLT:RANG 50\n");
    init.push_back("SOUR:VOLT 0\n");
    init.push_back("SOUR:VOLT:ILIM 2.5e-3\n");
    // SOUR:VOLT:STAT ON

    for (std::string com : init) {
        if (client->Write(com)) {
            cm_msg(MINFO, "Keithley6487Driver::Init()", "com = %s", com.c_str());
        } else {
            cm_msg(MERROR, "Keithley6487Driver::Init()", "com = %s", com.c_str());
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
    }

    for (auto& s: ReadErrorQueue(-1, err)) {
        if (s.find("No error") == std::string::npos) {
            cm_msg(MERROR, "Init KEITHLEY 6487 supply ... ", " Error from KEITHLEY 6487 supply, namely: %s", s.c_str());
        }
    }

    // KEITHLEY 6487 has ONLY 1 channel
    instrumentID = {1};
    int nChannels = instrumentID.size();
    settings["NChannels"] = nChannels;
    voltage.resize(nChannels);
    demandvoltage.resize(nChannels);
    current.resize(nChannels);
    currentlimit.resize(nChannels);
    state.resize(nChannels);
    OVPlevel.resize(nChannels);    

    // client->FlushQueu();
    // Read channels
    for (int i(0); i < nChannels; i++) {
        state[i] = ReadState(i, err);
        if (err != FE_SUCCESS) { return err; }
    }

    // Push to odb
    variables["State"] = state;
    variables["Set State"] = state;
    
    for (int i(0); i < nChannels; i++) {
        voltage[i] = ReadVoltage(i, err);
        demandvoltage[i] = ReadSetVoltage(i, err);

        current[i] = ReadCurrent(i, err);
        try {
            if (variables["Current Limit"]) {
                currentlimit[i] = variables["Current Limit"];
            }
        } catch (...) {
            std::cout << "Current limit not in the ODB yet" << std::endl;
            currentlimit[i] = ReadCurrentLimit(i, err);
        }

        OVPlevel[i] = ReadOVPLevel(i, err);
        // OVPlevel[i] = 10;

        if (err != FE_SUCCESS) { return err; }
    }

    settings["Identification Code"] = idCode;
    settings["ESR"] = ReadESR(-1, err);
    settings["Read ESR"] = false;

    variables["Voltage"] = voltage;
    variables["Demand Voltage"] = demandvoltage;
    variables["Current"] = current;
    variables["Current Limit"] = currentlimit;
    variables["OVP Level"] = OVPlevel;
    variables["Demand OVP Level"] = OVPlevel;

    // Watch functions
    variables["Set State"].watch([&](midas::odb &arg [[maybe_unused]]) { this->SetStateChanged(); });
    variables["Current Limit"].watch([&](midas::odb &arg [[maybe_unused]]) { this->CurrentLimitChanged(); });
    variables["Demand Voltage"].watch([&](midas::odb &arg [[maybe_unused]]) { this->DemandVoltageChanged(); });
    variables["Demand OVP Level"].watch([&](midas::odb &arg [[maybe_unused]]) { this->DemandOVPLevelChanged(); });
    settings["Read ESR"].watch([&](midas::odb &arg [[maybe_unused]]) { this->ReadESRChanged(); });

    return FE_SUCCESS;
}


INT Keithley6487Driver::ReadAll() {
    INT err;
    INT err_accumulated;
    int nChannels = instrumentID.size();

    // Update local book keeping
    for (int i(0); i < nChannels; i++) {
        if (readonlythisindex >= 0 && i != readonlythisindex) { continue; }

        bool bvalue = ReadState(i, err);
        err_accumulated = err;
        err = 0;
        // Only update odb if there is a change
        if (state[i] != bvalue) {
            state[i] = bvalue;
            variables["State"][i] = bvalue;
        }

        float fvalue = ReadVoltage(i, err);
        err_accumulated = err_accumulated | err;
        if (fabs(voltage[i] - fvalue) > fabs(relevantchange * voltage[i])) {
            voltage[i] = fvalue;
            variables["Voltage"][i] = fvalue;
        }

        fvalue = ReadCurrent(i, err);
        err_accumulated = err_accumulated | err;
        if (fabs(current[i] - fvalue) > fabs(relevantchange * current[i])) {
            current[i] = fvalue;
            variables["Current"][i] = fvalue;
        }

        fvalue = ReadOVPLevel(i, err);
        err_accumulated = err_accumulated | err;
        if (fabs(OVPlevel[i] - fvalue) > fabs(relevantchange * OVPlevel[i])) {
            OVPlevel[i] = fvalue;
            variables["OVP Level"][i] = fvalue;
        }

        if (err_accumulated != FE_SUCCESS) {
            // Remove the success bit if there is any
            return err_accumulated & 0xFFFE;
        }
    }

    //for (auto& s: ReadErrorQueue(-1, err)) {
    //    cm_msg(MINFO, "Read KEITHLEY 6487 supply ... ", "Error queue: %s", s.c_str());
    //    if (s.find("No error") == std::string::npos) {
    //        cm_msg(MERROR, "power_fe", " Error from KEITHLEY 6487 supply : %s", s.c_str());
    //    }
    //} // Something is off here

    ClearBuffer();
    return FE_SUCCESS;
}

void Keithley6487Driver::ReadESRChanged() {
    INT err;
    if (settings["Read ESR"]) {
        settings["ESR"] = ReadESR(-1, err);
        settings["Read ESR"] = false;
    }
}

std::string Keithley6487Driver::GenerateCommand(COMMAND_TYPE cmdt, float val) {
    if (cmdt == COMMAND_TYPE::CLearStatus) {
        return "*CLS\n";
    } else if (cmdt == COMMAND_TYPE::OPC) {
        return "*OPC?\n";
    } else if (cmdt == COMMAND_TYPE::ReadESR) {
        return "*ESR?\n";
    } else if (cmdt == COMMAND_TYPE::Reset) {
        return "*RST\n";
    } else if (cmdt == COMMAND_TYPE::SelectChannel){
        return ""; // Only one channel
    } else if (cmdt == COMMAND_TYPE::SetCurrent) {
        return ""; // Does not set the current
    } else if (cmdt == COMMAND_TYPE::ReadCurrent) {
        // return ":READ?\n";
        return "MEAS:CURR?\n";
    } else if (cmdt == COMMAND_TYPE::ReadState) {
        return "SOUR:VOLT:STAT?\n";
    } else if (cmdt == COMMAND_TYPE::SetCurrentLimit) {
        return "SOUR:VOLT:ILIM " + std::to_string(val) + "\n";
    } else if (cmdt == COMMAND_TYPE::ReadVoltage) {
        return "SOUR:VOLT?\n"; // Copy of the ReadSetVoltage!!!
    } else if (cmdt == COMMAND_TYPE::ReadSetVoltage) {
        return "SOUR:VOLT?\n";
    } else if (cmdt == COMMAND_TYPE::ReadCurrentLimit) {
        return "SOUR:VOLT:ILIM?\n";
    } else if (cmdt == COMMAND_TYPE::SetVoltage) {
        return "SOUR:VOLT " + std::to_string(val) + "\n";
    } else if (cmdt == COMMAND_TYPE::Beep) {
        cm_msg(MINFO, "KEITHLEY 6487 supply ... ", "BEEEEEEP BEEEEP mfs");
        return "\n"; // No other possibility to perform a beep :)
    } else if (cmdt == COMMAND_TYPE::SetState) {
        int ch = (int)val;
        if (ch == 1) {
            return "SOUR:VOLT:STAT ON\n";
        } else if (ch == 0) {
            return "SOUR:VOLT:STAT OFF\n";
        } else {
            cm_msg(MERROR, "KEITHLEY 6487 supply ... ", "SetState can be only 1 or 0, and not %d", ch);
            return "\n";
        }
    } else if (cmdt == COMMAND_TYPE::ReadErrorQueue) {
        return "SYST:ERR:NEXT?\n";
    } else if (cmdt == COMMAND_TYPE::ReadOVPLevel) {
        return "SOUR:VOLT:RANG?\n";
    } else if (cmdt == COMMAND_TYPE::SetOVPLevel) {
        return "SOUR:VOLT:RANG " + std::to_string(val) + "\n";
    } else if (cmdt == COMMAND_TYPE::ClearBuffer) {
        return "TRAC:CLEAR\n";
    }

    return "";
}

std::string Keithley6487Driver::GenerateCommand(COMMAND_TYPE cmdt, int, float val) {
    if (cmdt == COMMAND_TYPE::SelectChannelAndSetVoltage) {
        return "SOUR:VOLT " + std::to_string(val) + "\n";
    } else {
        cm_msg(MERROR, "KEITHLEY 6487 supply ... ", "GenerateCommand function is usable only with SelectChannelAndSetVoltage!");
        return "";
    }
}

std::string Keithley6487Driver::ReadIDCode(int index, INT& error) {
    std::string id_code(PowerDriver::ReadIDCode(index, error));

    return id_code.substr(0, id_code.find("C10") - 1);
}