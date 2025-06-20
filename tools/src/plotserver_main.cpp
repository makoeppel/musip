//
// This is code for a stand alone executable to serve old run files. When RPC calls for
// old runs are received, the speficied directories are searched for dqm_histos_<run number>.root
// files. Plots from these files are loaded and returned over RPC.
// The code to do this is mostly in DQMManager. The mechanism is basically the same as minalyzer
// does, except that we don't do anything to create plots for the current run.
//
// Since we reuse DQMManager, requesting run zero (which means the current run) doesn't give an error.
// You just get no data because we never add any new plots.
//
// The main purpose of this program is to serve the files from "prompt" analysis when these
// files are on a different machine to where minalyzer is run. Plots for the current run and
// previous "online" runs will be served by minalyzer itself. When client code (custom page
// or whatever) requests a plot, it chooses where to send the request by the "midas-progname".
// For minalyzer this is "ana" by default, for this server it is "prompt_server" by default,
// but either of these can by changed by the "--midas-progname" parameter when starting.
//
#include <cstdio>
#include <chrono>
#include "midas.h"
#include "mrpc.h"
#include "musip/dqm/DQMManager.hpp"

int main(int argc, char* argv[]) {
    printf("Starting plotserver\n");

    // Options we want to fill from the command line:
    const char* progName = "prompt_server";
    bool atLeastOneDirectorySpecified = false;
    std::string commandLineHostname, commandLineExptname;
    musip::dqm::DQMManager& dqmManager = musip::dqm::DQMManager::instance();

    //
    // Parse the command line
    //
    for(int argIndex = 1; argIndex < argc; ++argIndex) {
        std::string_view arg(argv[argIndex]);

        if((arg == "--help") || (arg == "-h")) {
            printf("plotserver - serves DQM plots loaded from dqm_histos_<run number>.root files.\n"
                "\n"
                "Usage:\n"
                "\tplotserver [options] <directory1> [[directory2] ...]\n"
                "\n"
                "The directories specified are searched in order until a file for the requested run is found. So earlier\n"
                "directories take higher precedence.\n"
                "Available options:\n"
                "\t--midas-progname <progname> : The RPC name Midas uses to contact this. Defaults to 'prompt_server'.\n"
                "--midas-hostname HOSTNAME[:PORT] -- connect to MIDAS mserver on given host and port\n"
                "--midas-exptname EXPTNAME -- connect to given experiment\n"
                "\n");
            return 0;
        }
        else if(arg == "--midas-progname") {
            if(argIndex + 1 < argc) {
                progName = argv[argIndex + 1];
                ++argIndex; // increment, because we've consumed to arguments
            }
            else {
                fprintf(stderr, "ERROR! command line parameter '--midas-progname' was given but no name was supplied!\n");
                return -1;
            }
        }
        else if(arg == "--midas-hostname") {
            if(argIndex + 1 < argc) {
                commandLineHostname = argv[argIndex + 1];
                ++argIndex; // increment, because we've consumed to arguments
            }
            else {
                fprintf(stderr, "ERROR! command line parameter '--midas-hostname' was given but no name was supplied!\n");
                return -1;
            }
        }
        else if(arg == "--midas-exptname") {
            if(argIndex + 1 < argc) {
                commandLineExptname = argv[argIndex + 1];
                ++argIndex; // increment, because we've consumed to arguments
            }
            else {
                fprintf(stderr, "ERROR! command line parameter '--midas-exptname' was given but no name was supplied!\n");
                return -1;
            }
        }
        else {
            atLeastOneDirectorySpecified = true;
            dqmManager.addHistoryDirectory(arg);
        }
    }

    if(!atLeastOneDirectorySpecified) {
        fprintf(stderr, "You need to specify at least one directory to look for dqm_histos_<run number>.root in.\n");
        return -1;
    }

    printf("plotserver serving with Midas program name = \"%s\".\n", progName);

    //
    // Register with Midas. Use a sentry object to make sure we disconnect properly/
    //
    struct Sentry {
        bool connected = false;
        Sentry(const char* progName, const std::string& commandLineHostname, const std::string& commandLineExptname){
            std::string host_name, exp_name;
            cm_get_environment( &host_name, &exp_name );
            if(!commandLineHostname.empty()) host_name = commandLineHostname;
            if(!commandLineExptname.empty()) exp_name = commandLineExptname;
            printf("Connecting host_name = '%s', exp_name = '%s', progName = '%s'\n", host_name.c_str(), exp_name.c_str(), progName);
            TMFeResult result = TMFE::Instance()->Connect(progName, host_name.c_str(), exp_name.c_str());
            if(!result.error_flag) {
                printf("Connected to midas\n");
                connected = true;
            }
            else printf("Unable to connect to Midas. Got error %d: %s\n", result.error_code, result.error_message.c_str());
        }
        ~Sentry(){ TMFE::Instance()->Disconnect(); }
    } experimentConnectionSentry(progName, commandLineHostname, commandLineExptname);

    if(!experimentConnectionSentry.connected) {
        return -1;
    }

    //
    // Loop continuosly and cede control to Midas' RPC checking system.
    //
    constexpr auto yieldWait = std::chrono::seconds(1);
    bool shutdownRequested = false;

    while(!shutdownRequested) {
        const int status = cm_yield(std::chrono::duration_cast<std::chrono::milliseconds>(yieldWait).count());

        if(status == RPC_SHUTDOWN || status == SS_ABORT) {
            shutdownRequested = true;
            printf("cm_yield() status %d, shutdown requested...\n", status);
        }
        else if((status != SS_TIMEOUT) && (status != SS_SERVER_RECV) && (status != SS_CLIENT_RECV)) {
            // Don't know what happened (might be fine?), give a message to aid in debugging.
            printf("Yield gave status %d.\n", status);
        }
    } // end of while loop running until shutdown requested

    printf("Finished plotserver\n");
}
