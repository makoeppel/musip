#pragma once

#include <vector>
#include <chrono>

#include "musip/dqm/dqmfwd.hpp"
#include "musip/dqm/detail.hpp"
#include "musip/dqm/Metadata.hpp"

namespace musip::dqm {

/** @brief A histogram that forgets data after a set time period, so only the most recent data is shown.
 *
 * This histogram is made up of several "time slices". After a set period the oldest slice is cleared and
 * reused for the newest period. So you have a rolling time window when the data is held in the histogram.
 *
 * `sliceDuration` - the time of each individual slice, during which all entries are put in a single batch.
 * `numberOfSlices` - the total number of slices.
 *
 * Data will be stored in the histogram for a total time of `numberOfSlices * sliceDuration`. So if you have 10
 * slices of 1 second duration, the histogram will not show data older than 10 seconds.
 *
 * The main use case is hitmaps so you can see what a chip is seeing right now.
 */
template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
class BasicRollingHistogram2D {
public:
    using xaxis_type = xaxis_type_;
    using yaxis_type = yaxis_type_;
    using content_type = content_type_;
    using histogram_type = musip::dqm::BasicHistogram2D<xaxis_type, yaxis_type, content_type>;
    using x_axis_type = typename histogram_type::x_axis_type;
    using y_axis_type = typename histogram_type::y_axis_type;

    static constexpr size_t dimensions = 2;
    static constexpr bool have_overflow = true; // TODO: Find a way of making this an option
    static constexpr size_t bin_offset = (have_overflow ? 1 : 0);
    static constexpr size_t additional_bins = (have_overflow ? 2 : 0);

    using mutex_type = detail::MutexPointer<std::mutex>;
private:
    mutable mutex_type mutex_;
    mutable std::vector<histogram_type> slices_;
    std::chrono::steady_clock::duration sliceDuration_;
    mutable size_t currentSliceIndex_;
    mutable std::chrono::steady_clock::time_point currentSliceTime_;

    // This is immutable after construction.
    Metadata metadata_;

    friend class PlotCollection;
    friend class DQMManager;
    friend struct HistogramEncoder;

public:
    template<typename... metadata_parameters>
    BasicRollingHistogram2D(std::mutex* pMutex, unsigned numberOfSlices, std::chrono::steady_clock::duration sliceDuration, unsigned numberOfXBins, xaxis_type lowXEdge, xaxis_type highXEdge, unsigned numberOfYBins, yaxis_type lowYEdge, yaxis_type highYEdge, metadata_parameters&&... metadataParams);

    template<Lock lock = Lock::PerformLock>
    histogram_type total() const;

    template<Lock lock = Lock::PerformLock>
    void fill(xaxis_type xValue, yaxis_type yValue, content_type weight = 1);

    // "Fill" with an uppercase "F" purely to ease conversion of code from root to dqm.
    template<Lock lock = Lock::PerformLock>
    void Fill(xaxis_type xValue, yaxis_type yValue, content_type weight = 1) { return fill<lock>(xValue, yValue, weight); }

    template<Lock lock = Lock::PerformLock>
    size_t entries() const;

    unsigned numberOfXBins() const;
    xaxis_type lowXEdge() const;
    xaxis_type highXEdge() const;

    unsigned numberOfYBins() const;
    yaxis_type lowYEdge() const;
    yaxis_type highYEdge() const;

    const std::string& title() const { return metadata_.get<Metadata::Category::Title>(); }
    const std::string& description() const { return metadata_.get<Metadata::Category::Description>(); }
    const std::string& axisTitleX() const { return metadata_.get<Metadata::Category::AxisTitleX>(); }
    const std::string& axisTitleY() const { return metadata_.get<Metadata::Category::AxisTitleY>(); }
    const std::string& axisTitleZ() const { return metadata_.get<Metadata::Category::AxisTitleZ>(); }

    template<Lock lock = Lock::PerformLock>
    void clear();

    using root_type = typename histogram_type::root_type;

    /** @brief Converts to a root (as in root.cern.ch) histogram.
     *
     * The root directory will be null, i.e. it is held in memory only. If you want to set the directory with
     * `SetDirectory(some_TDirectory);` then the TDirectory takes ownership, and you have to release the
     * unique_ptr to avoid a double free. E.g. to save to a file do:
     * ```
     * auto pRootFile = std::make_unique<TFile>(TFile::Open("myfilename", "RECREATE"));
     * auto pRootHistogram = pDQMHistogra->asRootObject("myHistogram", "My histogram title");
     * pRootHistogram->SetDirectory(pRootFile.get());
     * pRootHistogram.release();
     * ```
     */
    template<Lock lock = Lock::PerformLock>
    std::unique_ptr<root_type> asRootObject(const std::string& histogramName, const std::string& histogramTitle) const;
private:
    template<Lock lock = Lock::PerformLock>
    void updateSlices() const;
};

} // end of namespace musip::dqm

#include "musip/dqm/BasicHistogram2D.hpp"

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
template<typename... metadata_parameters>
musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::BasicRollingHistogram2D(std::mutex* pMutex, unsigned numberOfSlices, std::chrono::steady_clock::duration sliceDuration, unsigned numberOfXBins, xaxis_type lowXEdge, xaxis_type highXEdge, unsigned numberOfYBins, yaxis_type lowYEdge, yaxis_type highYEdge, metadata_parameters&&... metadataParams)
    : mutex_(pMutex),
      sliceDuration_(sliceDuration),
      currentSliceIndex_(0),
      metadata_(std::forward<metadata_parameters>(metadataParams)...) {
    slices_.reserve(numberOfSlices);
    for(unsigned index = 0; index < numberOfSlices; ++index) {
        slices_.emplace_back(pMutex, numberOfXBins, lowXEdge, highXEdge, numberOfYBins, lowYEdge, highYEdge);
    }
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
musip::dqm::BasicHistogram2D<xaxis_type_, yaxis_type_, content_type_> musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::total() const {
    musip::dqm::BasicHistogram2D<xaxis_type, yaxis_type, content_type> returnValue(nullptr, numberOfXBins(), lowXEdge(), highXEdge(), numberOfYBins(), lowYEdge(), highYEdge(), metadata_);

    typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);
    updateSlices<Lock::AlreadyLocked>();

    std::error_code error;
    for(const auto& slice : slices_) returnValue.template add<Lock::AlreadyLocked, Lock::AlreadyLocked>(slice, error);

    return returnValue;
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
void musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::updateSlices() const {
    const auto timeNow = std::chrono::steady_clock::now();

    // Figure out how many slices have passed since the last time
    const size_t slicesPassed = (timeNow - currentSliceTime_) / sliceDuration_;

    if(slicesPassed > 0) {
        typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);

        for(size_t index = 0; index < std::min(slicesPassed, slices_.size()); ++index) {
            currentSliceIndex_ = (currentSliceIndex_ + 1) % slices_.size();
            slices_[currentSliceIndex_].template clear<Lock::AlreadyLocked>();
        }

        // The time of this new slice is *not* timeNow, since we're probably somewhere in the middle of the slice.
        currentSliceTime_ += (sliceDuration_ * slicesPassed);
    }
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
void musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::fill(xaxis_type xValue, yaxis_type yValue, content_type weight) {
    typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);
    updateSlices<Lock::AlreadyLocked>();

    slices_[currentSliceIndex_].template fill<Lock::AlreadyLocked>(std::forward<xaxis_type>(xValue), std::forward<yaxis_type>(yValue), std::forward<content_type>(weight));
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
size_t musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::entries() const {
    typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);
    updateSlices<Lock::AlreadyLocked>();

    size_t entries = 0;
    for(const auto& slice : slices_) entries += slice.template entries<Lock::AlreadyLocked>();

    return entries;
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
unsigned musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::numberOfXBins() const {
    // Note that we don't lock the mutex for this, because once the histogram has been created
    // the binning can't change. The binning for all slices is the same, just use the first.
    return slices_.front().numberOfXBins();
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
xaxis_type_ musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::lowXEdge() const {
    // Note that we don't lock the mutex for this, because once the histogram has been created
    // the binning can't change. The binning for all slices is the same, just use the first.
    return slices_.front().lowXEdge();
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
xaxis_type_ musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::highXEdge() const {
    // Note that we don't lock the mutex for this, because once the histogram has been created
    // the binning can't change. The binning for all slices is the same, just use the first.
    return slices_.front().highXEdge();
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
unsigned musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::numberOfYBins() const {
    // Note that we don't lock the mutex for this, because once the histogram has been created
    // the binning can't change. The binning for all slices is the same, just use the first.
    return slices_.front().numberOfYBins();
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
yaxis_type_ musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::lowYEdge() const {
    // Note that we don't lock the mutex for this, because once the histogram has been created
    // the binning can't change. The binning for all slices is the same, just use the first.
    return slices_.front().lowYEdge();
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
yaxis_type_ musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::highYEdge() const {
    // Note that we don't lock the mutex for this, because once the histogram has been created
    // the binning can't change. The binning for all slices is the same, just use the first.
    return slices_.front().highYEdge();
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
void musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::clear() {
    typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);
    updateSlices<Lock::AlreadyLocked>();

    for(auto& slice : slices_) slice.template clear<Lock::AlreadyLocked>();
}

template<typename xaxis_type_, typename yaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
std::unique_ptr<typename musip::dqm::BasicHistogram2D<xaxis_type_, yaxis_type_, content_type_>::root_type> musip::dqm::BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>::asRootObject(const std::string& histogramName, const std::string& histogramTitle) const {
    return const_cast<BasicRollingHistogram2D<xaxis_type_, yaxis_type_, content_type_>*>(this)->total<lock>().asRootObject(histogramName, histogramTitle);
}
