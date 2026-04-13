#include "BaseClient.h"

#include <chrono>
#include <iostream>
#include <thread>

#include "midas.h"

BaseClient::BaseClient(int to) {
    read_time_out = to;
    read_stop = "\n";
    default_wait = 7;
}

bool BaseClient::Connect() {
    std::cout << "This must be implemented in the child class\n";
    return false;
}

BaseClient::~BaseClient() {}

bool BaseClient::Write(std::string /*str*/) {
    std::cout << "This must be implemented in the child class\n";
    return false;
}

bool BaseClient::ReadReply(std::string* /*str*/, size_t /*min_size*/) {
    std::cout << "This must be implemented in the child class\n";
    return false;
}
