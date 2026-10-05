//

#include "mudaq_device.h"

#include <fcntl.h>
#include <sys/mman.h>
#include <chrono>
#include <list>

constexpr uint32_t nreqPkg = 0xFFFE, nreqSH = 128, nreqHits = 2;

mudaq::DmaMudaqDevice mu("/dev/mudaq0");
const size_t RB_SIZE = MUDAQ_DMABUF_DATA_LEN;

struct reg_t {
    uint32_t addr;
    std::string name;
    uint32_t addr_sel = UINT32_MAX;
    uint32_t sel = UINT32_MAX;
    uint32_t last = 0;
    bool valid = false;
    uint32_t operator()() {
        if(addr_sel != UINT32_MAX) {
            mu.write_register(addr_sel, sel);
        }
        auto x = mu.read_register_ro(addr);
        if(!valid || x != last) {
            last = x;
            valid = true;
        }
        return x;
    }
    void operator()(uint32_t x) {
        if(!valid || x != last) {
            last = x;
            valid = true;
        }
        mu.write_register(addr, x);
    }
};
reg_t rrSTATUS = {EVENT_BUILD_STATUS_REGISTER_R, "STATUS"};
reg_t rrHALF_FULL = {DMA_HALFFUL_REGISTER_R, "HALF_FULL"};
reg_t rwRESET = {RESET_REGISTER_W, "RESET"};
reg_t rwDMA = {DMA_REGISTER_W, "DMA"};
reg_t rwDMA_N_WORDS = {GET_N_DMA_WORDS_REGISTER_W, "DMA_N_WORDS"};

uint32_t g_N_MUX                = 6;
uint32_t g_LINKS                = 24;
uint32_t C_CNT_GEN_HITS         = 0;
uint32_t C_SUBH_CNT_BASE        = 1;
uint32_t C_HIT_CNT_BASE         = C_SUBH_CNT_BASE + g_LINKS;
uint32_t C_PACKAGE_CNT_BASE     = C_HIT_CNT_BASE + g_LINKS;
uint32_t C_WORD_CNT_BASE        = C_PACKAGE_CNT_BASE + g_LINKS;
uint32_t C_ERROR_BASE           = C_WORD_CNT_BASE + g_N_MUX;
uint32_t C_WRITE_CNT_BASE       = C_ERROR_BASE + g_N_MUX;
uint32_t C_READ_CNT_BASE        = C_WRITE_CNT_BASE + g_N_MUX;
uint32_t C_OVERFLOW_CNT_BASE    = C_READ_CNT_BASE + g_N_MUX;
uint32_t C_HIT_DROP_CNT         = C_OVERFLOW_CNT_BASE + g_N_MUX;
uint32_t C_MERGER_ERROR         = C_HIT_DROP_CNT + g_N_MUX;
uint32_t C_ALIAS_CNT            = C_MERGER_ERROR + g_N_MUX;
uint32_t C_TIMOUT_CNT           = C_ALIAS_CNT + g_N_MUX;
uint32_t C_LATE_HIT_CNT         = C_TIMOUT_CNT + g_N_MUX;
uint32_t C_FULL_CNT             = C_LATE_HIT_CNT + g_N_MUX;
uint32_t C_HIT_CNT              = C_FULL_CNT + 1;
uint32_t C_INPUT_HIT_CNT        = C_HIT_CNT + 1;
uint32_t C_FIFO_FULL            = C_INPUT_HIT_CNT + 1;
uint32_t C_N_COUNTERS           = C_FIFO_FULL + 1;

reg_t rrCNT_GEN     = {SWB_COUNTER_REGISTER_R, "CNT_GEN"            , SWB_COUNTER_REGISTER_W, 0     };
reg_t rrCNT_SH0     = {SWB_COUNTER_REGISTER_R, "CNT_SH0"            , SWB_COUNTER_REGISTER_W, 1+0*24+0};
reg_t rrCNT_SH1     = {SWB_COUNTER_REGISTER_R, "CNT_SH1"            , SWB_COUNTER_REGISTER_W, 1+0*24+1};
reg_t rrCNT_SH2     = {SWB_COUNTER_REGISTER_R, "CNT_SH2"            , SWB_COUNTER_REGISTER_W, 1+0*24+2};
reg_t rrCNT_SH3     = {SWB_COUNTER_REGISTER_R, "CNT_SH3"            , SWB_COUNTER_REGISTER_W, 1+0*24+3};
reg_t rrCNT_HIT0    = {SWB_COUNTER_REGISTER_R, "CNT_HIT0"           , SWB_COUNTER_REGISTER_W, 1+1*24+0};
reg_t rrCNT_HIT1    = {SWB_COUNTER_REGISTER_R, "CNT_HIT1"           , SWB_COUNTER_REGISTER_W, 1+1*24+1};
reg_t rrCNT_HIT2    = {SWB_COUNTER_REGISTER_R, "CNT_HIT2"           , SWB_COUNTER_REGISTER_W, 1+1*24+2};
reg_t rrCNT_HIT3    = {SWB_COUNTER_REGISTER_R, "CNT_HIT3"           , SWB_COUNTER_REGISTER_W, 1+1*24+3};
reg_t rrCNT_PKG0    = {SWB_COUNTER_REGISTER_R, "CNT_PKG0"           , SWB_COUNTER_REGISTER_W, 1+2*24+0};
reg_t rrCNT_PKG1    = {SWB_COUNTER_REGISTER_R, "CNT_PKG1"           , SWB_COUNTER_REGISTER_W, 1+2*24+1};
reg_t rrCNT_PKG2    = {SWB_COUNTER_REGISTER_R, "CNT_PGK2"           , SWB_COUNTER_REGISTER_W, 1+2*24+2};
reg_t rrCNT_PKG3    = {SWB_COUNTER_REGISTER_R, "CNT_PGK3"           , SWB_COUNTER_REGISTER_W, 1+2*24+3};
reg_t rrCNT_WORD    = {SWB_COUNTER_REGISTER_R, "CNT_WORD"           , SWB_COUNTER_REGISTER_W, C_WORD_CNT_BASE};
reg_t rrCNT_WRITE   = {SWB_COUNTER_REGISTER_R, "CNT_WRITE"          , SWB_COUNTER_REGISTER_W, C_WRITE_CNT_BASE};
reg_t rrCNT_READ    = {SWB_COUNTER_REGISTER_R, "CNT_READ"           , SWB_COUNTER_REGISTER_W, C_READ_CNT_BASE};
reg_t rrCNT_OVF     = {SWB_COUNTER_REGISTER_R, "CNT_OVF"            , SWB_COUNTER_REGISTER_W, C_OVERFLOW_CNT_BASE};
reg_t rrCNT_ALI     = {SWB_COUNTER_REGISTER_R, "CNT_ALI"            , SWB_COUNTER_REGISTER_W, C_ALIAS_CNT};
reg_t rrCNT_TIM     = {SWB_COUNTER_REGISTER_R, "CNT_TIM"            , SWB_COUNTER_REGISTER_W, C_TIMOUT_CNT};
reg_t rrCNT_LATE    = {SWB_COUNTER_REGISTER_R, "CNT_LATE"           , SWB_COUNTER_REGISTER_W, C_LATE_HIT_CNT};
reg_t rrCNT_DROP    = {SWB_COUNTER_REGISTER_R, "CNT_DROP"           , SWB_COUNTER_REGISTER_W, C_HIT_DROP_CNT};
reg_t rrCNT_FULL    = {SWB_COUNTER_REGISTER_R, "CNT_FULL"           , SWB_COUNTER_REGISTER_W, C_FULL_CNT};
reg_t rrCNT_256     = {SWB_COUNTER_REGISTER_R, "CNT_256"            , SWB_COUNTER_REGISTER_W, C_HIT_CNT};
reg_t rrCNT_INPUT   = {SWB_COUNTER_REGISTER_R, "CNT_INPUT"          , SWB_COUNTER_REGISTER_W, C_INPUT_HIT_CNT};

struct link_t {
    int link = 0;

    static constexpr uint32_t N_SH = 1024;
    // number of hits per sub-header
    // (ring-buffer indexed by sub-header timestamp)
    uint16_t nHs[N_SH];
    uint64_t ts_min = 0, ts_max = 0;
    uint64_t ts_last = 0;

    // number of missing timestamps
    size_t nMis = 0;

    ~link_t() {
        while(ts_min/16 < (ts_max+15)/16) {
            pop(ts_min);
            ts_min += 16;
        }
        if(nMis == 0) return;
        printf("n_lost[%d] = %d\n", link, nMis);
    }

    void push(uint64_t ts) {
        uint16_t& nH = nHs[ts/16 % N_SH];
        if(nH > nreqHits) {
            printf("duplicate timestamp: link = %d, ts = 0x%08X\n", link, ts);
        }
        else {
            nH += 1;
        }
    }

    void pop(uint64_t ts) {
        auto _nreqHits = nreqHits;
        if(ts/16 % nreqSH >= nreqSH) _nreqHits = 0;

        uint16_t& nH = nHs[ts/16 % N_SH];
        if(nH < _nreqHits) {
            //printf("missing timestamp: link = %d, ts = 0x%08X, nH = %d\n", link, ts, nH);
            nMis += _nreqHits - nH;
        }
        if(nH > _nreqHits) {
            printf("unexpected timestamp: link = %d, ts = 0x%08X, nH = %d\n", link, ts, nH);
        }
        nH = 0;
    }

    void add_hit(uint64_t hit) {
        uint64_t ts = (ts_last & 0xFFFFFFFF00000000) | (hit & 0xFFFFFFFF);
        if(ts_last == 0) ts_last = ts;
        if((ts_last & 0xFFFFFFFF) >= 0xC0000000 && (ts & 0xFFFFFFFF) < 0x40000000) {
            // handle timestamp wrap
            ts += 0x100000000;
        }
        ts_last = ts;

        if(ts > ts_max) ts_max = ts;
        while(ts_min/16 + N_SH <= (ts_max+15)/16) {
            pop(ts_min);
            ts_min += 16;
        }
        push(ts);
    }
} links[24];

// NOTE: maximum block size is 256 kB
constexpr size_t BLOCK_SIZE = 256*1024;
std::mutex mutex;
std::atomic<int> stop = 0;

size_t n256 = 0, n64 = 0, nHits = 0;
size_t nOoO = 0;

void process_hits(const uint64_t* data, size_t n) {
    size_t _n256 = 0;
    for(size_t i = 0; i < n; i += 4) {
        if(data[i+0] == UINT64_MAX && data[i+1] == UINT64_MAX && data[i+2] == UINT64_MAX && data[i+3] == UINT64_MAX) {
            continue;
        }
        _n256 += 1;
    }

    uint64_t ts_last = 0;

    size_t _nFF = 0, _nSH = 0, _nHits = 0;
    for(size_t i = 0; i < n; i++) {
        auto hit = data[i];

        if(hit == UINT64_MAX) {
            // filler
            _nFF += 1;
            continue;
        }
        if((hit >> 62) == 0b11) {
            // debug
            _nFF += 1;
            continue;
        }
        if((hit >> 62) == 0b00) {
           // subheaders
           _nSH += 1;
           continue;
        }

        _nHits += 1;

        uint64_t ts = (ts_last & 0xFFFFFFFF00000000) | (hit & 0xFFFFFFFF);
        if(ts_last == 0) ts_last = ts;
        if((ts_last & 0xFFFFFFFF) >= 0xC0000000 && (ts & 0xFFFFFFFF) < 0x40000000) {
            // handle timestamp wrap
            ts += 0x100000000;
        }
        if(ts + 16 < ts_last) {
            //printf("out-of-order timestamp: ts = 0x%08X, ts_last = 0x%08X\n", ts, ts_last);
            nOoO += 1;
        }
        ts_last = ts;
    }
    n256 += _n256;
    n64 += _nSH + _nHits;
    nHits += _nHits;
}

int main(int argc, const char* argv[]) {

    uint8_t* dmabuf;
    int fd = open("/dev/mudaq0_dmabuf", O_RDWR);
    if (fd < 0) {
        printf("fd = %d\n", fd);
        return -1;
    }
    dmabuf = reinterpret_cast<uint8_t*>(
        mmap(nullptr, MUDAQ_DMABUF_DATA_LEN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0));

    if (dmabuf == MAP_FAILED) {
        return -1;
    }

    mu.open();

    // disable dma
    rwDMA(0x0);
    rwDMA_N_WORDS(0x0);

    // reset
    rwRESET(0xFFFFFFFF);
    usleep(10);
    rwRESET(0x0);

    // enable dma
    rwDMA(0x1);

    // configure generators
    //mu.write_register(SWB_GENERIC_MASK_REGISTER_W, 0xFFFFFF);
    mu.write_register(SWB_GENERIC_MASK_REGISTER_W, 0xF);
    mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, (nreqPkg << 16) | (nreqHits << 8) | (nreqSH << 0));
    // start generators
    mu.write_register(SWB_READOUT_STATE_REGISTER_W, 0);
    uint32_t readout_state_regs = 0;
    readout_state_regs = SET_USE_BIT_GEN_LINK(readout_state_regs);
    mu.write_register(SWB_READOUT_STATE_REGISTER_W, readout_state_regs);

    for(size_t i = 0; i < sizeof(links)/sizeof(links[0]); i++) {
        links[i].link = i;
    }

    auto clock_start = std::chrono::steady_clock::now(), clock_end = clock_start;
    int rb_full_n = 0;
    auto rb_full_clock = std::chrono::steady_clock::now();

    size_t nBlocks = 0;

    size_t rb_wptr = 0, rb_rptr = 0;
    while(1) {

        // update ring-buffer write pointer
        if(auto wptr = sizeof(uint32_t) * mu.last_written_addr(); rb_wptr != wptr) {
            rb_wptr = wptr;
            //printf("rptr/wptr = (%d)%08X/%08X\n", rb_rptr / RB_SIZE, rb_rptr % RB_SIZE, rb_wptr % RB_SIZE);
        }

        uint32_t rb_used = (rb_wptr % RB_SIZE - rb_rptr % RB_SIZE) % RB_SIZE;
        if(rb_used + 2*BLOCK_SIZE >= RB_SIZE) {
            rb_full_n += 1;
            if(std::chrono::steady_clock::now() > rb_full_clock + std::chrono::milliseconds(1000)) {
                mu.write_register(SWB_COUNTER_REGISTER_W, C_HIT_DROP_CNT);
                auto cnt_drop256 = mu.read_register_ro(SWB_COUNTER_REGISTER_R);
                printf("ring-buffer is full (%d times): drop256 = 0x%08X\n", rb_full_n, cnt_drop256);
                rb_full_n = 0;
                rb_full_clock = std::chrono::steady_clock::now();
            }
        }

        // request more dma transfers
        // NOTE: `GET_N_DMA_WORDS_REGISTER_W` is used to request more data on-the-fly,
        //       i.e. one can request more data from `*_event_builder` while DMA readout is active
        // - in `farm_event_builder` `N_DMA_WORDS` counts in units of 512 kB
        // - in `hit_event_builder` `N_DMA_WORDS` counts in units of 256 bits
        if(rb_used + BLOCK_SIZE < RB_SIZE) {
            auto nWords = (rb_rptr + RB_SIZE - BLOCK_SIZE) / (256/8);
            mu.write_register(GET_N_DMA_WORDS_REGISTER_W, nWords);
        }

        rb_rptr += BLOCK_SIZE;
        nBlocks += 1;
        if(nBlocks % 1000 == 0) printf("nBlocks = %d\n", nBlocks);

        clock_end = std::chrono::steady_clock::now();
    }
    stop = 1;
    printf("DONE\n");

    if(nOoO > 0) printf("%d out-of-order timestamps\n", nOoO);

    printf("\n");
    printf("   ");
    for(int i = 0; i < 8; i++) {
        printf("         %02d", i);
    }
    printf("\n");
    printf("PKG");
    for(int i = 0; i < 8; i++) {
        mu.write_register(SWB_COUNTER_REGISTER_W, 1+2*24+i);
        printf(" 0x%08X", mu.read_register_ro(SWB_COUNTER_REGISTER_R));
    }
    printf("\n");
    printf("SH ");
    for(int i = 0; i < 8; i++) {
        mu.write_register(SWB_COUNTER_REGISTER_W, 1+0*24+i);
        printf(" 0x%08X", mu.read_register_ro(SWB_COUNTER_REGISTER_R));
    }
    printf("\n");
    printf("HIT");
    for(int i = 0; i < 8; i++) {
        mu.write_register(SWB_COUNTER_REGISTER_W, 1+1*24+i);
        printf(" 0x%08X", mu.read_register_ro(SWB_COUNTER_REGISTER_R));
    }
    printf("\n");

    auto hit_cnt = 0;
    for(int i = 0; i < 24; i++) {
        mu.write_register(SWB_COUNTER_REGISTER_W, 1+1*24+i);
        hit_cnt += mu.read_register_ro(SWB_COUNTER_REGISTER_R);
    }

    rrCNT_FULL();

    rrCNT_WRITE();
    rrCNT_READ();
    rrCNT_OVF();
    rrCNT_ALI();
    rrCNT_TIM();
    rrCNT_LATE();

    rrCNT_WORD();
    rrCNT_INPUT();
    auto cnt_256 = rrCNT_256();
    auto cnt_drop = rrCNT_DROP();
    printf("nHits = 0x%08X -- nCntHits = 0x%08X\n", nHits, hit_cnt - cnt_drop);
    printf("n64 = 0x%08X\n", n64);
    printf("n256 = 0x%08X -> %s\n", n256, n256 == cnt_256 ? "GOOD" : "BAD");

    auto clock = std::chrono::duration<double>(clock_end - clock_start).count();
    printf("clock = %.3f seconds\n", clock);
    printf("nBlocks = 0x%08X -> rate = %.1f MB/s\n", nBlocks, nBlocks*BLOCK_SIZE / clock / (1024*1024));

    // disable dma
    rwDMA(0x0);
    rwDMA_N_WORDS(0x0);

    // reset
    //rwRESET(0xFFFFFFFF);
    //usleep(10);
    //rwRESET(0x0);

    mu.close();

    return EXIT_SUCCESS;
}
