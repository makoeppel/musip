/**
 * @author      Moritz Kiehn <kiehn@physi.uni-heidelberg.de>
 * @author      Heiko Augustin <augustin.heiko@physi.uni-heidelberg.de>
 * @author      Lennart Huth <huth@physi.uni-heidelberg.de>
 * @date        2013-11-14
 */

#include "mudaq_device.h"

#include <atomic>
#include <cmath>
#include <cstring>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <time.h>
#include <cstdint>

#include <fcntl.h>
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fstream>
#include <thread>
#include <chrono>

#include <sys/ioctl.h>

#define PAGEMAP_LENGTH 8 // each page table entry has 64 bits = 8 bytes
#define PAGE_SHIFT 12    // on x86_64: 4 kB pages, so shifts of 12 bits

using namespace std;

// ----------------------------------------------------------------------------
// additional local helper functions

/**
 * Check physical address of allocated memory
 * for 32 bits / 36 bits
 */
int physical_address_check( uint32_t * base_address, size_t size ) {

  /* Open binary file with page map table */
  FILE *pagemap = fopen("/proc/self/pagemap", "rb");
  void * virtual_address;
  unsigned long offset = 0, page_frame_number = 0, distance_from_page_boundary = 0;
  uint64_t offset_mem;

  for (uint i = 0; i < size / _pagesize(); i++ ) { // loop over all pages in allocated memory
    virtual_address = base_address + i * _pagesize() / 4; // uint32_t words
    /* go to entry for virtual_address  */
    offset = (unsigned long)virtual_address / _pagesize() * PAGEMAP_LENGTH;
    if( fseek( pagemap, (unsigned long)offset, SEEK_SET) != 0) {
      fprintf(stderr, "Failed to seek pagemap to proper location\n");
    }

    /* get page frame number and shift by page_shift to get physical address */
    if (fread(&page_frame_number, 1, PAGEMAP_LENGTH - 1, pagemap) < PAGEMAP_LENGTH - 1)
        std::cerr << "Warning: fread() read fewer bytes than expected.\n";
    page_frame_number &= 0x7FFFFFFFFFFFFF;  // clear bit 55: soft-dirty. clear this to indicate that nothing has been written yet
    distance_from_page_boundary = (unsigned long)virtual_address % _pagesize();
    offset_mem = (page_frame_number << PAGE_SHIFT) + distance_from_page_boundary;

    //cout << hex << "Physical address: " << offset_mem << endl;
    if ( offset_mem >> 32 == 0 ) {
      cout << dec << "Memory resides within 4 GB for page " << i << " at address " << hex << offset_mem << endl;
      fclose(pagemap);
      return -1;
    }
  }
  fclose(pagemap);
  return 0;
}

int is_page_aligned( void * pointer ) {
  DEBUG("diff to page: %lu", ( (uintptr_t)(const void *)(pointer) ) % _pagesize() );
  return !( ( (uintptr_t)(const void *)(pointer) ) % _pagesize()  == 0 );
}

void * align_page( void * pointer ) {
  void * aligned_pointer = (void *)( (uintptr_t)(const void *)pointer + _pagesize() - ((uintptr_t)(const void *)(pointer) ) % _pagesize() );
  return aligned_pointer;
}

void * get_next_aligned_page( void * base_address ) {

  int retval = is_page_aligned( base_address );
    if ( retval != 0 ) {
      //ERROR("Memory buffer is not page aligned");
      void * aligned_pointer = align_page( base_address );
      retval = is_page_aligned( aligned_pointer );
      return aligned_pointer;
    }

  return base_address;
}


static void _print_raw_buffer(volatile uint32_t* addr, unsigned len,
                              unsigned block_offset = 0)
{
    const unsigned BLOCK_SIZE = 8;
    const unsigned first = (block_offset * BLOCK_SIZE);
    const unsigned last = first + len - 1;

    cout << showbase << hex;

    unsigned i;
    for (i = first; i <= last; ++i) {
        if ((i % BLOCK_SIZE) == 0) {
            cout << setw(6) << i << " |";
        }
        cout << " " << setw(10) << addr[i];
        // add a newline after every complete block and after the last one.
        if ((i % BLOCK_SIZE) == (BLOCK_SIZE - 1) || (i == last)) {
            cout << endl;
        }
    }

    cout << noshowbase << dec;
}

namespace mudaq {

// MudaqDevice

  mudaq::MudaqDevice::MudaqDevice(const std::string& path) :
    _fd(-1),
#ifdef NO_SWITCHING_BOARD
    _path(path)
#else
    _path(path),
    _regs_rw(nullptr),
    _regs_ro(nullptr),
    _mem_ro(nullptr),
    _mem_rw(nullptr)
#endif
  {
      _last_read_address = 0;
}

bool MudaqDevice::is_ok() const
{
#ifdef NO_SWITCHING_BOARD
    return true;
#else
    bool error = (_fd < 0) ||
        (_regs_rw == nullptr) ||
        (_regs_ro == nullptr) ||
        (_mem_ro == nullptr)  ||
        (_mem_rw == nullptr);

    return !error;
#endif
}

  bool MudaqDevice::open()
{
#ifdef NO_SWITCHING_BOARD
    std::cout << "Dummy mudaq: open()" << std::endl;
    return true;
#else
    // O_SYNC only affects 'write'. not really needed but doesnt hurt and makes
    // things safer if we later decide to use 'write'.
    _fd = ::open(_path.c_str(), O_RDWR | O_SYNC);
    if (_fd < 0) {
        ERROR("could not open device '%s': %s", _path, strerror(errno));
        return false;
    }
    _regs_rw = mmap_rw(MUDAQ_REGS_RW_INDEX, MUDAQ_REGS_RW_LEN);
    _regs_ro = mmap_ro(MUDAQ_REGS_RO_INDEX, MUDAQ_REGS_RO_LEN);
    _mem_rw =  mmap_rw(MUDAQ_MEM_RW_INDEX,  MUDAQ_MEM_RW_LEN);
    _mem_ro =  mmap_ro(MUDAQ_MEM_RO_INDEX,  MUDAQ_MEM_RO_LEN);
    return (_regs_rw != nullptr) && (_regs_ro != nullptr) && (_mem_rw != nullptr) && (_mem_ro != nullptr);
#endif
}

void MudaqDevice::close()
{

#ifdef NO_SWITCHING_BOARD
    std::cout << "Dummy mudaq: close()" << std::endl;
#else
    munmap_wrapper(&_mem_ro,  MUDAQ_MEM_RO_LEN,  "could not unmap read-only memory");
    munmap_wrapper(&_mem_rw,  MUDAQ_MEM_RW_LEN,  "could not unmap read/write memory");  // added by DvB for rw mem
    munmap_wrapper(&_regs_ro, MUDAQ_REGS_RO_LEN, "could not unmap read-only registers");
    munmap_wrapper(&_regs_rw, MUDAQ_REGS_RW_LEN, "could not unmap read/write registers");
    if (_fd >= 0 && ::close(_fd) < 0) {
        ERROR("could not close '%s': %s", _path, strerror(errno));
    }
    // invalidate the file descriptor
    _fd = -1;
#endif

}

bool MudaqDevice::operator!() const
{
    #ifdef NO_SWITCHING_BOARD
        return (_fd < 0);
    #else
        return (_fd < 0) || (_regs_rw == nullptr)
                        || (_regs_ro == nullptr)
                        || (_mem_ro == nullptr)
                        || (_mem_rw == nullptr);
    #endif
}

void MudaqDevice::write_memory_rw(unsigned idx, uint32_t value)
{
    if(idx > 64*1024){
        cout << "Invalid memory address " << idx << endl;
        exit (EXIT_FAILURE);
    }
    else {
        _mem_rw[idx & MUDAQ_MEM_RW_MASK] = value;
    }
}

void MudaqDevice::write_register(unsigned idx, uint32_t value)
{
    if(idx > 63){
        cout << "Invalid register address " << idx << endl;
        exit (EXIT_FAILURE);
    }
    else {
    _regs_rw[idx] = value;
    }
}

void MudaqDevice::write_register_wait(unsigned idx, uint32_t value,
                                      unsigned wait_ns)
{
    write_register(idx, value);
    std::this_thread::sleep_for(std::chrono::nanoseconds(wait_ns));  // (MM): this is terrible and will sleep for a minimum of 60 us. Do we need this anywhere?
}

void MudaqDevice::toggle_register(unsigned idx, uint32_t value, unsigned wait_ns)
{
    uint32_t old_value = read_register_rw(idx);
    write_register_wait(idx, value, wait_ns);
    write_register(idx, old_value);
}

void MudaqDevice::toggle_register_fast(unsigned idx, uint32_t value)
{
    uint32_t old_value = read_register_rw(idx);
    write_register(idx, value);
    write_register(idx, old_value);
}

uint32_t MudaqDevice::read_register_rw(unsigned idx) const {
       if(idx > 63){
           cout << "Invalid register address " << idx << endl;
           exit (EXIT_FAILURE);
       }
       return _regs_rw[idx];
}


uint32_t MudaqDevice::read_register_ro(unsigned idx) const {
       if(idx > 63){
           cout << "Invalid register address " << idx << endl;
           exit (EXIT_FAILURE);
       }
       return _regs_ro[idx];
}

uint32_t MudaqDevice::read_memory_ro(unsigned idx) const {
       if(idx > 64*1024){
           cout << "Invalid memory address " << idx << endl;
           exit (EXIT_FAILURE);
       }
       return _mem_ro[idx & MUDAQ_MEM_RO_MASK];
}

uint32_t MudaqDevice::read_memory_rw(unsigned idx) const {
       if(idx > 64*1024-1){
           cout << "Invalid memory address " << idx << endl;
           exit (EXIT_FAILURE);
       }
       return _mem_rw[idx & MUDAQ_MEM_RW_MASK];
}

void MudaqDevice::write_dummy_acknowledge(unsigned startaddr, unsigned fpga_id)
{

#ifdef NO_SWITCHING_BOARD
    _regs_ro[MEM_WRITEADDR_LOW_REGISTER_R] = 3;
    _mem_ro[0] = PACKET_TYPE_SC << 26 | PACKET_TYPE_SC_WRITE << 24 | ((uint16_t)(fpga_id & 0x000000FF)) << 8 | 0xBC;
    _mem_ro[1] = startaddr;
    _mem_ro[2] = 0x10000;
    _mem_ro[3] = 0x9c;
#else

#endif

}

void MudaqDevice::write_register_ro_dummy(unsigned idx, uint32_t value)
{

#ifdef NO_SWITCHING_BOARD
    if(idx > 63){
        cout << "Invalid register address " << idx << endl;
        exit (EXIT_FAILURE);
    }
    _regs_ro[idx] = value;
#else

#endif

}

void MudaqDevice::read_dummy_acknowledge(unsigned startaddr, int length, unsigned fpga_id)
{

#ifdef NO_SWITCHING_BOARD
    _regs_ro[MEM_WRITEADDR_LOW_REGISTER_R] = length+3;
    _mem_ro[0] = PACKET_TYPE_SC << 26 | PACKET_TYPE_SC_READ << 24 | ((uint16_t)(fpga_id & 0x000000FF)) << 8 | 0xBC;
    _mem_ro[1] = startaddr;
    _mem_ro[2] = 0x10000 + length;

    // do some dummy counting
    dummyCounter[0] = 0;
    dummyCounter[3]++;
    dummyCounter[5] = dummyCounter[5] + 0x800;
    dummyCounter[7]++;
    dummyCounter[63] = 0;
    for ( int idx = 3; idx < length+3; idx++ ) {
        // TODO: here we can check what addr we write to and than fill this with some more usefull data for now random
        if (startaddr == MUTRIG_CNT_ADDR_REGISTER_R) {
            // NOTE: we have an offset of +2 in the firmware
            int cidx = idx - 2 - 3;
            if ( cidx % 64 == 0 ) { // ASIC ID
                _mem_ro[idx] = cidx / 64;
            } else if ( cidx % 64 == 1 ) { // DEBUG1
                _mem_ro[idx] = dummyCounter[1];
            } else if ( cidx % 64 == 2 ) { // DEBUG2
                _mem_ro[idx] = dummyCounter[2];
            } else if ( cidx % 64 == 3 ) { // HitRate
                _mem_ro[idx] = 12345;
            } else if ( cidx % 64 == 4 ) { // TimeLow
                _mem_ro[idx] = dummyCounter[4];
                dummyCounter[4]++;
            } else if ( cidx % 64 == 5 ) { // TimeHigh
                _mem_ro[idx] = dummyCounter[5];
                dummyCounter[5]++;
            } else if ( cidx % 64 == 6 ) { // CRCCnt
                _mem_ro[idx] = 0;
            } else if ( cidx % 64 == 7 ) { // FrameRate
                _mem_ro[idx] = std::rand()/((RAND_MAX +1u)/125000001);
            } else if ( cidx % 64 > 7 && cidx % 64 < 8+32 ) {
                _mem_ro[idx] = std::rand()/((RAND_MAX +1u)/125000001);
            } else {
                _mem_ro[idx] = 0xBEEFBEEF;
            }
        } else if ( startaddr == ARRIA_TEMP_REGISTER_RW ) {
            _FEB_REGS[startaddr] = _FEB_REGS[startaddr] + 5;
            _mem_ro[idx] = _FEB_REGS[startaddr];
        } else if ( startaddr == MAX10_ADC_0_1_REGISTER_R) {
            _FEB_REGS[startaddr] = _FEB_REGS[startaddr] + 5;
            _mem_ro[idx] = _FEB_REGS[startaddr];
        } else if ( startaddr == FIREFLY_STATUS_REGISTER_R) {
            _FEB_REGS[startaddr + idx - 3] = _FEB_REGS[startaddr + idx - 3] + 5;
            _mem_ro[idx] = _FEB_REGS[startaddr + idx - 3];
        } else {
            _mem_ro[idx] = std::rand()/((RAND_MAX +1u)/4096);
        }
    }
    _mem_ro[length+3] = 0x9c;
#else

#endif

}

void MudaqDevice::enable_led(unsigned which)
{
    uint8_t pattern;
    // turn on a single led w/o changing the status of the remaining ones
    // since we only have 8 leds we need to wrap the led index
    pattern  = read_register_rw(LED_REGISTER_W);
    pattern |= (1 << (which % 8));
    write_register(LED_REGISTER_W, pattern);
}

void MudaqDevice::enable_leds(uint8_t pattern)
{
    write_register(LED_REGISTER_W, pattern);
}

void MudaqDevice::disable_leds()
{
    write_register(LED_REGISTER_W, 0x0);
}

void MudaqDevice::print_registers()
{
    cout << "offset + read/write registers" << endl;
    _print_raw_buffer(_regs_rw, MUDAQ_REGS_RW_LEN);
    cout << "offset + read-only registers" << endl;
    _print_raw_buffer(_regs_ro, MUDAQ_REGS_RO_LEN);
}

// ----------------------------------------------------------------------------
// mmap / munmap helper functions

volatile uint32_t * MudaqDevice::mmap_rw(unsigned idx, unsigned len)
{
    off_t offset = idx * _pagesize();
    size_t size = len * sizeof(uint32_t);
    // TODO what about | MAP_POPULATE
    volatile void * rv = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED , _fd, offset);
    if (rv == MAP_FAILED) {
        ERROR("could not mmap region %d in read/write mode: %s", idx, strerror(errno));
        return static_cast<volatile uint32_t *>(nullptr);
    } else {
        return static_cast<volatile uint32_t *>(rv);
    }
}

volatile uint32_t * MudaqDevice::mmap_ro(unsigned idx, unsigned len)
{
    off_t offset = idx * _pagesize();
    size_t size = len * sizeof(uint32_t);
    // TODO what about | MAP_POPULATE
    volatile void * rv = mmap(nullptr, size, PROT_READ, MAP_SHARED , _fd, offset);
    if (rv == MAP_FAILED) {
        ERROR("could not mmap region %d in read-only mode: %s", idx, strerror(errno));
        return static_cast<volatile uint32_t *>(nullptr);
    } else {
        return static_cast<volatile uint32_t *>(rv);
    }
}

void MudaqDevice::munmap_wrapper(uint32_t** addr, unsigned len,
                                 const std::string& error_msg)
{
    // i have to cast away volatile to allow to call munmap. using any of the
    // "correct" c++ versions, e.g. const_cast, reinterpret_cast, ... do not
    // seem to work. back to plain c-type cast
    if (munmap((*addr), len * sizeof(uint32_t)) < 0) {
        ERROR("%s: %s", error_msg, strerror(errno));
    }
    // invalidate the pointer
    (*addr) = nullptr;
}

void MudaqDevice::munmap_wrapper(volatile uint32_t** addr, unsigned len,
                                 const std::string& error_msg)
{
    // cast away volatility. not required for munmap
    uint32_t** tmp = (uint32_t**)(addr);
    munmap_wrapper(tmp, len, error_msg);
}

// ----------------------------------------------------------------------------
// DmaMudaqDevice

  DmaMudaqDevice::DmaMudaqDevice(const string& path) :
    MudaqDevice(path), _dmabuf_ctrl(nullptr), _last_end_of_buffer(0)
  {
    // boring
  }


  bool DmaMudaqDevice::open()
  {
#ifdef NO_SWITCHING_BOARD
    std::cout << "Dummy DMA mudaq: open()" << std::endl;
    return true;
#else
    if (!MudaqDevice::open()) return false;
    _dmabuf_ctrl = mmap_ro(MUDAQ_DMABUF_CTRL_INDEX, MUDAQ_DMABUF_CTRL_WORDS);
    return (_dmabuf_ctrl != nullptr);
#endif
  }

  void DmaMudaqDevice::close()
  {
#ifdef NO_SWITCHING_BOARD
    std::cout << "Dummy DMA mudaq: close()" << std::endl;
#else
    munmap_wrapper(&_dmabuf_ctrl, MUDAQ_DMABUF_CTRL_WORDS, "could not unmap dma control buffer");
    MudaqDevice::close();
#endif
  }

  bool DmaMudaqDevice::operator!() const
  {
    return MudaqDevice::operator!() || (_dmabuf_ctrl == nullptr);
      //|| (_dmabuf_data == nullptr);
  }

  int DmaMudaqDevice::read_block(DataBlock& buffer,  volatile uint32_t * pinned_data)
  {
      uint32_t end_write = _dmabuf_ctrl[3]>>2; // dma address next to be written to (last written to + 1) (in words)
      if(end_write==0) // This is problematic if runs get bigger than the DMA bufer
           return READ_NODATA;
     // cout <<hex<< interrupt << ", "<<end_write<<endl;
      size_t begin = _last_end_of_buffer & MUDAQ_DMABUF_DATA_WORDS_MASK;
      size_t end = (end_write-1) & MUDAQ_DMABUF_DATA_WORDS_MASK;
      size_t len = ((end - begin+1) & MUDAQ_DMABUF_DATA_WORDS_MASK);

      if(len == 0){
          return READ_NODATA;
      }

    _last_end_of_buffer = end + 1;


    buffer = DataBlock( pinned_data, begin, len );
    return READ_SUCCESS;
}

int DmaMudaqDevice::get_current_interrupt_number()
{
  int interrupt_number;
  int ret_val = ioctl( _fd, REQUEST_INTERRUPT_COUNTER, &interrupt_number);
  if ( ret_val == -1 ) {
    printf("Requesting the interrupt number failed with %d \n", errno);
    return ret_val;
  }
  else
    return interrupt_number;
}

// in words!
uint32_t DmaMudaqDevice::last_written_addr() const
{
    // returns: remoteaddress_var <= remoteaddress_var + (packet_length & "00");
    // shifted by two bits
    return (_dmabuf_ctrl[3]>>2);

}

uint32_t DmaMudaqDevice::last_endofevent_addr() const
{
    // returns: d0 := memwriteaddreoedma_long(31 downto 0);
    return _dmabuf_ctrl[0];
}

// enable interrupts
int DmaMudaqDevice::enable_continous_readout(int interTrue)
{

   _last_end_of_buffer = 0;
  if (interTrue == 1){
    write_register(DMA_REGISTER_W, 0x9);
  }
  else {
    write_register(DMA_REGISTER_W, SET_DMA_BIT_ENABLE(0x0));
  }
  return 0;
}

void DmaMudaqDevice::disable()
{
   write_register(DMA_REGISTER_W, UNSET_DMA_BIT_ENABLE(0x0));
}


// ----------------------------------------------------------------------------
// convenience output functions

ostream& operator<<(ostream& os, const MudaqDevice& dev)
{
    os << "MudaqDevice '" << dev._path << "' "
       << "status: " << (!dev ? "ERROR" : "ok");
    return os;
}





} // namespace mudaq
