#include "musip/HitmapFile.hpp"

#include <cstring> // For std::memset
#include <fstream>

musip::HitmapFile::HitmapFile() {
    // Set everything to 0x0
    std::memset(data_.data(), 0x0, data_.size() * sizeof(pixel_type));
}

void musip::HitmapFile::loadFromFile(const char* filename, std::error_code& error) {
    std::ifstream inputFile(filename);
    if(!inputFile.is_open()) {
        error = std::make_error_code(std::errc::no_such_file_or_directory);
        return;
    }

    return load(inputFile, error);
}

void musip::HitmapFile::saveToFile(const char* filename, std::error_code& error) {
    std::ofstream outputFile(filename, std::ios_base::out | std::ios_base::trunc);
    if(!outputFile.is_open()) {
        error = std::make_error_code(std::errc::no_such_file_or_directory);
        return;
    }

    return save(outputFile, error);
}

void musip::HitmapFile::load(std::istream& inputStream, std::error_code& error) {
    inputStream.read(reinterpret_cast<char*>(data_.data()), data_.size());
    const auto gcount = inputStream.gcount();
    if(gcount < static_cast<std::streamsize>(data_.size())) {
        fprintf(stderr, "gcount was %zu, expected %zu\n", gcount, data_.size());
        error = std::make_error_code(std::errc::message_size);
        return;
    }
}

void musip::HitmapFile::save(std::ostream& outputStream, std::error_code& error) {
    outputStream.write(reinterpret_cast<char*>(data_.data()), data_.size());
    if(outputStream.bad()) {
        error = std::make_error_code(std::errc::message_size);
        return;
    }
}
