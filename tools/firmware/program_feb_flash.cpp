/**
 * @file program_feb.cpp
 * @brief Standalone FEB flash programmer.
 *
 * Programs an Altera/Intel raw binary file (.rbf) into the configuration flash
 * of one front-end board, addressed by its link ID (= QSFP port / febIDx).
 *
 * This is a stripped-down, MIDAS-free extraction of LoadFirmware() from
 * utils.h (quads frontend). The register-level programming protocol is
 * unchanged; what was removed is:
 *   - the hardcoded "online/firmware" path prefix (the file is now a CLI arg),
 *   - the midas::odb progress variable (progress goes to the terminal),
 *   - cm_msg1()/cm_yield() (replaced by stdout/stderr logging).
 *
 * What was deliberately changed with respect to the original:
 *   - A short final chunk is zero-padded with 0xFFFFFFFF (erased-flash value)
 *     instead of writing whatever was left in the uninitialised stack buffer.
 *   - A readback error or a poll timeout aborts with a non-zero exit code
 *     instead of only clearing the control register and continuing to push
 *     data into a disabled programming engine.
 *   - FEBEnable() is called before any FEB access, since the frontend normally
 *     does that in InitFEBs() and nothing else does it here.
 *
 * Usage:
 *   program_feb [options] <firmware.rbf> <link_id>
 *
 * Build: see CMakeLists.txt / Makefile in this directory.
 */

#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include <getopt.h>
#include <unistd.h>

#include "FEBSlowcontrolInterface.h"
#include "mudaq_device.h"

namespace {

/// Number of 32-bit words pushed into the programming FIFO per iteration.
constexpr uint32_t WORDS_PER_CHUNK = 256;
/// Flash page size in bytes.
constexpr uint32_t BYTES_PER_PAGE = 256;
/// Flash pages covered by one FIFO fill (256 words * 4 B / 256 B).
constexpr uint32_t PAGES_PER_CHUNK = (WORDS_PER_CHUNK * 4) / BYTES_PER_PAGE;
/// Value of erased flash, used to pad the last (short) chunk.
constexpr uint32_t BLANK_WORD = 0xFFFFFFFFu;

/// PROGRAMMING_STATUS_REGISTER_R bit that stays high while a page is busy.
constexpr uint32_t STATUS_BUSY_BIT = 0x2u;

/// Poll limits taken verbatim from the original LoadFirmware().
constexpr uint32_t POLL_LIMIT_DEFAULT = 1000000;  // 1e6 * 100 us ~ 100 s
constexpr uint32_t POLL_LIMIT_ERASE = 100000;     // first page of a sector
constexpr useconds_t POLL_INTERVAL_US = 100;

struct Options {
    std::string device = "/dev/mudaq0";
    std::string file;
    uint32_t link_id = 0;
    bool emergency = false;
    bool assume_yes = false;
};

void usage(const char* argv0) {
    std::printf(
        "Usage: %s [options] <firmware.rbf> <link_id>\n"
        "\n"
        "Program an .rbf firmware image into the configuration flash of the FEB\n"
        "connected to <link_id> (link ID == QSFP port == febIDx, 0-based).\n"
        "\n"
        "Options:\n"
        "  -d, --device <path>   mudaq device node (default: /dev/mudaq0)\n"
        "  -e, --emergency       program the emergency image area instead of the\n"
        "                        primary image area\n"
        "  -y, --yes             do not ask for confirmation\n"
        "  -h, --help            show this help\n"
        "\n"
        "Exit codes: 0 success, 1 usage/IO error, 2 device error, 3 programming error.\n",
        argv0);
}

bool parse_link_id(const char* s, uint32_t& out) {
    char* end = nullptr;
    errno = 0;
    const long v = std::strtol(s, &end, 0);
    if (errno != 0 || end == s || *end != '\0' || v < 0)
        return false;
    out = static_cast<uint32_t>(v);
    return true;
}

bool parse_args(int argc, char** argv, Options& opt) {
    static const struct option long_opts[] = {{"device", required_argument, nullptr, 'd'},
                                              {"emergency", no_argument, nullptr, 'e'},
                                              {"yes", no_argument, nullptr, 'y'},
                                              {"help", no_argument, nullptr, 'h'},
                                              {nullptr, 0, nullptr, 0}};
    int c;
    while ((c = getopt_long(argc, argv, "d:eyh", long_opts, nullptr)) != -1) {
        switch (c) {
            case 'd': opt.device = optarg; break;
            case 'e': opt.emergency = true; break;
            case 'y': opt.assume_yes = true; break;
            case 'h': usage(argv[0]); std::exit(EXIT_SUCCESS);
            default: return false;
        }
    }
    if (argc - optind != 2) {
        std::fprintf(stderr, "Error: expected exactly 2 positional arguments "
                             "(firmware file and link ID), got %d.\n",
                     argc - optind);
        return false;
    }
    opt.file = argv[optind];
    if (!parse_link_id(argv[optind + 1], opt.link_id)) {
        std::fprintf(stderr, "Error: '%s' is not a valid link ID.\n", argv[optind + 1]);
        return false;
    }
    return true;
}

/// Open the file and return its size, or -1 on error. Leaves the stream at pos 0.
long open_firmware(const std::string& path, FILE** out) {
    FILE* f = std::fopen(path.c_str(), "rb");
    if (!f) {
        std::fprintf(stderr, "Error: cannot open %s: %s\n", path.c_str(), std::strerror(errno));
        return -1;
    }
    if (std::fseek(f, 0, SEEK_END) != 0) {
        std::fprintf(stderr, "Error: cannot seek %s: %s\n", path.c_str(), std::strerror(errno));
        std::fclose(f);
        return -1;
    }
    const long fsize = std::ftell(f);
    std::rewind(f);
    if (fsize <= 0) {
        std::fprintf(stderr, "Error: %s is empty or its size is unknown.\n", path.c_str());
        std::fclose(f);
        return -1;
    }
    *out = f;
    return fsize;
}

/// Check that the image fits into the selected flash area.
bool fits_in_flash(long fsize, bool emergency) {
    const long primary_limit =
        static_cast<long>(FEBSlowcontrolInterface::EMERGENCY_IMAGE_START_ADDRESS);
    const long emergency_limit =
        static_cast<long>(FEBSlowcontrolInterface::FLASH_MAX_ADDRESS) - primary_limit;
    const long limit = emergency ? emergency_limit : primary_limit;
    if (fsize > limit) {
        std::fprintf(stderr,
                     "Error: image of %ld bytes does not fit into the %s image area "
                     "(%ld bytes).\n",
                     fsize, emergency ? "emergency" : "primary", limit);
        return false;
    }
    return true;
}

/**
 * @brief Wait until the FEB reports the current flash page as written.
 * @return true on completion, false on readback error or timeout.
 */
bool wait_page_done(FEBSlowcontrolInterface& feb_sc, uint32_t febIDx, uint32_t addr) {
    // The first page of a 64 kiB sector triggers an erase; the original code
    // uses a shorter limit there.
    const uint32_t limit = ((addr & 0xFFFF) == 0) ? POLL_LIMIT_ERASE : POLL_LIMIT_DEFAULT;
    uint32_t readback = STATUS_BUSY_BIT;
    uint32_t count = 0;
    while ((readback & STATUS_BUSY_BIT) && count < limit) {
        const int ec = feb_sc.FEB_read(febIDx, PROGRAMMING_STATUS_REGISTER_R, readback);
        if (ec != FEBSlowcontrolInterface::ERRCODES::OK) {
            std::fprintf(stderr, "\nError: slow control readback failed at address 0x%08x "
                                 "(error code %d).\n",
                         addr, ec);
            return false;
        }
        count++;
        usleep(POLL_INTERVAL_US);
    }
    if (count >= limit && (readback & STATUS_BUSY_BIT)) {
        std::fprintf(stderr, "\nError: timeout waiting for page at address 0x%08x "
                             "(status 0x%08x).\n",
                     addr, readback);
        return false;
    }
    return true;
}

/**
 * @brief Program a firmware image into the FEB configuration flash.
 * @return 0 on success, 3 on a programming error.
 */
int program_flash(FEBSlowcontrolInterface& feb_sc, uint32_t febIDx, const std::string& path,
                  long fsize, FILE* f, bool emergency) {
    std::printf("Programming %s (%ld bytes) into the %s image area of FEB %u\n", path.c_str(),
                fsize, emergency ? "emergency" : "primary", febIDx);
    std::fflush(stdout);

    // Clear the programming FIFO: set and release the reset bit.
    feb_sc.FEB_write(febIDx, PROGRAMMING_CTRL_REGISTER_W, 2);
    feb_sc.FEB_write(febIDx, PROGRAMMING_CTRL_REGISTER_W, 0);
    // Enable the programming engine.
    feb_sc.FEB_write(febIDx, PROGRAMMING_CTRL_REGISTER_W, 1);

    uint32_t addr = emergency ? FEBSlowcontrolInterface::EMERGENCY_IMAGE_START_ADDRESS : 0;

    long bytes_done = 0;
    int last_percent = -1;
    bool ok = true;

    while (bytes_done < fsize) {
        std::vector<uint32_t> data(WORDS_PER_CHUNK, BLANK_WORD);
        const size_t got = std::fread(data.data(), sizeof(uint32_t), WORDS_PER_CHUNK, f);
        if (got < WORDS_PER_CHUNK) {
            if (std::ferror(f)) {
                std::fprintf(stderr, "\nError: read error on %s after %ld bytes.\n", path.c_str(),
                             bytes_done);
                ok = false;
                break;
            }
            // Short tail: unread words keep the erased-flash value. fread() only
            // consumes whole 4-byte items, so if the file length is not a
            // multiple of 4 the last 1-3 bytes are still pending and are read
            // separately into the next word.
            const long remaining = fsize - bytes_done - static_cast<long>(got) * 4;
            if (remaining > 0 && remaining < 4) {
                uint32_t tail = BLANK_WORD;
                if (std::fread(&tail, 1, static_cast<size_t>(remaining), f) !=
                    static_cast<size_t>(remaining)) {
                    std::fprintf(stderr, "\nError: could not read the trailing %ld byte(s) of %s.\n",
                                 remaining, path.c_str());
                    ok = false;
                    break;
                }
                data[got] = tail;
            }
        }

        feb_sc.FEB_write(febIDx, PROGRAMMING_DATA_REGISTER_W, data, true);

        for (uint32_t page = 0; page < PAGES_PER_CHUNK; page++) {
            feb_sc.FEB_write(febIDx, PROGRAMMING_ADDR_REGISTER_W, addr);
            if (!wait_page_done(feb_sc, febIDx, addr)) {
                ok = false;
                break;
            }
            addr += BYTES_PER_PAGE;
        }
        if (!ok)
            break;

        bytes_done += static_cast<long>(WORDS_PER_CHUNK) * 4;
        if (bytes_done > fsize)
            bytes_done = fsize;

        const int percent = static_cast<int>(100.0 * bytes_done / fsize);
        if (percent != last_percent) {
            std::printf("\rProgrammed %3d%% (%ld / %ld bytes)", percent, bytes_done, fsize);
            std::fflush(stdout);
            last_percent = percent;
        }
    }

    // Always disable the programming engine again, success or not.
    feb_sc.FEB_write(febIDx, PROGRAMMING_CTRL_REGISTER_W, 0);

    if (!ok) {
        std::fprintf(stderr, "Programming of FEB %u ABORTED after %ld of %ld bytes. The flash "
                             "content is incomplete - re-run before power cycling the board.\n",
                     febIDx, bytes_done, fsize);
        return 3;
    }

    std::printf("\nDone programming FEB %u. Power cycle or reconfigure the FPGA to boot the new "
                "image.\n",
                febIDx);
    return 0;
}

bool confirm(const Options& opt, long fsize) {
    if (opt.assume_yes || !isatty(STDIN_FILENO))
        return true;
    std::printf("About to write %ld bytes from %s into the %s image area of FEB on link %u "
                "(%s).\nContinue? [y/N] ",
                fsize, opt.file.c_str(), opt.emergency ? "emergency" : "primary", opt.link_id,
                opt.device.c_str());
    std::fflush(stdout);
    char answer[8] = {};
    if (!std::fgets(answer, sizeof(answer), stdin))
        return false;
    return answer[0] == 'y' || answer[0] == 'Y';
}

}  // namespace

int main(int argc, char** argv) {
    Options opt;
    if (!parse_args(argc, argv, opt)) {
        usage(argv[0]);
        return 1;
    }

    if (opt.file.size() < 4 || opt.file.compare(opt.file.size() - 4, 4, ".rbf") != 0)
        std::fprintf(stderr, "Warning: %s does not look like an .rbf file.\n", opt.file.c_str());

    FILE* f = nullptr;
    const long fsize = open_firmware(opt.file, &f);
    if (fsize < 0)
        return 1;

    if (!fits_in_flash(fsize, opt.emergency)) {
        std::fclose(f);
        return 1;
    }

    if (!confirm(opt, fsize)) {
        std::printf("Aborted, nothing was written.\n");
        std::fclose(f);
        return 0;
    }

    mudaq::MudaqDevice mu(opt.device);
    if (!mu.open()) {
        std::fprintf(stderr, "Error: could not open device %s.\n", opt.device.c_str());
        std::fclose(f);
        return 2;
    }
    if (!mu.is_ok()) {
        std::fprintf(stderr, "Error: device %s is not ok.\n", opt.device.c_str());
        mu.close();
        std::fclose(f);
        return 2;
    }

    FEBSlowcontrolInterface feb_sc(mu);
    // Normally done by InitFEBs() in the frontend; without it the FEB does not
    // answer slow control requests.
    feb_sc.FEBEnable();

    const int rc = program_flash(feb_sc, opt.link_id, opt.file, fsize, f, opt.emergency);

    std::fclose(f);
    mu.close();
    return rc;
}