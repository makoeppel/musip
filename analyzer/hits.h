#ifndef HITS_H
#define HITS_H

#include <stdint.h>
#include <cstdio>

struct pixelhit {
    pixelhit() noexcept : hitdata(0x0) {}
    pixelhit(uint64_t h) noexcept : hitdata(h) {}

    uint64_t hitdata;

    [[nodiscard]] bool is_pixel() const { return ((hitdata >> 63) & 0x1) == 0; }
    [[nodiscard]] uint8_t chipid() const { return (hitdata >> 58) & 0x1F; }
    [[nodiscard]] uint8_t col() const { return (hitdata >> 50) & 0xFF; }
    [[nodiscard]] uint8_t row() const { return (hitdata >> 42) & 0xFF; }
    [[nodiscard]] uint8_t tot() const { return (hitdata >> 37) & 0x1F; }
    [[nodiscard]] uint8_t t2() const { return tot(); }
    [[nodiscard]] uint32_t ts_high() const { return (hitdata >> 16) & 0x1FFFFF; }
    [[nodiscard]] uint8_t ts_low() const { return (hitdata >> 11) & 0x1F; }
    [[nodiscard]] uint8_t subheader_time() const { return (hitdata >> 4) & 0x7F; }
    [[nodiscard]] uint8_t ts_sorterhit() const { return hitdata & 0xF; }
    [[nodiscard]] uint64_t time() const { return hitdata & 0x1FFFFFFFFFULL; }

    void Print() const {
        std::printf(
            "x64:%016llx chipid:%02x col:%u row:%u tot:%u time:%010llx\n",
            (unsigned long long)hitdata,
            chipid(),
            col(),
            row(),
            tot(),
            (unsigned long long)time()
        );
    }
};

struct mutrighit {
    mutrighit() noexcept : hitdata(0x0) {}
    mutrighit(uint64_t h) noexcept : hitdata(h) {}

    uint64_t hitdata;

    [[nodiscard]] bool is_mutrig() const { return ((hitdata >> 63) & 0x1) == 1; }
    [[nodiscard]] uint8_t chipid() const { return (hitdata >> 61) & 0x3; }
    [[nodiscard]] uint8_t asic() const { return chipid(); }
    [[nodiscard]] uint8_t channel() const { return (hitdata >> 56) & 0x1F; }
    [[nodiscard]] uint16_t et() const { return (hitdata >> 47) & 0x1FF; }
    [[nodiscard]] bool eflag() const { return et() == 0x1FF; }
    [[nodiscard]] uint16_t tot() const { return et(); }
    [[nodiscard]] uint8_t time_remainder() const { return (hitdata >> 44) & 0x7; }
    [[nodiscard]] uint8_t fine_time() const { return (hitdata >> 39) & 0x1F; }
    [[nodiscard]] uint32_t ts_high() const { return (hitdata >> 16) & 0x7FFFFF; }
    [[nodiscard]] uint8_t ts_low() const { return (hitdata >> 12) & 0xF; }
    [[nodiscard]] uint8_t subheader_time() const { return (hitdata >> 4) & 0xFF; }
    [[nodiscard]] uint8_t ts_sorterhit() const { return hitdata & 0xF; }
    [[nodiscard]] uint64_t time() const { return hitdata & 0x7FFFFFFFFFULL; }

    void Print() const {
        std::printf(
            "x64:%016llx chipid:%u channel:%u et:%u rem:%u fine:%u time:%010llx\n",
            (unsigned long long)hitdata,
            chipid(),
            channel(),
            et(),
            time_remainder(),
            fine_time(),
            (unsigned long long)time()
        );
    }

};

struct hit {
    hit() noexcept : hitdata(0x0) {}
    explicit hit(uint64_t h) noexcept : hitdata(h) {}

    uint64_t hitdata;

    // Common discriminator
    [[nodiscard]] bool is_pixel() const  { return ((hitdata >> 63) & 0x1) == 0; }
    [[nodiscard]] bool is_mutrig() const { return ((hitdata >> 63) & 0x1) == 1; }

    // Convert to typed views
    [[nodiscard]] pixelhit as_pixel() const { return pixelhit(hitdata); }
    [[nodiscard]] mutrighit as_mutrig() const { return mutrighit(hitdata); }

    // helper
    [[nodiscard]] uint64_t raw() const { return hitdata; }

    void Print() const {
        if(is_pixel()) {
            as_pixel().Print();
        } else {
            as_mutrig().Print();
        }
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
