#include "musip/dqm/PlotCollection.hpp"

#include <filesystem>
#include <TFile.h>
#include <TH1F.h>
#include <TH2F.h>

void musip::dqm::PlotCollection::switchOffThreadProtection() {
    // We don't bother locking to perform this change. It's clear the user considers
    // it safe to change things without locking.

    // This turns off thread locking for creating new objects, and this setting
    // will be passed on to any new objects that are created.
    this->mutex.pMutex = nullptr;
    // We still need to update all the objects previously created, so that they
    // also stop locking.
    for(auto& iNameObjectPair : objects_) {
        std::visit([](const auto& histogram) { histogram.mutex_.pMutex = nullptr; }, iNameObjectPair.second );
    }
}

void musip::dqm::PlotCollection::switchOnThreadProtection() {
    // We don't bother locking to perform this change. The state was thread unsafe
    // at the start of the function, so making it safe half way through is not going
    // to help with anything.

    // This turns on thread locking for creating new objects, and this setting
    // will be passed on to any new objects that are created.
    this->mutex.pMutex = &realMutex_;
    // We still need to update all the objects previously created.
    for(auto& iNameObjectPair : objects_) {
        std::visit([this](const auto& histogram) { histogram.mutex_.pMutex = &realMutex_; }, iNameObjectPair.second );
    }
}

void musip::dqm::PlotCollection::saveAsRootFile(const char* filename, bool skipEmptyHistograms, const char* options) {
    // If the parent folder doesn't exist, create it
    const std::filesystem::path parentFolder = std::filesystem::path(filename).parent_path();
    if(!parentFolder.empty()) std::filesystem::create_directories( parentFolder );

    // Use a custom deleter to write the file to disk when it goes out of scope.
    std::unique_ptr<TFile, void(*)(TFile*)> pOutputFile(TFile::Open(filename, options), [](TFile* pFile) {
        pFile->Write();
        delete pFile;
    });

    saveToRootDirectory(pOutputFile.get(), skipEmptyHistograms);
}

void musip::dqm::PlotCollection::saveToRootDirectory(TDirectory* pDirectory, bool skipEmptyHistograms) const {
    std::unique_lock mutexLock(mutex);

    // The root file is much easier to navigate if the histograms are created in order. `objects_`
    // is an unordered_map however (because we need pointers to objects in the collection to always be valid).
    // So take a copy (of references, obviously), sort that, and then loop through those.
    std::vector<std::pair<std::string_view,const PlotCollection::object_type*>> collectionCopy;
    collectionCopy.reserve(objects_.size());
    for(auto& [objectName, object] : objects_) {
        if(skipEmptyHistograms) {
            const bool isEmpty = std::visit([](const auto& histogram) {return histogram.template entries<Lock::AlreadyLocked>() == 0;}, object);
            if(isEmpty) continue;
        }
        collectionCopy.emplace_back(objectName, &object);
    }
    std::sort( collectionCopy.begin(), collectionCopy.end(), [](const auto& lhs, const auto& rhs) {
        return lhs.first < rhs.first; // `first` is the object name, so this is sorting by object name
    });

    for(const auto& [objectName, pObject] : collectionCopy) {
        TDirectory* pObjectDirectory = pDirectory;

        //
        // Split the objectName down by "/" and create directories in the root file
        // for everything between slashes.
        //
        const std::filesystem::path objectPath(objectName);
        auto iPathElement = objectPath.begin();
        for(; iPathElement != objectPath.end(); ++iPathElement) {
            // We want to stop before the final entry, because that is a histogram name not a directory name.
            auto iNextElement = iPathElement;
            ++iNextElement;
            if(iNextElement == objectPath.end()) break;
            // This is not the last entry, so this is a directory name.
            TDirectory* pSubDirectory = pObjectDirectory->Get<TDirectory>(iPathElement->c_str());
            if(pSubDirectory != nullptr) pObjectDirectory = pSubDirectory;
            else pObjectDirectory = pObjectDirectory->mkdir(iPathElement->c_str());
        }

        //
        // We should now have the correct directory, and `iPathElement` is the name of the histogram.
        //
        const std::string histogramName = (iPathElement->empty() ? "<unnamed>" : *iPathElement);
        // Note that we don't `pObjectDirectory->cd()` because we set the directory of the histogram immediately
        // after it's been created. This is so we don't mess with the global Root state.

        // Use std::visit to make decisions depending on what type of histogram the object is.
        std::visit(detail::overloaded{
            [&histogramName, pObjectDirectory](const auto& dqmObject) {
                const auto& histogramTitle = histogramName; // We don't have a title so reuse the name
                auto pRootHistogram = dqmObject.template asRootObject<Lock::AlreadyLocked>(histogramName, histogramTitle);
                pRootHistogram->SetDirectory(pObjectDirectory);
                // Once the histogram is assigned to a directory, the directory takes ownership so we need to release the unique_ptr
                pRootHistogram.release();
            }
        }, *pObject);
    } // end of loop over objects in the collection
} // end of method PlotCollection::saveToRootDirectory()
