//****************************************************************************************
//
// Base Driver for the LV power supplies. Use derived class fro TDK or HAMEG or .. supply
//
// F.Wauters - Nov. 2020
//

#ifndef Keithley6487Driver_H
#define Keithley6487Driver_H

#include "PowerDriver.h"

class Keithley6487Driver : public PowerDriver {
   public:
    Keithley6487Driver();
    Keithley6487Driver(std::string n, EQUIPMENT_INFO* inf);
    ~Keithley6487Driver();

    INT ConnectODB() override;
    INT Init() override;
    INT ReadAll() override;

    std::string GenerateCommand(COMMAND_TYPE cmdt, float val) override;
    std::string ReadIDCode(int, INT&) override;
    std::string GenerateCommand(COMMAND_TYPE cmdt, int ch, float val) override;

    std::string getDriverName() override { return "Keithley6487"; }

   private:
    void InitODBArray();
    bool AskPermissionToTurnOn(int) override;
    std::string idCode;
    std::string usb;
    std::string command_type;

    // Watch
    void ReadESRChanged() override;
};

#endif
