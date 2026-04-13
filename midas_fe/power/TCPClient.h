#ifndef TCPCLIENT_H
#define TCPCLIENT_H

#include <boost/asio.hpp>

#include "BaseClient.h"

class TCPClient : public BaseClient {
   public:
    TCPClient(std::string IP, int port, int = 2000);
    TCPClient(std::string IP, int port, int = 2000, std::string hostname = "");
    ~TCPClient();
    bool Connect() override;
    bool Write(std::string str) override;
    bool ReadReply(std::string* str, size_t min_size = 3) override;
    bool FlushQueu();
    int GetWaitTime() override { return default_wait; }
    void SetDefaultWaitTime(int value) override { default_wait = value; }

   private:
    boost::asio::io_context io_context;
    boost::asio::ip::tcp::socket* socket;
    std::string ip;
    std::string hostname;
    int port;
};

#endif
