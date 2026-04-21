#ifndef MUTRIG_ODB_CONFIG_GENERATOR_H
#define MUTRIG_ODB_CONFIG_GENERATOR_H

#include <cstdint>
#include <iomanip>
#include <map>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "../constants.h"
#include "odbxx.h"

namespace mutrig {

using midas::odb;

class ODBConfigGenerator {
public:
    struct SectionRange {
        const char* first;
        const char* last;
    };

    static constexpr SectionRange GLOBAL_RANGE{"gen_idle", "en_ch_evt_cnt"};
    static constexpr SectionRange TDC_RANGE{"dmon_sel", "latchbias"};
    static constexpr SectionRange CH_RANGE{"energy_c_en", "recv_all"};
    static constexpr SectionRange FOOTER_RANGE{"coin_xbar_lower_rx_ena", "lvds_tx_bias"};

    class BoundGenerator {
    public:
        explicit BoundGenerator(odb& config_mutrig) : m_config(config_mutrig) {}

        std::size_t total_bits() {
            return section_bits(m_config["Nbits"], GLOBAL_RANGE)
                 + section_bits(m_config["Nbits"], TDC_RANGE)
                 + NMUTRIGCHANNELS * section_bits(m_config["Nbits"], CH_RANGE)
                 + footer_bits();
        }

        std::size_t total_bytes() {
            return (total_bits() + 7u) / 8u;
        }

        bool validate() {
            return total_bits() == N_BITS_MUTRIG && total_bytes() == N_BYTES_MUTRIG;
        }

        std::vector<std::uint8_t> generate(std::uint32_t asic_idx) {
            std::vector<std::uint8_t> bitpattern(total_bytes(), 0);
            std::size_t offset = 0;

            offset += write_global(m_config, bitpattern, offset);
            offset += write_tdc(m_config, bitpattern, offset, asic_idx);
            offset += write_channels(m_config, bitpattern, offset, asic_idx);
            offset += write_footer(m_config, bitpattern, offset, asic_idx);

            if (offset != total_bits()) {
                throw std::runtime_error("MuTRiG config size mismatch while generating ASIC config");
            }

            return bitpattern;
        }

        std::map<std::uint32_t, std::vector<std::uint8_t>> generate_enabled(odb& settings) {
            std::map<std::uint32_t, std::vector<std::uint8_t>> out;
            odb& daq = settings["DAQ"]["Links"];

            const std::size_t nfebs = daq["FEBsActive"].size();
            for (std::size_t feb_idx = 0; feb_idx < nfebs; ++feb_idx) {
                const bool feb_active = daq["FEBsActive"][feb_idx];
                const bool feb_is_mutrig = daq["FEBsMutrig"][feb_idx];
                if (!feb_active || !feb_is_mutrig) {
                    continue;
                }

                const std::uint16_t asic_mask = daq["ASICMask"][feb_idx];
                for (std::uint32_t local_asic = 0; local_asic < N_MUTRIGS_PER_FEB; ++local_asic) {
                    if (((asic_mask >> local_asic) & 0x1u) == 0u) {
                        continue;
                    }

                    const std::uint32_t global_asic =
                        static_cast<std::uint32_t>(feb_idx) * N_MUTRIGS_PER_FEB + local_asic;
                    out[global_asic] = generate(global_asic);
                }
            }

            return out;
        }

        std::string test_json(std::uint32_t asic_idx = 0) {
            const auto bytes = generate(asic_idx);

            std::ostringstream os;
            os << "{\n";
            os << "  \"layout\": {\n";
            os << "    \"n_mutrigs_per_feb\": " << N_MUTRIGS_PER_FEB << ",\n";
            os << "    \"n_mutrig_channels\": " << NMUTRIGCHANNELS << ",\n";
            os << "    \"n_bytes_mutrig_constant\": " << N_BYTES_MUTRIG << ",\n";
            os << "    \"n_bits_mutrig_constant\": " << N_BITS_MUTRIG << ",\n";
            os << "    \"n_bytes_mutrig_from_layout\": " << total_bytes() << ",\n";
            os << "    \"n_bits_mutrig_from_layout\": " << total_bits() << ",\n";
            os << "    \"layout_matches_constants\": " << (validate() ? "true" : "false") << "\n";
            os << "  },\n";

            os << "  \"sections\": {\n";
            os << "    \"header_bits\": " << section_bits(m_config["Nbits"], GLOBAL_RANGE) << ",\n";
            os << "    \"tdc_bits\": " << section_bits(m_config["Nbits"], TDC_RANGE) << ",\n";
            os << "    \"channel_bits\": " << section_bits(m_config["Nbits"], CH_RANGE) << ",\n";
            os << "    \"footer_bits\": " << footer_bits() << "\n";
            os << "  },\n";

            os << "  \"defaults\": {\n";
            write_scalar_section_json(os,
                          "Global",
                          m_config["Global"],
                          m_config["Nbits"],
                          m_config["Inverted"],
                          GLOBAL_RANGE);
            os << ",\n";

            write_scalar_section_json(os,
                                    "TDCs",
                                    m_config["TDCs"],
                                    m_config["Nbits"],
                                    m_config["Inverted"],
                                    TDC_RANGE,
                                    asic_idx);
            os << ",\n";

            write_scalar_section_json(os,
                                    "Channels",
                                    m_config["Channels"],
                                    m_config["Nbits"],
                                    m_config["Inverted"],
                                    CH_RANGE,
                                    asic_idx * NMUTRIGCHANNELS);
            os << ",\n";

            write_scalar_section_json(os,
                                    "Footer",
                                    m_config["TDCs"],
                                    m_config["Nbits"],
                                    m_config["Inverted"],
                                    FOOTER_RANGE,
                                    asic_idx,
                                    &m_config["TDCs"],
                                    asic_idx);

            os << " , \"bitpattern\": {\n";
            os << "    \"asic_index\": " << asic_idx << ",\n";
            os << "    \"bytes\": " << bytes.size() << ",\n";
            os << "    \"hex_le\": \"" << to_hex_le(bytes) << "\",\n";
            os << "    \"hex_be\": \"" << to_hex_be(bytes) << "\"\n";
            os << "  }\n";
            os << "}}\n";

            return os.str();
        }

    private:
        odb& m_config;

        static std::size_t section_bits(odb& nbits, const SectionRange& range) {
            bool enabled = false;
            std::size_t total = 0;

            for (odb& subkey : nbits) {
                const std::string name = subkey.get_name();
                if (name == range.first) {
                    enabled = true;
                }
                if (!enabled) {
                    continue;
                }

                total += static_cast<std::uint32_t>(subkey);
                if (name == range.last) {
                    break;
                }
            }

            return total;
        }

        std::size_t footer_bits() {
            bool enabled = false;
            std::size_t bits = 0;

            for (odb& subkey : m_config["Nbits"]) {
                const std::string name = subkey.get_name();
                if (name == FOOTER_RANGE.first) {
                    enabled = true;
                }
                if (!enabled) {
                    continue;
                }

                if (name == "coin_mat") {
                    bits += static_cast<std::uint32_t>(subkey) * NMUTRIGCHANNELS;
                } else {
                    bits += static_cast<std::uint32_t>(subkey);
                }

                if (name == FOOTER_RANGE.last) {
                    break;
                }
            }

            return bits;
        }

        static std::size_t write_global(odb& config,
                                        std::vector<std::uint8_t>& bitpattern,
                                        std::size_t bit_offset) {
            return write_range(config["Nbits"], config["Global"], config["Inverted"],
                               bitpattern, bit_offset, 0, GLOBAL_RANGE);
        }

        static std::size_t write_tdc(odb& config,
                                     std::vector<std::uint8_t>& bitpattern,
                                     std::size_t bit_offset,
                                     std::uint32_t asic_idx) {
            return write_range(config["Nbits"], config["TDCs"], config["Inverted"],
                               bitpattern, bit_offset, asic_idx, TDC_RANGE);
        }

        static std::size_t write_channels(odb& config,
                                          std::vector<std::uint8_t>& bitpattern,
                                          std::size_t bit_offset,
                                          std::uint32_t asic_idx) {
            std::size_t bits_written = 0;

            for (std::uint32_t ch = 0; ch < NMUTRIGCHANNELS; ++ch) {
                const std::uint32_t global_channel = asic_idx * NMUTRIGCHANNELS + ch;
                bits_written += write_range(config["Nbits"], config["Channels"], config["Inverted"],
                                            bitpattern, bit_offset + bits_written,
                                            global_channel, CH_RANGE);
            }

            return bits_written;
        }

        static std::size_t write_footer(odb& config,
                                        std::vector<std::uint8_t>& bitpattern,
                                        std::size_t bit_offset,
                                        std::uint32_t asic_idx) {
            // coin_mat stays in TDCs in this project
            return write_range(config["Nbits"], config["TDCs"], config["Inverted"],
                               bitpattern, bit_offset, asic_idx, FOOTER_RANGE,
                               &config["TDCs"], asic_idx);
        }

        static std::size_t write_range(odb& nbits,
                                       odb& values,
                                       odb& inverted,
                                       std::vector<std::uint8_t>& bitpattern,
                                       std::size_t bit_offset,
                                       std::uint32_t index,
                                       const SectionRange& range,
                                       odb* coin_mat_values = nullptr,
                                       std::uint32_t asic_idx_for_coinmat = 0) {
            const std::size_t start_offset = bit_offset;
            bool enabled = false;

            for (odb& subkey : nbits) {
                const std::string name = subkey.get_name();
                if (name == range.first) {
                    enabled = true;
                }
                if (!enabled) {
                    continue;
                }

                const std::uint32_t width = static_cast<std::uint32_t>(subkey);
                const bool inv = static_cast<bool>(inverted[name]);

                if (name == "tthresh_offset_0" || name == "tthresh_offset_1" || name == "tthresh_offset_2") {
                    const std::uint8_t tthresh_offset = values["tthresh_offset"][index];
                    std::uint32_t value = 0;
                    if (name == "tthresh_offset_0") value = (tthresh_offset >> 2) & 0x1u;
                    if (name == "tthresh_offset_1") value = (tthresh_offset >> 1) & 0x1u;
                    if (name == "tthresh_offset_2") value = (tthresh_offset >> 0) & 0x1u;
                    pack_value(bitpattern, bit_offset, value, width, inv);
                } else if (name == "coin_mat") {
                    if (coin_mat_values == nullptr) {
                        throw std::runtime_error("coin_mat requires source values");
                    }
                    for (std::uint32_t ch = 0; ch < NMUTRIGCHANNELS; ++ch) {
                        const std::uint32_t global_channel = asic_idx_for_coinmat * NMUTRIGCHANNELS + ch;
                        const std::uint32_t value = (*coin_mat_values)["coin_mat"][global_channel];
                        pack_value(bitpattern, bit_offset, value, width, inv);
                    }
                } else if (is_scalar_global(values, name)) {
                    const std::uint32_t value = static_cast<std::uint32_t>(values[name]);
                    pack_value(bitpattern, bit_offset, value, width, inv);
                } else {
                    const std::uint32_t value = static_cast<std::uint32_t>(values[name][index]);
                    pack_value(bitpattern, bit_offset, value, width, inv);
                }

                if (name == range.last) {
                    break;
                }
            }

            return bit_offset - start_offset;
        }

        static bool is_scalar_global(odb& values, const std::string& name) {
            return values.get_name() == "Global"
                && name != "ms_limits"
                && name != "ms_switch_sel"
                && name != "dmon_sel"
                && name != "dmon_sel_enable"
                && name != "dmon_sw";
        }

        static void pack_value(std::vector<std::uint8_t>& bitpattern,
                               std::size_t& bit_offset,
                               std::uint32_t value,
                               std::uint32_t width,
                               bool inverted_bits) {
            if (width < 32u && (value >> width) != 0u) {
                throw std::out_of_range("ODB value exceeds declared bit width");
            }

            for (std::uint32_t src_bit = 0; src_bit < width; ++src_bit) {
                const bool bit = ((value >> src_bit) & 0x1u) != 0u;
                const std::uint32_t dst_bit = inverted_bits ? src_bit : (width - 1u - src_bit);

                const std::size_t absolute_bit = bit_offset + dst_bit;
                const std::size_t byte_index = absolute_bit / 8u;
                const std::size_t bit_index = absolute_bit % 8u;

                if (bit) {
                    bitpattern[byte_index] |= static_cast<std::uint8_t>(1u << bit_index);
                } else {
                    bitpattern[byte_index] &= static_cast<std::uint8_t>(~(1u << bit_index));
                }
            }

            bit_offset += width;
        }

        static std::string to_hex_le(const std::vector<std::uint8_t>& bytes) {
            std::ostringstream os;
            os << std::hex << std::setfill('0');
            for (std::uint8_t b : bytes) {
                os << std::setw(2) << static_cast<unsigned int>(b);
            }
            return os.str();
        }

        static std::string to_hex_be(const std::vector<std::uint8_t>& bytes) {
            std::ostringstream os;
            os << std::hex << std::setfill('0');
            for (auto it = bytes.rbegin(); it != bytes.rend(); ++it) {
                os << std::setw(2) << static_cast<unsigned int>(*it);
            }
            return os.str();
        }

        static void write_scalar_section_json(std::ostringstream& os,
                                            const std::string& section_name,
                                            odb& section,
                                            odb& nbits,
                                            odb& inverted,
                                            const SectionRange& range,
                                            std::uint32_t index = 0,
                                            odb* coin_mat_values = nullptr,
                                            std::uint32_t asic_idx_for_coinmat = 0)
        {
            os << "    \"" << section_name << "\": {\n";

            bool first = true;
            bool enabled = false;

            for (odb& subkey : nbits)
            {
                const std::string name = subkey.get_name();

                if (name == range.first)
                    enabled = true;

                if (!enabled)
                    continue;

                if (!first)
                    os << ",\n";
                first = false;

                const std::uint32_t width =
                    static_cast<std::uint32_t>(subkey);

                const bool inv = static_cast<bool>(inverted[name]);

                os << "      \"" << name << "\": ";

                // SPECIAL: tthresh_offset split
                if (name == "tthresh_offset_0" ||
                    name == "tthresh_offset_1" ||
                    name == "tthresh_offset_2")
                {
                    const std::uint8_t tthresh_offset =
                        section["tthresh_offset"][index];

                    std::uint32_t value = 0;

                    if (name == "tthresh_offset_0")
                        value = (tthresh_offset >> 2) & 0x1u;

                    if (name == "tthresh_offset_1")
                        value = (tthresh_offset >> 1) & 0x1u;

                    if (name == "tthresh_offset_2")
                        value = (tthresh_offset >> 0) & 0x1u;

                    os << "{ \"value\": " << value
                    << ", \"bits\": " << width
                    << ", \"inverted\": " << (inv ? "true" : "false")
                    << " }";
                }

                // SPECIAL: coin_mat (32 entries)
                else if (name == "coin_mat")
                {
                    if (coin_mat_values == nullptr)
                        throw std::runtime_error(
                            "coin_mat requires source values");

                    os << "[\n";

                    for (std::uint32_t ch = 0;
                        ch < NMUTRIGCHANNELS;
                        ++ch)
                    {
                        const std::uint32_t global_channel =
                            asic_idx_for_coinmat *
                            NMUTRIGCHANNELS + ch;

                        const std::uint32_t value =
                            static_cast<std::uint32_t>(
                                (*coin_mat_values)["coin_mat"]
                                                [global_channel]);

                        os << "        { \"channel\": "
                        << ch
                        << ", \"value\": "
                        << value
                        << ", \"bits\": "
                        << width
                        << ", \"inverted\": "
                        << (inv ? "true" : "false")
                        << " }";

                        if (ch + 1 != NMUTRIGCHANNELS)
                            os << ",";

                        os << "\n";
                    }

                    os << "      ]";
                }

                // GLOBAL scalar
                else if (is_scalar_global(section, name))
                {
                    const std::uint32_t value =
                        static_cast<std::uint32_t>(section[name]);

                    os << "{ \"value\": "
                    << value
                    << ", \"bits\": "
                    << width
                    << ", \"inverted\": "
                    << (inv ? "true" : "false")
                    << " }";
                }

                // NORMAL indexed field
                else
                {
                    const std::uint32_t value =
                        static_cast<std::uint32_t>(
                            section[name][index]);

                    os << "{ \"value\": "
                    << value
                    << ", \"bits\": "
                    << width
                    << ", \"inverted\": "
                    << (inv ? "true" : "false")
                    << " }";
                }

                if (name == range.last)
                    break;
            }

            os << "\n    }";
        }

        static void write_indexed_section_json(std::ostringstream& os,
                                       const std::string& section_name,
                                       odb& section,
                                       odb& nbits,
                                       std::uint32_t index) {
            os << "    \"" << section_name << "\": {\n";

            bool first = true;
            for (odb& subkey : section) {
                if (!first) {
                    os << ",\n";
                }
                first = false;

                const std::string name = subkey.get_name();

                os << "      \"" << name << "\": { ";

                if (subkey.size() > 0) {
                    os << "\"value\": "
                    << odb_value_to_json_value(subkey[index]);
                } else {
                    os << "\"value\": "
                    << odb_value_to_json_value(subkey);
                }

                os << ", \"bits\": " << static_cast<std::uint32_t>(nbits[name]);

                os << " }";
            }

            os << "\n    }";
        }

        template <typename T>
        static std::string odb_value_to_json_value(T&& value) {
            std::ostringstream os;

            try {
                const bool b = value;
                os << (b ? "true" : "false");
                return os.str();
            } catch (...) {}

            try {
                const std::int64_t i = value;
                os << i;
                return os.str();
            } catch (...) {}

            try {
                const std::uint64_t u = value;
                os << u;
                return os.str();
            } catch (...) {}

            try {
                const double d = value;
                os << d;
                return os.str();
            } catch (...) {}

            try {
                const std::string s = value;
                os << "\"" << s << "\"";
                return os.str();
            } catch (...) {}

            os << "\"<unsupported>\"";
            return os.str();
        }
    };
};

} // namespace mutrig

#endif // MUTRIG_ODB_CONFIG_GENERATOR_H