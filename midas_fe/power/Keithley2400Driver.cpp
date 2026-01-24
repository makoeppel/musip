#include "Keithley2400Driver.h"
#include <thread>


Keithley2400Driver::Keithley2400Driver()
{

}


Keithley2400Driver::~Keithley2400Driver()
{
}


Keithley2400Driver::Keithley2400Driver(std::string n, EQUIPMENT_INFO* inf) : PowerDriver(n,inf)
{
    std::cout << " Keithley2400 driver with " << instrumentID.size() << " channels instantiated " << std::endl;
}


INT Keithley2400Driver::ConnectODB()
{
    InitODBArray();
    PowerDriver::ConnectODB();
    settings["port"](5025);
    settings["reply timout"](100);
    settings["min reply"](2); //minimum reply , 2 chars , not 3 (not fully figured out why)
    settings["ESR"](0);
    settings["Max Voltage"](2000);
    settings["Temp cal y-interception"](0.6643); //based on a diode calibration measurement in zurich
    settings["Temp cal slope"](-0.00188); //based on a diode calibration measurement in zurich
    if(false) return FE_ERR_ODB;
    return FE_SUCCESS;
}


void Keithley2400Driver::InitODBArray()
{
    midas::odb settings_array = { {"Channel Names",std::array<std::string,1>()} };
    settings_array.connect("/Equipment/"+name+"/Settings");
}

bool Keithley2400Driver::AskPermissionToTurnOn(int /*channel*/) //extra check whether it is safe to tunr on supply;
{
    return true;
}

INT Keithley2400Driver::Init()
{
    usb = settings["USB_PORT"];
    std::cout << "Call init on " << usb << std::endl;
    std::string cmd = "";
    std::string reply = "";
    INT err;

    //longer wait time for the HMP supplies //TODO What abut Keithly?
    client->SetDefaultWaitTime(200);
    //global reset if requested
    if(settings["Global Reset On FE Start"] == true)
    {
        cmd = "*RST\n";
        if( !client->Write(cmd) ) cm_msg(MERROR, "Init KEITH supply ... ", "could not global reset %s", usb.c_str());
        else cm_msg(MINFO,"power_fe","Init global reset of %s",usb.c_str());
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    cmd=GenerateCommand(COMMAND_TYPE::Beep, 0);


    if( !client->Write(cmd) ) cm_msg(MERROR, "Init KEITH supply ... ", "could not beep %s", usb.c_str());
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));


    // std::vector<std::string> error_queue = ReadErrorQueue(-1,err);
    // for(auto& s : error_queue)
    // {
    //     if(s.find("No error") == std::string::npos) { cm_msg(MERROR,"power_fe"," Error from KEITH supply : %s",s.c_str()); }
    // } //TOFIX: what's wrong???


    //KEITH has 1 channel
    instrumentID = {1};
    int nChannels = instrumentID.size();
    settings["NChannels"] = nChannels;

    voltage.resize(nChannels);
    demandvoltage.resize(nChannels);
    demandcurrent.resize(nChannels);
    current.resize(nChannels);
    currentlimit.resize(nChannels);
    state.resize(nChannels);
    OVPlevel.resize(nChannels);
    temperature.resize(nChannels);
    //instrumentID = {1,2,3,4}; // The HMP4040 supply has 4 channel numbered 1,2,3, and 4.

    idCode=ReadIDCode(-1,err); //channel selection not relevant for HAMEG supply to read ID
                               // "-1" is a trick not to select a channel before the query

    std::cout << "ID code: " << idCode << std::endl;

    //client->FlushQueu();

    //read channels
    float interception = settings["Temp cal y-interception"];
    float slope = settings["Temp cal slope"];
    for(int i = 0; i<nChannels; i++ )
    {
        state[i]=ReadState(i,err);
        if(err!=FE_SUCCESS) return err;
    }
    variables["State"]=state; //push to odb
    variables["Set State"]=state;
    for(int i = 0; i<nChannels; i++ )
    {
        voltage[i]=ReadVoltage(i,err);
        demandvoltage[i]=ReadSetVoltage(i,err);
        OVPlevel[i]=ReadOVPLevel(i,err);
        current[i]=ReadCurrent(i,err);
        demandcurrent[i] = ReadSetCurrent(i,err);
        currentlimit[i]=ReadCurrentLimit(i,err);

        SourceMode.push_back(ReadSourceMode(i,err));
        temperature[i]= (voltage[i]- interception) / slope;

        if(err!=FE_SUCCESS) return err;
    }

    settings["Identification Code"]=idCode;
    settings["ESR"]=ReadESR(-1,err);
    settings["Read ESR"]=false;

    variables["State"]=state; //push to odb
    variables["Set State"]=state; //the init function can not change the on/off state of the supply

    variables["Voltage"]=voltage;
    variables["Temperature"] = temperature;
    variables["Demand Voltage"]=demandvoltage;

    variables["Current"]=current;
    variables["Demand Current"] = demandcurrent;
    variables["Current Limit"]=currentlimit;

    variables["OVP Level"]=OVPlevel;
    variables["Demand OVP Level"]=OVPlevel;

    settings["Source Mode"]=SourceMode;

    //watch functions
    variables["Set State"].watch(  [&](midas::odb &arg  [[maybe_unused]]) { this->SetStateChanged(); }  );
    variables["Demand Current"].watch(  [&](midas::odb &arg [[maybe_unused]]) { this->DemandCurrentChanged(); }  );
    variables["Demand Voltage"].watch(  [&](midas::odb &arg [[maybe_unused]]) { this->DemandVoltageChanged(); }  );
    variables["Current Limit"].watch(  [&](midas::odb &arg [[maybe_unused]]) { this->CurrentLimitChanged(); }  );
    variables["Demand OVP Level"].watch(  [&](midas::odb &arg  [[maybe_unused]]) { this->DemandOVPLevelChanged(); }  );
    settings["Read ESR"].watch(  [&](midas::odb &arg  [[maybe_unused]]) { this->ReadESRChanged(); }  );
    settings["Source Mode"].watch(  [&](midas::odb &arg  [[maybe_unused]]) { this->SourceModeChanged(); }  );
    return FE_SUCCESS;
}

INT Keithley2400Driver::ReadAll()
{
    INT err;
    INT err_accumulated;
    int nChannels = instrumentID.size();
    //update local book keeping
    for(int i=0; i<nChannels; i++)
    {
        if( readonlythisindex >= 0 && i != readonlythisindex) continue;

        bool bvalue = ReadState(i,err);
        err_accumulated = err;
        err = 0;
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
            float tvalue = (fvalue - 0.6559) / -0.00198;
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

        fvalue = ReadOVPLevel(i,err);
        err_accumulated = err_accumulated | err;
        if( fabs(OVPlevel[i]-fvalue) > fabs(relevantchange*OVPlevel[i]) )
        {
            OVPlevel[i]=fvalue;
            variables["OVP Level"][i]=fvalue;
        }


        if(err_accumulated!=FE_SUCCESS){
            return err_accumulated & 0xFFFE; //remove the success bit if there is any
        }
    }

    std::vector<std::string> error_queue = ReadErrorQueue(-1,err);
    for(auto& s : error_queue)
    {
        cm_msg(MINFO, "Read KEITH supply ... ", "Error queue: %s", s.c_str());
        if(s.find("No error") == std::string::npos) { cm_msg(MERROR,"power_fe"," Error from KEITH supply : %s",s.c_str()); }
    } //TOFIX: what's wrong???

    return FE_SUCCESS;
}


void Keithley2400Driver::ReadESRChanged()
{
    INT err;
    bool value = settings["Read ESR"];
    if(value)
    {
        settings["ESR"] = ReadESR(-1,err);
        settings["Read ESR"]=false;
    }
}


// bool Keithley2400Driver::AskPermissionToTurnOn(int channel) //extra check whether it is safe to tunr on supply;
// {
//     return true;
// }

std::string Keithley2400Driver::GenerateCommand(COMMAND_TYPE cmdt, float val)
{
    if (cmdt == COMMAND_TYPE::SetCurrent) {
        return ":SOUR:CURR "+std::to_string(val)+"\n";
    } else if (cmdt == COMMAND_TYPE::ReadCurrent){
        return ":READ?\n";
    } else if (cmdt == COMMAND_TYPE::ReadState) {
        return ":OUTP?\n";
    } else if (cmdt == COMMAND_TYPE::ON) {
        return ":OUTP ON\n";
    } else if (cmdt == COMMAND_TYPE::OFF) {
        return ":OUTP OFF\n";
    } else if (cmdt == COMMAND_TYPE::ReadVoltage){
        return ":READ?\n";
    } else if (cmdt == COMMAND_TYPE::SetCurrentLimit){
        return ":SENS:CURR:PROT "+std::to_string(val)+"\n";
    } else if (cmdt == COMMAND_TYPE::ReadCurrentLimit){
        return ":SENS:CURR:PROT?\n";
    } else if (cmdt == COMMAND_TYPE::SetVoltage){
        return ":SOUR:VOLT "+std::to_string(val)+"\n";
    } else if (cmdt == COMMAND_TYPE::ReadSetVoltage){
        return ":SOUR:VOLT?\n";
    } else if (cmdt == COMMAND_TYPE::ReadSetCurrent){
        return ":SOUR:CURR?\n";
    } else if (cmdt == COMMAND_TYPE::Beep){
        return ":SYST:BEEP 100,1\n";
    } else if (cmdt == COMMAND_TYPE::CLearStatus){
        return "*CLS\n";
    } else if (cmdt == COMMAND_TYPE::OPC){
        return "*OPC?\n";
    } else if (cmdt == COMMAND_TYPE::ReadESR){
        return "*ESR?\n";
    } else if (cmdt == COMMAND_TYPE::Reset){
        return "*RST\n";
    } else if (cmdt == COMMAND_TYPE::ReadOVPLevel){
        return ":SENS:VOLT:PROT?\n";
    } else if (cmdt == COMMAND_TYPE::SetOVPLevel) {
        return ":SENS:VOLT:PROT "+std::to_string(val)+"\n";
    } else if (cmdt == COMMAND_TYPE::SetCurrentAsRead) {
        return ":FORM:ELEM CURR\n";
    } else if (cmdt == COMMAND_TYPE::SetVoltageAsRead) {
        return ":FORM:ELEM VOLT\n";
    } else if (cmdt == COMMAND_TYPE::SetState) {
        if (val == 1)
            return ":OUTP ON\n";
        else
        return ":OUTP OFF\n";
    } else if (cmdt==COMMAND_TYPE::SourceCurrent){
        return ":SOUR:FUNC CURR\n";
    } else if (cmdt==COMMAND_TYPE::SourceVoltage){
        return ":SOUR:FUNC VOLT\n";
    } else if (cmdt==COMMAND_TYPE::ReadSourceMode){
        return ":SOUR:FUNC?\n";
    }
    return "";
}

std::string Keithley2400Driver::GenerateCommand(COMMAND_TYPE cmdt, int /*ch*/, float val)
{
    if (cmdt == COMMAND_TYPE::SelectChannelAndSetVoltage) {
        return ":SOUR:VOLT "+std::to_string(val)+"\n";
    }
    if (cmdt == COMMAND_TYPE::SelectChannelAndSetCurrent) {
        return ":SOUR:CURR "+std::to_string(val)+"\n";
    }
    else {
        std::cout << "This function is usable only with SelectChannelAndSetVoltageorCurrent!\n";
        return "";
    }
}

std::string Keithley2400Driver::ReadIDCode(int index, INT& error) {
    std::string id_code = PowerDriver::ReadIDCode(index, error);

    int found = id_code.find("C10");
    return id_code.substr(0, found-1);

}
/*std::string Keithley2400Driver::GenerateCommand(COMMAND_TYPE cmdt, int ch, float val)
{
    std::cout << "This function is not usable with Keithley2400Driver!\n";
    return "";
}*/
