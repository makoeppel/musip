#ifndef MUTRIG3_CONFIG_FIELDS_H
#define MUTRIG3_CONFIG_FIELDS_H

#include <stdint.h>

#include "mutrig3/mutrig3_config_schema.h"

namespace mutrig3_config {

enum : uint16_t {
    CONFIG_BITS = 2662,
    CONFIG_BYTES = 333,
    CONFIG_WORDS = 84,
    NUM_ASICS = 8,
    NUM_LOCAL_ASICS = 4,
    NUM_CHANNELS = 32,

    HEADER_BITS = 34,
    CHANNEL_BITS = 71,
    TDC_BITS = 84,
    FOOTER_BITS = 272,
    TDC_BASE_OFFSET = HEADER_BITS + NUM_CHANNELS * CHANNEL_BITS,
    FOOTER_BASE_OFFSET = TDC_BASE_OFFSET + TDC_BITS,
    CONFIG_PADDING_BITS = CONFIG_BYTES * 8 - CONFIG_BITS,
    CONFIG_LAST_BYTE_MASK = (1u << (8 - CONFIG_PADDING_BITS)) - 1u,

    TX_MODE_OFFSET = 19,
    TX_MODE_WIDTH = 3,

    CHANNEL_TDCTEST_N_OFFSET = 8,
    CHANNEL_CML_SC_OFFSET = 7,
    CHANNEL_TTHRESH_OFFSET = 24,
    CHANNEL_TTHRESH_WIDTH = 6,
    CHANNEL_CML_OFFSET = 63,
    CHANNEL_CML_WIDTH = 4,
    CHANNEL_MASK_OFFSET = 69,
    CHANNEL_RECV_ALL_OFFSET = 70,

    TDC_VNCNT_OFFSET_OFFSET = TDC_BASE_OFFSET + 19,
    TDC_VNCNT_OFFSET = TDC_BASE_OFFSET + 21,
    TDC_VNVCODELAY_OFFSET_OFFSET = TDC_BASE_OFFSET + 37,
    TDC_VNVCODELAY_OFFSET = TDC_BASE_OFFSET + 39,
    TDC_VNHITLOGIC_OFFSET_OFFSET = TDC_BASE_OFFSET + 55,
    TDC_VNHITLOGIC_OFFSET = TDC_BASE_OFFSET + 57,
    TDC_PLL_DAC_WIDTH = 6,
    TDC_PLL_OFFSET_WIDTH = 2
};

inline bool valid_field(uint16_t offset, uint8_t width)
{
    return width > 0 && width <= 32 &&
           static_cast<uint32_t>(offset) + width <= CONFIG_BITS;
}

inline uint32_t get_field_be(const uint8_t* pattern, uint16_t offset, uint8_t width)
{
    if(pattern == 0 || !valid_field(offset, width)) {
        return 0;
    }

    uint32_t value = 0;
    for(uint8_t i = 0; i < width; ++i) {
        const uint16_t bit = offset + i;
        value = (value << 1) | ((pattern[bit / 8] >> (bit % 8)) & 0x1u);
    }
    return value;
}

inline uint32_t get_field_le(const uint8_t* pattern, uint16_t offset, uint8_t width)
{
    if(pattern == 0 || !valid_field(offset, width)) {
        return 0;
    }

    uint32_t value = 0;
    for(uint8_t i = 0; i < width; ++i) {
        const uint16_t bit = offset + i;
        value |= static_cast<uint32_t>((pattern[bit / 8] >> (bit % 8)) & 0x1u) << i;
    }
    return value;
}

inline bool set_field_be(uint8_t* pattern, uint16_t offset, uint8_t width, uint32_t value)
{
    if(pattern == 0 || !valid_field(offset, width) ||
       (width < 32 && value >= (1u << width))) {
        return false;
    }

    for(uint8_t i = 0; i < width; ++i) {
        const uint16_t bit = offset + i;
        const uint8_t mask = static_cast<uint8_t>(1u << (bit % 8));
        const bool set = ((value >> (width - i - 1)) & 0x1u) != 0;
        if(set) {
            pattern[bit / 8] |= mask;
        } else {
            pattern[bit / 8] &= static_cast<uint8_t>(~mask);
        }
    }
    return true;
}

inline bool set_field_le(uint8_t* pattern, uint16_t offset, uint8_t width, uint32_t value)
{
    if(pattern == 0 || !valid_field(offset, width) ||
       (width < 32 && value >= (1u << width))) {
        return false;
    }

    for(uint8_t i = 0; i < width; ++i) {
        const uint16_t bit = offset + i;
        const uint8_t mask = static_cast<uint8_t>(1u << (bit % 8));
        if(((value >> i) & 0x1u) != 0) {
            pattern[bit / 8] |= mask;
        } else {
            pattern[bit / 8] &= static_cast<uint8_t>(~mask);
        }
    }
    return true;
}

inline uint32_t get_field(
    const uint8_t* pattern,
    const field_descriptor_t& field)
{
    return field.order == FIELD_LITTLE_ENDIAN
               ? get_field_le(pattern, field.offset, field.width)
               : get_field_be(pattern, field.offset, field.width);
}

inline bool set_field(
    uint8_t* pattern,
    const field_descriptor_t& field,
    uint32_t value)
{
    return field.order == FIELD_LITTLE_ENDIAN
               ? set_field_le(pattern, field.offset, field.width, value)
               : set_field_be(pattern, field.offset, field.width, value);
}

inline uint32_t field_maximum(const field_descriptor_t& field)
{
    return field.width == 32 ? 0xFFFFFFFFu : (1u << field.width) - 1u;
}

inline uint16_t channel_field_offset(uint8_t channel, uint8_t field_offset)
{
    return HEADER_BITS + static_cast<uint16_t>(channel) * CHANNEL_BITS + field_offset;
}

inline uint32_t get_channel_field(
    const uint8_t* pattern,
    uint8_t channel,
    uint8_t field_offset,
    uint8_t width)
{
    if(channel >= NUM_CHANNELS) {
        return 0;
    }
    return get_field_be(pattern, channel_field_offset(channel, field_offset), width);
}

inline bool set_channel_field(
    uint8_t* pattern,
    uint8_t channel,
    uint8_t field_offset,
    uint8_t width,
    uint32_t value)
{
    return channel < NUM_CHANNELS &&
           set_field_be(pattern, channel_field_offset(channel, field_offset), width, value);
}

inline uint32_t get_channel_field(
    const uint8_t* pattern,
    uint8_t channel,
    const field_descriptor_t& field)
{
    if(channel >= NUM_CHANNELS) {
        return 0;
    }
    const uint16_t offset = channel_field_offset(
        channel, static_cast<uint8_t>(field.offset));
    return field.order == FIELD_LITTLE_ENDIAN
               ? get_field_le(pattern, offset, field.width)
               : get_field_be(pattern, offset, field.width);
}

inline bool set_channel_field(
    uint8_t* pattern,
    uint8_t channel,
    const field_descriptor_t& field,
    uint32_t value)
{
    if(channel >= NUM_CHANNELS) {
        return false;
    }
    const uint16_t offset = channel_field_offset(
        channel, static_cast<uint8_t>(field.offset));
    return field.order == FIELD_LITTLE_ENDIAN
               ? set_field_le(pattern, offset, field.width, value)
               : set_field_be(pattern, offset, field.width, value);
}

inline bool configurations_equal(
    const uint8_t* authoritative_target,
    const uint8_t* cached_readback)
{
    if(authoritative_target == 0 || cached_readback == 0) {
        return false;
    }

    for(uint16_t byte = 0; byte + 1 < CONFIG_BYTES; ++byte) {
        if(authoritative_target[byte] != cached_readback[byte]) {
            return false;
        }
    }
    return (authoritative_target[CONFIG_BYTES - 1] & CONFIG_LAST_BYTE_MASK) ==
           (cached_readback[CONFIG_BYTES - 1] & CONFIG_LAST_BYTE_MASK);
}

inline bool target_matches_readback(
    const uint8_t* authoritative_target,
    const uint8_t* cached_readback,
    bool cached_readback_valid)
{
    return cached_readback_valid &&
           configurations_equal(authoritative_target, cached_readback);
}

enum configuration_sync_state_t : uint8_t {
    CONFIG_SYNC_NO_CACHED_READBACK = 0,
    CONFIG_SYNC_CACHED_READBACK_UNVERIFIED,
    CONFIG_SYNC_TARGET_MATCHES_VALIDATED_READBACK,
    CONFIG_SYNC_TARGET_DIFFERS_FROM_VALIDATED_READBACK
};

inline configuration_sync_state_t classify_configuration_sync(
    const uint8_t* authoritative_target,
    const uint8_t* cached_readback,
    bool cached_readback_valid,
    bool hardware_validation_ok)
{
    if(!cached_readback_valid || cached_readback == 0) {
        return CONFIG_SYNC_NO_CACHED_READBACK;
    }
    if(!hardware_validation_ok) {
        return CONFIG_SYNC_CACHED_READBACK_UNVERIFIED;
    }
    return target_matches_readback(
               authoritative_target, cached_readback, cached_readback_valid)
               ? CONFIG_SYNC_TARGET_MATCHES_VALIDATED_READBACK
               : CONFIG_SYNC_TARGET_DIFFERS_FROM_VALIDATED_READBACK;
}

inline uint16_t descriptor_difference_count(
    const uint8_t* left,
    const uint8_t* right,
    const field_descriptor_t* fields,
    uint8_t field_count)
{
    if(left == 0 || right == 0 || fields == 0) {
        return 0;
    }

    uint16_t differences = 0;
    for(uint8_t index = 0; index < field_count; ++index) {
        differences += get_field(left, fields[index]) !=
                       get_field(right, fields[index]);
    }
    return differences;
}

inline uint16_t channel_descriptor_difference_count(
    const uint8_t* left,
    const uint8_t* right,
    const field_descriptor_t* fields,
    uint8_t field_count,
    uint8_t channel)
{
    if(left == 0 || right == 0 || fields == 0 || channel >= NUM_CHANNELS) {
        return 0;
    }

    uint16_t differences = 0;
    for(uint8_t index = 0; index < field_count; ++index) {
        differences += get_channel_field(left, channel, fields[index]) !=
                       get_channel_field(right, channel, fields[index]);
    }
    return differences;
}

struct configuration_difference_summary_t {
    uint16_t header;
    uint16_t tdc;
    uint16_t channels;
    uint16_t footer;
};

inline configuration_difference_summary_t summarize_configuration_differences(
    const uint8_t* authoritative_target,
    const uint8_t* cached_readback)
{
    configuration_difference_summary_t summary = {
        descriptor_difference_count(
            authoritative_target,
            cached_readback,
            HEADER_FIELDS,
            HEADER_FIELD_COUNT),
        descriptor_difference_count(
            authoritative_target,
            cached_readback,
            TDC_FIELDS,
            TDC_FIELD_COUNT),
        0,
        descriptor_difference_count(
            authoritative_target,
            cached_readback,
            FOOTER_FIELDS,
            FOOTER_FIELD_COUNT)};
    for(uint8_t channel = 0; channel < NUM_CHANNELS; ++channel) {
        summary.channels += channel_descriptor_difference_count(
            authoritative_target,
            cached_readback,
            CHANNEL_FIELDS,
            CHANNEL_FIELD_COUNT,
            channel);
    }
    return summary;
}

enum channel_mask_class_t : uint8_t {
    CHANNEL_MASK_NONE = 0,
    CHANNEL_MASK_SOME,
    CHANNEL_MASK_FULL
};

enum channel_mode_class_t : uint8_t {
    CHANNEL_MODE_TDC = 0,
    CHANNEL_MODE_ANALOG,
    CHANNEL_MODE_RANDOM
};

struct channel_configuration_summary_t {
    uint8_t masked;
    uint8_t tdc_enabled;
    uint8_t cml_enabled;
};

inline channel_configuration_summary_t summarize_channel_configuration(
    const uint8_t* pattern)
{
    channel_configuration_summary_t summary = {0, 0, 0};
    if(pattern == 0) {
        return summary;
    }

    for(uint8_t channel = 0; channel < NUM_CHANNELS; ++channel) {
        summary.masked +=
            get_channel_field(pattern, channel, CHANNEL_MASK_OFFSET, 1) != 0;
        // tdctest_n is active-low: zero means that TDC injection is enabled.
        summary.tdc_enabled +=
            get_channel_field(
                pattern, channel, CHANNEL_TDCTEST_N_OFFSET, 1) == 0;
        summary.cml_enabled +=
            get_channel_field(
                pattern,
                channel,
                CHANNEL_CML_OFFSET,
                CHANNEL_CML_WIDTH) != 0;
    }
    return summary;
}

inline channel_mask_class_t classify_channel_mask(
    const channel_configuration_summary_t& summary)
{
    if(summary.masked == 0) {
        return CHANNEL_MASK_NONE;
    }
    return summary.masked == NUM_CHANNELS
               ? CHANNEL_MASK_FULL
               : CHANNEL_MASK_SOME;
}

inline channel_mode_class_t classify_channel_mode(
    const channel_configuration_summary_t& summary)
{
    if(summary.tdc_enabled == NUM_CHANNELS &&
       summary.cml_enabled == 0) {
        return CHANNEL_MODE_TDC;
    }
    if(summary.tdc_enabled == 0 &&
       summary.cml_enabled == NUM_CHANNELS) {
        return CHANNEL_MODE_ANALOG;
    }
    return CHANNEL_MODE_RANDOM;
}

inline void normalize_padding(uint8_t* pattern)
{
    if(pattern != 0) {
        pattern[CONFIG_BYTES - 1] &= CONFIG_LAST_BYTE_MASK;
    }
}

inline uint8_t align_spi_readback_byte(
    uint8_t previous_raw,
    uint8_t current_raw,
    uint16_t byte_index)
{
    const uint8_t shift = 8 - (CONFIG_BITS % 8);
    uint8_t aligned = static_cast<uint8_t>(
        (static_cast<uint16_t>(previous_raw) << 8 | current_raw) >> shift);
    if(byte_index == CONFIG_BYTES - 1) {
        aligned &= CONFIG_LAST_BYTE_MASK;
    }
    return aligned;
}

inline bool two_pass_readback_valid(int prime_result, int validation_result)
{
    // A MuTRiG shift returns the pattern that preceded the current write.
    // Consequently the first result is diagnostic only; the second result is
    // the readback of the pattern written by the first transfer.
    (void)prime_result;
    return validation_result == 0;
}

inline bool complete_spi_readback_result(int readback_result)
{
    return readback_result <= 0 &&
           readback_result >= -static_cast<int>(CONFIG_BYTES);
}

inline bool promote_normal_readback(
    int second_pass_result,
    const uint8_t* second_pass_readback,
    uint8_t* cached_readback,
    bool& cached_readback_valid,
    bool& hardware_validation_ok)
{
    // A complete second-pass RX is useful evidence even when it differs from
    // the authoritative target. Controller faults and incomplete exchanges do
    // not provide a complete image, so they preserve the last cached bank.
    hardware_validation_ok = false;
    if(!complete_spi_readback_result(second_pass_result) ||
       second_pass_readback == 0 ||
       cached_readback == 0) {
        return false;
    }

    for(uint16_t byte = 0; byte < CONFIG_BYTES; ++byte) {
        cached_readback[byte] = second_pass_readback[byte];
    }
    normalize_padding(cached_readback);
    cached_readback_valid = true;
    hardware_validation_ok = second_pass_result == 0;
    return true;
}

inline bool direct_readback_valid(
    int zero_echo_result,
    int probe_echo_result,
    int restore_validation_result)
{
    // Pass two must return the zeros installed by pass one. Pass three must
    // return a nonzero, safe probe while restoring the captured image. This
    // prevents a stuck-low MISO from validating an all-zero capture. Pass four
    // returns the restored image without changing the final configuration.
    return zero_echo_result == 0 &&
           probe_echo_result == 0 &&
           restore_validation_result == 0;
}

enum direct_restore_source_t : uint8_t {
    DIRECT_RESTORE_CAPTURED = 0,
    DIRECT_RESTORE_VERIFIED_READBACK,
    DIRECT_RESTORE_AUTHORITATIVE_TARGET,
    DIRECT_RESTORE_SAFE_ALL_OFF
};

inline direct_restore_source_t select_direct_restore_source(
    int capture_result,
    bool cached_readback_valid,
    bool cached_readback_verified,
    bool authoritative_target_valid)
{
    if(capture_result == 0) {
        return DIRECT_RESTORE_CAPTURED;
    }
    if(cached_readback_valid && cached_readback_verified) {
        return DIRECT_RESTORE_VERIFIED_READBACK;
    }
    if(authoritative_target_valid) {
        return DIRECT_RESTORE_AUTHORITATIVE_TARGET;
    }
    return DIRECT_RESTORE_SAFE_ALL_OFF;
}

inline bool promote_direct_readback(
    int capture_result,
    int zero_echo_result,
    int probe_echo_result,
    int restore_validation_result,
    const uint8_t* captured,
    uint8_t* readback,
    bool& readback_valid,
    bool& restore_verified)
{
    // A failed capture/restore must never replace the last usable reference or
    // the authoritative target/edit bank. Mark the current hardware state
    // unknown, then promote the captured image into the readback bank only
    // after all four exchanges are accepted.
    restore_verified = false;
    if(capture_result != 0 ||
       !direct_readback_valid(
           zero_echo_result,
           probe_echo_result,
           restore_validation_result) ||
       captured == 0 ||
       readback == 0) {
        return false;
    }

    for(uint16_t byte = 0; byte < CONFIG_BYTES; ++byte) {
        readback[byte] = captured[byte];
    }
    normalize_padding(readback);
    readback_valid = true;
    restore_verified = true;
    return true;
}

} // namespace mutrig3_config

#endif // MUTRIG3_CONFIG_FIELDS_H
