#include "musip/dqm/HistogramEncoder.hpp"

// Most of the methods are templated so they have to be in the header file.

size_t musip::dqm::HistogramEncoder::requiredSize(const musip::dqm::PlotCollection::object_type& object) {
    return std::visit([](auto& object) -> size_t {
        using histogram_type = typename std::decay<decltype(object)>::type;

        // For RollingHistograms, we just use the information from one of the slices (they're all the same).
        const std::vector<typename histogram_type::content_type>* pData;
        if constexpr(std::is_same<histogram_type, RollingHistogram2DF>::value) {
            pData = &object.slices_.front().data_;
        }
        else {
            pData = &object.data_;
        }

        // Note that we don't lock the object's mutex, because data_.size() will not change after construction.
        return DataHeader<histogram_type>::dataOffset + (pData->size() * sizeof(typename histogram_type::content_type));
    }, object);
}
