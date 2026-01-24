//

#include "Keithley2450Driver.h"
#include <thread>

Keithley2450Driver::Keithley2450Driver() {}

Keithley2450Driver::~Keithley2450Driver() {}

Keithley2450Driver::Keithley2450Driver(std::string n, EQUIPMENT_INFO* inf)
 : PowerDriver(n, inf) {
    std::cout << " Keithley2450 driver with " << instrumentID.size() << " channels instantiated." << std::endl;
}

INT Keithley2450Driver::ConnectODB() {
    InitODBArray();
    PowerDriver::ConnectODB();

    settings["port"](5025);
    settings["reply timout"](300);
    // minimum reply , 2 chars , not 3 (not fully figured out why)
    settings["min reply"](2);
    settings["ESR"](0);
    settings["Max Voltage"](2);
    // based on a diode calibration measurement in zurich
    settings["Temp cal y-interception"](0.6643);
    // based on a diode calibration measurement in zurich
    settings["Temp cal slope"](-0.00188);

    if (false) { return FE_ERR_ODB; }
    return FE_SUCCESS;
}


void Keithley2450Driver::InitODBArray() {
    midas::odb settings_array = {{"Channel Names", std::array<std::string, 4>()}};
    settings_array.connect("/Equipment/" + name + "/Settings");
}


INT Keithley2450Driver::Init() {
    INT err;
    ip = settings["IP"];
    client->SetDefaultWaitTime(200);

    // Global reset if requested
    if (settings["Global Reset On FE Start"]) {
        if (client->Write("*RST\n")) {
            cm_msg(MINFO, "Init KEITH supply ... ", "init global reset of %s", ip.c_str());
        } else {
            cm_msg(MERROR, "Init KEITH supply ... ", "could not global reset %s", ip.c_str());
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
    }

    if (!client->Write(GenerateCommand(COMMAND_TYPE::Beep, 0))) {
        cm_msg(MERROR, "Init KEITH supply ... ", "could not beep %s", ip.c_str());
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    // Channel selection not relevant for HAMEG supply to read ID
    // "-1" is a trick not to select a channel before the query
    idCode = ReadIDCode(-1, err);
    std::cout << "ID code: " << idCode << std::endl;

    float interception = settings["Temp cal y-interception"];
    float slope = settings["Temp cal slope"];

    // KEITH has 1 channel
    instrumentID = {1};
    int nChannels = instrumentID.size();
    settings["NChannels"] = nChannels;
    // Voltage
    voltage.resize(nChannels);
    demandvoltage.resize(nChannels);
    //
    current.resize(nChannels);
    demandcurrent.resize(nChannels);
    currentlimit.resize(nChannels);
    // Service
    state.resize(nChannels);
    OVPlevel.resize(nChannels);
    SourceMode.resize(nChannels);
    temperature.resize(nChannels);

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
        // Voltage
        voltage[i] = ReadVoltage(i, err);
        demandvoltage[i] = ReadSetVoltage(i, err);
        // Current
        current[i] = ReadCurrent(i, err);
        demandcurrent[i] = ReadSetCurrent(i, err);
        // For whatever reason we have this structure...
        try {
            if (variables["Current Limit"]) {
                currentlimit[i] = variables["Current Limit"];
            }
        } catch (...) {
            std::cout << "Current limit not in the ODB yet" << std::endl;
            currentlimit[i] = ReadCurrentLimit(i, err);
        }
        // OVPlevel[i] = ReadOVPLevel(i, err);
        // Hardcoded limit of 20V
        OVPlevel[i] = 20;
        SourceMode[i] = ReadSourceMode(i, err);
        temperature[i]= (voltage[i]- interception) / slope;


        if (err != FE_SUCCESS) { return err; }
    }

    settings["Identification Code"] = idCode;
    settings["ESR"] = ReadESR(-1, err);
    settings["Read ESR"] = false;

    variables["Voltage"] = voltage;
    variables["Demand Voltage"] = demandvoltage;
    variables["Current"] = current;
    variables["Demand Current"] = demandcurrent;
    variables["Current Limit"] = currentlimit;

    variables["OVP Level"] = OVPlevel;
    variables["Demand OVP Level"] = OVPlevel;
    settings["Source Mode"] = SourceMode;
    variables["Temperature"] = temperature;

    // Watch functions
    variables["Set State"].watch([&](midas::odb &arg [[maybe_unused]]) { this->SetStateChanged(); });
    variables["Demand Voltage"].watch([&](midas::odb &arg [[maybe_unused]]) { this->DemandVoltageChanged(); });
    variables["Demand Current"].watch([&](midas::odb &arg [[maybe_unused]]) { this->DemandCurrentChanged(); });
    variables["Current Limit"].watch([&](midas::odb &arg [[maybe_unused]]) { this->CurrentLimitChanged(); });
    variables["Demand OVP Level"].watch([&](midas::odb &arg [[maybe_unused]]) { this->DemandOVPLevelChanged(); });
    settings["Source Mode"].watch([&](midas::odb &arg [[maybe_unused]]) { this->SourceModeChanged(); });
    settings["Read ESR"].watch([&](midas::odb &arg [[maybe_unused]]) { this->ReadESRChanged(); });

    return FE_SUCCESS;
}


INT Keithley2450Driver::ReadAll() {
    INT err;
    INT err_accumulated;
    int nChannels = instrumentID.size();
    //update local book keeping
    for (int i(0); i < nChannels; i++) {
        if( readonlythisindex >= 0 && i != readonlythisindex) continue;

        bool bvalue = ReadState(i,err);
        err_accumulated = err;
        if(state[i]!=bvalue) //only update odb if there is a change
        {
            state[i]=bvalue;
            variables["State"][i]=bvalue;
        }

        float fvalue = ReadVoltage(i,err);
        err_accumulated = err_accumulated | err;
        if( fabs(voltage[i]-fvalue) > fabs(relevantchange*voltage[i]) )
        {
            voltage[i]=fvalue;
            variables["Voltage"][i]=fvalue;
            float tvalue = (fvalue - 0.6643) / -0.00188;
            temperature[i]= tvalue;
            variables["Temperature"][i] = tvalue;
        }

        fvalue = ReadCurrent(i,err);
        err_accumulated = err_accumulated | err;
        if( fabs(current[i]-fvalue) > fabs(relevantchange*current[i]) )
        {
            current[i]=fvalue;
            variables["Current"][i]=fvalue;
        }
        sleep(1);
        fvalue = ReadCurrentLimit(i,err);
        err_accumulated = err_accumulated | err;

        //remove the success bit if there is any
        if(err_accumulated!=FE_SUCCESS)
            return err_accumulated & 0xFFFE;
    }

    [[maybe_unused]] bool buffer = ClearBuffer();
    return FE_SUCCESS;
}

void Keithley2450Driver::ReadESRChanged() {
    INT err;
    if (settings["Read ESR"]) {
        settings["ESR"] = ReadESR(-1, err);
        settings["Read ESR"] = false;
    }
}

// FIXME: this function will be removed in the next cleanup
// extra check whether it is safe to turn on supply
bool Keithley2450Driver::AskPermissionToTurnOn(int ) {
    return true;
}

// TODO: see if we can set HIMPedance mode: p12-38
// :OUTP:<function>:SMODe <state>
// <function> as CURRent / VOLTage
// <state> as NORMal / !!!! HIMPedance / ZERO / GUARd

// Or :SOURce:CURRent/VOLTage:HIGH:CAPacitance ON
//    smu.source.highc = smu.ON
std::string Keithley2450Driver::GenerateCommand(COMMAND_TYPE cmdt, float val) {
    std::string command_type = settings["Command Type"];
    if (cmdt == COMMAND_TYPE::CLearStatus) {
        return "*CLS\n";
    } else if (cmdt == COMMAND_TYPE::OPC) {
        return "*OPC?\n";
    } else if (cmdt == COMMAND_TYPE::ReadESR) {
        return "*ESR?\n";
    } else if (cmdt == COMMAND_TYPE::Reset) {
        return "*RST\n";
    } else if (command_type == "SCPI") {
        // Current
        if (cmdt == COMMAND_TYPE::SetCurrent) {
            return ":SOUR:CURR " + std::to_string(val) + "\n";
        } else if (cmdt == COMMAND_TYPE::SetCurrentRange) {
            return ":SENS:CURR:RANG " + std::to_string(val) + "\n";
        } else if (cmdt == COMMAND_TYPE::SetCurrentLimit) {
            return ":SOUR:VOLT:ILIM " + std::to_string(val) + "\n";
        } else if (cmdt == COMMAND_TYPE::ReadCurrentLimit) {
            return ":SOUR:VOLT:ILIM?\n";
        } else if (cmdt == COMMAND_TYPE::SetCurrentAsRead) {
            return ":SENS:FUNC \"CURR\"\n";
        } else if (cmdt == COMMAND_TYPE::ReadSetCurrent){
            return ":SOUR:CURR?\n"; // Have been added recently
        } else if (cmdt == COMMAND_TYPE::ReadCurrent) {
            // return ":READ?\n";
            return ":MEAS:CURR?\n";
        }
        // Voltage
        else if (cmdt == COMMAND_TYPE::SetVoltage) {
            return ":SOUR:VOLT " + std::to_string(val) + "\n";
        } else if (cmdt == COMMAND_TYPE::SetVoltageRange) {
            return ":SENS:VOLT:RANG " + std::to_string(val) + "\n";
        } else if (cmdt == COMMAND_TYPE::SetOVPLevel) {
            return ":SOUR:VOLT:PROT PROT" + std::to_string((int)(val)) + "\n";
        } else if (cmdt == COMMAND_TYPE::SetVoltageLimit) {
            return ":SOUR:CURR:VLIM " + std::to_string(val) + "\n";
        } else if (cmdt == COMMAND_TYPE::ReadVoltageLimit) {
            return ":SOUR:CURR:VLIM?\n";
        } else if (cmdt == COMMAND_TYPE::ReadOVPLevel){
            return ":SOUR:VOLT:PROT?\n";
        } else if (cmdt == COMMAND_TYPE::SetVoltageAsRead) {
            return ":SENS:FUNC \"VOLT\"\n";
        } else if (cmdt == COMMAND_TYPE::ReadSetVoltage) {
            return ":SOUR:VOLT?\n";
        } else if (cmdt == COMMAND_TYPE::ReadVoltage) {
            return ":READ?\n";
            // return ":MEAS:VOLT?\n";
        }
        // Other
        else if (cmdt == COMMAND_TYPE::CurrHighCapacitanceOn) {
            return ":SOUR:CURR:HIGH:CAP ON\n";
        } else if (cmdt == COMMAND_TYPE::VoltHighCapacitanceOn) {
            return ":SOUR:VOLT:HIGH:CAP ON\n";
        } else if (cmdt == COMMAND_TYPE::ReadSourceMode) {
            return ":SOUR:FUNC?\n";
        } else if (cmdt == COMMAND_TYPE::SetState) {
            int ch = (int)val;
            if (ch == 1) {
                return ":OUTP:STAT ON\n";
            } else if (ch == 0) {
                return ":OUTP:STAT OFF\n";
            } else {
                cm_msg(MERROR, "Init KEITH supply ... ", "SetState can be only 1 or 0, and not %d", ch);
                return "\n";
            }
        } else if (cmdt == COMMAND_TYPE::ReadState) {
            return ":OUTP:STAT?\n";
        } else if (cmdt == COMMAND_TYPE::Beep) {
            return ":SYST:BEEP 4400,0.5\n";
        } else if (cmdt == COMMAND_TYPE::ReadErrorQueue){
            return ":SYST:ERR:NEXT?\n";
        } else if (cmdt == COMMAND_TYPE::ClearBuffer) {
            return ":TRAC:CLEAR\n";
        }
    // TOKNOW: It is far from complete!
    } else if (command_type == "TSP"){
        if (cmdt == COMMAND_TYPE::SetCurrent) {
            return "smu.source.ilimit.level="+std::to_string(val)+"\n";
        } else if (cmdt == COMMAND_TYPE::ReadCurrent){
            return "print(smu.measure.read())";
            // return "smu.measure.read(defbuffer1);printbuffer(defbuffer1.n, defbuffer1.n, defbuffer1)\n";
        } else if (cmdt == COMMAND_TYPE::SetCurrentAsRead) {
            // return "smu.source.func = smu.FUNC_CURRENT";
            return "smu.source.func = smu.FUNC_DC_CURRENT";
        } else if (cmdt == COMMAND_TYPE::SetVoltageAsRead) {
            return "smu.source.func = smu.FUNC_DC_VOLTAGE";
        } else if (cmdt == COMMAND_TYPE::ReadState) {
            return "print(smu.source.output)\n";
        } else if (cmdt == COMMAND_TYPE::ReadVoltage){
            return "print(smu.measure.read())";
            // return "print(smu.source.level)\n";
        } else if (cmdt == COMMAND_TYPE::ReadSetVoltage){
            return "print(smu.source.level)\n";
        } else if (cmdt == COMMAND_TYPE::ReadCurrentLimit){
            return "print(smu.source.ilimit.level)\n";
        } else if (cmdt == COMMAND_TYPE::SetVoltage){
            return "smu.source.level="+std::to_string(val)+"\n";
        } else if (cmdt == COMMAND_TYPE::Beep){
            return "beeper.beep(0.5, 4400);\n";
        } else if (cmdt == COMMAND_TYPE::SetCurrentLimit){
            return "smu.source.ilimit.level="+std::to_string(val)+"\n";
        } else if (cmdt == COMMAND_TYPE::SetState){
            int ch = (int)val;
            if (ch == 1) {
                return "smu.source.output=smu.ON\n";
            }
            else if (ch == 0) {
                return "smu.source.output=smu.OFF\n";
            }
            else {
                std::cout << "Error: set state can be onlz 1 or 0\n";//TODO: message in midas
                return "\n";
            }
        } else if (cmdt == COMMAND_TYPE::ReadErrorQueue){
            return "print(errorqueue.next())\n";
        } else if (cmdt == COMMAND_TYPE::ReadOVPLevel){
            return "print(smu.source.protect.level)\n";
        } else if (cmdt == COMMAND_TYPE::SetOVPLevel) {
            return "smu.source.protect.level=smu.PROTECT_"+std::to_string((int)(val))+"V\n";
        }
    }
    return "";
}

std::string Keithley2450Driver::GenerateCommand(COMMAND_TYPE cmdt, int, float val) {
    std::string command_type = settings["Command Type"];
    if(command_type == "SCPI") {
        if(cmdt == COMMAND_TYPE::SelectChannelAndSetVoltage) {
            return ":SOUR:VOLT " + std::to_string(val) + "\n";
        }
        else if(cmdt == COMMAND_TYPE::SelectChannelAndSetCurrent) {
            return ":SOUR:CURR " + std::to_string(val) + "\n";
        }
    }
    else if(command_type == "TSP") {
        if(cmdt == COMMAND_TYPE::SelectChannelAndSetVoltage) {
            return "smu.source.level=" + std::to_string(val) + "\n";
        }
        else if(cmdt == COMMAND_TYPE::SelectChannelAndSetCurrent) {
            return "";
            // return "smu.source.level=" + std::to_string(val) + "\n";
        }
    }
    else {
        std::cout << "This function is usable only with SelectChannelAndSetVoltage(Current)!\n";
        return "";
    }
    return "";
}
