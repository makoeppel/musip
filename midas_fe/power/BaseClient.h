#ifndef BASECLIENT_H
#define BASECLIENT_H

#include <boost/asio.hpp>

class BaseClient {

public:
    BaseClient(int to);
    virtual ~BaseClient();
    virtual bool Connect();
    virtual bool Write(std::string str);
    virtual bool ReadReply(std::string* str, size_t = 3);
    virtual int GetWaitTime() {
        return default_wait;
    }
    virtual void SetDefaultWaitTime(int value) {
        default_wait = value;
    }

protected:
    int default_wait;
    std::string read_stop;

    int read_time_out;
};

#endif
