/** @file
 * @brief Class to read hitmap files for testing.
 *
 * @author Mark Grimes (mark.grimes@bristol.ac.uk)
 * @date 2025-02-04
 */
#pragma once

#include <array>
#include <iosfwd>
#include <system_error>
#include <cstdint>

namespace musip {

class HitmapFile {
public:
    static constexpr unsigned numberOfColumns = 256;
    static constexpr unsigned numberOfRows = 250;
    using pixel_type = uint8_t; // Data for each pixel is 8 bits.
private:
    std::array<pixel_type, numberOfColumns * numberOfRows> data_;
public:
    HitmapFile();
    void loadFromFile(const char* filename, std::error_code& error);
    void saveToFile(const char* filename, std::error_code& error);
    void load(std::istream& inputStream, std::error_code& error);
    void save(std::ostream& outputStream, std::error_code& error);

    pixel_type& pixel(unsigned column, unsigned row) { return data_[column * numberOfRows + row]; }
    const pixel_type& pixel(unsigned column, unsigned row) const { return data_[column * numberOfRows + row]; }
}; // end of class HitmapFile

} // end of the musip namespace
