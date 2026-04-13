//****************************************************************************************
//
// Base Driver for the LV power supplies. Use derived class fro TDK or HAMEG or .. supply
//
// F.Wauters - Nov. 2020
//

#ifndef Keithley2400Driver_H
#define Keithley2400Driver_H

#include "PowerDriver.h"

class Keithley2400Driver : public PowerDriver {
   public:
    Keithley2400Driver();
    Keithley2400Driver(std::string n, EQUIPMENT_INFO* inf);
    ~Keithley2400Driver();

    INT ConnectODB() override;
    INT Init() override;
    INT ReadAll() override;

    std::string GenerateCommand(COMMAND_TYPE cmdt, float val) override;
    std::string ReadIDCode(int, INT&) override;
    std::string GenerateCommand(COMMAND_TYPE cmdt, int ch, float val) override;

    std::string getDriverName() override { return "Keithley2400"; }

   private:
    void InitODBArray();
    bool AskPermissionToTurnOn(int) override;
    std::string idCode;
    std::string usb;

    // watch
    void ReadESRChanged() override;
};

#endif
