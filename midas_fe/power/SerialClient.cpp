#include "SerialClient.h"
#include <iostream>
#include <chrono>
#include <thread>
#include "midas.h"
#include <boost/asio.hpp>


SerialClient::SerialClient(std::string P, int B, int C,std::string PT,float SB,int to,std::string fc) :
  BaseClient(to),
  USB_PORT(P)
{
    baudrate = B;
    character_size = C;
    parity = PT;
    stop_bits = SB;
    port = new boost::asio::serial_port(io_context, USB_PORT.c_str());
    flow_ctrl = fc;
}

bool SerialClient::Connect()
{
    boost::system::error_code ec;
    port->set_option(boost::asio::serial_port_base::baud_rate(baudrate));
    port->set_option(boost::asio::serial_port_base::parity(convert_parity()));
    port->set_option(boost::asio::serial_port_base::character_size(character_size));
    port->set_option(boost::asio::serial_port_base::stop_bits(convert_stop_bits()));
    port->set_option(boost::asio::serial_port_base::flow_control(convert_flow_control()));
    if (ec) {
        std::cout << " connection to port failed with err:" << ec << std::endl;
    }
    return true;
}

SerialClient::~SerialClient()
{
    port->close();
}

bool SerialClient::Write(std::string str)
{
    boost::system::error_code ec;
    boost::asio::write(*port, boost::asio::buffer(str), ec);

    if( !ec )
    {

    }
    else
    {
        std::cout << "send failed: " << ec.message() << std::endl;
        return false;
    }

    return true;
}

//bool TCPClient::FlushQueu()
//{
//    boost::system::error_code error;
//    std::size_t data_size;
//    char data[1024];
//    data_size = socket->available(error);
//    if(error) { std::cout << " size request failed " << std::endl; return false; }
//    while( int(data_size) > 0)
//    {
//        socket->read_some(boost::asio::buffer(data), error);
//        if(error) { std::cout << " size request failed " << std::endl; return false; }
//        data_size = socket->available(error);
//        if(error) { std::cout << " size request failed " << std::endl; return false; }
//    }
//    return true;
//}

bool SerialClient::ReadReply(std::string* str, size_t min_size) {
    boost::system::error_code ec;
    const int bufferSize = 1024;
    char readBuffer[bufferSize];
    std::size_t bytesRead = 0;
    auto start = std::chrono::system_clock::now();
    int time_elapsed = 0;

    while(time_elapsed < read_time_out && bytesRead < min_size) {
        bytesRead = port->read_some(boost::asio::buffer(readBuffer, bufferSize), ec);
        if(ec) std::cout << " size request failed " << std::endl;
        std::this_thread::sleep_for(std::chrono::milliseconds(default_wait));
        auto end = std::chrono::system_clock::now();
        time_elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    }
    //waiting for valid data failed
    if(bytesRead < min_size || time_elapsed > read_time_out) {
        *str = "";
        return false;
    }
    std::string data(readBuffer, bytesRead);
    data.erase(std::remove(data.begin(), data.end(), '\n'), data.end());
    data.erase(std::remove(data.begin(), data.end(), '\r'), data.end()); //don`t get why there is a /r in the reply string FW
    *str = data;
    return true;
}

boost::asio::serial_port_base::parity::type SerialClient::convert_parity() {
  if (parity == "None")
    return boost::asio::serial_port_base::parity::none;
  else if (parity == "Odd")
    return boost::asio::serial_port_base::parity::odd;
  else if (parity == "Even")
    return boost::asio::serial_port_base::parity::even;
  else {
    cm_msg(MINFO,"power_fe","Serial parity %s not recognized, setting it to none",parity.c_str());
    return  boost::asio::serial_port_base::parity::none;
  }
}


boost::asio::serial_port_base::flow_control::type SerialClient::convert_flow_control() {
  if (flow_ctrl == "None")
    return boost::asio::serial_port_base::flow_control::none;
  else if (flow_ctrl == "Software")
    return boost::asio::serial_port_base::flow_control::software;
  else if (flow_ctrl == "Hardware")
    return boost::asio::serial_port_base::flow_control::hardware;
  else {
    cm_msg(MINFO,"power_fe","Serial flow_control %s not recognized, setting it to none",flow_ctrl.c_str());
    return  boost::asio::serial_port_base::flow_control::none;
  }
}


boost::asio::serial_port_base::stop_bits::type SerialClient::convert_stop_bits() {
  if (stop_bits == 1.0)
    return boost::asio::serial_port_base::stop_bits::one;
  else if (stop_bits == 1.5)
    return boost::asio::serial_port_base::stop_bits::onepointfive;
  else if (stop_bits == 2.0)
    return boost::asio::serial_port_base::stop_bits::two;
  else {
    cm_msg(MINFO,"power_fe","Serial stop bit %f not recognized, setting it to one",stop_bits);
    return  boost::asio::serial_port_base::stop_bits::one;
  }
}
