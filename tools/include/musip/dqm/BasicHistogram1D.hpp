#pragma once

#include "musip/dqm/dqmfwd.hpp"
#include "musip/dqm/detail.hpp"
#include "musip/dqm/Metadata.hpp"

#include <boost/histogram/axis/regular.hpp>

namespace musip::dqm {

template<typename xaxis_type_, typename content_type_>
class BasicHistogram1D {
public:
    using xaxis_type = xaxis_type_;
    using content_type = content_type_;
    using axis_type = boost::histogram::axis::regular<xaxis_type>;

    static constexpr size_t dimensions = 1;
    static constexpr bool have_overflow = true; // TODO: Find a way of making this an option
    static constexpr size_t bin_offset = (have_overflow ? 1 : 0);
    static constexpr size_t additional_bins = (have_overflow ? 2 : 0);

    using mutex_type = detail::MutexPointer<std::mutex>;
private:
    mutable mutex_type mutex_;
    axis_type axis_;
    std::vector<content_type> data_;
    size_t entries_;

    // Rather stupidly you can't get these values out of the boost axis, so we have to store a duplicate as well.
    xaxis_type lowEdge_;
    xaxis_type highEdge_;

    // This is immutable after construction.
    Metadata metadata_;

    friend class PlotCollection;
    friend class DQMManager;
    friend struct HistogramEncoder;

public:
    template<typename... metadata_parameters>
    BasicHistogram1D(std::mutex* pMutex, unsigned numberOfBins, xaxis_type lowEdge, xaxis_type highEdge, metadata_parameters&&... metadataParams)
        : mutex_(pMutex),
          axis_(numberOfBins, lowEdge, highEdge),
          data_(numberOfBins + additional_bins),
          entries_(0),
          lowEdge_(lowEdge),
          highEdge_(highEdge),
          metadata_(std::forward<metadata_parameters>(metadataParams)...)
    {}

    template<Lock lock = Lock::PerformLock>
    void fill(xaxis_type value, content_type weight = 1);

    // "Fill" with an uppercase "F" purely to ease conversion of code from root to dqm.
    template<Lock lock = Lock::PerformLock>
    void Fill(xaxis_type value, content_type weight = 1) { return fill<lock>(value, weight); }

    template<Lock lock = Lock::PerformLock>
    size_t entries() const;

	unsigned numberOfBins() const;
    xaxis_type lowEdge() const;
    xaxis_type highEdge() const;

    const std::string& title() const { return metadata_.get<Metadata::Category::Title>(); }
    const std::string& description() const { return metadata_.get<Metadata::Category::Description>(); }
    const std::string& axisTitleX() const { return metadata_.get<Metadata::Category::AxisTitleX>(); }
    const std::string& axisTitleY() const { return metadata_.get<Metadata::Category::AxisTitleY>(); }

    template<Lock lock = Lock::PerformLock, Lock otherLock = Lock::PerformLock>
    void add(const BasicHistogram1D& other, std::error_code& error);

    template<Lock lock = Lock::PerformLock, Lock otherLock = Lock::PerformLock>
    void add(BasicHistogram1D&& other, std::error_code& error);

    /** @brief Add from a raw array in memory.
     *
     * @param data Pointer to the first element of data.
     * @param dataSize The number of elements in the array (NOT the number of bytes). If this does not match the
     * size of the internal data store the method fails.
     * @param entries The number of entries this data corresponds to. If you don't know call the overload without
     * it, and it will assume unweighted data and sum the data in the array.
     * @param error An error_code that is modified on failure.
     */
    template<Lock lock = Lock::PerformLock>
    void add(const content_type* data, size_t dataSize, size_t entries, std::error_code& error);

    /** @brief Add from a raw array in memory, calculating the number of entries by assuming unweighted data. */
    template<Lock lock = Lock::PerformLock>
    void add(const content_type* data, size_t dataSize, std::error_code& error);

    template<Lock lock = Lock::PerformLock>
    void clear();

    using root_type = typename detail::root_type<1, content_type>::type;

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
    template<Lock lock = Lock::PerformLock, Lock otherLock = Lock::PerformLock, typename histogram_type>
    void addImpl(histogram_type&& other, std::error_code& error);
};

} // end of namespace musip::dqm

//
// Definitions that need to be in this file because they're templated.
//
#include <cstring>
#include "musip/dqm/PlotCollection.hpp"

template<typename xaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
void musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::fill(xaxis_type value, content_type weight) {
    typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);

    const int boostIndex = axis_.index(value);

    data_[ boostIndex + bin_offset ] += weight;
    ++entries_;
}

template<typename xaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
size_t musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::entries() const {
    typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);

    return entries_;
}

template<typename xaxis_type_, typename content_type_>
unsigned musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::numberOfBins() const {
    // Note that we don't lock the mutex for this, because once the histogram has been created
    // the binning can't change.
    return axis_.size();
}

template<typename xaxis_type_, typename content_type_>
xaxis_type_ musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::lowEdge() const {
    // Note that we don't lock the mutex for this, because once the histogram has been created
    // the binning can't change.
    return lowEdge_;
}

template<typename xaxis_type_, typename content_type_>
xaxis_type_ musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::highEdge() const {
    // Note that we don't lock the mutex for this, because once the histogram has been created
    // the binning can't change.
    return highEdge_;
}

template<typename xaxis_type_, typename content_type_>
template<musip::dqm::Lock lock, musip::dqm::Lock otherLock>
void musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::add(const BasicHistogram1D& other, std::error_code& error) {
    return addImpl<lock, otherLock>(other, error);
}

template<typename xaxis_type_, typename content_type_>
template<musip::dqm::Lock lock, musip::dqm::Lock otherLock>
void musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::add(BasicHistogram1D&& other, std::error_code& error) {
    return addImpl<lock, otherLock>(std::move(other), error);
}

template<typename xaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
void musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::add(const content_type* data, size_t dataSize, size_t entries, std::error_code& error) {
    // Currently require all of the data needs to be set, or none. I don't see a useful case for partial adds.
    if(dataSize != data_.size()) { error = std::make_error_code(std::errc::argument_out_of_domain); return; }

    typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);

    if(entries_ == 0) {
        // We can use memcpy to do a fast copy of the data
        std::memcpy(data_.data(), data, dataSize * sizeof(content_type));
    }
    else {
        // There is already data in this histogram. We need to perform a slower add.
        for(size_t index = 0; index < data_.size(); ++index) {
            data_[index] += data[index];
        }
    }

    entries_ += entries;
}

template<typename xaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
void musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::add(const content_type* data, size_t dataSize, std::error_code& error) {
    // We need to know the number of entries and that wasn't provided. Assume that the data provided is
    // unweighted so we can get the number of entries simply by summing the entries in each bin.
    // No mutex lock required yet.
    size_t dataSum = 0;
    for(size_t index = 0; index < dataSize; ++index) dataSum += data[index];
    if(dataSum == 0) return; // No data to add

    // Now we know the number of entries delegate to the overload that takes the number of entries
    return add<lock>(data, dataSize, dataSum, error);
}

template<typename xaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
void musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::clear() {
    typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);

    std::memset(data_.data(), 0, data_.size() * sizeof(content_type));
    entries_ = 0;
}

template<typename xaxis_type_, typename content_type_>
template<musip::dqm::Lock lock>
std::unique_ptr<typename musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::root_type> musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::asRootObject(const std::string& histogramName, const std::string& histogramTitle) const {
    typename detail::guard_type<lock, mutex_type>::type lockGuard(mutex_);

    // If a title has been set in the metadata, use that. If not just reuse the name parameter
    const std::string& titleFromMetadata = metadata_.get<Metadata::Category::Title>();
    const std::string& title = (&titleFromMetadata != &Metadata::nullEntry ? titleFromMetadata : histogramName);

    auto pHistogram = std::make_unique<root_type>(histogramName.c_str(), title.c_str(), numberOfBins(), lowEdge(), highEdge());
    // Hope and pray whatever the current directory is, it isn't destroyed before the next line. Gotta love root's memory model.
    pHistogram->SetDirectory(nullptr);

    const std::string& axisTitleX = metadata_.get<Metadata::Category::AxisTitleX>();
    if(&axisTitleX != &Metadata::nullEntry) pHistogram->GetXaxis()->SetTitle(axisTitleX.c_str());

    const std::string& axisTitleY = metadata_.get<Metadata::Category::AxisTitleY>();
    if(&axisTitleY != &Metadata::nullEntry) pHistogram->GetYaxis()->SetTitle(axisTitleY.c_str());

    std::memcpy(pHistogram->GetArray(), data_.data(), data_.size() * sizeof(content_type_));
    pHistogram->SetEntries(entries<Lock::AlreadyLocked>());

    return pHistogram;
}

template<typename xaxis_type_, typename content_type_>
template<musip::dqm::Lock lock, musip::dqm::Lock otherLock, typename histogram_type>
void musip::dqm::BasicHistogram1D<xaxis_type_, content_type_>::addImpl(histogram_type&& other, std::error_code& error) {
    // Check the type of both histograms matches. This method shouldn't be able to be called
    // with different types but we might as well check.
    static_assert(std::is_same<typename std::decay<decltype(*this)>::type, typename std::decay<histogram_type>::type>::value, "Adding histograms together is only supported with histograms of the same type");

    // First check binning matches. We don't need to lock either mutex for this.
    if(numberOfBins() != other.numberOfBins() || lowEdge() != other.lowEdge() || highEdge() != other.highEdge()) {
        error = std::make_error_code(std::errc::invalid_argument); // TODO: make my own error codes with more meaningful values
        return;
    }
    // This is implied if the binning matches, but I want to be extra safe.
    if(data_.size() != other.data_.size()) {
        error = std::make_error_code(std::errc::invalid_argument);
        return;
    }

    // If the two histograms are using the same mutex, we can't lock the same mutex twice.
    // So use a dummy void mutex in that case.
    mutex_type otherMutex = (mutex_ == other.mutex_ ? mutex_type(nullptr) : other.mutex_);

    // We now need to look at the mutable data, so we need to lock both histograms
    typename detail::guard_type<lock, mutex_type>::type thisLockGuard(mutex_);
    typename detail::guard_type<otherLock, mutex_type>::type otherLockGuard(otherMutex);

    if constexpr(std::is_rvalue_reference<histogram_type&&>::value) {
        // The other histogram is an rvalue reference, i.e. it is a temporary or it was
        // passed in with std::move. So we can switch out the data if we need to.
        if(entries_ == 0) {
            // This histogram is empty, so we can optimise with a fast swap.
            std::swap(data_, other.data_);
            std::swap(entries_, other.entries_);
            return;
        }
    }

    // If we got to this point the vector swap optimisation didn't trigger. We can delegate
    // to the `add` method that works on raw memory.
    add<Lock::AlreadyLocked>(other.data_.data(), other.data_.size(), other.entries_, error);
}
