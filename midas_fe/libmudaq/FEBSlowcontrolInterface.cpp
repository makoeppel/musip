#include "FEBSlowcontrolInterface.h"

#include <iostream>
#include <thread>
#include <math.h>

#include "midas.h"

using std::cout;
using std::endl;

FEBSlowcontrolInterface::FEBSlowcontrolInterface(mudaq::MudaqDevice & _mdev):
    mdev(_mdev),
    last_fpga_rmem_addr(0),
    m_FEBsc_wmem_addr(0),
    m_FEBsc_rmem_addr(0)
{
    FEBsc_resetMain();
    FEBsc_resetSecondary();
}

FEBSlowcontrolInterface::~FEBSlowcontrolInterface()
{
    // We do not close the mudaq device here on purpose
}



/*
 *  PCIe packet and software interface
 *  20b: N: packet length for following payload(in 32b words)

 *  N*32b: packet payload:
 *      0xBC, 4b type=0xC, 2b SC type = 0b11, 16b FPGA ID
 *      start addr(32b, user parameter)
 *      (N-2)*data(32b, user parameter)
 *
 *      1 word as dummy: 0x00000000 NOTE: MK: why this?
 *      Write length from 0xBC -> 0x9c to SC_MAIN_LENGTH_REGISTER_W
 *      Write enable to SC_MAIN_ENABLE_REGISTER_W
 */

int FEBSlowcontrolInterface::FEB_write(size_t febIDx, const uint32_t startaddr, const vector<uint32_t> & data, const bool nonincrementing, const bool broadcast, const uint32_t MSTR_bar)
{
    uint32_t FPGA_ID = febIDx;
    if ( broadcast )
        FPGA_ID = ADDRS::BROADCAST_ADDR;

    if ( startaddr >= pow(2,16) ) {
        cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write", "FEB_write address %i is bigger then max addr %f", startaddr, pow(2,16));
        return ERRCODES::ADDR_INVALID;
    }

    // TODO: We will have more than 16 FPGAs...
    if ( FPGA_ID > 15 and FPGA_ID != ADDRS::BROADCAST_ADDR ) {
        cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write", "FEB_write ID %i is bigger then current max ID 15", FPGA_ID);
        return ERRCODES::ADDR_INVALID;
    }

    if ( !data.size() ) {
        cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write", "FEB_write Length zero");
        return ERRCODES::SIZE_ZERO;
    }

    if ( data.size() > MAX_SLOWCONTROL_WRITE_MESSAGE_SIZE) {
        cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write", "FEB_write Length of %li too big", data.size());
        return ERRCODES::SIZE_INVALID;
    }

    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(sc_mutex);

    // check if the SWB is busy
    if ( !(mdev.read_register_ro(SC_MAIN_STATUS_REGISTER_R) & 0x1) ) {
        cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write", "SWB is busy");
        return ERRCODES::FPGA_BUSY;
    }

    uint32_t packet_type = PACKET_TYPE_SC_WRITE;
    if ( nonincrementing )
        packet_type = PACKET_TYPE_SC_WRITE_NONINCREMENTING;

    // two most significant bits are 0
    mdev.write_memory_rw(0, PACKET_TYPE_SC << 26 | packet_type << 24 | ((uint16_t)(FPGA_ID & 0x000000FF)) << 8 | 0xBC);
    mdev.write_memory_rw(1, (startaddr & 0x00FFFFFF) | MSTR_bar);
    mdev.write_memory_rw(2, data.size());

    for (uint32_t i = 0; i < data.size(); i++) {
        mdev.write_memory_rw(3 + i, data[i]);
    }
    mdev.write_memory_rw(3 + data.size(), 0x0000009c);

    // SC_MAIN_LENGTH_REGISTER_W starts from 1
    // length for SC Main does not include preamble and trailer, thats why it is 2+length
    mdev.write_register(SC_MAIN_LENGTH_REGISTER_W, 2 + data.size());
    mdev.write_register(SC_MAIN_ENABLE_REGISTER_W, 0x0);
    mdev.toggle_register_fast(SC_MAIN_ENABLE_REGISTER_W, 0x1);
    // firmware regs SC_MAIN_ENABLE_REGISTER_W so that it only starts on a 0->1 transition

    // check if SC Main is done
    uint32_t count = 0;
    while ( count < 1000 ) {
        if ( mdev.read_register_ro(SC_MAIN_STATUS_REGISTER_R) & 0x1 ) break;
        count++;
    }

    if ( count==1000 ) {
        cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write", "MudaqDevice::FEB_write Timeout for done reg");
        return ERRCODES::FPGA_TIMEOUT;
    }

    if ( FPGA_ID == ADDRS::BROADCAST_ADDR || MSTR_bar!=0 )
        return OK;

    // check for acknowledge packet
    count = 0;
    int read_packets = 0;
    while ( count<1000 ) {
        read_packets = FEBsc_read_packets();
        if(read_packets > 0 && sc_packet_deque.front().IsWR()) break;
        // for some reason there is a read acknowledge at the front of the queue...
        if ( read_packets > 0 ) {
            cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write" , "wrong packet type, N packets: %i, count: %i", read_packets, count);
            sc_packet_deque.front().Print();
            sc_packet_deque.pop_front();
        };
        count++;
    }

    if ( count==1000 ) {
        cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write", "Timeout occured waiting for reply: Wanted to write to FPGA %d, Addr %d, length %zu", FPGA_ID, startaddr, data.size());
        return ERRCODES::FPGA_TIMEOUT;
    }

    if ( !sc_packet_deque.front().Good() ) {
        cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write" , "Received bad packet");
        sc_packet_deque.pop_front();
        return ERRCODES::BAD_PACKET;
    }

    if ( !sc_packet_deque.front().IsResponse() ) {
        cm_msg(MERROR, "FEBSlowcontrolInterface::FEB_write" , "Received request packet, this should not happen...");
        sc_packet_deque.pop_front();
        return ERRCODES::BAD_PACKET;
    }
    // Message was consumed, drop it
    sc_packet_deque.pop_front();

    return OK;
}

int FEBSlowcontrolInterface::FEB_write(size_t febIDx, const uint32_t startaddr, const uint32_t data)
{
    return FEB_write(febIDx, startaddr, vector<uint32_t>(1, data) );
}

int FEBSlowcontrolInterface::FEB_ping(size_t febIDx)
{
    return FEB_write(febIDx, STATUS_REGISTER_R, vector<uint32_t>(1, 0), true, false, 0);
}

int FEBSlowcontrolInterface::FEB_read(size_t febIDx, const uint32_t startaddr, vector<uint32_t> &data, const bool nonincrementing)
{
    uint32_t FPGA_ID = febIDx;

     if(startaddr >= pow(2,16)){
        cout << "FEB_read Address out of range: " << std::hex << startaddr << endl;
        return ERRCODES::ADDR_INVALID;
     }


    // TODO: There will be more than 15 FPGAs...
    if(FPGA_ID > 15){
        cout << "FEB_read FPGA ID out of range: " << FPGA_ID << endl;
        return ERRCODES::ADDR_INVALID;
     }

    if(!data.size()){
        cout << "FEB_read Length zero" << endl;
        return ERRCODES::SIZE_ZERO;
     }

    if(data.size() > MAX_SLOWCONTROL_MESSAGE_SIZE){
        // If our read becomes to big, we split it iteratively (If this becomes a performance bother, do a loop)

        vector<uint32_t> data_subset1(data.begin(), data.begin()+MAX_SLOWCONTROL_MESSAGE_SIZE);
        FEB_read(febIDx, startaddr, data_subset1, nonincrementing);
        vector<uint32_t> data_subset2(data.begin()+MAX_SLOWCONTROL_MESSAGE_SIZE, data.end());
        if(nonincrementing)
            FEB_read(febIDx, startaddr, data_subset2, nonincrementing);
        else
           FEB_read(febIDx, startaddr+MAX_SLOWCONTROL_MESSAGE_SIZE, data_subset2, nonincrementing); 
        data.insert(data.begin(), data_subset1.begin(), data_subset1.end());
        data.insert(data.begin()+MAX_SLOWCONTROL_MESSAGE_SIZE, data_subset2.begin(), data_subset2.end());

        return ERRCODES::OK;
    }


    // From here on we grab the mutex until the end of the function: One transaction at a time
    const std::lock_guard<std::mutex> lock(sc_mutex);

    if(!(mdev.read_register_ro(SC_MAIN_STATUS_REGISTER_R)&0x1)){ // FPGA is busy, should not be here...
       cout << "FPGA busy" << endl;
       return ERRCODES::FPGA_BUSY;
    }

    uint32_t packet_type = PACKET_TYPE_SC_READ;
    if(nonincrementing)
        packet_type = PACKET_TYPE_SC_READ_NONINCREMENTING;

    mdev.write_memory_rw(0, PACKET_TYPE_SC << 26 | packet_type << 24 | ((uint16_t)(FPGA_ID & 0x000000FF)) << 8 | 0xBC);

    mdev.write_memory_rw(1, startaddr);
    mdev.write_memory_rw(2, data.size());
    mdev.write_memory_rw(3, 0x0000009c);

    // SC_MAIN_LENGTH_REGISTER_W starts from 1
    // length for SC Main does not include preamble and trailer, thats why it is 2
    mdev.write_register(SC_MAIN_LENGTH_REGISTER_W, 2);
    mdev.write_register(SC_MAIN_ENABLE_REGISTER_W, 0x0);
    // firmware regs SC_MAIN_ENABLE_REGISTER_W so that it only starts on a 0->1 transition
    mdev.toggle_register(SC_MAIN_ENABLE_REGISTER_W, 0x1, 100);

    int count = 0;
    while(count<1000){
        int retval = FEBsc_read_packets();
        if(retval > 0 && sc_packet_deque.front().IsRD()) break;
        // for some reason there is a write acknowledge at the front of the queue...
        if(retval > 0 ){
            cout << "wrong packet type3" << endl;
            sc_packet_deque.pop_front();
            return ERRCODES::BAD_PACKET;
        };
        if(retval < 0){
            cout << "Receiving failed, resetting" << endl;
            FEBsc_resetSecondary();
            return ERRCODES::BAD_PACKET;
        }
        count++;
    }
    if(count==1000){
        cm_msg(MERROR, "MudaqDevice::FEBsc_read",  "Timeout occured waiting for reply: Wanted to read from FPGA %d, Addr %d, length %zu, memaddr %d", FPGA_ID, startaddr, data.size(), m_FEBsc_rmem_addr);
        return ERRCODES::FPGA_TIMEOUT;
    }
    if(!sc_packet_deque.front().Good()){
        cm_msg(MERROR, "MudaqDevice::FEBsc_read" , "Received bad packet, resetting");
        sc_packet_deque.pop_front();
        FEBsc_resetSecondary();
        return ERRCODES::BAD_PACKET;
    }
    if(!sc_packet_deque.front().IsResponse()){
        cm_msg(MERROR, "MudaqDevice::FEBsc_read" , "Received request packet, this should not happen..., resetting");
        sc_packet_deque.pop_front();
        FEBsc_resetSecondary();
        return ERRCODES::BAD_PACKET;
    }
    if(sc_packet_deque.front().GetLength()!=data.size()){
        cm_msg(MERROR, "MudaqDevice::FEBsc_read", "Wanted to read from FPGA %d, Addr %d, length %zu", FPGA_ID, startaddr, data.size());
        cm_msg(MERROR, "MudaqDevice::FEBsc_read" , "Received packet fails size check, communication error, resetting");
        sc_packet_deque.pop_front();
        FEBsc_resetSecondary();
        return ERRCODES::WRONG_SIZE;
    }

    for(uint32_t index =0; index < data.size(); index++){
        data[index] = sc_packet_deque.front().data()[index+3];
    }

    // Message was consumed, drop it
    sc_packet_deque.pop_front();

    return ERRCODES::OK;
}

int FEBSlowcontrolInterface::FEB_read(size_t febIDx, const uint32_t startaddr, uint32_t &data)
{
    vector<uint32_t> d(1,0);
    int status = FEB_read(febIDx, startaddr, d);
    data = d[0];
    return status;
}


void FEBSlowcontrolInterface::FEBsc_resetMain()
{
    //reset our pointer
    m_FEBsc_wmem_addr=0;
    //reset fpga entity
    mdev.toggle_register(RESET_REGISTER_W, SET_RESET_BIT_SC_MAIN(0), 1000);
}

void FEBSlowcontrolInterface::FEBsc_resetSecondary()
{
    //cm_msg(MINFO, "FEB_slowcontrol" , "Resetting slow control secondary");
    //reset our pointer
    m_FEBsc_rmem_addr=0;
    //reset fpga entity
    mdev.toggle_register(RESET_REGISTER_W, SET_RESET_BIT_SC_SECONDARY(0), 1000);
    //wait until SECONDARY is reset, clearing the ram takes time
    uint16_t timeout_cnt=0;
    // poll register until addr of sc secondary is 0xffff (and of init state)
    // NOTE: we have to wait 2**16 * 156.25MHz here, but we wait a bit longer
    while ( (mdev.read_register_ro(SC_STATE_REGISTER_R) & 0x20000000) != 0x20000000 ) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
        fflush(stdout);
        timeout_cnt++;
        if(timeout_cnt>=100){
            cm_msg(MERROR, "FEBsc_resetSecondary()", "Slow control secondary reset FAILED with timeout");
            // someone basically unplugged the PCie card. stop switch_fe now
            cm_disconnect_experiment();
            ss_sleep(3000);
            exit(0);
        }
    };
}

int FEBSlowcontrolInterface::FEBsc_NiosRPC(size_t febIDx, uint16_t command, vector<vector<uint32_t> > payload_chunks)
{
    int status = 0;
    int index = 0;

    // Write the payload
    for(auto chunk: payload_chunks){
        status=FEB_write(febIDx, (uint32_t) index+OFFSETS::FEBsc_RPC_DATAOFFSET, chunk);
         if(status < 0)
             return status;
        index += chunk.size();
    }
    if(index >= 1<<16)
        return ERRCODES::WRONG_SIZE;

    // Write the position of the payload in the offset register
    status=FEB_write(febIDx, CMD_OFFSET_REGISTER_RW, vector<uint32_t>(1,OFFSETS::FEBsc_RPC_DATAOFFSET));
    if(status < 0)
        return status;

    // Write the command in the upper 16 bits of the length register and
    // the size of the payload in the lower 16 bits
    // This triggers the callback function on the frontend board
    status=FEB_write(febIDx, CMD_LEN_REGISTER_RW,
                     vector<uint32_t>(1,(((uint32_t)command) << 16) | index));

    if(status < 0)
        return status;

    //Wait for remote command to finish, poll register
    uint timeout_cnt = 0;
    vector<uint32_t> readback(1,0);
    while(1){
        if(++timeout_cnt >= 500) return ERRCODES::NIOS_RPC_TIMEOUT;
        status=FEB_read(febIDx, CMD_LEN_REGISTER_RW, readback);
        if(status < 0)
            return status;

        if(timeout_cnt > 200 && timeout_cnt%10==0) printf("MudaqDevice::FEBsc_NiosRPC(): Polling for command %x @%d: %x, %x\n",command,timeout_cnt,readback[0],readback[0]&0xffff0000);
        if((readback[0]&0xffff0000) == 0) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    return readback[0]&0xffff;
}

int FEBSlowcontrolInterface::FEBsc_read_packets()
{

    int packetcount = 0;

    uint32_t fpga_rmem_addr = (mdev.read_register_ro(MEM_WRITEADDR_LOW_REGISTER_R)+1) & 0xffff;
    while ( fpga_rmem_addr != m_FEBsc_rmem_addr ) {

        if ((mdev.read_memory_ro(m_FEBsc_rmem_addr) & 0x1c0000bc) != 0x1c0000bc){
            cout << "Start pattern not seen at addr " << std::hex << m_FEBsc_rmem_addr << " seeing " << mdev.read_memory_ro(m_FEBsc_rmem_addr) << std::dec << endl;
            return -1;
        }

        // the eqaulity case is taken care of by the while condition
        if(((fpga_rmem_addr > m_FEBsc_rmem_addr) && (fpga_rmem_addr-m_FEBsc_rmem_addr < MIN_SC_MESSAGE_SIZE))
            || ((fpga_rmem_addr < m_FEBsc_rmem_addr) && (MUDAQ_MEM_RO_LEN - m_FEBsc_rmem_addr + fpga_rmem_addr) < MIN_SC_MESSAGE_SIZE)   ){ // This is the wraparound case
            cout << "Incomplete packet!" << endl;
            return -1;
        }

        SC_reply_packet packet;
        packet.push_back(mdev.read_memory_ro(m_FEBsc_rmem_addr)); //save preamble
        rmenaddrIncr();
        packet.push_back(mdev.read_memory_ro(m_FEBsc_rmem_addr)); //save startaddr
        rmenaddrIncr();
        packet.push_back(mdev.read_memory_ro(m_FEBsc_rmem_addr)); //save length word
        rmenaddrIncr();

        if(((fpga_rmem_addr >= m_FEBsc_rmem_addr) && (fpga_rmem_addr-m_FEBsc_rmem_addr) < packet.GetLength() +1) // Plus 1 for the trailer
            || ((fpga_rmem_addr < m_FEBsc_rmem_addr) && (MUDAQ_MEM_RO_LEN - m_FEBsc_rmem_addr + fpga_rmem_addr) < packet.GetLength() + 1 ) ){ // This is the wraparound case
            cout << "Incomplete packet!" << endl;
            return -1;
        }
        // Read data
        for (uint32_t i = 0; i < packet.GetLength(); i++) {
            packet.push_back(mdev.read_memory_ro(m_FEBsc_rmem_addr)); //save data
            rmenaddrIncr();
        }

        // Read trailer
        packet.push_back(mdev.read_memory_ro(m_FEBsc_rmem_addr));
        rmenaddrIncr();

        if(packet[packet.size()-1]!=0x9c){
            cout << "Did not see trailer: something is wrong.\n" << endl;
            packet.Print();
            return -1;
        }

        sc_packet_deque.push_back(packet);
        packetcount++;
    }
    return packetcount;
}

void FEBSlowcontrolInterface::FPGAHistoInit(int febNumber, int chipNumber) {
    mdev.write_register(SWB_HISTO_LINK_SELECT_REGISTER_W,febNumber);
    mdev.write_register(SWB_HISTO_CHIP_SELECT_REGISTER_W,chipNumber);
    mdev.write_register(SWB_ZERO_HISTOS_REGISTER_W,2);
    mdev.write_register(SWB_ZERO_HISTOS_REGISTER_W,0);
    uint32_t start_setup = 0;
    start_setup = SET_RESET_BIT_RUN_START_ACK(start_setup);
    start_setup = SET_RESET_BIT_RUN_END_ACK(start_setup);
    mdev.write_register_wait(RESET_REGISTER_W, start_setup, 1000);
    mdev.write_register(RESET_REGISTER_W, 0x0);
}

void FEBSlowcontrolInterface::FPGAHistoStart(){
    mdev.write_register(SWB_ZERO_HISTOS_REGISTER_W,1);
}

void FEBSlowcontrolInterface::FPGAHistoStop(){
    mdev.write_register(SWB_ZERO_HISTOS_REGISTER_W,0);
}

uint32_t FEBSlowcontrolInterface::FPGAHistoGetContent(uint32_t idx) {
    mdev.write_register(SWB_HISTO_ADDR_REGISTER_W, idx);//((col << 8) | row));
    return mdev.read_register_ro(SWB_HISTOS_DATA_REGISTER_R);
}

void FEBSlowcontrolInterface::SC_reply_packet::Print(){
   printf("--- Packet dump ---\n");
   printf("Type %x\n", this->at(0)&0x1f0000bc);
   printf("FPGA ID %x\n", this->GetFPGA_ID());
   printf("startaddr %x\n", this->GetStartAddr());
   printf("length %ld\n", this->GetLength());
   printf("packet: size=%lu length=%lu IsRD=%c IsWR=%c, IsResponse=%c, IsGood=%c\n",
     this->size(),this->GetLength(),
     this->IsRD()?'y':'n',
     this->IsWR()?'y':'n',
     this->IsResponse()?'y':'n',
     this->Good()?'y':'n'
   );
   //report and check
   for(size_t i=0 ;i<10;i++){
      if(i>= this->size()) break;
      printf("data: +%lu: %16.16x\n",i,this->at(i));
   }
   printf("--- *********** ---\n");
}
