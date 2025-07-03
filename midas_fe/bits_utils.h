//

#include <stdlib.h>

#include <vector>

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
