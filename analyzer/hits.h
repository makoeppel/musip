#ifndef HITS_H
#define HITS_H

#include <stdint.h>
#include <cstdio>

struct pixelhit {
    pixelhit(uint64_t h) noexcept:hitdata(h){};
    uint64_t hitdata;
    [[nodiscard]] uint8_t overflowFlags() const { return (hitdata >> 62) & 0x3; }
    [[nodiscard]] uint32_t chipid() const {return (hitdata >> 48) & 0x3FFF; }
    [[nodiscard]] uint8_t col() const {return (hitdata >> 40) & 0xFF;}
    [[nodiscard]] uint8_t row() const {return (hitdata >> 32) & 0xFF;}
    [[nodiscard]] uint8_t tot() const {return (hitdata >> 27) & 0x1F;}
    [[nodiscard]] uint8_t t2() const {return (hitdata >> 27) & 0x1F;}
    [[nodiscard]] uint32_t time() const {return hitdata & 0x7FFFFFF;}
    [[nodiscard]] uint8_t layer() const {return -1;}

    void Print(){
        printf("x64:%llx chipid:%2.2x col:%u row:%u tot:%u t2:%u time:%8.8x\n", hitdata, chipid(), col(), row(), tot(), t2(), time());
    }

    // Implement less than operator so that we can put in std::set etc.
    bool operator<(const pixelhit& other) const { return hitdata < other.hitdata; }
};

struct febdata {
    uint32_t header;
    uint32_t ts_high;
    uint16_t package_counter, ts_low;
    uint32_t debug0;
    uint32_t debug1;
    uint16_t shead_cnt; uint8_t header_cnt, __zero;
    uint32_t __AFFEAFFE[6];
};

struct eventheader {
    uint16_t event_id;
    uint16_t trigger_mask;
    uint32_t serial_number;
    uint32_t midas_time_stamp;
    uint32_t data_size;
};

#endif
