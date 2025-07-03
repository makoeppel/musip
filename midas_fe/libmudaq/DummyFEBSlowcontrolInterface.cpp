//

#include "DummyFEBSlowcontrolInterface.h"

#include <math.h>

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <thread>

using std::cout;
using std::endl;

DummyFEBSlowcontrolInterface::DummyFEBSlowcontrolInterface(mudaq::MudaqDevice& mdev)
    : FEBSlowcontrolInterface(mdev), scregs(8, vector<uint32_t>(pow(2, 16), 0)) {
    for (uint32_t i = 0; i < MAX_LINKS_PER_SWITCHINGBOARD; i++) {
        for (uint32_t j = 0; j < pow(2, 16); j++) {
            scregs[i][j] = scregs[i][j] + std::rand() / ((RAND_MAX + 1u) / 4096);
        }
    }

    t = thread(&DummyFEBSlowcontrolInterface::operator(), this);
}

DummyFEBSlowcontrolInterface::~DummyFEBSlowcontrolInterface() {}

void DummyFEBSlowcontrolInterface::operator()() {
    while (1) {
        for (uint32_t i = 0; i < MAX_LINKS_PER_SWITCHINGBOARD; i++) {
            for (uint32_t j = 0; j < pow(2, 16); j++) {
                scregs[i][j] = scregs[i][j] + std::rand() / ((RAND_MAX + 1u) / 257) - 128;
            }
        }
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
}

int DummyFEBSlowcontrolInterface::FEB_write(uint32_t febIDx, const uint32_t startaddr,
                                            const vector<uint32_t>& data,
                                            const bool nonincrementing, const bool broadcast,
                                            const uint32_t MSTR_bar [[maybe_unused]]) {
#ifdef EMULATE_HARDWARE_ERRORS
    if (cnt_when_to_trigger_error == cnt_of_writes) {
        if (rand() % 10 == 0) {
            cnt_of_writes = 0;
            cnt_when_to_trigger_error = rand() % 100;
        }
        return ERRCODES(rand() % num_of_error_codes);
    }
#endif

    // we first genertate a dummy acknowledge
    m_FEBsc_rmem_addr = 0;
    mdev.write_dummy_acknowledge(startaddr, febIDx);

    auto status = FEBSlowcontrolInterface::FEB_write(febIDx, startaddr, data, nonincrementing,
                                                     broadcast, MSTR_bar);

    // store the data
    for (size_t i = 0; i < data.size(); i++)
        scregs[febIDx][startaddr + i * (!nonincrementing)] = data[i];

    cnt_of_writes++;

    return status;
}

int DummyFEBSlowcontrolInterface::FEB_read(uint32_t febIDx, const uint32_t startaddr,
                                           vector<uint32_t>& data, const bool nonincrementing) {
#ifdef EMULATE_HARDWARE_ERRORS
    if (cnt_when_to_trigger_error == cnt_of_reads) {
        // we also give feedback that all links are not locked
        mdev.write_register_ro_dummy(LINK_LOCKED_LOW_REGISTER_R, 0x0);
        mdev.write_register_ro_dummy(LINK_LOCKED_HIGH_REGISTER_R, 0x0);
        if (rand() % 10 == 0) {
            cnt_of_reads = 0;
            cnt_when_to_trigger_error = rand() % 100;
            // lock the links again
            mdev.write_register_ro_dummy(LINK_LOCKED_LOW_REGISTER_R, 0xFFFFFFFF);
            mdev.write_register_ro_dummy(LINK_LOCKED_HIGH_REGISTER_R, 0xFFFFFFFF);
        }
        return ERRCODES(rand() % num_of_error_codes);
    }
#endif

    // we first genertate a dummy acknowledge
    m_FEBsc_rmem_addr = 0;
    mdev.read_dummy_acknowledge(startaddr, data.size(), febIDx);

    auto status = FEBSlowcontrolInterface::FEB_read(febIDx, startaddr, data, nonincrementing);

    cnt_of_reads++;

    return status;
}

int DummyFEBSlowcontrolInterface::FEBsc_NiosRPC(uint32_t febIDx [[maybe_unused]],
                                                uint16_t command [[maybe_unused]],
                                                vector<vector<uint32_t>> payload_chunks
                                                [[maybe_unused]]) {
#ifdef EMULATE_HARDWARE_ERRORS
    if (cnt_when_to_trigger_error == cnt_of_rpcs) {
        if (rand() % 10 == 0) {
            cnt_of_rpcs = 0;
            cnt_when_to_trigger_error = rand() % 100;
        }
        return ERRCODES(rand() % num_of_error_codes);
    }
#endif

    cnt_of_rpcs++;

    return ERRCODES::OK;
}
