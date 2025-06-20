#include "musip/TDACFile.hpp"

#include <cstring> // For std::memset
#include <fstream>

musip::TDACFile::TDACFile() {
    // Set everything to 0x47 to enable all pixels.
    std::memset(data_.data(), 0x40, data_.size() * sizeof(uint8_t));
    // The "rows" 250 to 255 are special values (we only have 250 rows, but TDAC file has 256 entries per row)
    for(unsigned column = 0; column < 256; ++column) {
        pixel(column, 250) = 0xda; // 0xdada as end of column marker
        pixel(column, 251) = 0xda;
        pixel(column, 252) = 0xda; // I think this is high bits for number of columns. Not sure.
        pixel(column, 253) = 255;  // Number of columns
        pixel(column, 254) = 0xda; // LVDS error flag. I don't actually know why this would be in a TDAC file.
        pixel(column, 255) = 0x00; // Not used currently apparently.
    } // end of loop over columns
}

void musip::TDACFile::loadFromFile(const char* filename, std::error_code& error) {
    std::ifstream inputFile(filename);
    if(!inputFile.is_open()) {
        error = std::make_error_code(std::errc::no_such_file_or_directory);
        return;
    }

    return load(inputFile, error);
}

void musip::TDACFile::saveToFile(const char* filename, std::error_code& error) {
    std::ofstream outputFile(filename, std::ios_base::out | std::ios_base::trunc);
    if(!outputFile.is_open()) {
        error = std::make_error_code(std::errc::no_such_file_or_directory);
        return;
    }

    return save(outputFile, error);
}

void musip::TDACFile::load(std::istream& inputStream, std::error_code& error) {
    inputStream.read(reinterpret_cast<char*>(data_.data()), data_.size());
    if(inputStream.gcount() < static_cast<std::streamsize>(data_.size())) {
        error = std::make_error_code(std::errc::message_size);
        return;
    }
}

void musip::TDACFile::save(std::ostream& outputStream, std::error_code& error) {
    outputStream.write(reinterpret_cast<char*>(data_.data()), data_.size());
    if(outputStream.bad()) {
        error = std::make_error_code(std::errc::message_size);
        return;
    }
}
