//****************************************************************************************
//
// Driver for the Genesys LV power supplies. Not compatible with EQ_SLOW, use EQ_PERIODIC
//
// F.Wauters - Sep. 2020
//

#ifndef GENESYSDRIVER_H
#define GENESYSDRIVER_H

#include "PowerDriver.h"

/*SCPI Protocol for TDK
Recommended time delay between commands: 5mSec minimum. Some commands might require
longer time. In such cases, refer to NOTE following command description.
*/

// void my_settings_changed(midas::odb);

class GenesysDriver : public PowerDriver {
   public:
    GenesysDriver(std::string n, EQUIPMENT_INFO* inf);
    ~GenesysDriver();

    INT ConnectODB() override;
    INT Init() override;
    INT ReadAll() override;

    std::string getDriverName() override { return "Genesys"; }

   private:
    // utility/communications functions
    bool SetActiveChannel(int);
    void SetBlink(int, bool, INT&);
    void SetInterlock(int, bool, INT&);
    bool AskPermissionToTurnOn(int) override;
    void ReadESRChanged() override;

    void BlinkChanged();
    void InitODBArray();

    std::vector<bool> InterlockStatus(std::vector<WORD>);

    int reply_time_out;

    // local copy of hardware settings

    std::vector<std::string> idCode;
    std::vector<bool> interlock_enabled;
    std::vector<WORD> QCGEreg;
};

#endif
