#include "GenesysDriver.h"
#include <cstring>
#include <chrono>
#include <thread>

//
// MIDAS Driver for our TDK Genesys supplies
// FW, Sep. 2020
//
// communicate with SCPI commands
// Setup for 1 supply connected with LAN, the other supplies daisy chained with the RS485 bus
// supply IDs are setup as 0,1,2,...
//
// From manual:
// * Recommended time delay between commands: 5mSec minimum. Some commands might require longer time. In such cases, refer to NOTE following command description.
//
GenesysDriver::GenesysDriver(std::string n, EQUIPMENT_INFO* inf) : PowerDriver(n,inf)
{
    std::cout << " GenesysDriver instantiated " << std::endl;

    //device specific constants
}


GenesysDriver::~GenesysDriver()
{

}


INT GenesysDriver::ConnectODB()
{
    InitODBArray();
    INT status = PowerDriver::ConnectODB();
    settings["port"](8003);
    settings["reply timout"](50);
    settings["min reply"](3); //minimum reply , a char + "\n"
    return status;
}


//didn't find a cleaner way to init the array entries, have a prior initialized 'variables', and not overwrite Set values
void GenesysDriver::InitODBArray()
{
    midas::odb settings_array = { {"Channel Names",std::array<std::string,16>()} , {"Blink",std::array<bool,16>()} , {"ESR",std::array<int,16>()}  };
    settings_array.connect("/Equipment/"+name+"/Settings");
}



INT GenesysDriver::Init()
{
    std::string ip = settings["IP"];
    std::cout << "Call init on " << ip << std::endl;
    std::string cmd = "";
    std::string reply = "";
    INT err;

    //global reset if requested
    if( settings["Global Reset On FE Start"] )
    {
        cmd = "GLOB:*RST\n";
        if( !client->Write(cmd) ) cm_msg(MERROR, "Init genesys supply ... ", "could not global reset %s", ip.c_str());
        else cm_msg(MINFO,"power_fe","Init global reset of %s",ip.c_str());
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    //figure out the number of supplies connected
    for(int i = 0; i < 12; i++)
    {
        cmd = "INST:NSEL " + std::to_string(i) + "\n";
        client->Write(cmd);
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
        bool success = OPC();
        if(!success) cm_msg(MINFO,"power_fe","Supply nr %d NOT detected",i);
        else
        {
            cm_msg(MINFO,"power_fe","Supply nr %d seen",i);
            instrumentID.push_back(i);
        }
    }

    cm_msg(MINFO,"power_fe"," %d supplies registered in daisy chain",int(instrumentID.size()));
    int nChannels = instrumentID.size();
    if(nChannels != settings["NChannels"]) cm_msg(MINFO,"power_fe"," Different as the set ODB value of %d, updating",int(settings["NChannels"]));
    settings["NChannels"] = instrumentID.size();

    // ***** channel by channel settings ***** //

    //read system errors
    for(int i = 0; i<nChannels; i++ )
    {
        std::vector<std::string> error_queue = ReadErrorQueue(i,err);
        for(auto& s : error_queue)
        {
            if(s.substr(0,1) != "0") { cm_msg(MERROR,"power_fe"," Error from tdk %d supply : %s",instrumentID[i],s.c_str()); }
        }
    }

    settings["Address"] = instrumentID;
    state.resize(nChannels);
    voltage.resize(nChannels);
    demandvoltage.resize(nChannels);
    current.resize(nChannels);
    currentlimit.resize(nChannels);
    idCode.resize(nChannels);
    OVPlevel.resize(nChannels);
    interlock_enabled.resize(nChannels);
    OVPlevel.resize(nChannels);
    QCGEreg.resize(nChannels);

    for(int i = 0; i<nChannels; i++ )
    {
        idCode[i]=ReadIDCode(i,err);

        state[i]=ReadState(i,err);

        voltage[i]=ReadVoltage(i,err);
        demandvoltage[i]=ReadSetVoltage(i,err);
        demandcurrent[i]=ReadSetCurrent(i,err);

        current[i]=ReadCurrent(i,err);
        currentlimit[i]=ReadCurrentLimit(i,err);

        OVPlevel[i]=ReadOVPLevel(i,err);

        interlock_enabled[i]=true;
        SetInterlock(i,interlock_enabled[i],err);

        settings["ESR"]=ReadESR(i,err);

        QCGEreg[i] =ReadQCGE(i,err);

        if(err!=FE_SUCCESS) return err;
    }

    settings["Identification Code"]=idCode;

    variables["Questionable Condition Register"]=QCGEreg;

    variables["State"]=state; //push to odb
    variables["Set State"]=state; //the init function can not change the on/off state of the supply


    variables["Voltage"]=voltage;
    variables["Demand Voltage"]=demandvoltage;

    variables["Current"]=current;
    variables["Current Limit"]=currentlimit;

    variables["OVP Level"]=OVPlevel;

    variables["Interlock"]= InterlockStatus(QCGEreg);



    // user arrays.
    settings["Channel Names"].resize(nChannels);
    settings["Blink"].resize(nChannels);
    settings["ESR"].resize(nChannels);
    settings["Read ESR"]=false;


    // ***** set up watch ***** //
    variables["Set State"].watch(  [&](midas::odb &) { this->SetStateChanged(); }  );
    variables["Demand Voltage"].watch(  [&](midas::odb &) { this->DemandVoltageChanged(); }  );
    variables["Current Limit"].watch(  [&](midas::odb &) { this->CurrentLimitChanged(); }  );

    settings["Blink"].watch(  [&](midas::odb &) { this->BlinkChanged(); }  );
    settings["Read ESR"].watch(  [&](midas::odb &) { this->ReadESRChanged(); }  );





    return FE_SUCCESS;
}





bool GenesysDriver::AskPermissionToTurnOn(int) //extra check whether it is safe to tunr on supply;
{
    return true;
}



// ************ watch functions ************* //


void GenesysDriver::BlinkChanged()
{
    INT err;

    for(unsigned int i=0; i< instrumentID.size(); i++)
    {
        bool value = settings["Blink"][i];
        SetBlink(i,value,err);
        if(err!=FE_SUCCESS ) cm_msg(MERROR, "Genesys supply ... ", "changing flashing of channel %d to %d failed, error %d", instrumentID[i],value,err);
    }

}

void GenesysDriver::ReadESRChanged()
{
    INT err;
    bool value = settings["Read ESR"];
    cm_msg(MINFO, "Genesys supply ... ", "ESR read request set to %d",value);
    if(value)
    {
        for(unsigned int i=0; i< instrumentID.size(); i++)
        {
            settings["ESR"][i] = ReadESR(i,err);
        }
        settings["Read ESR"]=false;
    }

}


// **************  Set Functions ************** //

void GenesysDriver::SetInterlock(int index,bool value, INT& error)
{
    std::string cmd;
    bool success;
    error = FE_SUCCESS;

    if( SelectChannel(instrumentID[index]) )
    {
        //OUTPut:ILC[:STATe] <Bool>
        if(value==true) { cmd="OUTP:ILC 1\n"; }
        else { cmd = "OUTP:ILC 0\n"; }
        client->Write(cmd);
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
        success = OPC();
        if(!success) error=FE_ERR_DRIVER;
        else cm_msg(MINFO, "Genesys supply ... ", "Interlock enabled[1]/disabled[0]: %d",value );
    }
}



void GenesysDriver::SetBlink(int index, bool value,INT& error)
{
    std::string cmd;
    bool success;
    error = FE_SUCCESS;

    if( SelectChannel(instrumentID[index]) )
    {
        if(value==true) { cmd="DISP:WIND:FLAS 1\n"; }
        else { cmd = "DISP:WIND:FLAS 0\n"; }
        client->Write(cmd);
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
        success = OPC();
        if(!success) error=FE_ERR_DRIVER;
    }
}



// **************  Read Functions ************** //



INT GenesysDriver::ReadAll()
{
    int nChannels = instrumentID.size();
    INT err;
    INT err_accumulated;
    bool status_reg_update = false;

    //update local book keeping
    for(int i=0; i<nChannels; i++)
    {
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


        std::vector<std::string> error_queue = ReadErrorQueue(i,err);
        for(auto& s : error_queue)
        {
            if(s.substr(0,1) != "0") { cm_msg(MERROR,"power_fe"," Error from tdk %d supply : %s",instrumentID[i],s.c_str()); }
        }

        WORD reg = ReadQCGE(i,err); //Questionable Condition Group Event register
        if(reg != QCGEreg[i]) {
            variables["Questionable Condition Register"][i]= QCGEreg[i];
            status_reg_update = true;
        }

        if(err_accumulated!=FE_SUCCESS) return err_accumulated & 0xFFFE;
    }

    if(status_reg_update)
    {
        variables["Interlock"]= InterlockStatus(QCGEreg);
    }

    return FE_SUCCESS;
}


std::vector<bool> GenesysDriver::InterlockStatus(std::vector<WORD> reg)
{
    std::vector<bool> vec;
    std::transform( reg.begin(), reg.end(), std::back_inserter(vec) , [](DWORD word) { return (( word & 0x8 ) != 0) ? true : false ;} );
    //std::transform( vec.begin(), vec.end(), interlock_enabled.begin(), vec.begin(), [](bool value, bool flag) { return flag ? value : false ;} ); //if the interlock is disabled, we can not
    return vec;
}

/*

Bit configuration of the Questionable Condition Group Event register is as follows:

Position 15 14 13 12 11 10 9 8
Value - 16384 8192 4096 2048 1024 512 256
Name - POFF PWS PERR GERR PACK UVP ENA

Position 7 6 5 4 3 2 1 0
Value 128 64 32 16 8 4 2 -
Name ILC OFF SO OVP FLD OTP AC -

POFF - Power OFF.

ILC - Interlock.
Set to "1" when the power supply Set to "1" when Interlock signal fault
Power Switch is OFF. occurs.

PWS - Parallel Wait Slave. OFF - DC Output OFF.
Set to "1" when master power supply Set to "1" when the power supply DC
is waiting for slaves to become ready. output is OFF.

PERR - Parallel Error. SO - Shut OFF (Daisy In).
Set to "1" when an error occurs in Set to "1" when Shut OFF signal is high.
Advanced Parallel system. OVP - Over Voltage Protection.

GERR - General Error. Set to "1" when Over Voltage Protection
Unrecoverable system fault. Recycle fault occurs.

AC input.

FLD - Foldback.

PACK - Parallel Acknowledge. Set to "1" when Foldback fault occurs.
Acknowledge new parallel system.

OTP - Over Temperature Protection.
Refer to section 5.9. Set to "1" when Over Temperature

UVP - Under Voltage Protection. Protection fault occurs.
Set to "1" when Under Voltage AC - AC.
Protection fault occurs. Set to "1" when AC fault occurs.

ENA - Enable.
Set to "1" when Enable fault occurs.

*/
