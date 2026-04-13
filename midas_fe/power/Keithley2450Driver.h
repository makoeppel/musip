//****************************************************************************************
//
// Base Driver for the LV power supplies. Use derived class fro TDK or HAMEG or .. supply
//
// F.Wauters - Nov. 2020
//

#ifndef Keithley2450Driver_H
#define Keithley2450Driver_H

#include "PowerDriver.h"

class Keithley2450Driver : public PowerDriver {
   public:
    Keithley2450Driver();
    Keithley2450Driver(std::string n, EQUIPMENT_INFO* inf);
    ~Keithley2450Driver();

    INT ConnectODB() override;
    INT Init() override;
    INT ReadAll() override;

    std::string GenerateCommand(COMMAND_TYPE cmdt, float val) override;
    std::string GenerateCommand(COMMAND_TYPE cmdt, int ch, float val) override;

    std::string getDriverName() override { return "Keithley2450"; }

   private:
    void InitODBArray();
    bool AskPermissionToTurnOn(int) override;
    std::string idCode;
    std::string ip;
    std::string command_type;

    // watch
    void ReadESRChanged() override;
};

#endif
