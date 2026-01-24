//****************************************************************************************
//
// Base Driver for the LV power supplies. Use derived class for TDK or HAMEG or .. supply
//
// F.Wauters - Nov. 2020
//

#ifndef POWERDRIVER_H
#define POWERDRIVER_H

#include "BaseClient.h"
#include "SerialClient.h"
#include "TCPClient.h"

#include "midas.h"
#include "odbxx.h"

#include <atomic>
#include <iostream>
#include <mutex>
#include <thread>

enum COMMAND_TYPE {
    SetVoltage,
    SetCurrent,
    Reset,
    Beep,
    CLearStatus,
    SelectChannel,
    ReadErrorQueue,
    ReadVoltage,
    ReadSetVoltage,
    ReadSetCurrent,
    ReadCurrent,
    ReadCurrentLimit,
    SetCurrentLimit,
    SetState,
    SelectChannelAndSetVoltage,
    SelectChannelAndSetCurrent,


    ReadESR,
    OPC,
    ReadQCGE,
    ReadState,
    ReadOVPLevel,
    SetOVPLevel,
    ReadSourceMode,
    SourceCurrent,
    SourceVoltage,
    SetCurrentAsRead,
    SetVoltageAsRead,
    ON,
    OFF,
    ClearBuffer,
    SetCurrentRange,
    SetVoltageRange,
    SetVoltageLimit,
    ReadVoltageLimit,
    CurrHighCapacitanceOn,
    VoltHighCapacitanceOn

    //TODO Complete with full list of action commands
};

class PowerDriver {
public:
    virtual ~PowerDriver();

    std::vector<bool> GetState() const {
        return state;
    }
    std::vector<float> GetVoltage() const {
        return voltage;
    }
    std::vector<float> GetCurrent() const {
        return current;
    }
    virtual std::string ReadIDCode(int, INT&);
    std::vector<std::string> ReadErrorQueue(int, INT&);
    std::string GetName() {
        return name;
    }

    INT Connect();
    INT GetReadStatus() {
        return readstatus;
    }

    void ReadLoop();
    void StartReading() {
        read = 1;
        readonlythisindex = -1;
    }
    void Print();
    void SetInitialized() {
        initialized = true;
    }
    void UnsetInitialized() {
        initialized = false;
    }
    void AddReadFault() {
        n_read_faults = n_read_faults + 1;
    }
    void ResetNReadFaults() {
        n_read_faults = 0;
    }

    bool Initialized() const {
        return initialized;
    }
    bool Enabled();
    bool ReadState(int, INT&);

    float ReadVoltage(int, INT&);
    float ReadCurrent(int, INT&);

    int ReadESR(int, INT&);
    bool ClearBuffer();
    int GetNReadFaults() {
        return n_read_faults;
    }

    WORD ReadQCGE(int, INT&);
    EQUIPMENT_INFO GetInfo() {
        return *info;
    } //by value, so you cant modify the original

    virtual INT ConnectODB();
    virtual INT Init() {
        return FE_ERR_DRIVER;
    };
    virtual INT ReadAll() {
        return FE_ERR_DRIVER;
    }
    virtual void ReadESRChanged() {};
    virtual bool AskPermissionToTurnOn(int) {
        std::cout << "Ask permissions in derived class!" << std::endl;
        return false;
    };

    virtual std::string getDriverName() {
        return "PowerDriver";
    }

protected:
    PowerDriver();
    PowerDriver(std::string, EQUIPMENT_INFO*);

    EQUIPMENT_INFO* info;
    std::string name;
    midas::odb settings;
    midas::odb variables;

    BaseClient* client;

    int n_read_faults;

    float relevantchange;


    //local copies of hardware state
    std::vector<bool> state;
    std::vector<float> voltage;
    std::vector<float> temperature;
    std::vector<float> demandvoltage;
    std::vector<float> demandcurrent;
    std::vector<float> current;
    std::vector<float> currentlimit;

    std::vector<float> OVPlevel;
    std::vector<std::string> SourceMode;
    std::vector<int> instrumentID;

    std::mutex power_mutex;
    std::thread readthread;

    std::atomic<int> read;
    std::atomic<int> stop;
    std::atomic<INT> readstatus;
    std::atomic<int> readonlythisindex;

    //read
    float Read(std::string,INT&);
    float ReadSetVoltage(int,INT&);
    float ReadSetCurrent(int,INT&);
    float ReadCurrentLimit(int,INT&);
    float ReadOVPLevel(int,INT&);
    std::string ReadSourceMode(int,INT&);
    //set
    bool SelectChannel(int);
    bool OPC();
    bool Set(std::string,INT&);
    void SetCurrentLimit(int,float,INT&);

    //watch
    void CurrentLimitChanged();
    void SetStateChanged();
    void SetState(int,bool,INT&);
    void SetVoltage(int,float,INT&);
    void SetCurrent(int,float,INT&);
    void DemandVoltageChanged();
    void DemandCurrentChanged();

    void DemandOVPLevelChanged();
    void SourceModeChanged();
    void SetOVPLevel(int,float,INT&);
    void SourceCurrent(int,INT&);
    void SourceVoltage(int,INT&);
    virtual std::string GenerateCommand(COMMAND_TYPE, float);
    virtual std::string GenerateCommand(COMMAND_TYPE, int, float);

private:
    bool initialized = false;
    int min_reply_length;
};

#endif
