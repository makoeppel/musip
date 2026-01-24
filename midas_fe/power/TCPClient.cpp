//

#include "midas.h"

#include "TCPClient.h"

#include <chrono>
#include <iostream>
#include <thread>

TCPClient::TCPClient(std::string IP, int P, int to, std::string hn)
    : BaseClient(to)
{
    socket = new boost::asio::ip::tcp::socket(io_context);
    ip = IP;
    port = P;
    hostname = hn;
}

bool TCPClient::Connect() {
    boost::system::error_code ec;
    if(hostname.length() < 1) {
        socket->connect(boost::asio::ip::tcp::endpoint(boost::asio::ip::make_address(ip), port), ec);
    } else {
        std::cout << "hostname " << hostname << std::endl;

        boost::asio::ip::tcp::resolver resolver(io_context);

        // Resolve hostname with empty service (you can replace "" with a service like "http" if needed)
        auto iter = resolver.resolve(hostname, "");

        // Use the first resolved endpoint and set the desired port
        boost::asio::ip::tcp::endpoint endpoint = iter.begin()->endpoint();
        endpoint.port(port);

        std::cout << "ip derived " << endpoint.address() << " " << endpoint.port() << std::endl;

        // Connect using the socket and capture any error
        socket->connect(endpoint, ec);
    }
    if(ec) {
        std::cout << " socket->connect failed with err:" << ec << std::endl;
        return false;
    }
    socket->non_blocking(true);
    FlushQueu();
    return true;
}

TCPClient::~TCPClient() {
    socket->close();
}

bool TCPClient::Write(std::string str) {
    if(!socket->is_open()) return false;
    boost::system::error_code error;
    boost::asio::write(*socket, boost::asio::buffer(str), error);
    if(!error) {
    }
    else {
        std::cout << "send failed: " << error.message() << std::endl;
        return false;
    }

    return true;
}

bool TCPClient::FlushQueu() {
    boost::system::error_code error;
    std::size_t data_size;
    char data[1024];
    data_size = socket->available(error);
    if(error) {
        std::cout << " size request failed " << std::endl;
        return false;
    }
    while(int(data_size) > 0) {
        socket->read_some(boost::asio::buffer(data), error);
        if(error) {
            std::cout << " size request failed " << std::endl;
            return false;
        }
        data_size = socket->available(error);
        if(error) {
            std::cout << " size request failed " << std::endl;
            return false;
        }
    }
    return true;
}

bool TCPClient::ReadReply(std::string* str, size_t min_size) {
    std::size_t data_size = 0;
    auto start = std::chrono::system_clock::now();
    int time_elapsed = 0;
    boost::system::error_code error;

    // wait for at least 3 characters (minimum reply for  is "*\n")
    while(time_elapsed < read_time_out && data_size < min_size) {
        data_size = socket->available(error);
        if(error) std::cout << " size request failed " << std::endl;
        std::this_thread::sleep_for(std::chrono::milliseconds(default_wait));
        auto end = std::chrono::system_clock::now();
        time_elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    }

    //std::cout << " data of size " << data_size << " waiting after " << time_elapsed << " ms " << std::endl;

    // read
    boost::asio::streambuf buf;
    try {
        read_until(*socket, buf, read_stop);
    }
    catch(...) {
        cm_msg(MERROR, "ReadReply", "read_until failed");
    }

    std::string data = { boost::asio::buffers_begin(buf.data()), boost::asio::buffers_begin(buf.data()) + buf.size() };

    //std::cout << "data : " << data << std::endl;
    //std::size_t found = data.find('\r');
    //if (found!=std::string::npos)  std::cout << "first 'needle' found at: " << found << '\n';
    //remove newline
    data.erase(std::remove(data.begin(), data.end(), '\n'), data.end());
    data.erase(
        std::remove(data.begin(), data.end(), '\r'), data.end()
    ); //don`t get why there is a /r in the reply string FW
    *str = data;
    //std::cout << " --- data read : " << *str << std::endl;
    return true;
}
