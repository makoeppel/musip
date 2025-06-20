//
// This is code for a stand alone executable of a proxy to multiple instances of DQM services.
// It will listen for histogram requests and then forward that request on to the configured
// DQM services. When the results come back, they're added up into a single histogram and that
// is the result returned for the original histogram request.
//
// The intention is that one instance of the DQM service will run on each of the farm nodes. A
// single instance of this proxy will run in a central place, presumably the backend. DQM plots
// will be displayed in a Midas custom page that makes requests to this proxy. That way histograms
// from the farm nodes are only summed when they're actually required, rather than have data
// for hundreds of histograms moving through the system even when they're not being looked at.
//
#include <cstdio>
#include <chrono>
#include <set>
#include <optional>
#include "midas.h"
#include "mrpc.h"
#include "musip/dqm/PlotCollection.hpp"
#include "musip/dqm/HistogramEncoder.hpp"
#include "musip/dqm/DQMManager.hpp"

namespace { // the unnamed namespace
    struct RPCConnection {
        RPCConnection(const char* clientName)
            : clientName_(clientName) {
            connect();
        }

        ~RPCConnection() {
            disconnect();
        }

        bool isConnected() {
            return (hConn_ != 0);
        }

        bool connect(bool quiet = false) {
            const int result = cm_connect_client(clientName_.c_str(), &hConn_);
            if(result != RPC_SUCCESS) {
                if(!quiet) {
                    if(result == CM_NO_CLIENT) printf("Cannot connect to frontend \"%s\" (CM_NO_CLIENT)\n", clientName_.c_str());
                    else printf("Cannot connect to frontend \"%s\" (%d)\n", clientName_.c_str(), result);
                }
                hConn_ = 0;
                return false;
            }
            else {
                printf("Connected to client '%s'\n", clientName_.c_str());
                return true;
            }
        }

        void disconnect() {
            if(hConn_ == 0) return;

            const int result = cm_disconnect_client(hConn_, false);
            if(result != RPC_SUCCESS) {
                printf("Cannot disconnect from frontend '%s' (%d)\n", clientName_.c_str(), result);
            }
            printf("Disconnect from client '%s'\n", clientName_.c_str());
        }

        // Forbid copying, otherwise two handles will try and close the connection
        RPCConnection(const RPCConnection& other) = delete;
        RPCConnection& operator=(const RPCConnection& other) = delete;

        // Custom move construction and assignment to stop the old instance shutting the connection
        RPCConnection(RPCConnection&& other)
            : hConn_(other.hConn_),
              clientName_(std::move(other.clientName_)) {
            other.hConn_ = 0;
        }

        RPCConnection& operator=(RPCConnection&& other) {
            if(&other != this) {
                disconnect();

                hConn_ = other.hConn_;
                clientName_ = std::move(other.clientName_);
                other.hConn_ = 0;
            }
            return *this;
        }

        std::vector<char> binaryCall(const char* command, const char* arguments, const size_t maximumResultSize = 1048576) {
            std::vector<char> buffer(maximumResultSize);
            uint32_t bufferSize = buffer.size();

            const int result = rpc_client_call(hConn_, RPC_BRPC, command, arguments, buffer.data(), &bufferSize);
            if(result != RPC_SUCCESS) {
                if(result == RPC_NET_ERROR) {
                    printf("RPCConnection '%s' has disconnected (RPC_NET_ERROR)\n", clientName_.c_str());
                    hConn_ = 0;
                }
                else printf("Error with RPCConnection call to '%s': (%d)\n", clientName_.c_str(), result);
                buffer.resize(0);
            }
            else {
                buffer.resize(bufferSize);
            }

            return buffer;
        }

        HNDLE hConn_;
        std::string clientName_;
    };

    // Note that we don't have a mutex lock on this. It's filled before any RPC calls can be received.
    std::vector<RPCConnection> global_rpcConnections;

    /** @brief An object to combine multiple RPC results into one result.
     *
     * The result of each proxy call to a connected RPC client will be added with `add(...)`. Once
     * all of the calls have returned, the combined result can be written with `writeTo(...)`.
     */
    struct CombinedResult {
        CombinedResult(const char* command);
        void add(const std::vector<char>& buffer) { return add(buffer.data(), buffer.size()); }
        void add(const char* buffer, size_t bufferSize);
        bool empty() const;
        size_t writeTo(char* buffer, const size_t bufferSize) const;

        enum class CallType { unknown, list, histogram };
        CallType callType_;

        // Used when callType_ is `list`
        void addToList(const char* buffer, size_t bufferSize);
        size_t writeListTo(char* buffer, const size_t bufferSize) const;
        static constexpr char delimiter_ = '\n';
        std::set<std::string> objectNames_;

        // Used when callType_ is `histogram`
        void addToHistogram(const char* buffer, size_t bufferSize);
        size_t writeHistogramTo(char* buffer, const size_t bufferSize) const;
        std::optional<musip::dqm::PlotCollection::object_type> object_;
    };

    CombinedResult::CombinedResult(const char* command) {
        if(0 == std::strcmp(command, "dqm::list")) callType_ = CallType::list;
        else if(0 == std::strcmp(command, "dqm::histogram")) callType_ = CallType::histogram;
        else {
            fprintf(stderr, "CombinedResult constructor: unknown command '%s'\n", command);
            callType_ = CallType::unknown;
        }
    }

    void CombinedResult::add(const char* buffer, const size_t bufferSize) {
        switch(callType_) {
            case CallType::unknown:
                fprintf(stderr, "CombinedResult::add: can't add result to unknown command\n");
                return;
            case CallType::list:
                return addToList(buffer, bufferSize);
            case CallType::histogram:
                return addToHistogram(buffer, bufferSize);
        }
    }

    bool CombinedResult::empty() const {
        switch(callType_) {
            case CallType::unknown: return true;
            case CallType::list: return objectNames_.empty();
            case CallType::histogram: return !object_.has_value();
        }

        return true;
    }

    size_t CombinedResult::writeTo(char* buffer, size_t bufferSize) const {
        switch(callType_) {
            case CallType::unknown:
                fprintf(stderr, "CombinedResult::writeTo: can't write result for unknown command\n");
                return 0;
            case CallType::list:
                return writeListTo(buffer, bufferSize);
            case CallType::histogram:
                return writeHistogramTo(buffer, bufferSize);
        }

        // Should never get to here, but to stop compiler warnings...
        return 0;
    }

    void CombinedResult::addToList(const char* buffer, const size_t bufferSize) {
        std::string_view bufferView(buffer, bufferSize);

        // Results are just a list of strings of the available histogram names separated by new lines.
        while(!bufferView.empty()) {
            const size_t delimiterPosition = bufferView.find(delimiter_);
            // Note that if there is no delimiter, `delimiterPosition` will be npos and `substr` will take to the
            // end of `bufferView`. Which is exactly the behaviour I want.
            objectNames_.emplace(bufferView.substr(0, delimiterPosition));

            if(delimiterPosition == std::string_view::npos) break; // finished
            else bufferView = bufferView.substr(delimiterPosition + 1); // `+1` to skip over the delimiter
        } // end of loop looking for delimiter splits in the vector data
    } // end of method CombinedResult::addToList

    size_t CombinedResult::writeListTo(char* buffer, const size_t bufferSize) const {
        // We want the object names to be sorted, but this is a property of std::set so already in the correct order.

        char* pDestination = buffer; // Place to copy the first string
        size_t bytesWritten = 0;

        for(const std::string& entry : objectNames_) {
            // For everything other than the first entry, we want to write a delimeter before the entry.
            const size_t spaceForDelimiter = (bytesWritten != 0 ? 1 : 0);

            if((bytesWritten + spaceForDelimiter + entry.size()) < bufferSize) {
                if(bytesWritten != 0) {
                    // Not the first entry, add a delimiter
                    *pDestination = delimiter_;
                    ++pDestination;
                    ++bytesWritten;
                }

                std::memcpy(pDestination, entry.data(), entry.size());
                pDestination += entry.size();
                bytesWritten += entry.size();
            }
            else {
                fprintf(stderr, "CombinedResult::writeListTo: buffer wasn't large enough for all entries\n");
                break;
            }
        } // end of loop over objectNames_

        return bytesWritten;
    }

    void CombinedResult::addToHistogram(const char* buffer, size_t bufferSize) {
        musip::dqm::HistogramEncoder decoder;
        std::error_code error;
        const auto newHistogramOptional = decoder.decode(buffer, bufferSize, error);

        if(error) {
            const std::string errorMessage = error.message();
            fprintf(stderr, "CombinedResult::addToHistogram: got an error while decoding the binary buffer: %s\n", errorMessage.c_str());
            return;
        }
        else if(!newHistogramOptional.has_value()) {
            fprintf(stderr, "CombinedResult::addToHistogram: no histogram decoded\n");
            return;
        }

        if(object_.has_value()) {
            const auto& newHistogram = newHistogramOptional.value();

            // Use a double `visit` so that we have the concrete types of both histograms. Then we can check
            // if they're both the same type, and if so add them.
            std::visit(musip::dqm::detail::overloaded{
                [](musip::dqm::RollingHistogram2DF& object) {
                    // This should never happen because RollingHistograms are always transported as
                    // normal histograms. But we need this type-matcher to stop the compiler trying
                    // to compile the general one below for RollingHistogram.
                    fprintf(stderr, "CombinedResult::addToHistogram: the current histogram is a RollingHistogram2DF, which should not occur.\n");
                },
                [&newHistogram](auto& object) {
                    std::visit([&object](auto& newObject) {
                        using histogram_type = typename std::decay<decltype(object)>::type;
                        using new_histogram_type = typename std::decay<decltype(newObject)>::type;

                        if constexpr(std::is_same<histogram_type, new_histogram_type>::value) {
                            std::error_code error;
                            object.add(newObject, error);
                            if(error) {
                                const std::string errorMessage = error.message();
                                fprintf(stderr, "CombinedResult::addToHistogram: got an error while adding the new histogram to the current: %s\n", errorMessage.c_str());
                            }
                        }
                        else {
                            fprintf(stderr, "CombinedResult::addToHistogram: the new histogram is not the same type as the current one\n");
                        }
                    }, newHistogram);
                }
            }, object_.value());
        }
        else object_ = newHistogramOptional;
    } // end of method CombinedResult::addToHistogram

    size_t CombinedResult::writeHistogramTo(char* buffer, size_t bufferSize) const {
        if(!object_.has_value()) {
            fprintf(stderr, "CombinedResult::writeHistogramTo: There is no histogram object available\n");
            return 0;
        }

        musip::dqm::HistogramEncoder decoder;
        std::error_code error;
        const size_t bytesWritten = decoder.encode(object_.value(), buffer, bufferSize, error);

        if(error) {
            const std::string errorMessage = error.message();
            fprintf(stderr, "CombinedResult::writeHistogramTo: got an error while encoding the histogram: %s\n", errorMessage.c_str());
            return bytesWritten;
        }

        return bytesWritten;
    } // end of method CombinedResult::writeHistogramTo

    int binary_rpc_callback(int index, void *prpc_param[]) {
        const char* cmd  = static_cast<const char*>(prpc_param[0]);
        const char* args = static_cast<const char*>(prpc_param[1]);
        char* return_buf = static_cast<char*>(prpc_param[2]);
        int& return_max_length = *static_cast<int*>(prpc_param[3]);

        printf("Got RPC %d. Cmd = '%s', args = '%s' return_max_length = %d\n", index, cmd, args, return_max_length);

        CombinedResult combinedResult(cmd);

        // DQM RPC calls now put a small header at the start of every response. This is so that clients can detect when
        // a response has been truncated by Midas because they didn't supply a large enough value for`return_max_length`.
        using RPCHeader = musip::dqm::DQMManager::RPCHeader;
        RPCHeader::MessageType messageType = RPCHeader::MessageType::unknown; // We need to pass this on in our reply.

        // No mutex lock because global_rpcConnections is filled before we accept connections
        for(auto& connection : global_rpcConnections) {
            std::vector<char> subResult = connection.binaryCall(cmd, args, return_max_length);
            if(subResult.size() < sizeof(RPCHeader)) {
                printf("RPC sub-call got a response of length %zu, which is below the minimum required.\n", subResult.size());
            }
            else {
                printf("RPC sub-call got response with size %zu\n", subResult.size());
                const RPCHeader& header = *reinterpret_cast<RPCHeader*>(subResult.data());
                if(header.messageSize != subResult.size()) {
                    fprintf(stderr, "RPC sub-call was truncated from %u to %zu bytes\n", header.messageSize, subResult.size());
                    // TODO resubmit the request with adequate `maximumResultSize`
                }
                messageType = header.messageType;
                combinedResult.add(subResult.data() + sizeof(RPCHeader), subResult.size() - sizeof(RPCHeader));
            }
        }

        size_t bytesWritten = 0;

        if(!combinedResult.empty()) {
            bytesWritten = combinedResult.writeTo(return_buf + sizeof(RPCHeader), return_max_length - sizeof(RPCHeader));
        }

        return_max_length = sizeof(RPCHeader) + bytesWritten;

        RPCHeader& header = *reinterpret_cast<RPCHeader*>(return_buf);
        header.messageSize = static_cast<uint32_t>(sizeof(RPCHeader) + bytesWritten);
        header.messageType = messageType;

        return RPC_SUCCESS;
    }
} // end of the unnamed namespace

int main(int argc, char* argv[]) {
    printf("Starting dqmproxy\n");

    // Options we want to fill from the command line:
    const char* analyzerName = "dqm";
    std::vector<const char*> dqmInstanceNames;

    //
    // Parse the command line
    //
    for(int argIndex = 1; argIndex < argc; ++argIndex) {
        if((0 == std::strcmp(argv[argIndex], "--help")) || (0 == std::strcmp(argv[argIndex], "-h"))) {
            printf("dqmproxy - collates DQM responses from multiple minalyzer instances into one response.\n"
                "\n"
                "Usage:\n"
                "\tdqmproxy [options] [minalyzer1_name [minalyzer2_name...]]\n"
                "\n"
                "The minalyzer names should be what you set as '--midas-progname' when starting the minalyzers\n"
                "(defaults to 'ana').\n"
                "Available options:\n"
                "\t--midas-progname <progname> : The RPC name Midas uses to contact this. Defaults to 'dqm'.\n"
                "\n"
                "Example:\n"
                "On two different machines start two instances of minalyzer with different names:\n"
                "\tminalyzer --mt --midas-buffer musipFARM0 --midas-progname minalyzer_farm0\n"
                "\tminalyzer --mt --midas-buffer musipFARM1 --midas-progname minalyzer_farm1\n"
                "Then on a 3rd machine start dqmproxy and point it these two minalyzers:\n"
                "\tdqmproxy --midas-progname ana minalyzer_farm0 minalyzer_farm1\n"
                "Now any plot requests for 'ana' will be the total of the two minalyzer instances.\n");
            return 0;
        }
        else if(0 == std::strcmp(argv[argIndex], "--midas-progname")) {
            if(argIndex + 1 < argc) {
                analyzerName = argv[argIndex + 1];
                ++argIndex; // increment, because we've consumed to arguments
            }
            else {
                fprintf(stderr, "ERROR! command line parameter '--midas-progname' was given but no name was supplied!\n");
                return -1;
            }
        }
        else dqmInstanceNames.push_back(argv[argIndex]);
    }

    if(dqmInstanceNames.empty()) {
        fprintf(stderr, "WARNING! No analyzer program names were provided on the command line. Will attempt to connect to \"ana\".\n");
        dqmInstanceNames.push_back("ana");
    }

    printf("dqmproxy serving with Midas program name = \"%s\". Will attempt to connect to DQM instance(s): [", analyzerName);
    for(size_t index = 0; index < dqmInstanceNames.size(); ++index) {
        if(index != 0) printf(", ");
        printf("\"%s\"", dqmInstanceNames[index]);
    }
    printf("]\n");

    //
    // Register with Midas. Use a sentry object to make sure we disconnect properly/
    //
    struct Sentry {
        Sentry(const char* analyzerName){
            std::string host_name, exp_name;
            cm_get_environment( &host_name, &exp_name );
            printf("Connecting host_name = '%s', exp_name = '%s', analyzerName = '%s'\n", host_name.c_str(), exp_name.c_str(), analyzerName);
            const int result = cm_connect_experiment( host_name.c_str(), exp_name.c_str(), analyzerName, nullptr );
            if(result == CM_SUCCESS) printf("Connected to midas\n");
            else printf("Unable to connect to Midas. Got error %d\n", result);
        }
        ~Sentry(){ cm_disconnect_experiment(); }
    } experimentConnectionSentry(analyzerName);

    //
    // Create connections to the requested DQM instances
    //
    global_rpcConnections.reserve(dqmInstanceNames.size());
    for(const auto& dqmInstanceName : dqmInstanceNames) global_rpcConnections.emplace_back(dqmInstanceName);

    //
    // Once connections are made, tell Midas we want to receive Remote Procedure Calls.
    //
    cm_register_function(RPC_BRPC, binary_rpc_callback);

    //
    // Loop continuosly and cede control to Midas' RPC checking system.
    //
    constexpr auto yieldWait = std::chrono::seconds(1);

    bool shutdownRequested = false;

    while(!shutdownRequested) {

        const int status = cm_yield(std::chrono::duration_cast<std::chrono::milliseconds>(yieldWait).count());

        if(status == RPC_SHUTDOWN || status == SS_ABORT) {
            shutdownRequested = true;
            printf("TMFE::RpcThread: cm_yield() status %d, shutdown requested...\n", status);
        }
        else if(status == SS_TIMEOUT) {
            // If any clients didn't connect (e.g. dqmproxy started before them), reconnect them
            // now.
            for(auto& connection : global_rpcConnections) {
                if(!connection.isConnected()) connection.connect(true);
            } // end of loop over connections
        }
        else if((status != SS_SERVER_RECV) && (status != SS_CLIENT_RECV)) {
            // Don't know what happened (might be fine?), give a message to aid in debugging.
            printf("Yield gave status %d.\n", status);
        }
    } // end of while loop running until shutdown requested

    printf("Finished dqmproxy\n");
}
