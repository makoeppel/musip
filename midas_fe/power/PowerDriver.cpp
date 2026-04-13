#include "PowerDriver.h"

#include <boost/lexical_cast.hpp>
#include <sstream>
#include <thread>

PowerDriver::PowerDriver() {}

PowerDriver::PowerDriver(std::string n, EQUIPMENT_INFO* inf)
    : info{inf}, name{n}, n_read_faults(0), read{0}, stop{0}, readstatus(FE_ERR_DISABLED) {}

PowerDriver::~PowerDriver() {
    stop = 1;
    if (readthread.joinable()) {
        readthread.join();
    }
}

INT PowerDriver::ConnectODB() {
    settings.connect("/Equipment/" + name + "/Settings");
    // General settings
    settings["IP"]("10.10.10.10");
    settings["Use Hostname"](false);
    settings["Hostname"]("");
    settings["NChannels"](2);
    settings["Global Reset On FE Start"](false);
    settings["Read ESR"](false);
    settings["Connection Type"]("Tcp");
    settings["Command Type"]("SCPI");
    settings["USB_PORT"]("/dev/ttyUSB0");
    settings["Baudrate"](19200);
    settings["Character size"](8);
    settings["Parity"]("None");
    settings["Stop Bits"](1.0);
    settings["Flow Control"]("Software");
    settings["DriverName"]("");

    // Variables
    variables.connect("/Equipment/" + name + "/Variables");
    // decimal places to check
    relevantchange = 0.001;  // only take action when values change more than this value

    return FE_SUCCESS;
}

INT PowerDriver::Connect() {
    std::string conn_type(settings["Connection Type"]);
    std::cout << "Connection type: " << conn_type << std::endl;

    if (conn_type == "Tcp") {
        std::string hostname("");
        if (settings["Use Hostname"]) {
            hostname = settings["Hostname"];
            // make a hostname from the eq name
            if (hostname.length() < 2) {
                hostname = name;
                std::transform(hostname.begin(), hostname.end(), hostname.begin(),
                               [](unsigned char c) { return std::tolower(c); });
                settings["Hostname"] = hostname;
                std::cout << "Set hostname key as " << settings["Hostnafme"] << std::endl;
            }
        }
        client =
            new TCPClient(settings["IP"], settings["port"], settings["reply timout"], hostname);
    } else if (conn_type == "Serial") {
        std::string usbp(settings["USB_PORT"]);
        std::string parit(settings["Parity"]);
        std::string flw_ctrl(settings["Flow Control"]);
        std::cout << "USB port = " << usbp << ", Parity = " << parit << std::endl;
        client = new SerialClient(usbp, settings["Baudrate"], settings["Character size"], parit,
                                  settings["Stop Bits"], 2000, flw_ctrl);
    } else {
        cm_msg(MINFO, "power_fe", "Please specify the Connection type!");
    }
    ss_sleep(100);
    std::string ip(settings["IP"]);
    min_reply_length = settings["min reply"];

    if (!client->Connect()) {
        cm_msg(MERROR, "Connect to power supply ... ", "could not connect to %s.", ip.c_str());
        return FE_ERR_HW;
    } else {
        cm_msg(MINFO, "power_fe", "Init Connection to %s alive.", ip.c_str());
    }

    // Also start the read thread here
    readthread = std::thread(&PowerDriver::ReadLoop, this);

    return FE_SUCCESS;
}

void PowerDriver::ReadLoop() {
    while (!stop) {
        if (read) {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            // cm_msg(MINFO, "Power Fe ... ", "Call Read All ... ");
            readstatus = ReadAll();
            read = 0;
        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }

        if (readonlythisindex >= 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            // cm_msg(MINFO, "Power Fe ... ", "Call Read All ... ");
            readstatus = ReadAll();
            readonlythisindex = -1;
        }
    }
}

bool PowerDriver::Enabled() {
    midas::odb common("/Equipment/" + name + "/Common");

    return common["Enabled"];
}

bool PowerDriver::SelectChannel(int ch) {
    std::string cmd(GenerateCommand(COMMAND_TYPE::SelectChannel, ch));

    if (cmd.empty()) {
        return true;
    }
    client->Write(cmd);
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    if (OPC()) {
        return true;
    } else {
        cm_msg(MERROR, "power_fe", "Not able to select channel %d.", ch);
        return false;
    }
}

bool PowerDriver::ClearBuffer() {
    std::string cmd(GenerateCommand(COMMAND_TYPE::ClearBuffer, 0));

    if (cmd.empty()) {
        return true;
    }
    client->Write(cmd);
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    // This is what I assume should be a placeholder
    bool success(true);
    if (success) {
        return true;
    } else {
        cm_msg(MERROR, "power_fe", "Not able to clear the buffer %d.", 0);
        return false;
    }
}

bool PowerDriver::OPC() {
    client->Write(GenerateCommand(COMMAND_TYPE::OPC, 0));
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
    std::string reply;

    return client->ReadReply(&reply, min_reply_length);
}

void PowerDriver::Print() {
    std::cout << "ODB settings: " << std::endl << settings.print() << std::endl;
    std::cout << "ODB variables: " << std::endl << variables.print() << std::endl;
}

/******/
// **************** Read functions *************** //
/******/

float PowerDriver::Read(std::string cmd, INT& error) {
    error = FE_SUCCESS;

    std::string classname(getDriverName());
    client->Write(cmd);
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    float value = 0;
    std::string reply("");
    if (!client->ReadReply(&reply, min_reply_length)) {
        cm_msg(MERROR, "Power supply read ... ", "could not read after command %s.", cmd.c_str());
        error = FE_ERR_DRIVER;
    }

    try {
        if (reply.empty()) {
            cm_msg(MERROR, "Power supply read...", "no reply is given as a result of command %s.",
                   cmd.c_str());
            error = FE_ERR_DRIVER;
        } else if (reply.find("smu") != std::string::npos) {
            reply = reply.substr(12, 14);
            value = std::stof(reply);
        } else if ((reply.find_first_of("eE") != std::string::npos) ||
                   (classname.find("Keithley") != std::string::npos)) {
            if (reply.size() > 0 && (reply[0] == '+' || reply[0] == '-')) {
                reply = reply.substr(1, 14);
            } else {
                if (classname == "Keithley2400") {
                    reply = reply.substr(1, 14);  // WHY??
                } else {
                    reply = reply.substr(0, 14);
                }
            }
            if (reply.find("E") != std::string::npos)
                reply.replace(reply.find("E"), 1, "e");
            std::istringstream os(reply);
            os >> value;
            if (os.fail())
                std::cout << "Failed to convert " << reply << " into a number\n";
        } else {
            value = std::stof(reply);
        }
    } catch (const std::exception& e) {
        cm_msg(MERROR, "Power supply read...", "could not convert to float %s (%s).", reply.c_str(),
               e.what());
        error = FE_ERR_DRIVER;
    }

    return value;
}

std::string PowerDriver::ReadIDCode(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_SUCCESS;

    if (index >= 0) {
        SelectChannel(instrumentID[index]);
    }
    client->Write("*IDN?\n");
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    std::string reply("");
    if (!client->ReadReply(&reply, min_reply_length)) {
        cm_msg(MERROR, "Power supply read ... ", "could not read id supply with address %d.",
               instrumentID[index]);
        error = FE_ERR_DRIVER;
    }

    return reply;
}

std::vector<std::string> PowerDriver::ReadErrorQueue(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_SUCCESS;

    if (index >= 0) {
        SelectChannel(instrumentID[index]);
    }
    std::vector<std::string> error_queue;

    std::string cmd("");
    std::string classname(getDriverName());
    while (1) {
        cmd = GenerateCommand(COMMAND_TYPE::ReadErrorQueue, 0);
        if (cmd.empty() && (classname.find("Keithley") != std::string::npos)) {
            break;
        }

        client->Write(cmd);
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
        std::string reply("");
        if (!client->ReadReply(&reply, min_reply_length)) {
            if (index >= 0) {
                cm_msg(MERROR, "Power supply read ... ",
                       "could not read error supply with address %d.", instrumentID[index]);
            } else {
                cm_msg(MERROR, "Power supply read ... ", "could not read error supply.");
            }
            error = FE_ERR_DRIVER;
        }
        error_queue.push_back(reply);

        if (reply.substr(0, 1) == "0" || reply.find("Queue Is Empty") != std::string::npos ||
            reply.find("No error") != std::string::npos) {
            break;
        }
    }

    return error_queue;
}

int PowerDriver::ReadESR(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_SUCCESS;

    if (index >= 0) {
        SelectChannel(instrumentID[index]);
    }

    client->Write(GenerateCommand(COMMAND_TYPE::ReadESR, 0));
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    std::string reply("");
    if (!client->ReadReply(&reply, min_reply_length)) {
        cm_msg(MERROR, "Power supply read ... ", "could not read ESR supply with address %d",
               instrumentID[index]);
        error = FE_ERR_DRIVER;
    }

    int value = 0;
    std::string classname(getDriverName());
    if (classname == "Keithley2400" || classname == "Keithley6487") {
        std::istringstream os(reply);
        os >> value;
    } else {
        value = std::stoi(reply);
    }

    return value;
}

WORD PowerDriver::ReadQCGE(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_SUCCESS;

    if (index >= 0) {
        SelectChannel(instrumentID[index]);
    }

    client->Write(GenerateCommand(COMMAND_TYPE::ReadQCGE, 0));
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    std::string reply("");
    if (!client->ReadReply(&reply, min_reply_length)) {
        cm_msg(MERROR, "Power supply read ... ", "could not read QCGE supply with address %d",
               instrumentID[index]);
        error = FE_ERR_DRIVER;
    }

    return WORD(std::stoi(reply));
}

bool PowerDriver::ReadState(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_SUCCESS;

    if (index >= 0) {
        SelectChannel(instrumentID[index]);
    }

    client->Write(GenerateCommand(COMMAND_TYPE::ReadState, 0));
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    std::string reply("");
    if (!client->ReadReply(&reply, min_reply_length)) {
        cm_msg(MERROR, "Power supply read ... ", "could not read off %s state supply/channel: %d.",
               name.c_str(), instrumentID[index]);
        error = FE_ERR_DRIVER;
    }

    return (reply.find("1") != std::string::npos) || (reply.find("ON") != std::string::npos);
}

std::string PowerDriver::ReadSourceMode(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_SUCCESS;

    if (index >= 0) {
        SelectChannel(instrumentID[index]);
    }

    client->Write(GenerateCommand(COMMAND_TYPE::ReadSourceMode, 0));
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    std::string reply("");
    if (!client->ReadReply(&reply, min_reply_length)) {
        cm_msg(MERROR, "Power supply read ... ",
               "could not read off %s source mode supply/channel: %d.", name.c_str(),
               instrumentID[index]);
        error = FE_ERR_DRIVER;
    }
    // Might be wrong of me to comment this out, bring back if causing problems
    // else { return reply; }
    std::cout << "ReadSourceMode : reply = " << reply << std::endl;
    if (reply.find("VOLT") != std::string::npos)
        reply = "VOLT";  // Why???
    return reply;
}

float PowerDriver::ReadVoltage(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_ERR_DRIVER;

    std::string classname(getDriverName());
    if (classname == "Keithley2400" || classname == "Keithley2450") {
        // I guess Keithley2400 do not allow voltage reading while being off :(
        if (state[index]) {
            client->Write(GenerateCommand(COMMAND_TYPE::SetVoltageAsRead, 0));
            error = FE_SUCCESS;
            std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
        }
    }

    float value(0.f);
    std::string cmd(GenerateCommand(COMMAND_TYPE::ReadVoltage, 0));
    if (classname == "Keithley2450") {
        // cmd = GenerateCommand(COMMAND_TYPE::ReadSetVoltage, 0);
        std::string sourceMode(settings["Source Mode"]);
        if (sourceMode == "VOLT") {
            cmd = GenerateCommand(COMMAND_TYPE::ReadSetVoltage, 0);
            Read(cmd, error);
        }
    }
    // if (SelectChannel(instrumentID[index])) {
    //     if (state) {
    //         error = FE_SUCCESS;
    //         value = Read(cmd, error);
    //     }
    // }
    if (SelectChannel(instrumentID[index])) {
        if (state[index]) {
            error = FE_SUCCESS;
            value = Read(GenerateCommand(COMMAND_TYPE::ReadVoltage, 0), error);
        } else {
            error = FE_SUCCESS;
        }
    }

    return value;
}

float PowerDriver::ReadSetVoltage(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_ERR_DRIVER;

    float value(0.f);
    if (SelectChannel(instrumentID[index])) {
        error = FE_SUCCESS;
        value = Read(GenerateCommand(COMMAND_TYPE::ReadSetVoltage, 0), error);
    }

    return value;
}

float PowerDriver::ReadSetCurrent(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_ERR_DRIVER;

    float value(0.f);
    if (SelectChannel(instrumentID[index])) {
        error = FE_SUCCESS;
        value = Read(GenerateCommand(COMMAND_TYPE::ReadSetCurrent, 0), error);
    }

    return value;
}

float PowerDriver::ReadCurrent(int index, INT& error) {
    bool status = 1;
    std::string classname = getDriverName();
    // From here on we grab the mutex until the end of the function: One transaction at a time
    error = FE_SUCCESS;
    const std::lock_guard<std::mutex> lock(power_mutex);
    std::string cmd_set_curr = "";
    if (classname == "Keithley2400" || classname == "Keithley2450") {
        if (variables["State"]) {
            status = 1;
        } else {
            status = 0;
        }
        if (status != 0) {
            cmd_set_curr = GenerateCommand(COMMAND_TYPE::SetCurrentAsRead, 0);
        }
    }
    if (cmd_set_curr != "") {
        client->Write(cmd_set_curr);
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
    }

    float value = 0;
    if (SelectChannel(instrumentID[index]) && status != 0) {
        value = Read(GenerateCommand(COMMAND_TYPE::ReadCurrent, 0), error);
    }

    else if (status == 0) {
        value = 0;
    } else
        error = FE_ERR_DRIVER;
    return value;
}

float PowerDriver::ReadCurrentLimit(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_ERR_DRIVER;

    float value(0.f);
    if (SelectChannel(instrumentID[index])) {
        error = FE_SUCCESS;
        value = Read(GenerateCommand(COMMAND_TYPE::ReadCurrentLimit, 0), error);
    }

    return value;
}

float PowerDriver::ReadOVPLevel(int index, INT& error) {
    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_ERR_DRIVER;

    float value(0.f);
    if (SelectChannel(instrumentID[index])) {
        error = FE_SUCCESS;
        value = Read(GenerateCommand(COMMAND_TYPE::ReadOVPLevel, 0), error);
    }

    return value;
}

/******/
// **************** Set functions *************** //
/******/

bool PowerDriver::Set(std::string cmd, INT& error) {
    client->Write(cmd);
    std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

    if (OPC()) {
        error = FE_SUCCESS;
        return true;
    } else {
        error = FE_ERR_DRIVER;
        cm_msg(MERROR, "Power supply ... ", "command %s not succesful for %s supply", cmd.c_str(),
               name.c_str());
        return false;
    }
}

void PowerDriver::SetCurrentLimit(int index, float value, INT& error) {
    // Have to lock it here (and not in the Set() function), otherwise you might change the wrong
    // channel as a consequence you can not call the Read functions or, you try to lock a second
    // time
    const std::lock_guard<std::mutex> lock(power_mutex);
    error = FE_SUCCESS;

    // Check valid range
    if (value < -0.1 || value > 90.0) {
        cm_msg(MERROR, "Power supply ... ", "current limit of %f not allowed", value);
        variables["Current Limit"][index] = currentlimit[index];  // Disable request
        error = FE_ERR_DRIVER;
        return;
    }

    std::string classname(getDriverName());
    if (SelectChannel(instrumentID[index])) {
        bool success(true);
        if (classname == "Keithley2400" || classname == "Keithley2450" ||
            classname == "Keithley6487") {
            success = Set(GenerateCommand(COMMAND_TYPE::SetCurrentLimit, value), error);
        } else {
            cm_msg(MINFO, "Power ... ",
                   "changing current limit of %s, channel %d requested, command = %d.",
                   name.c_str(), instrumentID[index], COMMAND_TYPE::SetCurrent);
            success = Set(GenerateCommand(COMMAND_TYPE::SetCurrent, value), error);
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));

        if (success) {
            readonlythisindex = index;
            // voltage[index] = ReadVoltage(index,error); // These functions also have a lock_guard,
            // so can not be called directly variables["Voltage"][index] = voltage[index];
        } else {
            error = FE_ERR_DRIVER;
        }
    } else {
        error = FE_ERR_DRIVER;
    }
}

void PowerDriver::SetVoltage(int index, float value, INT& error) {
    error = FE_SUCCESS;
    std::string classname(getDriverName());

    if (classname == "Keithley2450") {
        // cmd = GenerateCommand(COMMAND_TYPE::ReadSetCurrent, 0);
        std::string sourceMode(settings["Source Mode"]);
        if (sourceMode == "CURR") {
            cm_msg(MERROR, "Power supply ... ",
                   "voltage change is not allowed for this device given the source mode.");
            variables["Demand Voltage"][index] = demandvoltage[index];  // Disable request
            error = FE_ERR_DISABLED;
            return;
        }
    }

    // Making sure we do not go over the limits!
    if ((classname.find("Keithley") == std::string::npos)  // not a Keithley
        && (value < -0.1 || value > 25.)) {
        cm_msg(MERROR, "Power supply ... ", "voltage of %f not allowed.", value);
        variables["Demand Voltage"][index] = demandvoltage[index];  // Disable request
        error = FE_ERR_DISABLED;
        return;
    }

    // For some reason making sure that Keithleys cant set the voltage (except the 6487 ofc)
    if ((classname.find("Keithley6487") !=
         std::string::npos)  // a Keithley6487 is a voltage source at UZH
        && (value > 0)
        // && (classname.find("6487") != std::string::npos) // the Keithley6487
    ) {
        cm_msg(MERROR, "Power supply ... ", "voltage of %f not allowed.", value);
        variables["Demand Voltage"][index] = demandvoltage[index];  // Disable request
        error = FE_ERR_DISABLED;
        return;
    }

    // Have to lock it here, otherwise you might change the wrong channel
    // as a consequence you can not call the Read functions or, you try to lock a second time
    const std::lock_guard<std::mutex> lock(power_mutex);

    if (SelectChannel(instrumentID[index])) {  // module address in the daisy chain to select
                                               // channel, or 1/2/3/4 for the HAMEG
        if (Set(GenerateCommand(COMMAND_TYPE::SelectChannelAndSetVoltage, instrumentID[index],
                                value),
                error)) {
            readonlythisindex = index;
            // voltage[index] = ReadVoltage(index, error);
            // variables["Voltage"][index] = voltage[index];
            // current[index] = ReadCurrent(index, error);
            // variables["Current"][index] = current[index];
        } else {
            error = FE_ERR_DRIVER;
        }
    } else {
        error = FE_ERR_DRIVER;
    }
}

void PowerDriver::SetCurrent(int index, float value, INT& error) {
    error = FE_SUCCESS;

    std::string classname(getDriverName());
    if (classname == "Keithley2450") {
        // cmd = GenerateCommand(COMMAND_TYPE::ReadSetCurrent, 0);
        std::string sourceMode(settings["Source Mode"]);
        if (sourceMode == "VOLT") {
            cm_msg(MERROR, "Power supply ... ",
                   "current change is not allowed for this device given the source mode.");
            variables["Demand Current"][index] = demandcurrent[index];  // Disable request
            error = FE_ERR_DISABLED;
            return;
        } else {
            if (value < 0 || value > 1e-3) {
                cm_msg(MERROR, "Power supply ... ", "current of %f not allowed.", value);
                variables["Demand Current"][index] = demandcurrent[index];  // Disable request
                error = FE_ERR_DISABLED;
                return;
            }
        }
    }

    if ((classname.find("Keithley") == std::string::npos)
        // (GenerateCommand(COMMAND_TYPE::SelectChannel, 0)).empty()
        // && (classname.find("Keithley") != std::string::npos) // Now the Keithley2450 is setting
        // current at UZH
    ) {
        cm_msg(MERROR, "Power supply ... ",
               "current change is not allowed for this device, revisit your strategy.");
        variables["Demand Current"][index] = demandcurrent[index];  // Disable request
        error = FE_ERR_DISABLED;
        return;
    }

    // Have to lock it here, otherwise you might change the wrong channel
    // as a consequence you can not call the Read functions or, you try to lock a second time
    const std::lock_guard<std::mutex> lock(power_mutex);

    if (SelectChannel(instrumentID[index])) {  // module address in the daisy chain to select
                                               // channel, or 1/2/3/4 for the HAMEG
        if (Set(GenerateCommand(COMMAND_TYPE::SelectChannelAndSetCurrent, instrumentID[index],
                                value),
                error)) {
            readonlythisindex = index;
            // voltage[index] = ReadVoltage(index, error);
            // variables["Voltage"][index] = voltage[index];
            // current[index] = ReadCurrent(index, error);
            // variables["Current"][index] = current[index];
        } else {
            error = FE_ERR_DRIVER;
        }
    } else {
        error = FE_ERR_DRIVER;
    }
}

void PowerDriver::SetState(int index, bool value, INT& error) {
    error = FE_SUCCESS;

    cm_msg(MINFO, "Power supply ... ", "request to set channel %d to %d", instrumentID[index],
           value);

    if (value && !AskPermissionToTurnOn(index)) {
        cm_msg(MERROR, "Power supply ... ",
               "changing the state of channel %d not allowed, name = %s.", instrumentID[index],
               name.c_str());
        variables["Set State"][index] = false;  // Disable request
        error = FE_ERR_DISABLED;
        return;
    }

    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);

    if (SelectChannel(instrumentID[index])) {
        client->Write(GenerateCommand(COMMAND_TYPE::SetState, value));
        std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
        if (!OPC()) {
            error = FE_ERR_DRIVER;
        }
    } else {
        error = FE_ERR_DRIVER;
    }
}

void PowerDriver::SetOVPLevel(int index, float value, INT& error) {
    error = FE_SUCCESS;

    // Making sure we do not go over the limits!
    if (value < -0.1 || value > 25.) {
        cm_msg(MERROR, "Power supply ... ", "voltage protection level of %f not allowed.", value);
        variables["Demand OVP Level"][index] = OVPlevel[index];  // Disable request
        error = FE_ERR_DISABLED;
        return;
    }

    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(power_mutex);

    if (SelectChannel(instrumentID[index])) {  // module address in the daisy chain to select
                                               // channel, or 1/2/3/4 for the HAMEG
        if (Set(GenerateCommand(COMMAND_TYPE::SetOVPLevel, value), error)) {
            readonlythisindex = index;
            // voltage[index] = ReadVoltage(index,error);
            // variables["Voltage"][index] = voltage[index];
            // current[index] = ReadCurrent(index,error);
            // variables["Current"][index] = current[index];
            // OVPlevel[index] = ReadOVPLevel(index,error);
            // variables["OVP Level"][index] = OVPlevel[index];
        } else {
            error = FE_ERR_DRIVER;
        }
    } else {
        error = FE_ERR_DRIVER;
    }
}

/******/
// **************** Watch functions *************** //
/******/

void PowerDriver::CurrentLimitChanged() {
    INT err;
    int nChannelsChanged(0);
    for (unsigned int i(0); i < currentlimit.size(); i++) {
        float value(variables["Current Limit"][i]);
        if (fabs(value - currentlimit[i]) >
            fabs(relevantchange *
                 currentlimit[i])) {  // Compare to local book keeping, look for significant change
            SetCurrentLimit(i, value, err);
            if (err == FE_SUCCESS) {
                cm_msg(MINFO, "Power supply ... ", "changing %s current limit of channel %d to %f",
                       name.c_str(), instrumentID[i], value);
                nChannelsChanged++;
                currentlimit[i] = value;
            } else {
                variables["Current Limit"][i] = currentlimit[i];  // Set back to local book keeping
                cm_msg(MERROR, "Power supply ... ",
                       "changing %s current limit of channel %d to %f failed, error %d",
                       name.c_str(), instrumentID[i], value, err);
            }
        }
    }
    if (nChannelsChanged < 1) {
        cm_msg(MINFO, "Power supply ... ", "changing current limit request of %s rejected",
               name.c_str());
    }
}

void PowerDriver::SetStateChanged() {
    INT err;
    for (unsigned int i(0); i < state.size(); i++) {
        bool value(variables["Set State"][i]);
        if (value != state[i]) {  // Compare to local book keeping
            SetState(i, value, err);
            if (err == FE_SUCCESS) {
                cm_msg(MINFO, "Power supply ... ", "changing %s state of channel %d to %d",
                       name.c_str(), instrumentID[i], value);
            } else {
                variables["Set State"][i] = state[i];  // Set back to local book keeping
                cm_msg(MERROR, "Power supply ... ",
                       "changing %s state of channel %d to %d failed, error %d", name.c_str(),
                       instrumentID[i], value, err);
            }
        }
    }

    for (size_t i = 0; i < instrumentID.size(); i++) {
        if (err == FE_SUCCESS) {
            state[i] = ReadState(i, err);
        }
    }
    variables["State"] = state;  // Push to odb
}

void PowerDriver::DemandVoltageChanged() {
    INT err;
    int nChannelsChanged(0);
    for (unsigned int i(0); i < demandvoltage.size(); i++) {
        float value(variables["Demand Voltage"][i]);
        if (fabs(value - demandvoltage[i]) >
            fabs(relevantchange *
                 demandvoltage[i])) {  // Compare to local book keeping, look for significant change
            SetVoltage(i, value, err);
            if (err == FE_SUCCESS) {
                cm_msg(MINFO, "Power supply ... ", "changing %s voltage of channel %d to %f",
                       name.c_str(), instrumentID[i], value);
                nChannelsChanged++;
                demandvoltage[i] = value;
            } else {
                variables["Demand Voltage"][i] =
                    demandvoltage[i];  // Set back to local book keeping
                cm_msg(MERROR, "Power supply ... ",
                       "changing %s voltage of channel %d to %f failed, error %d", name.c_str(),
                       instrumentID[i], value, err);
            }
        }
    }
    if (nChannelsChanged < 1) {
        cm_msg(MINFO, "Power supply ... ", "changing voltage request of %s rejected", name.c_str());
    }
}

void PowerDriver::DemandCurrentChanged() {
    INT err;
    int nChannelsChanged(0);
    for (unsigned int i(0); i < demandcurrent.size(); i++) {
        float value(variables["Demand Current"][i]);
        cm_msg(MINFO, "Power supply ... ", "Trying to change %s current of channel %d to %f",
               name.c_str(), instrumentID[i], value);
        if (fabs(value - demandcurrent[i]) >
            fabs(relevantchange *
                 demandcurrent[i])) {  // Compare to local book keeping, look for significant change
            cm_msg(MINFO, "Power supply ... ", "Setting %s current of channel %d to %f",
                   name.c_str(), instrumentID[i], value);
            SetCurrent(i, value, err);
            if (err == FE_SUCCESS) {
                cm_msg(MINFO, "Power supply ... ", "changing %s current of channel %d to %f",
                       name.c_str(), instrumentID[i], value);
                nChannelsChanged++;
                demandcurrent[i] = value;
            } else {
                variables["Demand Current"][i] =
                    demandcurrent[i];  // Set back to local book keeping
                cm_msg(MERROR, "Power supply ... ",
                       "changing %s current of channel %d to %f failed, error %d", name.c_str(),
                       instrumentID[i], value, err);
            }
        }
    }
    if (nChannelsChanged < 1) {
        cm_msg(MINFO, "Power supply ... ", "changing current request of %s rejected", name.c_str());
    }
}

void PowerDriver::DemandOVPLevelChanged() {
    INT err;
    int nChannelsChanged(0);
    for (unsigned int i(0); i < OVPlevel.size(); i++) {
        float value(variables["Demand OVP Level"][i]);
        if (fabs(value - OVPlevel[i]) >
            fabs(relevantchange *
                 OVPlevel[i])) {  // Compare to local book keeping, look for significant change
            SetOVPLevel(i, value, err);
            if (err == FE_SUCCESS) {
                cm_msg(MINFO, "Power supply ... ",
                       "changing %s voltage protection level of channel %d to %f", name.c_str(),
                       instrumentID[i], value);
                nChannelsChanged++;
                OVPlevel[i] = value;
                variables["OVP Level"][i] = value;
            } else {
                variables["Demand OVP Level"][i] = OVPlevel[i];  // Set back to local book keeping
                cm_msg(MERROR, "Power supply ... ",
                       "changing %s voltage protection level of channel %d to %f failed, error %d",
                       name.c_str(), instrumentID[i], value, err);
            }
        }
    }
    if (nChannelsChanged < 1) {
        cm_msg(MINFO, "Power supply ... ",
               "changing voltage protection level request of %s rejected", name.c_str());
    }
}

void PowerDriver::SourceModeChanged() {
    INT err;

    for (unsigned int i = 0; i < SourceMode.size(); i++) {
        std::string cmd_set_volt = "";
        std::string mode = settings["Source Mode"][i];
        // cm_msg(MINFO, "Power ... ", "set state = %d, current state = %d of index = %d, channel =
        // %d ", value,(int)state[i],i,instrumentID[i]);
        if (mode != SourceMode[i])  // compare to local book keeping
        {
            // only works if power supply is off
            bool state = ReadState(i, err);
            if (state == true) {
                SetState(i, 0, err);
                variables["Set State"][i] = false;
                sleep(2);
            }

            if (mode == "VOLT") {
                cmd_set_volt = GenerateCommand(COMMAND_TYPE::SourceVoltage, 0);
            } else if (mode == "CURR") {
                cmd_set_volt = GenerateCommand(COMMAND_TYPE::SourceCurrent, 0);
            }

            if (cmd_set_volt.empty()) {
                cm_msg(MERROR, "Power supply ... ", "Wrong state! Need different information.");
            } else {
                client->Write(cmd_set_volt);
                std::this_thread::sleep_for(std::chrono::milliseconds(client->GetWaitTime()));
                sleep(1);
            }
        }
    }
}

// **************** Flexiblity functions ***************** //
std::string PowerDriver::GenerateCommand(COMMAND_TYPE, float) {
    std::cout << "Warning: empty base class used, no command" << std::endl;
    return "";
}

std::string PowerDriver::GenerateCommand(COMMAND_TYPE, int, float) {
    std::cout << "Warning: empty base class used, no command" << std::endl;
    return "";
}
