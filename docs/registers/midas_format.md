For the data from the FPGA we create MIDAS events using the 32-bit banks 64-bit aligned format: https://daq00.triumf.ca/MidasWiki/index.php/Event_Structure.
Each bank contains time sorted 64-bit hits from the MuPix or the MuTRiG.
Overall one event can hold up to 100 of these banks with the bank name HT00-HT99.
The hit formats have following structure:

MuPix hit format
----

| Bits  | Width | Field          | C++ accessor equivalent    | Description             |
| ----- | ----- | -------------- | -------------------------- | ----------------------- |
| 63    | 1     | indicator      | `is_pixel()`               | `true` for MuPix        |
| 62–58 | 5     | chipid         | `chipid()`                 | Global chip ID          |
| 57–50 | 8     | col            | `col()`                    | Column index            |
| 49–42 | 8     | row            | `row()`                    | Row index               |
| 41–37 | 5     | tot / t2       | `tot()` / `t2()`           | Time-over-threshold     |
| 36–16 | 21    | ts_high        | `time()` (part)            | Timestamp high          |
| 15–11 | 5     | ts_low         | `time()` (part)            | Timestamp mid           |
| 10–4  | 7     | subheader_time | `time()` (part)            | Subheader timing        |
| 3–0   | 4     | ts_sorterhit   | `time()` (part)            | Hit timestamp sorter    |

MuTRiG hit format
----

| Bits  | Width | Field          | C++ accessor equivalent      | Description              |
| ----- | ----- | -------------- | ---------------------------- | ------------------------ |
| 63    | 1     | indicator      | `is_mutrig()`                | `true` for MuTRiG        |
| 62–61 | 2     | chipid         | `asic()`                     | ASIC ID                  |
| 60–56 | 5     | channel        | `channel()`                  | Channel ID               |
| 55–47 | 9     | e-t            | `tot()` / `eflag()`          | Energy or short-hit flag |
| 46–44 | 3     | time_remainder | —                            | 1.6 ns remainder bits    |
| 43–39 | 5     | fine_time      | —                            | Fine timestamp           |
| 38–16 | 23    | ts_high        | `time()` (part)              | Timestamp high           |
| 15–12 | 4     | ts_low         | `time()` (part)              | Timestamp mid            |
| 11–4  | 8     | subheader_time | `time()` (part)              | Subheader timing         |
| 3–0   | 4     | ts_sorterhit   | `time()` (part)              | Hit timestamp sorter     |


And in structs:
```cpp
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

```

To extract the banks from the MIDAS event the following analyze function can be used:
```cpp
TAFlowEvent* AnaFillHits::Analyze(TARunInfo* runinfo, TMEvent* event, TAFlags* flags, TAFlowEvent* flow) {
    // If this module is disabled, don't do anything.
    if(!enabled_) {
        *flags |= TAFlag_SKIP_PROFILE;
        return flow;
    }

    // Only process readout events
    if(event->event_id != 301) return flow;

    // ----------------------------------------
    // Build event header
    // ----------------------------------------
    eventheader h;
    h.event_id         = event->event_id;
    h.trigger_mask     = event->trigger_mask;
    h.serial_number    = event->serial_number;
    h.midas_time_stamp = event->time_stamp;
    h.data_size        = event->data_size;

    const uint32_t sr_num = h.serial_number;
    SrNo->Fill(static_cast<double>(sr_num));

    // ----------------------------------------
    // Scan MIDAS banks
    // ----------------------------------------
    event->FindAllBanks();

    for(const auto& bank : event->banks) {
        const std::string firstTwoChars = bank.name.substr(0, 2);
        const char* rawData = event->GetBankData(&bank);

        // ----------------------------------------
        // HTxx bank: mixed hit bank
        // ----------------------------------------
        if(firstTwoChars == "HT") {
            const hit* dataStart = reinterpret_cast<const hit*>(rawData);
            const hit* dataEnd   = reinterpret_cast<const hit*>(rawData + bank.data_size);

            hits_.reserve(hits_.size() + (dataEnd - dataStart));

            for(const hit* current = dataStart; current != dataEnd; ++current) {
                // Optional validation / monitoring can be added here
                // Example:
                //   if(current->is_pixel()) { auto p = current->as_pixel(); ... }
                //   else                    { auto m = current->as_mutrig(); ... }

                hits_.emplace_back(*current);
            }
        }
    }

    // ----------------------------------------
    // Optional monitoring of mixed hits
    // ----------------------------------------
    for(const auto& hhit : hits_) {
        if(hhit.is_pixel()) {
            const auto p = hhit.as_pixel();
            timestamp->Fill(static_cast<double>(p.time()));
            SrNo_ts->Fill(static_cast<double>(sr_num), static_cast<double>(p.time()));
        } else {
            const auto m = hhit.as_mutrig();
            SrNo_ts_mutrig->Fill(static_cast<double>(sr_num), static_cast<double>(m.time()));
        }
    }

    // ----------------------------------------
    // Package hits into flow event
    // ----------------------------------------
    flow = new HitVectorFlowEvent(flow, h, std::move(hits_));

    // After std::move, reset to default state
    hits_ = std::vector<hit>();

    return flow;
}
```