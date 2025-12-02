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


struct mutrighit {
    mutrighit() noexcept:hitdata(0x00){};
    mutrighit(uint64_t h) noexcept:hitdata(h){};
    uint64_t hitdata;
    [[nodiscard]] uint8_t  overflowFlags()   const {return (hitdata >> 62) & 0x3; }
    [[nodiscard]] bool     had_overflow()    const {return (hitdata >> 63) & 0x1;}
    [[nodiscard]] bool     had_suboverflow() const {return (hitdata >> 62) & 0x1;}

    [[nodiscard]] uint16_t channel()         const {return (hitdata >> 48) & 0x3fff;}
    [[nodiscard]] uint16_t asic()            const {return (hitdata >> 48) & 0x1f;}

    [[nodiscard]] bool     eflag()           const {return (hitdata >> 47) & 0x1;}
    [[nodiscard]] uint16_t tot()             const {return (hitdata >> 32) & 0x1FF;}

    [[nodiscard]] uint8_t finetime_extended() const{return (hitdata >>  0) & 0xFF;}
    [[nodiscard]] uint32_t time8ns()         const {return (hitdata >> 8) & 0xFFFFFF;}
    [[nodiscard]] int64_t timestamp()        const {return time8ns()*160 + finetime_extended();} //returns time in units of 50ps
    [[nodiscard]] int64_t time()             const {return timestamp()*50e-3;} //returns time in ns

    void Print(){
        printf("x64:%llx channel:%2.2x tot:%u t:%u time:%8.8x\n", hitdata, channel(), tot(), timestamp(), time());
    }
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
