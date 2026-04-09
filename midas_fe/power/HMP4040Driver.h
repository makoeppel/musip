//****************************************************************************************
//
// Base Driver for the LV power supplies. Use derived class fro TDK or HAMEG or .. supply
//
// F.Wauters - Nov. 2020
//

#ifndef HMP4040DRIVER_H
#define HMP4040DRIVER_H

#include "PowerDriver.h"

class HMP4040Driver : public PowerDriver {
   public:
    HMP4040Driver();
    HMP4040Driver(std::string n, EQUIPMENT_INFO* inf);
    ~HMP4040Driver();

    INT ConnectODB() override;
    INT Init() override;
    INT ReadAll() override;

    std::string GenerateCommand(COMMAND_TYPE cmdt, float val) override;
    std::string GenerateCommand(COMMAND_TYPE cmdt, int ch, float val) override;

    std::string getDriverName() override { return "HMP4040"; }

   private:
    std::string idCode;
    std::string ip;
    void InitODBArray();
    bool AskPermissionToTurnOn(int) override;

    // watch
    void ReadESRChanged() override;
};

#endif
