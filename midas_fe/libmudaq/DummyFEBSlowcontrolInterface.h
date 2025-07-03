#ifndef DUMMYFEBSLOWCONTROLINTERFACE_H
#define DUMMYFEBSLOWCONTROLINTERFACE_H

#include "FEBSlowcontrolInterface.h"

#include <vector>
#include <thread>
#include <random>

using std::vector;
using std::thread;

class DummyFEBSlowcontrolInterface: public FEBSlowcontrolInterface
{
public:
    DummyFEBSlowcontrolInterface(mudaq::MudaqDevice & mdev /*,Add midas connection here */);
    virtual ~DummyFEBSlowcontrolInterface();
    // There should only be one SC interface, forbid copy and assignment
    DummyFEBSlowcontrolInterface() = delete;
    DummyFEBSlowcontrolInterface(const FEBSlowcontrolInterface &) = delete;
    DummyFEBSlowcontrolInterface& operator=(const FEBSlowcontrolInterface&) = delete;

    // We use the () operator to simulate changing values in the SC registers using a separate thread
    void operator()();

    virtual int FEB_write(uint32_t febIDx, const uint32_t startaddr, const vector<uint32_t> & data, const bool nonincrementing = false, const bool broadcast = false, const uint32_t MSTR_bar = 0) override;
    virtual int FEB_read(uint32_t febIDx, const uint32_t startaddr, vector<uint32_t> & data, const bool nonincrementing = false) override;

    virtual void FEBsc_resetMain() override {}
    virtual void FEBsc_resetSecondary() override {}
    virtual int FEBsc_NiosRPC(uint32_t febIDx, uint16_t command, vector<vector<uint32_t> > payload_chunks) override;

protected:
    vector<vector<uint32_t>> scregs;
    thread t;
    uint32_t cnt_when_to_trigger_error = 100;
    uint32_t cnt_of_reads = 0;
    uint32_t cnt_of_writes = 0;
    uint32_t cnt_of_rpcs = 0;
    uint32_t MAX_LINKS_PER_SWITCHINGBOARD = 8;
};

#endif // DUMMYFEBSLOWCONTROLINTERFACE_H
