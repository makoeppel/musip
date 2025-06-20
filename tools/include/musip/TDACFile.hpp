/** @file
 * @brief Class to write TDAC files for testing.
 *
 * @author Mark Grimes (mark.grimes@bristol.ac.uk)
 * @date 2025-02-04
 */
#pragma once

#include <array>
#include <cstdint>
#include <iosfwd>
#include <system_error>

namespace musip {

class TDACFile {
    std::array<uint8_t, 256 * 256> data_;
    static constexpr uint8_t IsEnabledBitmask  = 0b01000000;
    static constexpr uint8_t ThHighTrimBitmask = 0b00111000;
    static constexpr uint8_t ThLowTrimBitmask  = 0b00000111;
    // I don't know what any of the other bits are.
public:
    TDACFile();
    void loadFromFile(const char* filename, std::error_code& error);
    void saveToFile(const char* filename, std::error_code& error);
    void load(std::istream& inputStream, std::error_code& error);
    void save(std::ostream& outputStream, std::error_code& error);
    // Data for each pixel is 8 bits.
    // * 0x40 (one bit) is pixel enabled (set to zero to mask it).
    // * 0x38 (3 bits) is the pixel threshold high trim (ThHigh).
    // * 0x07 (3 bits) is the pixel threshold low trim (ThLow).
    // No idea what 0x80 (the first bit) is, pretty sure it's not used.
    uint8_t& pixel(unsigned column, unsigned row) { return data_[column * 256 + row]; }
    const uint8_t& pixel(unsigned column, unsigned row) const { return data_[column * 256 + row]; }

    bool isEnabled(unsigned column, unsigned row) const { return pixel(column, row) & IsEnabledBitmask; }
    void setEnabled(unsigned column, unsigned row, bool isEnabled) {
        if(isEnabled) pixel(column, row) |= IsEnabledBitmask;
        else pixel(column, row) &= (~IsEnabledBitmask);
    }

    bool isMasked(unsigned column, unsigned row) const { return !isEnabled(column, row); }
    void setMasked(unsigned column, unsigned row, bool isMasked) { return setEnabled(column, row, !isMasked); }

    // ThHigh trims are only 3 bits at 0b00111000
    uint8_t ThHighTrim(unsigned column, unsigned row) const { return (pixel(column, row) & ThHighTrimBitmask) >> 3; }
    void setThHighTrim(unsigned column, unsigned row, uint8_t value) {
        auto& current = pixel(column, row);
        current = (current & ~ThHighTrimBitmask) | ((value << 3) & ThHighTrimBitmask);
    }

    // ThLow trims are 3 bits at 0b00000111
    uint8_t ThLowTrim(unsigned column, unsigned row) const { return (pixel(column, row) & ThLowTrimBitmask) >> 3; }
    void setThLowTrim(unsigned column, unsigned row, uint8_t value) {
        auto& current = pixel(column, row);
        current = (current & ~ThLowTrimBitmask) | ((value << 3) & ThLowTrimBitmask);
    }
}; // end of class TDACFile

} // end of the musip namespace
