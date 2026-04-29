/**
 * Snapshot the current SWB DMA ring buffer without changing readout state.
 *
 * This tool is intentionally read-only against the FPGA register model: it maps
 * the MUDAQ device and DMA buffer, records status registers and a bounded window
 * of DMA words, then exits. Use another explicit setup tool to arm/reset DMA.
 */

#include "mudaq_device.h"

#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <chrono>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

namespace {

struct Options {
    std::string device = "/dev/mudaq0";
    std::string dmabuf = "/dev/mudaq0_dmabuf";
    std::string output;
    std::string around = "eoe";
    std::string format = "text";
    std::size_t words = 256;
    uint32_t start_word = 0;
    uint32_t wait_done_ms = 0;
    bool has_start_word = false;
};

struct RegisterValue {
    std::string name;
    uint32_t value;
};

[[noreturn]] void usage(const char* argv0, int exit_code) {
    std::ostream& os = exit_code == 0 ? std::cout : std::cerr;
    os << "Usage: " << argv0 << " [options]\n\n"
       << "Read-only SWB DMA snapshot options:\n"
       << "  --device PATH          MUDAQ device path (default: /dev/mudaq0)\n"
       << "  --dmabuf PATH          DMA buffer device path (default: /dev/mudaq0_dmabuf)\n"
       << "  --out PATH             Write snapshot to PATH instead of stdout\n"
       << "  --format text|csv      Output format (default: text)\n"
       << "  --words N              Number of 32-bit DMA words to dump (default: 256)\n"
       << "  --start WORD           First DMA word index; wraps at the ring size\n"
       << "  --around eoe|write|zero\n"
       << "                         Center dump on end-of-event, write pointer, or zero\n"
       << "                         when --start is not set (default: eoe)\n"
       << "  --wait-done-ms N       Poll EVENT_BUILD_STATUS bit 0 before snapshot\n"
       << "  -h, --help             Show this help\n";
    std::exit(exit_code);
}

std::string take_value(int& idx, int argc, char* argv[], const std::string& opt) {
    if (++idx >= argc) {
        throw std::runtime_error(opt + " requires a value");
    }
    return argv[idx];
}

uint64_t parse_u64(const std::string& text, const std::string& opt) {
    char* end = nullptr;
    errno = 0;
    const unsigned long long value = std::strtoull(text.c_str(), &end, 0);
    if (errno != 0 || end == text.c_str() || *end != '\0') {
        throw std::runtime_error("invalid numeric value for " + opt + ": " + text);
    }
    return static_cast<uint64_t>(value);
}

Options parse_args(int argc, char* argv[]) {
    Options opt;
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "-h" || arg == "--help") {
            usage(argv[0], 0);
        } else if (arg == "--device") {
            opt.device = take_value(i, argc, argv, arg);
        } else if (arg == "--dmabuf") {
            opt.dmabuf = take_value(i, argc, argv, arg);
        } else if (arg == "--out") {
            opt.output = take_value(i, argc, argv, arg);
        } else if (arg == "--format") {
            opt.format = take_value(i, argc, argv, arg);
        } else if (arg == "--words") {
            const uint64_t value = parse_u64(take_value(i, argc, argv, arg), arg);
            if (value == 0 || value > MUDAQ_DMABUF_DATA_WORDS) {
                throw std::runtime_error("--words must be in 1.." +
                                         std::to_string(MUDAQ_DMABUF_DATA_WORDS));
            }
            opt.words = static_cast<std::size_t>(value);
        } else if (arg == "--start") {
            const uint64_t value = parse_u64(take_value(i, argc, argv, arg), arg);
            if (value > std::numeric_limits<uint32_t>::max()) {
                throw std::runtime_error("--start does not fit in 32 bits");
            }
            opt.start_word = static_cast<uint32_t>(value);
            opt.has_start_word = true;
        } else if (arg == "--around") {
            opt.around = take_value(i, argc, argv, arg);
        } else if (arg == "--wait-done-ms") {
            const uint64_t value = parse_u64(take_value(i, argc, argv, arg), arg);
            if (value > std::numeric_limits<uint32_t>::max()) {
                throw std::runtime_error("--wait-done-ms does not fit in 32 bits");
            }
            opt.wait_done_ms = static_cast<uint32_t>(value);
        } else {
            throw std::runtime_error("unknown option: " + arg);
        }
    }

    if (opt.format != "text" && opt.format != "csv") {
        throw std::runtime_error("--format must be text or csv");
    }
    if (opt.around != "eoe" && opt.around != "write" && opt.around != "zero") {
        throw std::runtime_error("--around must be eoe, write, or zero");
    }
    return opt;
}

uint32_t ring_add(uint32_t base, int64_t delta) {
    const int64_t ring_words = static_cast<int64_t>(MUDAQ_DMABUF_DATA_WORDS);
    int64_t value = static_cast<int64_t>(base & MUDAQ_DMABUF_DATA_WORDS_MASK) + delta;
    value %= ring_words;
    if (value < 0) {
        value += ring_words;
    }
    return static_cast<uint32_t>(value);
}

bool wait_for_event_done(mudaq::DmaMudaqDevice& mu, uint32_t timeout_ms) {
    if (timeout_ms == 0) {
        return true;
    }

    const auto start = std::chrono::steady_clock::now();
    while (true) {
        if ((mu.read_register_ro(EVENT_BUILD_STATUS_REGISTER_R) & 0x1u) != 0) {
            return true;
        }
        const auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - start);
        if (elapsed.count() >= timeout_ms) {
            return false;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
}

std::vector<RegisterValue> read_rw_registers(mudaq::DmaMudaqDevice& mu) {
    return {
        {"DMA_REGISTER_W", mu.read_register_rw(DMA_REGISTER_W)},
        {"GET_N_DMA_WORDS_REGISTER_W", mu.read_register_rw(GET_N_DMA_WORDS_REGISTER_W)},
        {"SWB_READOUT_STATE_REGISTER_W", mu.read_register_rw(SWB_READOUT_STATE_REGISTER_W)},
        {"FARM_READOUT_STATE_REGISTER_W", mu.read_register_rw(FARM_READOUT_STATE_REGISTER_W)},
        {"SWB_LINK_MASK_PIXEL_REGISTER_W", mu.read_register_rw(SWB_LINK_MASK_PIXEL_REGISTER_W)},
        {"SWB_LINK_MASK_SCIFI_REGISTER_W", mu.read_register_rw(SWB_LINK_MASK_SCIFI_REGISTER_W)},
        {"SWB_GENERIC_MASK_REGISTER_W", mu.read_register_rw(SWB_GENERIC_MASK_REGISTER_W)},
        {"FARM_LINK_MASK_REGISTER_W", mu.read_register_rw(FARM_LINK_MASK_REGISTER_W)},
    };
}

std::vector<RegisterValue> read_ro_registers(mudaq::DmaMudaqDevice& mu) {
    return {
        {"VERSION_REGISTER_R", mu.read_register_ro(VERSION_REGISTER_R)},
        {"EVENTCOUNTER_REGISTER_R", mu.read_register_ro(EVENTCOUNTER_REGISTER_R)},
        {"GLOBAL_TS_LOW_REGISTER_R", mu.read_register_ro(GLOBAL_TS_LOW_REGISTER_R)},
        {"GLOBAL_TS_HIGH_REGISTER_R", mu.read_register_ro(GLOBAL_TS_HIGH_REGISTER_R)},
        {"BUFFER_STATUS_REGISTER_R", mu.read_register_ro(BUFFER_STATUS_REGISTER_R)},
        {"EVENT_BUILD_STATUS_REGISTER_R", mu.read_register_ro(EVENT_BUILD_STATUS_REGISTER_R)},
        {"EVENT_BUILD_IDLE_NOT_HEADER_R", mu.read_register_ro(EVENT_BUILD_IDLE_NOT_HEADER_R)},
        {"EVENT_BUILD_SKIP_EVENT_DMA_R", mu.read_register_ro(EVENT_BUILD_SKIP_EVENT_DMA_R)},
        {"EVENT_BUILD_CNT_EVENT_DMA_R", mu.read_register_ro(EVENT_BUILD_CNT_EVENT_DMA_R)},
        {"EVENT_BUILD_TAG_FIFO_FULL_R", mu.read_register_ro(EVENT_BUILD_TAG_FIFO_FULL_R)},
        {"DMA_CNT_WORDS_REGISTER_R", mu.read_register_ro(DMA_CNT_WORDS_REGISTER_R)},
        {"DMA_STATUS_REGISTER_R", mu.read_register_ro(DMA_STATUS_REGISTER_R)},
        {"DMA_DATA_ADDR_LOW_REGISTER_R", mu.read_register_ro(DMA_DATA_ADDR_LOW_REGISTER_R)},
        {"DMA_DATA_ADDR_HI_REGISTER_R", mu.read_register_ro(DMA_DATA_ADDR_HI_REGISTER_R)},
        {"DMA_NUM_PAGES_REGISTER_R", mu.read_register_ro(DMA_NUM_PAGES_REGISTER_R)},
        {"LINK_LOCKED_LOW_REGISTER_R", mu.read_register_ro(LINK_LOCKED_LOW_REGISTER_R)},
        {"LINK_LOCKED_HIGH_REGISTER_R", mu.read_register_ro(LINK_LOCKED_HIGH_REGISTER_R)},
    };
}

uint32_t find_register(const std::vector<RegisterValue>& regs, const std::string& name) {
    for (const auto& reg : regs) {
        if (reg.name == name) {
            return reg.value;
        }
    }
    return 0;
}

void print_hex_value(std::ostream& os, uint32_t value) {
    os << "0x" << std::hex << std::setw(8) << std::setfill('0') << value << std::dec
       << std::setfill(' ');
}

void write_text(std::ostream& os, const Options& opt, const std::vector<RegisterValue>& rw_regs,
                const std::vector<RegisterValue>& ro_regs, uint32_t last_written_word,
                uint32_t last_eoe_block, uint32_t start_word,
                const volatile uint32_t* dma_words) {
    const uint64_t global_ts =
        (static_cast<uint64_t>(find_register(ro_regs, "GLOBAL_TS_HIGH_REGISTER_R")) << 32) |
        find_register(ro_regs, "GLOBAL_TS_LOW_REGISTER_R");
    const uint32_t eoe_next_word = ((last_eoe_block + 1u) * 8u) & MUDAQ_DMABUF_DATA_WORDS_MASK;

    os << "# swb_dma_snapshot\n";
    os << "device: " << opt.device << "\n";
    os << "dmabuf: " << opt.dmabuf << "\n";
    os << "ring_words: " << MUDAQ_DMABUF_DATA_WORDS << "\n";
    os << "capture_start_word: ";
    print_hex_value(os, start_word);
    os << "\n";
    os << "capture_words: " << opt.words << "\n";
    os << "last_written_word: ";
    print_hex_value(os, last_written_word);
    os << "\n";
    os << "last_endofevent_block: ";
    print_hex_value(os, last_eoe_block);
    os << "\n";
    os << "last_endofevent_next_word: ";
    print_hex_value(os, eoe_next_word);
    os << "\n";
    os << "global_ts: 0x" << std::hex << std::setw(16) << std::setfill('0') << global_ts
       << std::dec << std::setfill(' ') << "\n\n";

    os << "rw_registers:\n";
    for (const auto& reg : rw_regs) {
        os << "  " << reg.name << ": ";
        print_hex_value(os, reg.value);
        os << " (" << reg.value << ")\n";
    }

    os << "\nro_registers:\n";
    for (const auto& reg : ro_regs) {
        os << "  " << reg.name << ": ";
        print_hex_value(os, reg.value);
        os << " (" << reg.value << ")\n";
    }

    os << "\ndata:\n";
    os << "ordinal ring_word value_hex value_dec\n";
    for (std::size_t i = 0; i < opt.words; ++i) {
        const uint32_t idx = ring_add(start_word, static_cast<int64_t>(i));
        const uint32_t value = dma_words[idx];
        os << std::setw(7) << i << " ";
        print_hex_value(os, idx);
        os << " ";
        print_hex_value(os, value);
        os << " " << value << "\n";
    }
}

void write_csv(std::ostream& os, const Options& opt, const std::vector<RegisterValue>& rw_regs,
               const std::vector<RegisterValue>& ro_regs, uint32_t last_written_word,
               uint32_t last_eoe_block, uint32_t start_word, const volatile uint32_t* dma_words) {
    const uint32_t eoe_next_word = ((last_eoe_block + 1u) * 8u) & MUDAQ_DMABUF_DATA_WORDS_MASK;

    os << "# swb_dma_snapshot\n";
    os << "# device," << opt.device << "\n";
    os << "# dmabuf," << opt.dmabuf << "\n";
    os << "# ring_words," << MUDAQ_DMABUF_DATA_WORDS << "\n";
    os << "# capture_start_word," << start_word << "\n";
    os << "# capture_words," << opt.words << "\n";
    os << "# last_written_word," << last_written_word << "\n";
    os << "# last_endofevent_block," << last_eoe_block << "\n";
    os << "# last_endofevent_next_word," << eoe_next_word << "\n";
    for (const auto& reg : rw_regs) {
        os << "# rw," << reg.name << "," << reg.value << "\n";
    }
    for (const auto& reg : ro_regs) {
        os << "# ro," << reg.name << "," << reg.value << "\n";
    }
    os << "ordinal,ring_word,value_hex,value_dec\n";
    for (std::size_t i = 0; i < opt.words; ++i) {
        const uint32_t idx = ring_add(start_word, static_cast<int64_t>(i));
        const uint32_t value = dma_words[idx];
        os << i << "," << idx << ",0x" << std::hex << std::setw(8) << std::setfill('0')
           << value << std::dec << std::setfill(' ') << "," << value << "\n";
    }
}

}  // namespace

int main(int argc, char* argv[]) {
    Options opt;
    try {
        opt = parse_args(argc, argv);
    } catch (const std::exception& ex) {
        std::cerr << "swb_dma_snapshot: " << ex.what() << "\n";
        usage(argv[0], 2);
    }

    int fd = -1;
    void* mapped = MAP_FAILED;
    int exit_code = 0;

    try {
        mudaq::DmaMudaqDevice mu(opt.device);
        if (!mu.open()) {
            throw std::runtime_error("could not open " + opt.device);
        }
        if (!mu.is_ok()) {
            throw std::runtime_error("MUDAQ device mapping is incomplete");
        }

        const bool done_seen = wait_for_event_done(mu, opt.wait_done_ms);
        if (!done_seen) {
            std::cerr << "swb_dma_snapshot: timed out waiting for EVENT_BUILD_STATUS bit 0\n";
            exit_code = 3;
        }

        fd = ::open(opt.dmabuf.c_str(), O_RDONLY);
        if (fd < 0) {
            throw std::runtime_error("could not open " + opt.dmabuf + ": " + std::strerror(errno));
        }
        mapped = mmap(nullptr, MUDAQ_DMABUF_DATA_LEN, PROT_READ, MAP_SHARED, fd, 0);
        if (mapped == MAP_FAILED) {
            throw std::runtime_error("could not mmap " + opt.dmabuf + ": " + std::strerror(errno));
        }
        const auto* dma_words = static_cast<const volatile uint32_t*>(mapped);

        const uint32_t last_written_word = mu.last_written_addr() & MUDAQ_DMABUF_DATA_WORDS_MASK;
        const uint32_t last_eoe_block = mu.last_endofevent_addr();
        const uint32_t eoe_next_word = ((last_eoe_block + 1u) * 8u) & MUDAQ_DMABUF_DATA_WORDS_MASK;

        uint32_t start_word = 0;
        if (opt.has_start_word) {
            start_word = opt.start_word & MUDAQ_DMABUF_DATA_WORDS_MASK;
        } else {
            uint32_t center = 0;
            if (opt.around == "eoe") {
                center = eoe_next_word;
            } else if (opt.around == "write") {
                center = last_written_word;
            }
            start_word = ring_add(center, -static_cast<int64_t>(opt.words / 2));
        }

        const auto rw_regs = read_rw_registers(mu);
        const auto ro_regs = read_ro_registers(mu);

        std::ofstream fout;
        std::ostream* out = &std::cout;
        if (!opt.output.empty()) {
            fout.open(opt.output);
            if (!fout) {
                throw std::runtime_error("could not open output " + opt.output);
            }
            out = &fout;
        }

        if (opt.format == "csv") {
            write_csv(*out, opt, rw_regs, ro_regs, last_written_word, last_eoe_block, start_word,
                      dma_words);
        } else {
            write_text(*out, opt, rw_regs, ro_regs, last_written_word, last_eoe_block, start_word,
                       dma_words);
        }

        if (mapped != MAP_FAILED) {
            munmap(mapped, MUDAQ_DMABUF_DATA_LEN);
        }
        if (fd >= 0) {
            ::close(fd);
        }
    } catch (const std::exception& ex) {
        if (mapped != MAP_FAILED) {
            munmap(mapped, MUDAQ_DMABUF_DATA_LEN);
        }
        if (fd >= 0) {
            ::close(fd);
        }
        std::cerr << "swb_dma_snapshot: " << ex.what() << "\n";
        return 1;
    }

    return exit_code;
}
