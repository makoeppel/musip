#pragma once

#include <array>
#include <system_error>
#include <optional>
#include "musip/dqm/dqmfwd.hpp"
#include "musip/dqm/PlotCollection.hpp"

namespace musip::dqm {

struct HistogramEncoder {
    static size_t requiredSize(const musip::dqm::PlotCollection::object_type& object);

    template<musip::dqm::Lock lock = Lock::PerformLock, typename byte_type>
    static size_t encode(const musip::dqm::PlotCollection::object_type& object, byte_type* buffer, size_t bufferSize, std::error_code& error);

    template<typename byte_type>
    static std::optional<musip::dqm::PlotCollection::object_type> decode(const byte_type* buffer, size_t bufferSize, std::error_code& error);

private:
    struct CommonHeader;

    template<typename histogram_type>
    struct DataHeader;

    template<typename histogram_type>
    static size_t requiredSize(const DataHeader<histogram_type>& header);

    template<typename histogram_type>
    static std::optional<musip::dqm::PlotCollection::object_type> decodeAs(const DataHeader<histogram_type>& header, size_t bufferSize, std::error_code& error);
};

} // end of namespace musip::dqm

namespace musip::dqm::detail {

//
// A helper struct to statically find out the index into a std::variant of a given type.
// So e.g. variant_index<float, std::variant<int, double, float, char>>::value
// will be `2`.
//
template<typename T,typename V,size_t I = 0> struct variant_index;

// When types match, return the index of this type
template<typename T, typename... Ts, size_t I>
struct variant_index<T, std::variant<T, Ts...>, I> {
    static constexpr size_t value = I;
};

// When types don't match, continue checking the other types
template<typename T, typename T2, typename... Ts, size_t I>
struct variant_index<T,std::variant<T2,Ts...>,I> {
    static constexpr size_t value = variant_index<T, std::variant<Ts...>, I + 1>::value;
};

//
// A helper struct to create storage for the size of the axis_type values. It will be an array
// with an entry for each dimension.
//
template<typename histogram_type, typename integer_type = size_t>
struct axis_type_sizes;

// 1D has an array of length one
template<typename xaxis_type, typename content_type, typename integer_type>
struct axis_type_sizes<musip::dqm::BasicHistogram1D<xaxis_type, content_type>, integer_type> { static constexpr std::array<integer_type,1> value{ sizeof(xaxis_type) }; };

// 2D has an array of length one
template<typename xaxis_type, typename yaxis_type, typename content_type, typename integer_type>
struct axis_type_sizes<musip::dqm::BasicHistogram2D<xaxis_type, yaxis_type, content_type>, integer_type> { static constexpr std::array<integer_type,2> value{ sizeof(xaxis_type), sizeof(yaxis_type) }; };

//
// A helper struct to define the type to hold the low and high edges of each axis.
// In memory this should be the low then the high for each dimension in turn, of their
// respective types. This is so that data of the same type is sequential to minimise
// memory layout.
//
// TODO: Check that std::tuple and std::pair have a predictable memory layout.
template<typename histogram_type>
struct bin_edges_type;

template<typename xaxis_type, typename content_type>
struct bin_edges_type<musip::dqm::BasicHistogram1D<xaxis_type, content_type>> {
    struct { xaxis_type low, high; } dimension0;

    static void set(const musip::dqm::BasicHistogram1D<xaxis_type, content_type>& histogram, std::array<uint32_t, 1>& numberOfBins, bin_edges_type& binEdges ) {
        numberOfBins[0] = histogram.numberOfBins();
        binEdges.dimension0.low  = histogram.lowEdge();
        binEdges.dimension0.high = histogram.highEdge();
    }
};

template<typename xaxis_type, typename yaxis_type, typename content_type>
struct bin_edges_type<musip::dqm::BasicHistogram2D<xaxis_type, yaxis_type, content_type>> {
    // I was previously using a std::tuple for this, but the memory layout differs between compilers.
    // So use structs instead.
    struct { xaxis_type low, high; } dimension0;
    struct { yaxis_type low, high; } dimension1;

    static void set(const musip::dqm::BasicHistogram2D<xaxis_type, yaxis_type, content_type>& histogram, std::array<uint32_t, 2>& numberOfBins, bin_edges_type& binEdges) {
        numberOfBins[0] = histogram.numberOfXBins();
        numberOfBins[1] = histogram.numberOfYBins();
        binEdges.dimension0.low  = histogram.lowXEdge();
        binEdges.dimension0.high = histogram.highXEdge();
        binEdges.dimension1.low  = histogram.lowYEdge();
        binEdges.dimension1.high = histogram.highYEdge();
    }
};

// This is the same as for BasicHistogram2D, since RollingHistograms are encoded as normal histograms
// (we send the total for all time slices as one histogram). I couldn't get a `using` declaration to
// work for template specialisations.
template<typename xaxis_type, typename yaxis_type, typename content_type>
struct bin_edges_type<musip::dqm::BasicRollingHistogram2D<xaxis_type, yaxis_type, content_type>> {
    // I was previously using a std::tuple for this, but the memory layout differs between compilers.
    // So use structs instead.
    struct { xaxis_type low, high; } dimension0;
    struct { yaxis_type low, high; } dimension1;

    static void set(const musip::dqm::BasicHistogram2D<xaxis_type, yaxis_type, content_type>& histogram, std::array<uint32_t, 2>& numberOfBins, bin_edges_type& binEdges) {
        numberOfBins[0] = histogram.numberOfXBins();
        numberOfBins[1] = histogram.numberOfYBins();
        binEdges.dimension0.low  = histogram.lowXEdge();
        binEdges.dimension0.high = histogram.highXEdge();
        binEdges.dimension1.low  = histogram.lowYEdge();
        binEdges.dimension1.high = histogram.highYEdge();
    }
};

} // end of namespace musip::dqm::detail

#include "musip/dqm/detail.hpp"

struct musip::dqm::HistogramEncoder::CommonHeader {
    const uint8_t version = 1;

    // This data is constant for a given histogram_type. We don't make it constexpr however because we want it
    // in memory so that it is written out. We also need to read it in.
    uint8_t objectType;
    uint8_t dimensions;

};

template<typename histogram_type>
struct musip::dqm::HistogramEncoder::DataHeader : public CommonHeader {
    using content_type = typename histogram_type::content_type;

    // This data is constant for a given histogram_type. We don't make it constexpr however because we want it
    // written out and read back in. If it was constexpr it wouldn't exist after compilation.
    const std::array<uint8_t, histogram_type::dimensions> axisTypeSizes = detail::axis_type_sizes<histogram_type, uint8_t>::value;
    const uint8_t ordinateSize = sizeof(content_type);

    // This data will be different among histograms of the same type. It is all constant for the specific histogram
    // though once the histogram has been created. Hence we don't need to lock the histogram's mutex to read it.
    std::array<uint32_t, histogram_type::dimensions> numberOfBins;
    typename detail::bin_edges_type<histogram_type> binEdges;

    // This data will change throughout the histogram's life. We need to lock the mutex to read it.
    uint64_t entries;

    // This is the end of the header. There will be some padding to get the content_type on to the correct alignment
    // and then the histogram data will follow.
    static constexpr size_t sizeOfPadding = (sizeof(content_type) - 1) - ((sizeof(DataHeader) - 1) % sizeof(content_type));
    static constexpr size_t dataOffset = sizeof(DataHeader) + sizeOfPadding;
};

template<musip::dqm::Lock lock, typename byte_type>
size_t musip::dqm::HistogramEncoder::encode(const musip::dqm::PlotCollection::object_type& object, byte_type* buffer, size_t bufferSize, std::error_code& error) {
    static_assert(sizeof(byte_type) == 1, "HistogramEncoder::encode() - pointer arithmetic assumes pointers have a size of 1 byte");

    const size_t bytesWritten = std::visit(musip::dqm::detail::overloaded{
        [buffer, bufferSize, &error](const musip::dqm::RollingHistogram2DF& object) {
            // For RollingHistograms we sum all the time slices and encode that.
            return encode(object.total(), buffer, bufferSize, error);
        },
        [buffer, bufferSize, &error](const auto& object) -> size_t {
            using histogram_type = typename std::decay<decltype(object)>::type;

            // Note that we don't lock the `object`s mutex, because data_.size() will not change after construction.
            const size_t dataSize = object.data_.size() * sizeof(typename histogram_type::content_type); // size in bytes taken up by the bin data
            const size_t requiredSize = DataHeader<histogram_type>::dataOffset + dataSize; // size in bytes required to write the whole object
            if(requiredSize > bufferSize) {
                error = std::make_error_code(std::errc::file_too_large);
                return 0;
            }

            // Although we set all the members, there are padding bytes in the binary encoding that will contain
            // arbitrary data. This is irrelevant to the encoding/decoding process, but it means the same histogram
            // encoded different times could produce different binary blobs. For ease of testing we set everything
            // to a known value so that an encoding will always produce the exact same bytes. We use 0xff arbitrarily
            // because it's easier to spot in binary blobs than zero.
            constexpr int PaddingByte = 0xff;
            std::memset(buffer, PaddingByte, DataHeader<histogram_type>::dataOffset);

            // Use placement new so that the header object is constructed directly inside the buffer
            DataHeader<histogram_type>& header = *new(buffer) DataHeader<histogram_type>;

            header.objectType = detail::variant_index<histogram_type, PlotCollection::object_type>::value;
            header.dimensions = histogram_type::dimensions;
            // We don't need to lock to write the binning details, since they never change after construction
            detail::bin_edges_type<histogram_type>::set(object, header.numberOfBins, header.binEdges);
            // header.binEdges.set(object);

            // At this point we need to lock the mutex, since we're reading data that can change at any time
            typename detail::guard_type<lock, typename histogram_type::mutex_type>::type lockGuard(object.mutex_);

            header.entries = static_cast<uint64_t>(object.template entries<Lock::AlreadyLocked>());

            std::memcpy(buffer + DataHeader<histogram_type>::dataOffset, object.data_.data(), dataSize);
            return requiredSize;
        }
    }, object);

    return bytesWritten;
}

template<typename byte_type>
std::optional<musip::dqm::PlotCollection::object_type> musip::dqm::HistogramEncoder::decode(const byte_type* buffer, size_t bufferSize, std::error_code& error) {
    static_assert(sizeof(byte_type) == 1, "HistogramEncoder::decode() - pointer arithmetic assumes pointers have a size of 1 byte");

    // std::optional<musip::dqm::PlotCollection::object_type> returnValue;
    using return_type = std::optional<musip::dqm::PlotCollection::object_type>;

    if(bufferSize < sizeof(CommonHeader)) {
        error = std::make_error_code(std::errc::file_too_large);
        return return_type();
    }

    const CommonHeader& tempHeader = *reinterpret_cast<const CommonHeader*>(buffer);
    if(tempHeader.version != 1) {
        // We only know how to read version 1 formats.
        error = std::make_error_code(std::errc::invalid_argument);
        return return_type();
    }

    if(tempHeader.objectType > std::variant_size<musip::dqm::PlotCollection::object_type>::value) {
        // This is not a type of plot we know about
        error = std::make_error_code(std::errc::invalid_argument);
        return return_type();
    }

    switch(tempHeader.objectType) {
        case 0: // Histogram1DF
            {
                const auto& header = *reinterpret_cast<const DataHeader<Histogram1DF>*>(buffer);
                return decodeAs(header, bufferSize, error);
            }
            break;
        case 1: // Histogram1DD
            {
                const auto& header = *reinterpret_cast<const DataHeader<Histogram1DD>*>(buffer);
                return decodeAs(header, bufferSize, error);
            }
            break;
        case 2: // Histogram2DF
            {
                const auto& header = *reinterpret_cast<const DataHeader<Histogram2DF>*>(buffer);
                return decodeAs(header, bufferSize, error);
            }
            break;
        case 3: // Histogram1DI
            {
                const auto& header = *reinterpret_cast<const DataHeader<Histogram1DI>*>(buffer);
                return decodeAs(header, bufferSize, error);
            }
            break;
        case 4: // Histogram2DI
            {
                const auto& header = *reinterpret_cast<const DataHeader<Histogram2DI>*>(buffer);
                return decodeAs(header, bufferSize, error);
            }
            break;
        case 5: // RollingHistogram2DF
            {
                // We should never get this because RollingHistograms are encoded as the total of their time
                // slices, i.e. as a normal histogram.
                error = std::make_error_code(std::errc::not_supported);
                return return_type();
            }
        case 6: // Histogram 2DD
            {
                const auto& header = *reinterpret_cast<const DataHeader<Histogram2DD>*>(buffer);
                return decodeAs(header, bufferSize, error);
            }
            break;
        default:
            // We've already checked objectType is one of the allowed types. Should only get here if another
            // type is added to the std::variant but this code is not updated.
            error = std::make_error_code(std::errc::not_supported);
            return return_type();
    } // end of switch(objectType)
}

template<typename histogram_type>
std::optional<musip::dqm::PlotCollection::object_type> musip::dqm::HistogramEncoder::decodeAs(const DataHeader<histogram_type>& header, size_t bufferSize, std::error_code& error) {
    std::optional<musip::dqm::PlotCollection::object_type> returnValue;

    if(header.ordinateSize != sizeof(typename histogram_type::content_type)) {
        error = std::make_error_code(std::errc::bad_message);
        return returnValue;
    }

    // Figure out the total number of bins from all dimensions so that we know how much data should
    // be in the buffer.
    size_t totalBins = 1;
    for(size_t dimension = 0; dimension < histogram_type::dimensions; ++dimension) {
        totalBins *= (header.numberOfBins[dimension] + 2); // `+2` for under and overflow bins
    }
    const size_t expectedDataSize = totalBins * sizeof(typename histogram_type::content_type);

    if(bufferSize < (header.dataOffset + expectedDataSize)) {
        error = std::make_error_code(std::errc::bad_message);
        return returnValue;
    }

    constexpr std::nullptr_t voidMutex = nullptr;

    if constexpr(histogram_type::dimensions == 1) {
        returnValue.emplace(std::in_place_type<histogram_type>, voidMutex, header.numberOfBins[0], header.binEdges.dimension0.low, header.binEdges.dimension0.high);
    }
    else if constexpr(histogram_type::dimensions == 2) {
        returnValue.emplace(std::in_place_type<histogram_type>, voidMutex, header.numberOfBins[0], header.binEdges.dimension0.low, header.binEdges.dimension0.high, header.numberOfBins[1], header.binEdges.dimension1.low, header.binEdges.dimension1.high);
    }
    else {
        static_assert(histogram_type::dimensions <= 2, "HistogramEncoder::decodeAs() has not been written to handle histograms with this many dimensions yet");
    }

    const char* dataStart = reinterpret_cast<const char*>(&header) + header.dataOffset;

    std::visit(musip::dqm::detail::overloaded{
        [&error](musip::dqm::RollingHistogram2DF& object) {
            // We should never be here because we never decodeAs a RollingHistogram. But we need a
            // pattern matcher to stop the compiler using the general one below for RollingHistogram.
            error = std::make_error_code(std::errc::invalid_argument);
        },
        [dataStart, &header](auto& object) {
            std::memcpy(object.data_.data(), dataStart, object.data_.size() * sizeof(typename decltype(object.data_)::value_type));
            object.entries_ = static_cast<size_t>(header.entries);
        }
    }, returnValue.value());

    return returnValue;
}
