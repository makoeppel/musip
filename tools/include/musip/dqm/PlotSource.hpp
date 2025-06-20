#pragma once

#include "musip/dqm/dqmfwd.hpp"
#include "musip/dqm/PlotCollection.hpp"

#include <optional>
#include <shared_mutex>
#include <unordered_map>

namespace musip::dqm {

/** @brief Contains all plots from a single place. E.g. all PlotCollections for a particular run will be contained in one PlotSource.
 *
 * The current run will have an instance of PlotSource containing all DQM data for that run. If a previous run
 * is retreived from disk, that will be in a different PlotSource instance.
 *
 * The mutex used is templated, so that for data loaded from disk (i.e. previous runs) which is never modified,
 * you don't have the cost of locking. For the current run data is constantly changing so a mutex is required.
 */
template<typename mutex_type = std::shared_mutex>
class PlotSource {
public:
    /** Returns the named collection. If it didn't previously exist it is created. */
    PlotCollection* getOrCreateCollection(const std::string& name);

    /** Returns the named collection. If it didn't previously exist nullptr is returned. */
    PlotCollection* getCollection(const std::string& name);

    void saveAsRootFile(const char* filename, std::error_code& error) const { return saveAsRootFile(filename, true, "RECREATE", error); }
    void saveAsRootFile(const char* filename, const char* options, std::error_code& error) const { return saveAsRootFile(filename, true, options, error); }
    void saveAsRootFile(const char* filename, bool skipEmptyHistograms, std::error_code& error) const { return saveAsRootFile(filename, skipEmptyHistograms, "RECREATE", error); }
    void saveAsRootFile(const char* filename, bool skipEmptyHistograms, const char* options, std::error_code& error) const;
    void addFromRootFile(const char* filename, std::error_code& error);

    /** @brief Clear all of the histograms in all of the collections. */
    void clearAll();

    /** @brief Returns a list of all histogram names. */
    std::vector<std::string> list(bool skipEmptyHistograms) const;

    /** @brief Appends a list of all histogram names to the provided vector. */
    void list(std::vector<std::string>& allNames, bool skipEmptyHistograms) const;
protected:
    mutable mutex_type globalMutex_;
    std::unordered_map<std::string,PlotCollection> plotCollections_;
}; // end of class PlotSource

} // end of namespace musip::dqm

//
// Definitions of methods required in the header because they're templated.
//

#include <filesystem>
#include <TFile.h>

template<typename mutex_type>
musip::dqm::PlotCollection* musip::dqm::PlotSource<mutex_type>::getOrCreateCollection(const std::string& name) {
    std::unique_lock lock(globalMutex_);

    auto [iCollection, wasInserted] = plotCollections_.try_emplace(name);
    PlotCollection& collection = iCollection->second;

    return &collection;
}

template<typename mutex_type>
musip::dqm::PlotCollection* musip::dqm::PlotSource<mutex_type>::getCollection(const std::string& name) {
    std::shared_lock globalLock(globalMutex_);

    if(auto iCollection = plotCollections_.find(name); iCollection != plotCollections_.end()) {
        return &iCollection->second;
    }

    return nullptr;
}

template<typename mutex_type>
void musip::dqm::PlotSource<mutex_type>::saveAsRootFile(const char* filename, bool skipEmptyHistograms, const char* options, std::error_code& error) const
{
    // If the parent folder doesn't exist, create it
    const std::filesystem::path parentFolder = std::filesystem::path(filename).parent_path();
    if(!parentFolder.empty()) std::filesystem::create_directories( parentFolder );

    // Use a custom deleter to write the file to disk when it goes out of scope.
    std::unique_ptr<TFile, void(*)(TFile*)> pOutputFile(TFile::Open(filename, options), [](TFile* pFile) {
        pFile->Write();
        delete pFile;
    });

    if(pOutputFile == nullptr) {
        error = std::make_error_code(std::errc::no_such_file_or_directory);
        return;
    }

    std::shared_lock globalLock(globalMutex_);

    for(const auto& [collectionName, collection] : plotCollections_) {
        TDirectory* pCollectionDirectory = pOutputFile->mkdir(collectionName.c_str());

        // The collection lock is taken inside this method.
        collection.saveToRootDirectory(pCollectionDirectory, skipEmptyHistograms);
    } // end of loop over collections
} // end of method PlotSource::saveAsRootFile

template<typename mutex_type>
void musip::dqm::PlotSource<mutex_type>::addFromRootFile(const char* filename, std::error_code& error) {
    std::unique_ptr<TFile> pInputFile(TFile::Open(filename, "READ"));

    if(pInputFile == nullptr) {
        error = std::make_error_code(std::errc::no_such_file_or_directory);
        return;
    }

    //
    // We first loop over directories in the root of the file. Each directory will be a `PlotCollection`. If there
    // are any objects other than directories there we can't do anything with them, since we don't have a PlotCollection
    // to put them in.
    //
    for(const TObject* pObject : *pInputFile->GetListOfKeys()) {
        const TKey* pKey = static_cast<const TKey*>(pObject);

        if(0 == std::strcmp(pKey->GetClassName(), "TDirectoryFile")) {
            // We don't need to lock `globalMutex_` because this call does it
            PlotCollection* pCollection = getOrCreateCollection(pKey->GetName());

            TDirectoryFile* pCollectionDirectory = pInputFile->Get<TDirectoryFile>(pKey->GetName());
            pCollection->addFromRootDirectory(pCollectionDirectory, "");
        }
        else printf("PlotSource::addFromRootFile - Ignoring key '%s' of class '%s' in base directory\n", pKey->GetName(), pKey->GetClassName());
    }
} // end of method PlotSource::addFromRootFile()

template<typename mutex_type>
void musip::dqm::PlotSource<mutex_type>::clearAll() {
    std::shared_lock globalLock(globalMutex_);

    for(auto& [collectionName, plotCollection] : plotCollections_) {
        plotCollection.clearAll();
    } // end of loop over collections
} // end of method PlotSource::clearAll()

template<typename mutex_type>
std::vector<std::string> musip::dqm::PlotSource<mutex_type>::list(bool skipEmptyHistograms) const {
    std::vector<std::string> returnValue;
    list(returnValue, skipEmptyHistograms);
    return returnValue;
}

template<typename mutex_type>
void musip::dqm::PlotSource<mutex_type>::list(std::vector<std::string>& allNames, bool skipEmptyHistograms) const {
    std::shared_lock globalLock(globalMutex_);

    for(const auto& [collectionName, plotCollection] : plotCollections_) {
        std::lock_guard collectionLock(plotCollection.mutex);

        for(const auto& [objectName, object] : plotCollection.objects_) {
            if(skipEmptyHistograms) {
                const bool isEmpty = std::visit([](const auto& histogram) {return histogram.template entries<Lock::AlreadyLocked>() == 0;}, object);
                if(isEmpty) continue;
            }
            allNames.push_back(collectionName + "/" + objectName);
        } // end of loop over histogram objects
    } // end of loop over collections
}
