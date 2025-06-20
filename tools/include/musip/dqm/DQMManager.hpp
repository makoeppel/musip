#pragma once

#include "musip/dqm/dqmfwd.hpp"
#include "musip/dqm/PlotSource.hpp"

#include <tmfe.h>

#include <filesystem>
#include <optional>
#include <list>

namespace musip::dqm {

/** @brief Main interaction point to create new DQM plots.
 *
 * This is a singleton. Get a reference to the only instance with DQMManager::instance();
 */
class DQMManager : public TMFeRpcHandlerInterface {
public:
    /** @brief Returns a reference to the singleton. */
    static DQMManager& instance();

    PlotCollection* getOrCreateCollection(const std::string& name);

    void saveAsRootFile(const char* filename, const char* options = "RECREATE") { return saveAsRootFile(filename, true, options); }
    void saveAsRootFile(const char* filename, bool skipEmptyHistograms, const char* options = "RECREATE");
    void addFromRootFile(const char* filename);

    /** @brief Clear all of the histograms in all of the collections. */
    void clearAll();

    /** @brief Add a directory to search in when previous runs are requested over RPC.
     *
     * The directories are searched in the order they are given to this method, and subsequent directories
     * are not checked once a suitable file is found. So for example, if we first call this method with the
     * directory where our prompt post-processed files are stored, and then call this method with the
     * directory where the online files are stored; the prompt file will be used if it is found and if not
     * it falls back to using the online file. */
    void addHistoryDirectory(const std::filesystem::path& directoryPath);

    /** @brief Header prepended to the reply to any RPC call.
     *
     * Note that it's important that adding the header doesn't change the alignment of histogram data: clients
     * rely on the histogram data being aligned. Hence the size has to be a multiple of the largest datatype
     * we use, i.e. 8 bytes for double.
     */
    struct RPCHeader {
        /// @brief Little endian size in bytes of the full message, including this header.
        uint32_t messageSize;

        enum class MessageType : uint32_t { unknown = 0x00, list = 0x7473696c, hist = 0x74736968 };
        MessageType messageType;
    };

    static_assert(offsetof(RPCHeader, messageSize) == 0);
    static_assert(sizeof(RPCHeader::messageSize) == 4);
    static_assert(offsetof(RPCHeader, messageType) == 4);
    static_assert(sizeof(RPCHeader::messageType) == 4);
    static_assert(sizeof(RPCHeader) == 8);
    static_assert(sizeof(RPCHeader) % 8 == 0); // It's important that the header doesn't mis-align histograms with datatype double
    // TODO: Add static_assert that we're on a little endian system (requires C++20)
protected:
    DQMManager();
    ~DQMManager();

    // Methods required for the TMFeRpcHandlerInterface interface.
    // Note that we can't use `HandleBeginRun` or `HandleEndRun` because these aren't called
    // when running offline on a file.
    virtual TMFeResult HandleBinaryRpc(const char* cmd, const char* args, std::vector<char>& result) override;

    unsigned verbosity_ = 0;
    musip::dqm::PlotSource<> currentRun_;
    struct PreviousRun {
        // We never change the data, so we don't want to lock the thread for reading.
        // This should compile down to no-ops.
        struct null_mutex
        {
            void lock() {}
            void unlock() noexcept {}
            bool try_lock() { return true; }
            void lock_shared() {}
            void unlock_shared() {}
        };

        /// The time when this run was last accessed, used to clear out old entries from the cache.
        std::chrono::steady_clock::time_point lastAccess;
        /// The sorted list of run numbers that this PlotSource is for, so that we can find it again later.
        std::vector<int> runs;

        // The actual cache entry. We use a shared_ptr so that we can return the ptr and release the
        // thread lock - the data won't change but whether it's in the cache or not will. So once we
        // have a copy of the ptr we no longer need the lock.
        std::shared_ptr<musip::dqm::PlotSource<null_mutex>> data;

        // Simple constructor so that we can `emplace` new instances.
        template<typename time_type, typename runs_type, typename data_type>
        PreviousRun(time_type&& time, runs_type&& runs, data_type&& dataPointer)
            : lastAccess(std::forward<time_type>(time)), runs(std::forward<runs_type>(runs)), data(std::forward<data_type>(dataPointer))
        {}
    };
    std::mutex previousRunsMutex_; // Protects access to `previousRuns_` and `previousRunDirectories_`
    std::list<PreviousRun> previousRuns_;
    static constexpr size_t maximumPreviousRunsSize_ = 5; // The maximum size of `previousRuns_` before we start ejecting old entries
    std::vector<std::filesystem::path> previousRunDirectories_; // The list of directories we search for old run files, in order.

    /** @brief Looks in previousRuns_ for a previously loaded set of files and returns the accumulated source. If not
     * found tries to load all the runs from disk, caches the accumulation in previousRuns_ and return it.
     *
     * Returns a shared_ptr so that PlotSource can still be used even if it is ejected from the cache by another thread.*/
    std::shared_ptr<musip::dqm::PlotSource<PreviousRun::null_mutex>> getHistorySource(std::vector<int>& runs);

    // Explicitly delete copy, assignment and move.
    DQMManager( const DQMManager& other ) = delete;
    DQMManager& operator=( const DQMManager& other ) = delete;
    DQMManager( DQMManager&& other ) = delete;
    DQMManager& operator=( DQMManager&& other ) = delete;
}; // end of class DQMManager

} // end of namespace musip::dqm
