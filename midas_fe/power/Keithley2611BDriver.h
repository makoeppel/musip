//****************************************************************************************
//
// Base Driver for the LV power supplies. Use derived class fro TDK or HAMEG or .. supply
//
// F.Wauters - Nov. 2020
//

#ifndef Keithley2611BDriver_H
#define Keithley2611BDriver_H

#include "PowerDriver.h"

class Keithley2611BDriver : public PowerDriver {

public:
    Keithley2611BDriver();
    Keithley2611BDriver(std::string n, EQUIPMENT_INFO* inf);
    ~Keithley2611BDriver();

    INT ConnectODB() override;
    INT Init() override;
    INT ReadAll() override;

    std::string GenerateCommand(COMMAND_TYPE cmdt, float val) override;
    std::string GenerateCommand(COMMAND_TYPE cmdt, int ch, float val) override;

    std::string getDriverName() override {
        return "Keithley2611B";
    }

private:
    void InitODBArray();
    bool AskPermissionToTurnOn(int) override;
    std::string idCode;
    std::string ip;

    //watch
    void ReadESRChanged() override;
};

#endif
