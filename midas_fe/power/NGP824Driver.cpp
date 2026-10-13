#include "NGP824Driver.h"

#include <thread>

NGP824Driver::NGP824Driver() {}

NGP824Driver::~NGP824Driver() {}

NGP824Driver::NGP824Driver(std::string n, EQUIPMENT_INFO* inf) : PowerDriver(n, inf) {
	std::cout << " NGP824 driver with " << instrumentID.size() << " channels instantiated "
			  << std::endl;
}

INT NGP824Driver::ConnectODB() {
	InitODBArray();
	PowerDriver::ConnectODB();
	settings["port"](5025);
	settings["reply timout"](300);
	settings["min reply"](2);
	settings["ESR"](0);
	settings["Max Voltage"](32);
	if (false)
		return FE_ERR_ODB;
	return FE_SUCCESS;
}

void NGP824Driver::InitODBArray() {
	midas::odb settings_array = {{"Channel Names", std::array<std::string, 4>()}};
	settings_array.connect("/Equipment/" + name + "/Settings");
}

INT NGP824Driver::Init() {
	ip = settings["IP"];
	std::cout << "Call init on " << ip << std::endl;
	std::string cmd = "";
	INT err;

	client->SetDefaultWaitTime(50);

	if (settings["Global Reset On FE Start"] == true) {
		cmd = GenerateCommand(COMMAND_TYPE::Reset, 0);
		if (!client->Write(cmd))
			cm_msg(MERROR, "Init NGP824 supply ... ", "could not global reset %s", ip.c_str());
		else
			cm_msg(MINFO, "power_fe", "Init global reset of %s", ip.c_str());
	}
	std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

	cmd = GenerateCommand(COMMAND_TYPE::Beep, 0);
	if (!client->Write(cmd))
		cm_msg(MERROR, "Init NGP824 supply ... ", "could not beep %s", ip.c_str());
	std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

	std::vector<std::string> error_queue = ReadErrorQueue(-1, err);
	for (auto& s : error_queue) {
		if (s.substr(0, 1) != "0") {
			cm_msg(MERROR, "power_fe", " Error from NGP824 supply : %s", s.c_str());
		}
	}

	instrumentID = {1, 2, 3, 4};
	int nChannels = instrumentID.size();
	settings["NChannels"] = nChannels;

	voltage.resize(nChannels);
	demandvoltage.resize(nChannels);
	current.resize(nChannels);
	currentlimit.resize(nChannels);
	state.resize(nChannels);
	OVPlevel.resize(nChannels);

	idCode = ReadIDCode(-1, err);

	std::cout << "ID code: " << idCode << std::endl;

	for (int i = 0; i < nChannels; i++) {
		state[i] = ReadState(i, err);
		voltage[i] = ReadVoltage(i, err);
		demandvoltage[i] = ReadSetVoltage(i, err);
		current[i] = ReadCurrent(i, err);
		currentlimit[i] = ReadCurrentLimit(i, err);
		OVPlevel[i] = ReadOVPLevel(i, err);

		if (err != FE_SUCCESS)
			return err;
	}

	settings["Identification Code"] = idCode;
	settings["ESR"] = ReadESR(-1, err);
	settings["Read ESR"] = false;

	variables["State"] = state;
	variables["Set State"] = state;

	variables["Voltage"] = voltage;
	variables["Demand Voltage"] = demandvoltage;

	variables["Current"] = current;
	variables["Current Limit"] = currentlimit;

	variables["OVP Level"] = OVPlevel;
	variables["Demand OVP Level"] = OVPlevel;

	variables["Current Limit"].watch(
		[&](midas::odb& arg [[maybe_unused]]) { this->CurrentLimitChanged(); });
	variables["Set State"].watch(
		[&](midas::odb& arg [[maybe_unused]]) { this->SetStateChanged(); });
	variables["Demand Voltage"].watch(
		[&](midas::odb& arg [[maybe_unused]]) { this->DemandVoltageChanged(); });
	variables["Demand OVP Level"].watch(
		[&](midas::odb& arg [[maybe_unused]]) { this->DemandOVPLevelChanged(); });

	settings["Read ESR"].watch([&](midas::odb& arg [[maybe_unused]]) { this->ReadESRChanged(); });

	return FE_SUCCESS;
}

bool NGP824Driver::AskPermissionToTurnOn(int) {
	return true;
}

INT NGP824Driver::ReadAll() {
	INT err;
	INT err_accumulated;
	int nChannels = instrumentID.size();

	for (int i = 0; i < nChannels; i++) {
		if (readonlythisindex >= 0 && i != readonlythisindex) {
			continue;
		}

		bool bvalue = ReadState(i, err);
		err_accumulated = err;
		if (state[i] != bvalue) {
			state[i] = bvalue;
			variables["State"][i] = bvalue;
		}

		float fvalue = ReadVoltage(i, err);
		err_accumulated = err_accumulated | err;
		if (fabs(voltage[i] - fvalue) > fabs(relevantchange * voltage[i])) {
			voltage[i] = fvalue;
			variables["Voltage"][i] = fvalue;
		}

		fvalue = ReadCurrent(i, err);
		err_accumulated = err_accumulated | err;
		if (fabs(current[i] - fvalue) > fabs(relevantchange * current[i])) {
			current[i] = fvalue;
			variables["Current"][i] = fvalue;
		}

		fvalue = ReadOVPLevel(i, err);
		err_accumulated = err_accumulated | err;
		if (fabs(OVPlevel[i] - fvalue) > fabs(relevantchange * OVPlevel[i])) {
			OVPlevel[i] = fvalue;
			variables["OVP Level"][i] = fvalue;
		}

		if (err_accumulated != FE_SUCCESS)
			return err_accumulated & 0xFFFE;
	}

	std::vector<std::string> error_queue = ReadErrorQueue(-1, err);
	for (auto& s : error_queue) {
		if (s.substr(0, 1) != "0") {
			cm_msg(MERROR, "power_fe", " Error from NGP824 supply : %s", s.c_str());
		}
	}

	return FE_SUCCESS;
}

void NGP824Driver::ReadESRChanged() {
	INT err;
	bool value = settings["Read ESR"];
	if (value) {
		settings["ESR"] = ReadESR(-1, err);
		settings["Read ESR"] = false;
	}
}

std::string NGP824Driver::GenerateCommand(COMMAND_TYPE cmdt, float val) {
	if (cmdt == COMMAND_TYPE::SetCurrent) {
		return "CURR " + std::to_string(val) + "\n";
	} else if (cmdt == COMMAND_TYPE::Reset) {
		return "*RST\n";
	} else if (cmdt == COMMAND_TYPE::Beep) {
		return "SYST:BEEP\n";
	} else if (cmdt == COMMAND_TYPE::CLearStatus) {
		return "*CLS\n";
	} else if (cmdt == COMMAND_TYPE::SelectChannel) {
		int ch = (int)val;
		return "INST:NSEL " + std::to_string(ch) + "\n";
	} else if (cmdt == COMMAND_TYPE::OPC) {
		return "*OPC?\n";
	} else if (cmdt == COMMAND_TYPE::ReadErrorQueue) {
		return "SYST:ERR?\n";
	} else if (cmdt == COMMAND_TYPE::ReadESR) {
		return "*ESR?\n";
	} else if (cmdt == COMMAND_TYPE::ReadQCGE) {
		return "STAT:QUES?\n";
	} else if (cmdt == COMMAND_TYPE::ReadState) {
		return "OUTP:STAT?\n";
	} else if (cmdt == COMMAND_TYPE::ReadVoltage) {
		return "MEAS:VOLT?\n";
	} else if (cmdt == COMMAND_TYPE::ReadSetVoltage) {
		return "VOLT?\n";
	} else if (cmdt == COMMAND_TYPE::ReadCurrent) {
		return "MEAS:CURR?\n";
	} else if (cmdt == COMMAND_TYPE::ReadCurrentLimit) {
		return "CURR?\n";
	} else if (cmdt == COMMAND_TYPE::ReadOVPLevel) {
		return "VOLT:PROT:LEV?\n";
	} else if (cmdt == COMMAND_TYPE::SetState) {
		int ch = (int)val;
		return "OUTP:STAT " + std::to_string(ch) + "\n";
	} else if (cmdt == COMMAND_TYPE::SetVoltage) {
		return "VOLT " + std::to_string(val) + "\n";
	} else if (cmdt == COMMAND_TYPE::SetOVPLevel) {
		return "VOLT:PROT:LEV " + std::to_string(val) + "\n";
	}

	return "";
}

std::string NGP824Driver::GenerateCommand(COMMAND_TYPE cmdt, int ch, float val) {
	if (cmdt == COMMAND_TYPE::SelectChannelAndSetVoltage) {
		return "INST:NSEL " + std::to_string(ch) + "\nVOLT " + std::to_string(val) + "\n";
	} else {
		std::cout << "This function is usable only with SelectChannelAndSetVoltage!\n";
		return "";
	}
}
