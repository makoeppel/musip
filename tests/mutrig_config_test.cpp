#include "../midas_fe/libmudaq/mutrig_config.h"
#include "../midas_fe/constants.h"
#include "../midas_fe/odb_setup.h"

#include <gtest/gtest.h>

#include <fstream>
#include <iomanip>
#include <sstream>
#include <vector>

using midas::odb;

namespace {

std::vector<uint8_t> read_binary(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary);
    EXPECT_TRUE(file.good()) << "Cannot open reference file: " << filename;

    file.seekg(0, std::ios::end);
    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::vector<uint8_t> buffer(static_cast<size_t>(size));
    file.read(reinterpret_cast<char*>(buffer.data()), size);

    return buffer;
}

std::string byte_to_hex(uint8_t b) {
    std::ostringstream os;
    os << "0x"
       << std::hex
       << std::setw(2)
       << std::setfill('0')
       << static_cast<int>(b);
    return os.str();
}

void write_text_file(const std::string& filename, const std::string& content) {
    std::ofstream file(filename);
    ASSERT_TRUE(file.good()) << "Cannot open output file: " << filename;
    file << content;
    ASSERT_TRUE(file.good()) << "Failed writing output file: " << filename;
}

}  // namespace

TEST(MuTRiGConfigTest, LayoutMatchesConstants) {
    mutrig::ODBConfigGenerator::BoundGenerator gen(settings["ConfigMuTRiG"]);

    EXPECT_EQ(gen.total_bits(), N_BITS_MUTRIG);
    EXPECT_EQ(gen.total_bytes(), N_BYTES_MUTRIG);
    EXPECT_TRUE(gen.validate());
}

TEST(MuTRiGConfigTest, GenerateMatchesReferenceBinary) {
    constexpr uint32_t asic_idx = 0;

    mutrig::ODBConfigGenerator::BoundGenerator gen(settings["ConfigMuTRiG"]);

    ASSERT_TRUE(gen.validate());

    const std::vector<uint8_t> generated = gen.generate(asic_idx);

    ASSERT_EQ(generated.size(), N_BYTES_MUTRIG);

    const std::vector<uint8_t> reference =
        read_binary("mutrig_reference_asic0.bin");

    ASSERT_EQ(reference.size(), generated.size())
        << "Reference file has wrong size";

    for (size_t i = 0; i < generated.size(); ++i) {
        EXPECT_EQ(generated[i], reference[i])
            << "Mismatch at byte " << i
            << " generated=" << byte_to_hex(generated[i])
            << " expected=" << byte_to_hex(reference[i]);
    }
}

TEST(MuTRiGConfigTest, WriteJsonReferenceFile) {
    constexpr uint32_t asic_idx = 0;
    const std::string output_filename = "mutrig_generated_asic0.json";

    mutrig::ODBConfigGenerator::BoundGenerator gen(settings["ConfigMuTRiG"]);

    //ASSERT_TRUE(gen.validate());

    const std::string json = gen.test_json(asic_idx);

    ASSERT_FALSE(json.empty());
    EXPECT_NE(json.find("\"layout\""), std::string::npos);
    EXPECT_NE(json.find("\"sections\""), std::string::npos);
    EXPECT_NE(json.find("\"defaults\""), std::string::npos);
    EXPECT_NE(json.find("\"bitpattern\""), std::string::npos);

    write_text_file(output_filename, json);

    std::ifstream check(output_filename);
    ASSERT_TRUE(check.good()) << "JSON output file was not created: " << output_filename;
}