#ifndef SERIAL_CLIENT_H
#define SERIAL_CLIENT_H

#include "BaseClient.h"

#include <boost/asio.hpp>
#include <boost/system/error_code.hpp>

class SerialClient : public BaseClient {

public:
    SerialClient(
        std::string USB_PORT,
        int baudrate,
        int character_size = 8,
        std::string parity = "None",
        float stop_bits = 1,
        int to = 100,
        std::string flow_ctrl = "None"
    );
    // SerialClient(std::string port, int baudrate, int character_size=8,std::string parity="None",int stop_bits=1);
    ~SerialClient();
    bool Connect() override;
    bool Write(std::string str) override;
    bool ReadReply(std::string* str, size_t min_size = 3) override;
    bool FlushQueu();
    int GetWaitTime() override {
        return default_wait;
    }
    void SetDefaultWaitTime(int value) override {
        default_wait = value;
    }

private:
    boost::asio::io_context io_context;
    boost::asio::serial_port* port;
    //boost::asio::serial_port serial;
    //ip::tcp::socket* socket;

    boost::asio::serial_port_base::parity::type convert_parity();
    boost::asio::serial_port_base::flow_control::type convert_flow_control();
    boost::asio::serial_port_base::stop_bits::type convert_stop_bits();

    std::string USB_PORT;
    int baudrate;
    int character_size;
    std::string parity;
    std::string flow_ctrl;
    float stop_bits;
};

#endif
