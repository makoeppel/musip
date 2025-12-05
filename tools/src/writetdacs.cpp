/** @file
 * @brief Little tool to write TDAC files for testing. All on; all off; and arbitrary patterns.
 *
 * @author Mark Grimes (mark.grimes@bristol.ac.uk)
 * @date 2025-02-04
 */
#include <charconv>
#include <cmath>
#include <iostream>
#include <system_error>

#include "musip/TDACFile.hpp"

namespace { // Use the unnamed namespace for things only used in this file

void writeAll(musip::TDACFile& tdacFile, const uint8_t value);
void writeCheckerboard(musip::TDACFile& tdacFile, const unsigned checkerSize, const uint8_t firstValue = 0x47, const uint8_t alternatingValue = 0x00);
void writeWave(musip::TDACFile& tdacFile, const unsigned size, const uint8_t firstValue = 0x47, const uint8_t alternatingValue = 0x00);

void printUsage(std::ostream& stream) {
    stream << "write_tdacs - small utility to write simple TDAC files for testing\n"
        "\n"
        "--help or -h       print this message\n"
        "--all <value>      set all pixels to <value>\n"
        "--checker <value>  create a checkerboard pattern with squares of width <value>\n"
        "--wave <value>     create a sine wave pattern with waves of width <value>\n"
        "--output <path>    write the results to <path>. Use '-' for stdout. Default is 'tdac.bin'.\n"
    ;
}
} // end of the unnamed namespace

int write_tdacs_main(int argc, char* argv[]) {
    musip::TDACFile tdacFile;
    std::string output("tdac.bin");

    for(int index = 1; index < argc; ++index) {
        std::string_view arg(argv[index]); // string_view has easier manipulation methods

        if(arg == "--help" || arg == "-h") {
            printUsage(std::cout);
            return 0;
        }
        else if(arg == "--all" || arg == "--checker" || arg == "--wave") {
            if((index + 1) >= argc) {
                std::cerr << "The '" << arg << "' argument requires a parameter\n\n";
                printUsage(std::cerr);
                return -1;
            }
            ++index; // We're consuming an extra arg as well as the advance in the `for` loop
            std::string_view param(argv[index]);

            uint8_t data = 0x47;
            int base = 10;
            if(param.substr(0, 2) == "0x" || param.substr(0, 2) == "0X") {
                base = 16;
                param = param.substr(2); // Chop off the "0x"
            }
            const auto& [pEnd, error] = std::from_chars(param.data(), param.data() + param.size(), data, base);
            // std::string foo = there;
            if((pEnd - param.data()) != static_cast<std::ptrdiff_t>(param.size()) || static_cast<bool>(error)) {
                std::cerr << "Couldn't convert the parameter '" << argv[index] << "' to a number\n\n";
                printUsage(std::cerr);
                return -1;
            }

            if(arg == "--all") writeAll(tdacFile, data);
            else if(arg == "--checker") writeCheckerboard(tdacFile, data); // Note that `data` here is the size of the checkerboard
            else if(arg == "--wave") writeWave(tdacFile, data); // Note that `data` here is the size of the wave
        }
        else if(arg == "--output" || arg == "-o") {
            if((index + 1) >= argc) {
                std::cerr << "The '" << arg << "' argument requires a parameter\n\n";
                printUsage(std::cerr);
                return -1;
            }
            ++index; // We're consuming an extra arg as well as the advance in the `for` loop
            output = argv[index];
        }
        else {
            std::cerr << "Unknown argument " << arg << "'\n\n";
            printUsage(std::cerr);
            return -1;
        }
    }

    if(output != "-") {
        // Write to the filename specified
        std::error_code error;
        tdacFile.saveToFile(output.c_str(), error);
        if(error) {
            std::cerr << "Got error '" << error.message() << "' when saving to filename '" << output << "'\n";
        }
        else {
            std::cout << "Wrote output to '" << output << "'\n";
        }
    }
    else {
        // Write to stdout
        std::error_code error;
        tdacFile.save(std::cout, error);
        if(error) {
            std::cerr << "Got error '" << error.message() << "' when saving to filename '" << output << "'\n";
        }
    }

    return 0;
}

int main(int argc, char* argv[]) {
    return write_tdacs_main(argc, argv);
}

namespace { // Start of the unnamed namespace

void writeAll(musip::TDACFile& tdacFile, const uint8_t value) {
    for(unsigned column = 0; column < 256; ++column) {
        for(unsigned row = 0; row < 250; ++row) {
            tdacFile.pixel(column, row) = value;
        }
    }
}

void writeCheckerboard(musip::TDACFile& tdacFile, const unsigned checkerSize, uint8_t firstValue, uint8_t alternatingValue) {
    for(unsigned column = 0; column < 256; ++column) {
        for(unsigned row = 0; row < 250; ++row) {
            if(((column / checkerSize) % 2) && ((row / checkerSize) % 2)) tdacFile.pixel(column, row) = alternatingValue;
            else tdacFile.pixel(column, row) = firstValue;
        }
    }
}

void writeWave(musip::TDACFile& tdacFile, const unsigned size, const uint8_t firstValue, const uint8_t alternatingValue) {
    for(unsigned column = 0; column < 256; ++column) {
        for(unsigned row = 0; row < 250; ++row) {
            if((static_cast<unsigned>(column + std::sin(row * M_PI / 2.0 / size)) / size) % 2) tdacFile.pixel(column, row) = alternatingValue;
            else tdacFile.pixel(column, row) = firstValue;
        }
    }
}

} // end of the unnamed namespace
