//****************************************************************************************
//
// Base Driver for the LV power supplies. Use derived class fro TDK or HAMEG or .. supply
//
// F.Wauters - Nov. 2020
//

#ifndef Keithley2612ADriver_H
#define Keithley2612ADriver_H

#include "PowerDriver.h"

class Keithley2612ADriver : public PowerDriver {

public:

    Keithley2612ADriver();
    Keithley2612ADriver(std::string n, EQUIPMENT_INFO* inf);
    ~Keithley2612ADriver();

    INT ConnectODB() override;
    INT Init() override;
    INT ReadAll() override;

    std::string GenerateCommand(COMMAND_TYPE cmdt, float val) override;
    std::string GenerateCommand(COMMAND_TYPE cmdt, int ch, float val) override;

    std::string getDriverName () override {return "Keithley2612A";}

private:

    void InitODBArray();
    bool AskPermissionToTurnOn(int) override;
    std::string idCode;
    std::string ip;

    int ch;

    //watch
    void ReadESRChanged() override;

};

#endif
