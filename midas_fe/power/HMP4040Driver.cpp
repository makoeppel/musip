#include "HMP4040Driver.h"

#include <thread>

HMP4040Driver::HMP4040Driver() {}

HMP4040Driver::~HMP4040Driver() {}

HMP4040Driver::HMP4040Driver(std::string n, EQUIPMENT_INFO* inf) : PowerDriver(n, inf) {
    std::cout << " HMP4040 HAMEG driver with " << instrumentID.size() << " channels instantiated "
              << std::endl;
}

INT HMP4040Driver::ConnectODB() {
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

void HMP4040Driver::InitODBArray() {
    midas::odb settings_array = {{"Channel Names", std::array<std::string, 4>()}};
    settings_array.connect("/Equipment/" + name + "/Settings");
}

INT HMP4040Driver::Init() {
    ip = settings["IP"];
    std::cout << "Call init on " << ip << std::endl;
    std::string cmd = "";
    std::string reply = "";
    INT err;

    // longer wait time for the HMP supplies
    client->SetDefaultWaitTime(50);

    // global reset if requested
    if (settings["Global Reset On FE Start"] == true) {
        cmd = GenerateCommand(COMMAND_TYPE::Reset, 0);
        if (!client->Write(cmd))
            cm_msg(MERROR, "Init HAMEG supply ... ", "could not global reset %s", ip.c_str());
        else
            cm_msg(MINFO, "power_fe", "Init global reset of %s", ip.c_str());
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    // beep
    cmd = GenerateCommand(COMMAND_TYPE::Beep, 0);
    if (!client->Write(cmd))
        cm_msg(MERROR, "Init HAMEG supply ... ", "could not beep %s", ip.c_str());
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    // clear error an status registers
    // cmd = GenerateCommend(COMMAND_TYPE:ClearStatus, 0);
    // if( !client->Write(cmd) ) cm_msg(MERROR, "Init HAMEG supply ... ", "could perform global
    // clear %s", ip.c_str()); else cm_msg(MINFO,"power_fe","Global CLS of %s",ip.c_str());
    // std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    std::vector<std::string> error_queue = ReadErrorQueue(-1, err);
    for (auto& s : error_queue) {
        if (s.substr(0, 1) != "0") {
            cm_msg(MERROR, "power_fe", " Error from hameg supply : %s", s.c_str());
        }
    }

    // HAMEG has fixed 4 channels
    instrumentID = {1, 2, 3, 4};
    int nChannels = instrumentID.size();
    settings["NChannels"] = nChannels;

    voltage.resize(nChannels);
    demandvoltage.resize(nChannels);
    current.resize(nChannels);
    currentlimit.resize(nChannels);
    state.resize(nChannels);
    OVPlevel.resize(nChannels);

    idCode = ReadIDCode(-1, err);  // channel selection not relevant for HAMEG supply to read ID
                                   //  "-1" is a trick not to select a channel before the query

    std::cout << "ID code: " << idCode << std::endl;

    // client->FlushQueu();

    // read channels
    for (int i = 0; i < nChannels; i++) {
        state[i] = ReadState(i, err);

        voltage[i] = ReadVoltage(i, err);

        demandvoltage[i] = ReadSetVoltage(i, err);

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

bool HMP4040Driver::AskPermissionToTurnOn(int)  // extra check whether it is safe to tunr on supply;
{
    return true;
}

INT HMP4040Driver::ReadAll() {
    INT err;
    INT err_accumulated;
    int nChannels = instrumentID.size();
    // update local book keeping
    for (int i = 0; i < nChannels; i++) {
        if (readonlythisindex >= 0 && i != readonlythisindex) {
            continue;
        }

        // cm_msg(MINFO, "Power Fe ... ", "Call Read All with index %d ... ",i);

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
        if (s.substr(0, 1) != "0") {
            cm_msg(MERROR, "power_fe", " Error from hameg supply : %s", s.c_str());
        }
    }

    return FE_SUCCESS;
}

void HMP4040Driver::ReadESRChanged() {
    INT err;
    bool value = settings["Read ESR"];
    if (value) {
        settings["ESR"] = ReadESR(-1, err);
        settings["Read ESR"] = false;
    }
}

std::string HMP4040Driver::GenerateCommand(COMMAND_TYPE cmdt, float val) {
    if (cmdt == COMMAND_TYPE::SetCurrent) {
        return "CURR " + std::to_string(val) + "\n";
    } else if (cmdt == COMMAND_TYPE::Reset) {
        return "*RST\n";
    } else if (cmdt == COMMAND_TYPE::Beep) {
        return "SYST:BEEP\n";
    } else if (cmdt == COMMAND_TYPE::CLearStatus) {
        return "*CLS\n";
    } else if (cmdt == COMMAND_TYPE::SelectChannel) {
        int ch = (int)val;
        return "INST:NSEL " + std::to_string(ch) + "\n";
    } else if (cmdt == COMMAND_TYPE::OPC) {
        return "*OPC?\n";
    } else if (cmdt == COMMAND_TYPE::ReadErrorQueue) {
        return "SYST:ERR?\n";
    } else if (cmdt == COMMAND_TYPE::ReadESR) {
        return "*ESR?\n";
    } else if (cmdt == COMMAND_TYPE::ReadQCGE) {
        return "STAT:QUES?\n";
    } else if (cmdt == COMMAND_TYPE::ReadState) {
        return "OUTP:STAT?\n";
    } else if (cmdt == COMMAND_TYPE::ReadVoltage) {
        return "MEAS:VOLT?\n";  // What is the difference between ReadVoltage and ReadSetVoltage
    } else if (cmdt == COMMAND_TYPE::ReadSetVoltage) {
        return "VOLT?\n";  // What is the difference between ReadVoltage and ReadSetVoltage
    } else if (cmdt == COMMAND_TYPE::ReadCurrent) {
        return "MEAS:CURR?\n";
    } else if (cmdt == COMMAND_TYPE::ReadCurrentLimit) {
        return "CURR?\n";
    } else if (cmdt == COMMAND_TYPE::ReadOVPLevel) {
        return "VOLT:PROT:LEV?\n";
    } else if (cmdt == COMMAND_TYPE::SetState) {
        int ch = (int)val;
        return "OUTP:STAT " + std::to_string(ch) + "\n";
    } else if (cmdt == COMMAND_TYPE::SetVoltage) {
        return "VOLT " + std::to_string(val) + "\n";
    } else if (cmdt == COMMAND_TYPE::SetOVPLevel) {
        return "VOLT:PROT:LEV " + std::to_string(val) + "\n";
    }

    return "";
}

std::string HMP4040Driver::GenerateCommand(COMMAND_TYPE cmdt, int ch, float val) {
    if (cmdt == COMMAND_TYPE::SelectChannelAndSetVoltage) {
        return "INST:NSEL " + std::to_string(ch) + "\nVOLT " + std::to_string(val) + "\n";
    } else {
        std::cout
            << "This function is usable only with SelectChannelAndSetVoltage!\n";  // -> Why? (FW)
        return "";
    }
}

//************************************************************************************
//** the STATE and SELECT OUTPUT on of is a bit confusion: from the manual

/*

OUTPut:SELect {OFF | ON | 0 | 1}
Activates or deactivates the previous selected channel. If the channel is activated the channel
LED lights up green in CV (constant voltage) mode or red in CC (constant current) mode.
Parameters:
    ON | 1 Channel will be activated
    OFF | 0 Channel will be deactivated
    *RST: OFF | 0
OUTPut[:STATe] {OFF | ON | 0 | 1}
Activates or deactivates the previous selected channel and turning on the output. The selected
channel LED lights up green. If the output will be turned of with OUTP OFF only the previous
selected channel will be deactivated. After sending OUTP OFF command the output button is
still activated.
Parameters:
    ON | 1 Channel and output will be activated
    OFF | 0 Channel will be deactivated
    *RST: OFF | 0
Example:
INST OUT1
OUTP ON (= channel 1 and output will be activated; channel and output LED will light up)
OUTPut[:STATe]?
Queries the output state.
Return values:
    1
    0
ON - output is activated
OFF - output is deactivated
26SCPI Commands HMP series
Remote Control
Command Reference
OUTPut:GENeral {OFF | ON | 0 | 1}
Turning on / off all previous selected channels simultaneously.
Parameters:
    ON | 1 Channels and output will be activated
    OFF | 0 Channels will be deactivated
Example:
INST OUT1
Volt 12
Curr 0.1
OUTP:SEL ON     CH1 LED lights up green
INST OUT2
Volt 12
Curr 0.2
OUTP:SEL ON     CH2 LED lights up green
OUTP:GEN ON     Channels will be activated simultaneously

*/

/*
STATus:QUEStionable Register


Bit No. Meaning

0 Voltage
This bit is set while the instrument is in constant current mode (CC). This means that the voltage
will be regulated and the current is constant.

1 Current
This bit is set while the instrument is in constant voltage mode (CV). This means that the current
is variable and the voltage is constant.

2 Not used
3 Not used

4 Temperature over range
This bit is set if an over temperature occurs

5-8Not used

9 OVP
TrippedThis bit is set if the over voltage protection has tripped.

10 Fuse
TrippedThis bit is set if the fuse protection has tripped.
*/
