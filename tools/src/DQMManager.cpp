#include "musip/dqm/DQMManager.hpp"

#include "musip/dqm/PlotCollection.hpp"
#include "musip/dqm/HistogramEncoder.hpp"

#include <mjson.h>

#include <string_view>
#include <filesystem>

#include <TROOT.h>
#include <TFile.h>
#include <TKey.h>
#include <TH1F.h>
#include <TH1D.h>
#include <TH2F.h>

namespace { // the unnamed namespace

/* @brief Runs some code when the excutable starts.
 *
 * Get an instance of the DQMManager so that it gets constructed. That way it will respond to
 * requests before the first run, when it would otherwise be constructed.
 *
 * It won't have any histograms, but at least it can respond and say it has no histograms.
 */
struct StartupCode {
    StartupCode() {
        musip::dqm::DQMManager::instance();
    }
} startupCode;

/** @brief Parse arguments from a JSON string.
 *
 * Note that this function is used by two different RPC calls, which may not have all of the parameters. For example,
 * a dqm::list call does not expect or want a `histogramPath`, but it just passes in a dummy variable to satisfy the
 * function signature. Not the best coding but it'll do for now.
 *
 * @param json The JSON string to parse
 * @param[out] histogramPath The value in the "name" entry. This is a view into the original `json` view. Make sure the buffer is still in scope when this is used.
 * @param[out] includeCurrentRun Set to true if the "runs" entry includes zero (which means current run).
 * @param[out] runNumbers All numbers in the "runs" entry, other than zero.
 * @param[out] error Gets set if any errors are encountered
 */
void parseJSONArgs(const std::string_view json, std::string_view& histogramPath, bool& includeCurrentRun, std::vector<int>& runNumbers, std::error_code& error) {
    MJsonNode* pRootNode = MJsonNode::Parse(json.data());

    if(pRootNode->GetType() == MJSON_ERROR) {
        std::string errorMessage = pRootNode->GetError();
        fprintf(stderr, "DQMManager::HandleRpc - Couldn't parse JSON string: '%s'\n", errorMessage.c_str());
        error = std::make_error_code(std::errc::bad_message);
        return;
    }
    else if(pRootNode->GetType() == MJSON_OBJECT) {
        const std::vector<std::string>& subNodeNames = *pRootNode->GetObjectNames();
        const std::vector<MJsonNode*>& subNodes = *pRootNode->GetObjectNodes();
        for(size_t index = 0; index < subNodeNames.size() && index < subNodes.size(); ++index) {
            if(subNodeNames[index] == "name") {
                if(subNodes[index]->GetType() != MJSON_STRING) {
                    const std::string typeName = MJsonNode::TypeToString(subNodes[index]->GetType());
                    fprintf(stderr, "DQMManager::HandleRpc - Unable to parse \"name\" node of type %s\n", typeName.c_str());
                    continue;
                }

                std::string parsedName = subNodes[index]->GetString();
                // We have a std::string copy of the name, but the code lower down works on std::string_view. We can't take
                // a string_view of `name` because it will be out of scope when the view is used. So find the same text in
                // the original arg which will stay in scope.
                histogramPath = json.substr(json.find(parsedName), parsedName.size());
            } // end of `if name == "name"`
            else if(subNodeNames[index] == "runs") {
                if(subNodes[index]->GetType() != MJSON_ARRAY) {
                    const std::string typeName = MJsonNode::TypeToString(subNodes[index]->GetType());
                    fprintf(stderr, "DQMManager::HandleRpc - Unable to parse \"runs\" node of type %s\n", typeName.c_str());
                    continue;
                }

                for(const auto& pRunNumberNode : *subNodes[index]->GetArray()) {
                    if(pRunNumberNode->GetType() == MJSON_INT) {
                        const int runNumber = pRunNumberNode->GetInt();
                        if(runNumber == 0) includeCurrentRun = true; // Zero means the current run
                        else runNumbers.push_back(static_cast<int>(pRunNumberNode->GetInt()));
                    }
                    else {
                        const std::string typeName = MJsonNode::TypeToString(pRunNumberNode->GetType());
                        fprintf(stderr, "DQMManager::HandleRpc - Unable to parse \"runs\" array element of type %s\n", typeName.c_str());
                    }
                } // end of loop over elements in the "runs" array
            } // end of `if name == "runs"`
            else fprintf(stderr, "DQMManager::HandleRpc - Ignoring unknown arg node \"%s\"\n", subNodeNames[index].c_str());
        } // end of loop over object sub nodes
    } // end of `if pRootNode type == MJSON_OBJECT`
    else {
        const std::string typeName = MJsonNode::TypeToString(pRootNode->GetType());
        fprintf(stderr, "DQMManager::HandleRpc - Unable to parse JSON node of type %s\n", typeName.c_str());
        error = std::make_error_code(std::errc::bad_message);
        return;
    }
} // end of function parseJSONArgs

} // end of the unnamed namespace

musip::dqm::DQMManager& musip::dqm::DQMManager::instance() {
    static DQMManager onlyInstance;
    return onlyInstance;
}

musip::dqm::PlotCollection* musip::dqm::DQMManager::getOrCreateCollection(const std::string& name) {
    auto returnValue = currentRun_.getOrCreateCollection(name);
    if(TMFE::Instance()->fDB == 0) {
        // If we're running offline, we won't get any RPC requests on the RPC thread. And modules
        // are *supposed* to get a unique PlotCollection instance. So they won't interfere with
        // each other even if they are running concurrently (with the `--mt` Midas option). We
        // can therefor speed up batch processing considerably by turning off thread locking.
        printf("Running offline, so switching off thread protection for collection '%s'\n", name.c_str());
        returnValue->switchOffThreadProtection();
    }
    return returnValue;
}

void musip::dqm::DQMManager::saveAsRootFile(const char* filename, bool skipEmptyHistograms, const char* options)
{
    std::error_code error;
    return currentRun_.saveAsRootFile(filename, skipEmptyHistograms, options, error);
    if(error) {
        fprintf(stderr, "DQMManager::saveAsRootFile - unable to save to '%s'\n", filename);
    }
} // end of method DQMManager::saveAsRootFile

void musip::dqm::DQMManager::addFromRootFile(const char* filename) {
    std::error_code error;
    return currentRun_.addFromRootFile(filename, error);
    if(error) {
        fprintf(stderr, "DQMManager::addFromRootFile - couldn't open file '%s'\n", filename);
    }
} // end of method DQMManager::addFromRootFile()

void musip::dqm::DQMManager::clearAll() {
    return currentRun_.clearAll();
} // end of method DQMManager::clearAll()

void musip::dqm::DQMManager::addHistoryDirectory(const std::filesystem::path& directoryPath) {
    std::lock_guard<std::mutex> lock(previousRunsMutex_);
    previousRunDirectories_.push_back(directoryPath);
}

musip::dqm::DQMManager::DQMManager() {
    // We always want Root to be multithreaded, because there's always a different thread
    // to handle the RPC even when analyzers are not multithreaded. Midas manalyzer only
    // enables this if "--mt" is specified on the command line, hence without these two
    // lines we'd get memory issues if run without "--mt".
    ROOT::EnableImplicitMT();
    ROOT::EnableThreadSafety();

    TMFE::Instance()->AddRpcHandler(this);
}

musip::dqm::DQMManager::~DQMManager() {
    TMFE::Instance()->RemoveRpcHandler(this);
}

TMFeResult musip::dqm::DQMManager::HandleBinaryRpc(const char* cmd, const char* args, std::vector<char>& result) {
    constexpr std::string_view commandPrefix = "dqm::";

    if(verbosity_ > 0) printf("Handle RPC '%s' '%s'\n", cmd, args);

    std::string_view command = cmd;
    if(command.substr(0, commandPrefix.size()) != commandPrefix) {
        // This command has nothing to do with us, so don't change `result` and let someone else
        // in the chain deal with it.
        return TMFeOk();
    }

    if(command == "dqm::list") {
        bool includeCurrentRun = true; // If there is no argument, we assume this is for the current run.
        std::vector<int> runNumbers;

        const std::string_view argument = args;
        if(!argument.empty()) {
            includeCurrentRun = false; // Now we know there is an argument, only use current run if specified
            std::string_view histogramPath; // We don't expect or care about this, but the function signature requires it.

            std::error_code error;
            parseJSONArgs(argument, histogramPath, includeCurrentRun, runNumbers, error);
            if(error) {
                fprintf(stderr, "DQMManager::HandleRpc - Error parsing JSON arguments for dqm::list call\n");
                return TMFeErrorMessage("TMFE completely ignores this error. I should put in a patch to Midas.");
            }
        }

        const bool skipEmptyHistograms = false; // TODO: Make this a parameter
        std::vector<std::string> names;
        if(includeCurrentRun) names = currentRun_.list(skipEmptyHistograms);
        // Append the names of any old runs requested. This might include duplicates but we deal
        // with this later.
        if(!runNumbers.empty()) {
            // Either get the preloaded accumulation of these runs, or if it doesn't exist yet load from disk.
            const auto pHistoricSource = getHistorySource(runNumbers);
            if(pHistoricSource != nullptr) pHistoricSource->list(names, skipEmptyHistograms);
        }

        // Sort the list of names before we return it. This also helps when removing duplicates.
        std::sort(names.begin(), names.end());
        if(verbosity_ > 0) printf("dqm::list - Got a list of %zu histogram names before removing duplicates.\n", names.size());

        // Put these in the output. For now we just concatenate separated by newlines. Later we
        // might do something more clever.
        std::string fullString = (names.empty() ? "" : names[0]);
        std::string_view lastEntry; // Used to avoid adding duplicates
        for(size_t index = 1; index < names.size(); ++index) {
            if(names[index] == lastEntry) continue; // don't add duplicate names
            fullString += "\n" + names[index];
            lastEntry = names[index];
        }

        // Midas will truncate the response if it is larger than the `max_reply_length` specified when
        // making the call. For the client to detect when this happens, we add a small header that states
        // the size that the full message should be. The client can then repeat the call with an adequate
        // value for `max_reply_length`.

        // I can't see this ever being close to 2^32 bytes, but we should check. If it is there's not much we can do, so just warn.
        if((sizeof(RPCHeader) + fullString.size()) > std::numeric_limits<uint32_t>::max()) fprintf(stderr, "DQMManager::HandleRpc - Size of message (%zu bytes) is too large to encode as a uint32_t\n", fullString.size());

        result.resize(sizeof(RPCHeader) + fullString.size());

        // Write the header information
        RPCHeader& header = *reinterpret_cast<RPCHeader*>(result.data());
        header.messageSize = static_cast<uint32_t>(sizeof(RPCHeader) + fullString.size());
        header.messageType = RPCHeader::MessageType::list;

        std::memcpy(result.data() + sizeof(RPCHeader), fullString.data(), fullString.size());
        // Final byte of result should already be zero from the resize

        return TMFeOk();
    }
    else if(command == "dqm::histogram") {
        const std::string_view argument = args;
        std::string_view histogramPath;
        bool includeCurrentRun = false;
        std::vector<int> runNumbers;

        if(argument.size() > 0 && argument[0] == '{') {
            // The arguments start with '{' so we assume this is a JSON object rather than just
            // a string of the histogram path.
            std::error_code error;
            parseJSONArgs(argument, histogramPath, includeCurrentRun, runNumbers, error);
            if(error) {
                fprintf(stderr, "DQMManager::HandleRpc - Error parsing JSON arguments for dqm::histogram call\n");
                return TMFeErrorMessage("TMFE completely ignores this error. I should put in a patch to Midas.");
            }
        }
        else {
            // This isn't a JSON object, so take the whole argument as the histogram name.
            histogramPath = argument;
        }

        if(runNumbers.empty()) includeCurrentRun = true; // No run(s) requested, so assume current run.

        const size_t collectionNameSize = histogramPath.find_first_of('/');
        if(collectionNameSize == std::string_view::npos) {
            printf("DQMManager::HandleRpc - Couldn't find collection name in argument '%s'\n", args);
            return TMFeErrorMessage("TMFE completely ignores this error. I should put in a patch to Midas.");
        }

        std::string collectionName( histogramPath.substr(0, collectionNameSize) );
        std::string histogramName( histogramPath.substr(collectionNameSize + 1) );

        //
        // Loop over all of the requested runs and add the histogram in each together
        //
        std::optional<PlotCollection::object_type> accumulatedHistogram;

        if(!runNumbers.empty()) {
            // Either get the preloaded accumulation of these numbers, or if it doesn't exist yet load from disk.
            const auto pHistoricSource = getHistorySource(runNumbers);
            if(pHistoricSource != nullptr) {
                // Look for the collection in this source
                const PlotCollection* pHistoricCollection = pHistoricSource->getCollection(collectionName);
                if(pHistoricCollection != nullptr) {
                    auto pHistoricPlot = pHistoricCollection->get(histogramName);
                    if(pHistoricPlot != nullptr) accumulatedHistogram = *pHistoricPlot;
                }
            }
        }

        // If the current run is to be included, add it on to the plot loaded from disk or set it
        // as the only plot if no previous runs are requested. 99.9% of the time the current plot
        // will be the only data added.
        if(includeCurrentRun) {
            PlotCollection* pCollection = currentRun_.getCollection(collectionName);

            if(pCollection != nullptr) {
                std::lock_guard<PlotCollection::mutex_type> lockGuard(pCollection->mutex);
                const auto pObject = pCollection->get<Lock::AlreadyLocked>(histogramName);
                if(pObject != nullptr) {
                    if(accumulatedHistogram.has_value()) {
                        std::error_code error;
                        std::visit(musip::dqm::detail::overloaded{
                            [&error](musip::dqm::RollingHistogram2DF& totalHistogram){
                                // This should never happen because a RollingHistogram will have been converted to
                                // a normal histogram (by using its `total()` method) when assigning to
                                // `accumulatedHistogram`. But we need this type-matcher to stop the compiler trying
                                // to compile the general one below for RollingHistogram.
                                error = std::make_error_code(std::errc::invalid_argument); // TODO: better error codes
                            },
                            [&pObject, &error](auto& totalHistogram){
                                std::visit([&totalHistogram, &error](const auto& currentRunHistogram){
                                    using total_type = typename std::decay<decltype(totalHistogram)>::type;
                                    using current_type = typename std::decay<decltype(currentRunHistogram)>::type;

                                    if constexpr(std::is_same<RollingHistogram2DF, current_type>::value && std::is_same<total_type, RollingHistogram2DF::histogram_type>::value) {
                                        // The timed histogram should have the total of all it's time slices added.
                                        totalHistogram.template add<Lock::AlreadyLocked, Lock::AlreadyLocked>(currentRunHistogram.total(), error);
                                    }
                                    else if constexpr(std::is_same<total_type, current_type>::value) {
                                        totalHistogram.template add<Lock::AlreadyLocked, Lock::AlreadyLocked>(currentRunHistogram, error);
                                    }
                                    else error = std::make_error_code(std::errc::invalid_argument); // TODO: better error codes
                                }, *pObject);
                            }
                        }, accumulatedHistogram.value());

                        if(error) {
                            const std::string errorMessage = error.message();
                            fprintf(stderr, "Couldn't add current run histogram to accumulation: %s\n", errorMessage.c_str());
                        }
                    }
                    else {
                        if(std::holds_alternative<RollingHistogram2DF>(*pObject)) {
                            // If it's a RollingHistogram we transport it as normal histogram, which is the
                            // total of all its time slices.
                            accumulatedHistogram = std::get<RollingHistogram2DF>(*pObject).total<Lock::AlreadyLocked>();
                        }
                        else {
                            accumulatedHistogram = *pObject;
                        }
                    }
                } // end of check pObject was found in pCollection->objects_
            } // end of check pCollection is not null
        } // end of `if includeCurrentRun`

        if(accumulatedHistogram.has_value()) {
            std::visit([&result](auto& histogram) {
                std::error_code error;
                musip::dqm::HistogramEncoder encoder;

                const size_t requiredSize = encoder.requiredSize(histogram);
                // Add a small header so that the client can detect if the response was truncated by Midas.
                // Note that alignment really matters for this message - javascript will want the histogram data
                // aligned on a type boundary, so for double histograms this means 8. This is one reason why our
                // header is 4+4 and not just the size.
                const size_t totalSize = sizeof(RPCHeader) + requiredSize;

                // I can't see this ever being close to 2^32 bytes, but we should check. If we're sending 4Gb in RPC calls we have bigger problems.
                if(totalSize > std::numeric_limits<uint32_t>::max()) fprintf(stderr, "DQMManager::HandleRpc - Size of message (%zu bytes) is too large to encode as a uint32_t\n", totalSize);

                result.resize(totalSize);

                // Write the header information
                RPCHeader& header = *reinterpret_cast<RPCHeader*>(result.data());
                header.messageSize = static_cast<uint32_t>(totalSize);
                header.messageType = RPCHeader::MessageType::hist;

                const size_t bytesWritten = encoder.encode<Lock::AlreadyLocked>(histogram, result.data() + sizeof(RPCHeader), requiredSize, error);
                if( error ) {
                    const std::string& errorMessage = error.message();
                    fprintf(stderr, "DQMManager::HandleBinaryRpc() - ERROR while trying to encode histogram: %s\n", errorMessage.c_str());
                }
                else if(bytesWritten != requiredSize) {
                    fprintf(stderr, "DQMManager::HandleBinaryRpc() - WARNING only wrote %zu bytes but expected %zu while trying to encode histogram.\n", bytesWritten, requiredSize);
                }
            }, accumulatedHistogram.value());
        }
        else {
            fprintf(stderr, "DQMManager::HandleBinaryRpc() - Don't have a histogram for request '%.*s'.\n", static_cast<int>(histogramPath.size()), histogramPath.data());
            return TMFeErrorMessage("TMFE completely ignores this error. I should put in a patch to Midas.");
        }

        return TMFeOk();
    } // end of command == "dqm::histogram"
    else if(command == "dqm::clear") {
        const std::string_view argument = args;

        if(argument.empty()) { // No collection or specific plot specified, so clear everything.
            printf("DQMManager::HandleBinaryRpc() - Clearing all histograms for RPC request.\n");
            currentRun_.clearAll();

            return TMFeOk();
        } // end of if argument is empty
        else {
            // Look for a collection with a name matching everything up to the first slash. Everything after
            // will be the histogram name. If there is no slash everything is the collection name and we clear
            // the whole collection.
            const size_t collectionNameSize = argument.find_first_of('/');
            const std::string requestedCollectionName( argument.substr(0, collectionNameSize) );

            if(PlotCollection* pCollection = currentRun_.getCollection(requestedCollectionName); pCollection != nullptr) {
                // Figure out if the request is for one histogram or the whole collection
                if(collectionNameSize == std::string_view::npos) {
                    // No histogram specified (no slash to separate collection and histogram). So clear the whole collection.
                    printf("DQMManager::HandleBinaryRpc() - Clearing all histograms in collection '%s' for RPC request.\n", requestedCollectionName.c_str());
                    pCollection->clearAll();
                    return TMFeOk();
                }
                else {
                    const std::string histogramName( argument.substr(collectionNameSize + 1) );

                    if(pCollection->clear(histogramName)) {
                        printf("DQMManager::HandleBinaryRpc() - Clearing histogram '%s' in collection '%s' for RPC request.\n", histogramName.c_str(), requestedCollectionName.c_str());
                        return TMFeOk();
                    }
                    else {
                        printf("DQMManager::HandleRpc - Unable to find object '%s' in collection '%s' to clear it\n", histogramName.c_str(), requestedCollectionName.c_str());
                        return TMFeErrorMessage("TMFE completely ignores this error. I should put in a patch to Midas.");
                    }
                } // end of if else histogram name was specified
            } // end of if collection found
            else {
                printf("DQMManager::HandleRpc - Unable to find collection '%s' to clear it\n", requestedCollectionName.c_str());
                return TMFeErrorMessage("TMFE completely ignores this error. I should put in a patch to Midas.");
            } // end of else when collection not found
        } // end of else if argument is not empty
    } // end of command == "dqm::clear"
    else if(command == "dqm::clearcache") {
        // Clear the cache of previous runs. This might be necessary if a file was previously served from
        // the "online" directory, but now the better file in the "prompt" directory is available.
        std::lock_guard<std::mutex> lock(previousRunsMutex_);
        previousRuns_.clear();
        return TMFeOk();
    }
    else {
        printf("DQMManager::HandleRpc - unrecognised command '%s'\n", cmd);
        return TMFeErrorMessage("TMFE completely ignores this error. I should put in a patch to Midas.");
    }
}

std::shared_ptr<musip::dqm::PlotSource<musip::dqm::DQMManager::PreviousRun::null_mutex>> musip::dqm::DQMManager::getHistorySource(std::vector<int>& runs) {
    std::sort(runs.begin(), runs.end());
    std::lock_guard<std::mutex> lock(previousRunsMutex_);

    // We can't do anything if the user never set a directory to load from.
    if(previousRunDirectories_.empty()) return nullptr;

    // We do a manual loop so that we can also find the oldest entry at the same time, in
    // case we need to eject an old entry from the cache.
    decltype(previousRuns_)::iterator iOldest = previousRuns_.end();
    decltype(previousRuns_)::iterator iSearchResult = previousRuns_.end();
    for(auto iCurrent = previousRuns_.begin(); iCurrent != previousRuns_.end(); ++iCurrent) {
        // Check if this is what we're looking for
        if(iSearchResult == previousRuns_.end()) {
            // Not found yet, need to look.
            if(iCurrent->runs == runs) {
                // We found it.
                iSearchResult = iCurrent;
                if(previousRuns_.size() <= maximumPreviousRunsSize_) break; // we don't need to eject, so don't need to find the oldest entry
            }
        }

        // Check if this is the oldest entry
        if(iOldest == previousRuns_.end()) iOldest = iCurrent;
        else if(iOldest->lastAccess < iCurrent->lastAccess) iOldest = iCurrent;
    } // end of loop over previousRuns_

    if(iSearchResult != previousRuns_.end()) {
        // Found a matching history entry
        if(verbosity_ > 0) printf("Found cached entry for previous run(s)\n");

        iSearchResult->lastAccess = std::chrono::steady_clock::now();
        return iSearchResult->data;
    }
    else {
        // Not found, need to create the new entry.
        if(verbosity_ > 0) printf("No cached entry for previous run(s), searching for files\n");

        std::vector<int> foundRuns;
        auto newHistoryEntry = std::make_shared<PlotSource<PreviousRun::null_mutex>>();

        // Load all the requested run numbers into the new entry
        for(const auto runNumber : runs) {
            char filename[32];
            snprintf(filename, sizeof(filename), "dqm_histos_%05d.root", runNumber);

            // Check each directory in turn. Once we find the file we stop, so that earlier directories
            // in the list take precedence.
            std::error_code error;
            for(const auto& path : previousRunDirectories_) {
                const std::filesystem::path fullPath = path / filename;

                error.clear();
                newHistoryEntry->addFromRootFile(fullPath.c_str(), error);
                if(!error) {
                    if(verbosity_ > 0) printf("Found file for previous run %d at %s\n", runNumber, fullPath.c_str());
                    break;
                }
            }

            if(error) fprintf(stderr, "Couldn't find plots for run %d\n", runNumber);
            else foundRuns.push_back(runNumber);
        } // End of loop over requested run numbers

        previousRuns_.emplace_front(std::chrono::steady_clock::now(), std::move(foundRuns), newHistoryEntry);

        // If the list of old runs has grown too large, remove an entry.
        if(previousRuns_.size() > maximumPreviousRunsSize_) {
            if(iOldest != previousRuns_.end()) previousRuns_.erase(iOldest);
        }

        return newHistoryEntry;
    }
} // end of method getHistorySource
