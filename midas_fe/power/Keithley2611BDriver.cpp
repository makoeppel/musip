#include "Keithley2611BDriver.h"

#include <thread>

Keithley2611BDriver::Keithley2611BDriver() {}

Keithley2611BDriver::~Keithley2611BDriver() {}

Keithley2611BDriver::Keithley2611BDriver(std::string n, EQUIPMENT_INFO* inf) : PowerDriver(n, inf) {
    std::cout << " Keithley2611B driver with " << instrumentID.size() << " channels instantiated "
              << std::endl;
}

INT Keithley2611BDriver::ConnectODB() {
    InitODBArray();
    PowerDriver::ConnectODB();
    settings["port"](5025);
    settings["reply timout"](300);
    settings["min reply"](2);  // minimum reply , 2 chars , not 3 (not fully figured out why)
    settings["ESR"](0);
    settings["Max Voltage"](2);
    if (false)
        return FE_ERR_ODB;
    return FE_SUCCESS;
}

void Keithley2611BDriver::InitODBArray() {
    midas::odb settings_array = {{"Channel Names", std::array<std::string, 4>()}};
    settings_array.connect("/Equipment/" + name + "/Settings");
}

INT Keithley2611BDriver::Init() {
    ip = settings["IP"];
    std::cout << "Call init on " << ip << std::endl;
    std::string cmd = "";
    std::string reply = "";
    INT err;

    // longer wait time for the HMP supplies //TODO What abut Keithly?
    client->SetDefaultWaitTime(50);

    // global reset if requested
    if (settings["Global Reset On FE Start"] == true) {
        cmd = "*RST\n";
        if (!client->Write(cmd))
            cm_msg(MERROR, "Init KEITH supply ... ", "could not global reset %s", ip.c_str());
        else
            cm_msg(MINFO, "power_fe", "Init global reset of %s", ip.c_str());
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    cmd = GenerateCommand(COMMAND_TYPE::Beep, 0);
    if (!client->Write(cmd))
        cm_msg(MERROR, "Init KEITH supply ... ", "could not beep %s", ip.c_str());
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    std::vector<std::string> error_queue = ReadErrorQueue(-1, err);
    for (auto& s : error_queue) {
        if (s.find("Queue Is Empty") == std::string::npos) {
            cm_msg(MERROR, "power_fe", " Error from KEITH supply : %s", s.c_str());
        }
    }

    // KEITH has 1 channel
    instrumentID = {1};
    int nChannels = instrumentID.size();
    settings["NChannels"] = nChannels;

    voltage.resize(nChannels);
    demandvoltage.resize(nChannels);
    current.resize(nChannels);
    currentlimit.resize(nChannels);
    state.resize(nChannels);
    OVPlevel.resize(nChannels);
    // instrumentID = {1,2,3,4}; // The HMP4040 supply has 4 channel numbered 1,2,3, and 4.

    idCode = ReadIDCode(-1, err);  // channel selection not relevant for HAMEG supply to read ID
                                   //  "-1" is a trick not to select a channel before the query

    std::cout << "ID code: " << idCode << std::endl;

    // client->FlushQueu();

    // read channels
    for (int i = 0; i < nChannels; i++) {
        state[i] = ReadState(i, err);
        voltage[i] = ReadVoltage(i, err);
        demandvoltage[i] = ReadSetVoltage(i, err);  // T

        current[i] = ReadCurrent(i, err);
        currentlimit[i] = ReadCurrentLimit(i, err);

        OVPlevel[i] = ReadOVPLevel(i, err);

        if (err != FE_SUCCESS)
            return err;
    }

    settings["Identification Code"] = idCode;
    settings["ESR"] = ReadESR(-1, err);
    settings["Read ESR"] = false;

    variables["State"] = state;  // push to odb
    variables["Set State"] =
        state;  // the init function can not change the on/off state of the supply

    variables["Voltage"] = voltage;
    variables["Demand Voltage"] = demandvoltage;

    variables["Current"] = current;
    variables["Current Limit"] = currentlimit;

    variables["OVP Level"] = OVPlevel;
    variables["Demand OVP Level"] = OVPlevel;

    // watch functions
    variables["Current Limit"].watch(
        [&](midas::odb& arg [[maybe_unused]]) { this->CurrentLimitChanged(); });
    variables["Set State"].watch(
        [&](midas::odb& arg [[maybe_unused]]) { this->SetStateChanged(); });
    variables["Demand Voltage"].watch(
        [&](midas::odb& arg [[maybe_unused]]) { this->DemandVoltageChanged(); });
    variables["Demand OVP Level"].watch(
        [&](midas::odb& arg [[maybe_unused]]) { this->DemandOVPLevelChanged(); });

    settings["Read ESR"].watch([&](midas::odb& arg [[maybe_unused]]) { this->ReadESRChanged(); });

    return FE_SUCCESS;
}

INT Keithley2611BDriver::ReadAll() {
    INT err;
    INT err_accumulated;
    int nChannels = instrumentID.size();
    // update local book keeping
    for (int i = 0; i < nChannels; i++) {
        if (readonlythisindex >= 0 && i != readonlythisindex)
            continue;

        bool bvalue = ReadState(i, err);
        err_accumulated = err;
        if (state[i] != bvalue)  // only update odb if there is a change
        {
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

        if (err_accumulated != FE_SUCCESS)
            return err_accumulated & 0xFFFE;  // remove the success bit if there is any
    }

    std::vector<std::string> error_queue = ReadErrorQueue(-1, err);
    for (auto& s : error_queue) {
        if (s.find("Queue Is Empty") == std::string::npos) {
            cm_msg(MERROR, "power_fe", " Error from KEITH supply : %s", s.c_str());
        }
    }

    return FE_SUCCESS;
}

void Keithley2611BDriver::ReadESRChanged() {
    INT err;
    bool value = settings["Read ESR"];
    if (value) {
        settings["ESR"] = ReadESR(-1, err);
        settings["Read ESR"] = false;
    }
}

bool Keithley2611BDriver::AskPermissionToTurnOn(
    int)  // extra check whether it is safe to tunr on supply;
{
    return true;
}

std::string Keithley2611BDriver::GenerateCommand(COMMAND_TYPE cmdt, float val) {
    if (cmdt == COMMAND_TYPE::SetCurrent) {
        return "smua.source.limiti=" + std::to_string(val) + "\n";
    } else if (cmdt == COMMAND_TYPE::ReadCurrent) {
        return "print(smua.measure.i())\n";
    } else if (cmdt == COMMAND_TYPE::ReadState) {
        return "print(smua.source.output)\n";
    } else if (cmdt == COMMAND_TYPE::ReadVoltage) {
        return "print(smua.measure.v())\n";
    } else if (cmdt == COMMAND_TYPE::ReadSetVoltage) {
        return "print(smua.source.levelv)\n";
    } else if (cmdt == COMMAND_TYPE::ReadCurrentLimit) {
        return "print(smua.source.limiti)\n";
    } else if (cmdt == COMMAND_TYPE::SetVoltage) {
        return "smua.source.levelv=" + std::to_string(val) + "\n";
    } else if (cmdt == COMMAND_TYPE::Beep) {
        return "beeper.beep(0.5, 4400)\n";  // TODO try out
    } else if (cmdt == COMMAND_TYPE::CLearStatus) {
        return "*CLS\n";
    } else if (cmdt == COMMAND_TYPE::OPC) {
        return "*OPC?\n";
    } else if (cmdt == COMMAND_TYPE::ReadESR) {
        return "*ESR?\n";
    } else if (cmdt == COMMAND_TYPE::Reset) {
        return "*RST\n";
    } else if (cmdt == COMMAND_TYPE::SetState) {
        int ch = (int)val;
        return "smua.source.output=" + std::to_string(ch) + "\n";
    } else if (cmdt == COMMAND_TYPE::ReadErrorQueue) {
        return "print(errorqueue.next())\n";
    } else if (cmdt == COMMAND_TYPE::ReadOVPLevel) {
        return "print(smua.source.limitv)\n";
    } else if (cmdt == COMMAND_TYPE::SetOVPLevel) {
        return "smua.source.limitv=" + std::to_string(val) + "\n";
    }
    return "";
}

std::string Keithley2611BDriver::GenerateCommand(COMMAND_TYPE cmdt, int, float val) {
    if (cmdt == COMMAND_TYPE::SelectChannelAndSetVoltage) {
        return "smua.source.levelv=" + std::to_string(val) + "\n";
    } else {
        std::cout << "This function is usable only with SelectChannelAndSetVoltage!\n";
        return "";
    }
}