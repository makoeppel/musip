#pragma once

#include "musip/dqm/dqmfwd.hpp"
#include "musip/dqm/BasicHistogram1D.hpp"
#include "musip/dqm/BasicHistogram2D.hpp"
#include "musip/dqm/BasicRollingHistogram2D.hpp"

#include <variant>
#include <unordered_map>
#include <mutex>
// Forward declarations
class TDirectory;

namespace musip::dqm {

class PlotCollection {
public:
    using mutex_type = detail::MutexPointer<std::mutex>;
    /** @brief Mutex for creating histograms and interacting with them in any way.
     *
     * Intentionally public so that users have the option of locking it themselves for a complex
     * series of interactions. If that is done, all methods that take the lock take a template argument
     * to tell them not to try taking the lock again. */
    mutable mutex_type mutex = mutex_type(&realMutex_);

    /** @brief Turn off thread locking protection for this collection and all objects contained within it.
     *
     * Only do this if you're absolutely sure the collection or any of its objects will be accessed sequentially.
     * Turning this protection off for a single threaded application can speed processing up considerably.
     *
     * The default is for thread lock to be enabled. */
    void switchOffThreadProtection();

    /** @brief Turn on thread locking. This is the default. */
    void switchOnThreadProtection();

    template<Lock lock = Lock::PerformLock, typename... metadata_param_types>
    Histogram1DF* getOrCreateHistogram1DF(const std::string& path, size_t numberOfBins, float lowEdge, float highEdge, std::error_code& error, metadata_param_types&&... metadataParams);

    template<Lock lock = Lock::PerformLock, typename... metadata_param_types>
    Histogram1DD* getOrCreateHistogram1DD(const std::string& path, size_t numberOfBins, float lowEdge, float highEdge, std::error_code& error, metadata_param_types&&... metadataParams);

    template<Lock lock = Lock::PerformLock, typename... metadata_param_types>
    Histogram1DI* getOrCreateHistogram1DI(const std::string& path, size_t numberOfBins, float lowEdge, float highEdge, std::error_code& error, metadata_param_types&&... metadataParams);

    template<Lock lock = Lock::PerformLock, typename... metadata_param_types>
    Histogram2DF* getOrCreateHistogram2DF(const std::string& path, size_t numberOfXBins, float lowXEdge, float highXEdge, size_t numberOfYBins, float lowYEdge, float highYEdge, std::error_code& error, metadata_param_types&&... metadataParams);

    template<Lock lock = Lock::PerformLock, typename... metadata_param_types>
    Histogram2DD* getOrCreateHistogram2DD(const std::string& path, size_t numberOfXBins, float lowXEdge, float highXEdge, size_t numberOfYBins, float lowYEdge, float highYEdge, std::error_code& error, metadata_param_types&&... metadataParams);

    template<Lock lock = Lock::PerformLock, typename... metadata_param_types>
    Histogram2DI* getOrCreateHistogram2DI(const std::string& path, size_t numberOfXBins, float lowXEdge, float highXEdge, size_t numberOfYBins, float lowYEdge, float highYEdge, std::error_code& error, metadata_param_types&&... metadataParams);

    template<Lock lock = Lock::PerformLock, typename... metadata_param_types>
    RollingHistogram2DF* getOrCreateRollingHistogram2DF(const std::string& path, unsigned numberOfSlices, std::chrono::steady_clock::duration sliceDuration, size_t numberOfXBins, float lowXEdge, float highXEdge, size_t numberOfYBins, float lowYEdge, float highYEdge, std::error_code& error, metadata_param_types&&... metadataParams);

    /** @brief Clears the data in all histograms. */
    template<Lock lock = Lock::PerformLock>
    void clearAll();

    /** @brief Clears the data in the specified histograms.
     *
     * Returns true if the histogram existed and was cleared, false if the histogram doesn't exist. */
    template<Lock lock = Lock::PerformLock>
    bool clear(const std::string& path);

    using object_type = std::variant<Histogram1DF, Histogram1DD, Histogram2DF, Histogram1DI, Histogram2DI, RollingHistogram2DF, Histogram2DD>;

    template<Lock lock = Lock::PerformLock>
    const object_type* get(const std::string& path) const;

    void saveAsRootFile(const char* filename, const char* options = "RECREATE") { return saveAsRootFile(filename, true, options); }
    void saveAsRootFile(const char* filename, bool skipEmptyHistograms, const char* options = "RECREATE");

protected:
    // Templated method that all the other `getOrCreate...` methods delegate to.
    template<Lock lock, typename histogram_type, typename... constructor_params>
    histogram_type* getOrCreate(const std::string& path, std::error_code& error, constructor_params&&... constructorParams);

    // Helper template function used by addFromRootDirectory
    template<typename root_type, typename dqm_type, Lock lock = Lock::PerformLock>
    void createAndAddFromRoot(TDirectory* pDirectory, const char* objectName, const std::string& fullPath, std::error_code& error);

    /* Helper template function to load a root histogram from a directory and add it to a DQM histogram.
     *
     * Syntax is a little weird because it uses the passed in function `getHistogramFunction` to create the DQM histogram.
     * This is so that the same code can be reused whether we want to create a new histogram, or use an already
     * existing histogram. */
    template<typename root_type, typename dqm_type, Lock lock = Lock::PerformLock, typename function_type>
    static void addFromRoot(TDirectory* pDirectory, const char* objectName, std::error_code& error, function_type&& getHistogramFunction);

    void saveToRootDirectory(TDirectory* pDirectory, bool skipEmptyHistograms) const;
    template<Lock lock = Lock::PerformLock>
    void addFromRootDirectory(TDirectory* pDirectory, const std::string& directoryPath);

    // This is the actual std::mutex we use for locking this object and all plots in the collection. Locking can
    // be turned off dynamically though, and this is done by locking on the proxy object `this->mutex`. If locking
    // is turned on, this->mutex locks this actual mutex. If not it does nothing.
    mutable std::mutex realMutex_;

    // We hand out pointers to objects in this collection. From https://en.cppreference.com/w/cpp/container/unordered_map
    // unordered_map has the property "...pointers to either key or data stored in the container are only invalidated by
    // erasing that element, even when the corresponding iterator is invalidated". Pretty sure std::map doesn't have this
    // property, so we can only use unordered_map.
    std::unordered_map<std::string,object_type> objects_;

    template<typename plotsource_mutex_type> friend class PlotSource;
};

} // end of namespace musip::dqm

//
// Definitions that need to be in this file because they're templated.
//
#include "musip/dqm/detail.hpp"
#include <TDirectory.h>
#include <TAxis.h>
#include <TKey.h>
#include <TDirectoryFile.h>

template<musip::dqm::Lock lock, typename... metadata_param_types>
musip::dqm::Histogram1DF* musip::dqm::PlotCollection::getOrCreateHistogram1DF(const std::string& path, size_t numberOfBins, float lowEdge, float highEdge, std::error_code& error, metadata_param_types&&... metadataParams) {
    return getOrCreate<lock, Histogram1DF>(path, error, numberOfBins, lowEdge, highEdge, std::forward<metadata_param_types>(metadataParams)...);
}

template<musip::dqm::Lock lock, typename... metadata_param_types>
musip::dqm::Histogram1DD* musip::dqm::PlotCollection::getOrCreateHistogram1DD(const std::string& path, size_t numberOfBins, float lowEdge, float highEdge, std::error_code& error, metadata_param_types&&... metadataParams) {
    return getOrCreate<lock, Histogram1DD>(path, error, numberOfBins, lowEdge, highEdge, std::forward<metadata_param_types>(metadataParams)...);
}

template<musip::dqm::Lock lock, typename... metadata_param_types>
musip::dqm::Histogram1DI* musip::dqm::PlotCollection::getOrCreateHistogram1DI(const std::string& path, size_t numberOfBins, float lowEdge, float highEdge, std::error_code& error, metadata_param_types&&... metadataParams) {
    return getOrCreate<lock, Histogram1DI>(path, error, numberOfBins, lowEdge, highEdge, std::forward<metadata_param_types>(metadataParams)...);
}

template<musip::dqm::Lock lock, typename... metadata_param_types>
musip::dqm::Histogram2DF* musip::dqm::PlotCollection::getOrCreateHistogram2DF(const std::string& path, size_t numberOfXBins, float lowXEdge, float highXEdge, size_t numberOfYBins, float lowYEdge, float highYEdge, std::error_code& error, metadata_param_types&&... metadataParams) {
    return getOrCreate<lock, Histogram2DF>(path, error, numberOfXBins, lowXEdge, highXEdge, numberOfYBins, lowYEdge, highYEdge, std::forward<metadata_param_types>(metadataParams)...);
}

template<musip::dqm::Lock lock, typename... metadata_param_types>
musip::dqm::Histogram2DD* musip::dqm::PlotCollection::getOrCreateHistogram2DD(const std::string& path, size_t numberOfXBins, float lowXEdge, float highXEdge, size_t numberOfYBins, float lowYEdge, float highYEdge, std::error_code& error, metadata_param_types&&... metadataParams) {
    return getOrCreate<lock, Histogram2DD>(path, error, numberOfXBins, lowXEdge, highXEdge, numberOfYBins, lowYEdge, highYEdge, std::forward<metadata_param_types>(metadataParams)...);
}

template<musip::dqm::Lock lock, typename... metadata_param_types>
musip::dqm::Histogram2DI* musip::dqm::PlotCollection::getOrCreateHistogram2DI(const std::string& path, size_t numberOfXBins, float lowXEdge, float highXEdge, size_t numberOfYBins, float lowYEdge, float highYEdge, std::error_code& error, metadata_param_types&&... metadataParams) {
    return getOrCreate<lock, Histogram2DI>(path, error, numberOfXBins, lowXEdge, highXEdge, numberOfYBins, lowYEdge, highYEdge, std::forward<metadata_param_types>(metadataParams)...);
}

template<musip::dqm::Lock lock, typename... metadata_param_types>
musip::dqm::RollingHistogram2DF* musip::dqm::PlotCollection::getOrCreateRollingHistogram2DF(const std::string& path, unsigned numberOfSlices, std::chrono::steady_clock::duration sliceDuration, size_t numberOfXBins, float lowXEdge, float highXEdge, size_t numberOfYBins, float lowYEdge, float highYEdge, std::error_code& error, metadata_param_types&&... metadataParams) {
    return getOrCreate<lock, RollingHistogram2DF>(path, error, numberOfSlices, sliceDuration, numberOfXBins, lowXEdge, highXEdge, numberOfYBins, lowYEdge, highYEdge, std::forward<metadata_param_types>(metadataParams)...);
}

template<musip::dqm::Lock lock>
void musip::dqm::PlotCollection::clearAll() {
    // Lock the mutex for the duration to save locking and unlocking for every plot
    typename detail::guard_type<lock, mutex_type>::type lockGuard(this->mutex);

    for(auto& nameObjectPair : objects_) {
        // Lock is already taken above, so specify not to attempt again with `Lock::AlreadyLocked` or we'll get a deadlock.
        std::visit( [](auto& object){ object.template clear<Lock::AlreadyLocked>(); }, nameObjectPair.second);
    } // end of loop over histogram objects
}

template<musip::dqm::Lock lock>
const musip::dqm::PlotCollection::object_type* musip::dqm::PlotCollection::get(const std::string& path) const {
    typename detail::guard_type<lock, mutex_type>::type lockGuard(this->mutex);

    if(auto iFindResult = objects_.find(path); iFindResult != objects_.end()){
        return &iFindResult->second;
    }
    else return nullptr;
}

template<musip::dqm::Lock lock>
bool musip::dqm::PlotCollection::clear(const std::string& path) {
    typename detail::guard_type<lock, mutex_type>::type lockGuard(this->mutex);

    if(const auto iObject = objects_.find(path); iObject != objects_.end()) {
        std::visit([](auto& histogram){histogram.template clear<Lock::AlreadyLocked>();}, iObject->second);
        return true;
    }
    else return false;
}

template<musip::dqm::Lock lock, typename histogram_type, typename... constructor_params>
histogram_type* musip::dqm::PlotCollection::getOrCreate(const std::string& path, std::error_code& error, constructor_params&&... constructorParams)
{
    typename detail::guard_type<lock, mutex_type>::type lockGuard(this->mutex);

    // Try to put the directory in at this position. If an object with this name already exists
    // then this won't do anything.
    auto [iNameObjectPair, wasInserted] = objects_.try_emplace(path, std::in_place_type<histogram_type>, this->mutex.pMutex, std::forward<constructor_params>(constructorParams)...);

    // If the object with this name is anything other than a `histogram_type` we need to fail.
    // If it is a `histogram_type` and it wasn't created with this call we need to check the
    // binning is the same.
    histogram_type* pHistogram = std::visit(detail::overloaded{
        [](auto& object) -> histogram_type* { return nullptr; },
        [](histogram_type& object) { return &object; }
    }, iNameObjectPair->second);

    if(pHistogram == nullptr) error = std::make_error_code(std::errc::file_exists);
    else if(!wasInserted) {
        // If this was already in the collection we need to check the binning matches.
        // TODO: check the binning matches.
        // TODO: check the metadata matches.
    }

    return pHistogram;
}

template<typename root_type, typename dqm_type, musip::dqm::Lock lock>
void musip::dqm::PlotCollection::createAndAddFromRoot(TDirectory* pDirectory, const char* objectName, const std::string& fullPath, std::error_code& error) {
    addFromRoot<root_type, dqm_type, lock>(pDirectory, objectName, error, [this, &fullPath](std::error_code& error, auto... params) -> dqm_type& {
        return *this->getOrCreate<lock, dqm_type>(fullPath, error, params...);
    });
}

template<typename root_type, typename dqm_type, musip::dqm::Lock lock, typename function_type>
void musip::dqm::PlotCollection::addFromRoot(TDirectory* pDirectory, const char* objectName, std::error_code& error, function_type&& getHistogramFunction) {
    const root_type* pHistogram = pDirectory->Get<root_type>(objectName);
    if(pHistogram == nullptr) return; // I've only seen this happen when the objectName is empty - root seems to be able to save objects with no name but not load them back
    const TAxis* pXAxis = pHistogram->GetXaxis();
    const auto numberOfXBins = pXAxis->GetNbins();
    const auto lowXEdge = pXAxis->GetBinLowEdge(1);
    const auto upperXEdge = pXAxis->GetBinUpEdge(numberOfXBins);

    // This cast is only required for Histogram<N>DI, because we use unsigned integer and root does not have an
    // unsigned histogram type. We'll just do a straight cast and keep our fingers crossed that none of the data
    // is larger than 2^31.
    const typename std::decay<dqm_type>::type::content_type* pRootData = reinterpret_cast<const typename dqm_type::content_type*>(pHistogram->GetArray());

    if constexpr(dqm_type::dimensions == 1) {
        // We can't use `auto` for the type of `newHistogram` because getHistogramFunction may or may not return a reference. If it does
        // return a reference we'd need `auto&`, and `auto` if not. Since we can't figure that out we have to explicitly figure out
        // the type.
        using histogram_type = typename std::invoke_result<function_type, std::error_code&, decltype(numberOfXBins), decltype(lowXEdge), decltype(upperXEdge)>::type;
        static_assert(std::is_same<typename std::decay<histogram_type>::type, dqm_type>::value, "The result of getHistogramFunction is not compatible with the declared dqm_type");

        histogram_type newHistogram = getHistogramFunction(error, numberOfXBins, lowXEdge, upperXEdge);
        newHistogram.template add<lock>(pRootData, newHistogram.data_.size(), pHistogram->GetEntries(), error);
    }
    else if constexpr(dqm_type::dimensions == 2) {
        const TAxis* pYAxis = pHistogram->GetYaxis();
        const auto numberOfYBins = pYAxis->GetNbins();
        const auto lowYEdge = pYAxis->GetBinLowEdge(1);
        const auto upperYEdge = pYAxis->GetBinUpEdge(numberOfYBins);

        // See the note above about why we can't use `auto` as the type of `newHistogram`.
        using histogram_type = typename std::invoke_result<function_type, std::error_code&, decltype(numberOfXBins), decltype(lowXEdge), decltype(upperXEdge), decltype(numberOfYBins), decltype(lowYEdge), decltype(upperYEdge)>::type;
        static_assert(std::is_same<typename std::decay<histogram_type>::type, dqm_type>::value, "The result of getHistogramFunction is not compatible with the declared dqm_type");

        histogram_type newHistogram = getHistogramFunction(error, numberOfXBins, lowXEdge, upperXEdge, numberOfYBins, lowYEdge, upperYEdge);
        newHistogram.template add<lock>(pRootData, newHistogram.data_.size(), pHistogram->GetEntries(), error);
    }
}

template<musip::dqm::Lock lock>
void musip::dqm::PlotCollection::addFromRootDirectory(TDirectory* pDirectory, const std::string& directoryPath) {
    // If the collection isn't already locked, lock it now so that we only lock once for all objects.
    typename detail::guard_type<lock, mutex_type>::type lockGuard(this->mutex);

    for(const TObject* pObject : *pDirectory->GetListOfKeys()) {
        const TKey* pKey = static_cast<const TKey*>(pObject);

        const std::string fullPath = directoryPath + (directoryPath.empty() ? "" : "/") + pKey->GetName();
        std::error_code error;

        if(0 == std::strcmp(pKey->GetClassName(), "TDirectoryFile")) {
            TDirectoryFile* pSubDirectory = pDirectory->Get<TDirectoryFile>(pKey->GetName());
            addFromRootDirectory<Lock::AlreadyLocked>(pSubDirectory, fullPath);
        }
        else if(0 == std::strcmp(pKey->GetClassName(), "TH1F")) createAndAddFromRoot<TH1F, Histogram1DF, Lock::AlreadyLocked>(pDirectory, pKey->GetName(), fullPath, error);
        else if(0 == std::strcmp(pKey->GetClassName(), "TH1D")) createAndAddFromRoot<TH1D, Histogram1DD, Lock::AlreadyLocked>(pDirectory, pKey->GetName(), fullPath, error);
        else if(0 == std::strcmp(pKey->GetClassName(), "TH2F")) createAndAddFromRoot<TH2F, Histogram2DF, Lock::AlreadyLocked>(pDirectory, pKey->GetName(), fullPath, error);
        else if(0 == std::strcmp(pKey->GetClassName(), "TH1I")) createAndAddFromRoot<TH1I, Histogram1DI, Lock::AlreadyLocked>(pDirectory, pKey->GetName(), fullPath, error);
        else if(0 == std::strcmp(pKey->GetClassName(), "TH2I")) createAndAddFromRoot<TH2I, Histogram2DI, Lock::AlreadyLocked>(pDirectory, pKey->GetName(), fullPath, error);
        else if(0 == std::strcmp(pKey->GetClassName(), "TH2D")) createAndAddFromRoot<TH2D, Histogram2DD, Lock::AlreadyLocked>(pDirectory, pKey->GetName(), fullPath, error);
        else printf("Don't know how to add '%s' of class '%s'\n", fullPath.c_str(), pKey->GetClassName());
    } // end of loop over TKeys in this TDirectory
} // end of method PlotCollection::addFromRootDirectory()
