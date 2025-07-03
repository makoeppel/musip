#include "../midas_fe/bits_utils.h"

#include <gtest/gtest.h>

#include <cstring>  // for memset
#include <vector>

// Helper to extract bit as bool
bool get_bit(uint8_t byte, int bit_pos) { return (byte >> bit_pos) & 1; }

TEST(SetParameterTest, BasicNonInverted) {
    uint8_t data[2];
    std::memset(data, 0, sizeof(data));

    // Set 4-bit value 0b1010 at offset 0, not inverted
    setParameter(data, 0b1010, 0, 4, false);

    EXPECT_EQ(get_bit(data[0], 0), 1);
    EXPECT_EQ(get_bit(data[0], 1), 0);
    EXPECT_EQ(get_bit(data[0], 2), 1);
    EXPECT_EQ(get_bit(data[0], 3), 0);
}

TEST(SetParameterTest, BasicInverted) {
    uint8_t data[2];
    std::memset(data, 0, sizeof(data));

    // Set 4-bit value 0b1010 at offset 0, inverted
    setParameter(data, 0b1010, 0, 4, true);

    EXPECT_EQ(get_bit(data[0], 0), 0);
    EXPECT_EQ(get_bit(data[0], 1), 1);
    EXPECT_EQ(get_bit(data[0], 2), 0);
    EXPECT_EQ(get_bit(data[0], 3), 1);
}

TEST(SetParameterTest, OffsetAndMultipleBytes) {
    uint8_t data[4];
    std::memset(data, 0, sizeof(data));

    // Set 8-bit value 0xFF at offset 6 (crosses byte boundary)
    setParameter(data, 0xFF, 6, 8, false);

    EXPECT_EQ(data[0] & 0xC0, 0xC0);  // first 2 bits
    EXPECT_EQ(data[1], 0x3F);         // remaining 6 bits
}