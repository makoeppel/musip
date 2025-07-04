/**
 * @file bits_utils.h
 * @brief Utility for bitwise parameter encoding in bit-pattern buffers.
 *
 * This header defines a function for writing integer values into a bitfield
 * buffer, which is useful in applications like hardware register configuration
 * or slow control settings for DAQ systems.
 *
 * The `setParameter` function encodes a given value into a byte array at a specific
 * bit offset, handling arbitrary bit lengths and bit order inversion.
 */

#pragma once

#include <stdlib.h>

#include <vector>

/**
 * @brief Set a value into a bit pattern buffer at a specific bit offset.
 *
 * This function encodes a `value` of length `nbits` into the buffer
 * `bitpattern_w` starting at the given `offset`. If `inverted` is true,
 * the bits are written in reverse order (MSB first).
 *
 * @param bitpattern_w Target buffer (must be pre-allocated).
 * @param value Integer value to encode.
 * @param offset Starting bit offset in the buffer.
 * @param nbits Number of bits used to encode the value.
 * @param inverted Whether to reverse bit order (MSB-first).
 * @return uint32_t The new bit offset after writing.
 */
uint32_t setParameter(uint8_t* bitpattern_w, uint32_t value, uint32_t offset, uint32_t nbits,
                      bool inverted) {
    uint32_t mask = 0x01;
    std::vector<uint8_t> bitorder;
    for (uint32_t pos = 0; pos < nbits; pos++)
        if (inverted)
            bitorder.push_back(nbits - pos - 1);
        else
            bitorder.push_back(pos);
    for (uint32_t pos = 0; pos < nbits; pos++, mask <<= 1) {
        uint32_t n = (offset + bitorder.at(nbits - pos - 1)) % 8;
        uint32_t b = (offset + bitorder.at(nbits - pos - 1)) / 8;
        // printf("b:%3.3u.%1.1u = %u\n", b, n, mask&value);
        if ((mask & value) != 0)
            bitpattern_w[b] |= 1 << n;  // set nth bit
        else
            bitpattern_w[b] &= ~(1 << n);  // clear nth bit
    }
    return offset + nbits;
}
