/* Interface for slow control of the FEBs from the switching PCs
 * Can work via optical link on the switching board or the MSCB
 * bus on the backplane, once available */

// Niklaus Berger, January 2021 niberger@uni-mainz.de

#ifndef FEB_SLOWCONTROL_H
#define FEB_SLOWCONTROL_H

#include <deque>
#include <mutex>
#include <vector>

#include "../constants.h"
#include "../registers.h"
#include "mudaq_device.h"

using std::deque;
using std::vector;

class FEBSlowcontrolInterface {
   public:
    FEBSlowcontrolInterface(mudaq::MudaqDevice& mdev /*,Add midas connection here */);
    virtual ~FEBSlowcontrolInterface();
    // There should only be one SC interface, forbid copy and assignment
    FEBSlowcontrolInterface() = delete;
    FEBSlowcontrolInterface(const FEBSlowcontrolInterface&) = delete;
    FEBSlowcontrolInterface& operator=(const FEBSlowcontrolInterface&) = delete;

    virtual int FEB_write(uint32_t febIDx, const uint32_t startaddr, const vector<uint32_t>& data,
                          const bool nonincrementing = false, const bool broadcast = false,
                          const uint32_t MSTR_bar = 0);
    virtual int FEB_write(uint32_t febIDx, const uint32_t startaddr, const uint32_t data);
    virtual int FEB_broadcast(const uint32_t startaddr, const uint32_t data);
    virtual int FEB_broadcast(const uint32_t startaddr, const vector<uint32_t> & data, const bool nonincrementing = false);
    virtual int FEB_ping(uint32_t febIDx);

    // expects data vector with read-length size
    virtual int FEB_read(uint32_t febIDx, const uint32_t startaddr, vector<uint32_t>& data,
                         const bool nonincrementing = false);
    virtual int FEB_read(uint32_t febIDx, const uint32_t startaddr, uint32_t& data);

    virtual void FEBsc_resetMain();
    virtual void FEBsc_resetSecondary();
    virtual int FEBsc_NiosRPC(uint32_t febIDx, uint16_t command,
                              vector<vector<uint32_t>> payload_chunks);

    virtual void FPGAHistoInit(int febNumber, int chipNumber);
    virtual void FPGAHistoStart();
    virtual void FPGAHistoStop();
    virtual uint32_t FPGAHistoGetContent(uint32_t idx);

    enum ERRCODES {
        ADDR_INVALID = -20,
        SIZE_INVALID,
        SIZE_ZERO,
        FPGA_BUSY,
        FPGA_TIMEOUT,
        BAD_PACKET,
        WRONG_SIZE,
        NIOS_RPC_TIMEOUT,
        OK = 0
    };
    enum OFFSETS { FEBsc_RPC_DATAOFFSET = 0 };
    // TODO: Check what the corect addr is
    enum ADDRS { BROADCAST_ADDR = 0xFFFFFFFF };

    static constexpr uint32_t MIN_SC_MESSAGE_SIZE = 4;

   protected:
    mudaq::MudaqDevice& mdev;

    std::mutex sc_mutex;

    struct SC_reply_packet : public std::vector<uint32_t> {
       public:
        bool Good() {
            // header+startaddr+length+trailer+[data]
            if (size() < 4)
                return false;
            if (IsWR() && IsResponse())
                return size() == 4;  // No payload for write response
            if (size() != GetLength() + 4)
                return false;
            return true;
        };
        // TODO: Remove hardcoded numbers here
        bool IsRD() {
            return (this->at(0) & 0x1f0000bc) == 0x1c0000bc + (PACKET_TYPE_SC_READ << 24) ||
                   (this->at(0) & 0x1f0000bc) ==
                       0x1c0000bc + (PACKET_TYPE_SC_READ_NONINCREMENTING << 24);
        };
        bool IsWR() {
            return (this->at(0) & 0x1f0000bc) == 0x1c0000bc + (PACKET_TYPE_SC_WRITE << 24) ||
                   (this->at(0) & 0x1f0000bc) ==
                       0x1c0000bc + (PACKET_TYPE_SC_WRITE_NONINCREMENTING << 24);
        };
        uint16_t IsResponse() { return (this->at(2) & 0x10000) != 0; };
        uint16_t GetFPGA_ID() { return (this->at(0) >> 8) & 0xffff; };
        uint16_t GetStartAddr() { return this->at(1); };
        size_t GetLength() {
            if (IsWR() && IsResponse())
                return 0;
            else
                return this->at(2) & 0xffff;
        };
        void Print();
    };

    deque<SC_reply_packet> sc_packet_deque;

    SC_reply_packet FEBsc_pop_packet();
    SC_reply_packet& FEBsc_peek_packet();

    int FEBsc_read_packets();

    uint32_t last_fpga_rmem_addr;
    uint32_t m_FEBsc_wmem_addr;
    uint32_t m_FEBsc_rmem_addr;

    void rmenaddrIncr() {
        m_FEBsc_rmem_addr =
            (((m_FEBsc_rmem_addr + 1) == MUDAQ_MEM_RO_LEN) ? 0 : m_FEBsc_rmem_addr + 1);
    }
};

#endif
