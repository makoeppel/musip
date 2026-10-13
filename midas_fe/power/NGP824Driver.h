//****************************************************************************************
//
// Base Driver for the R&S NGP824 power supplies.
//
// K.Frahm - Apr. 2026
//

#ifndef NGP824DRIVER_H
#define NGP824DRIVER_H

#include "PowerDriver.h"

#include <cmath>

class NGP824Driver : public PowerDriver {
   public:
	NGP824Driver();
	NGP824Driver(std::string n, EQUIPMENT_INFO* inf);
	~NGP824Driver();

	INT ConnectODB() override;
	INT Init() override;
	INT ReadAll() override;

	std::string GenerateCommand(COMMAND_TYPE cmdt, float val) override;
	std::string GenerateCommand(COMMAND_TYPE cmdt, int ch, float val) override;

	std::string getDriverName() override { return "NGP824"; }

   private:
	std::string idCode;
	std::string ip;
	void InitODBArray();
	bool AskPermissionToTurnOn(int) override;

	void ReadESRChanged() override;
};

#endif
