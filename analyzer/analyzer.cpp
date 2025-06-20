//

#include "manalyzer.h"

#include "AnaQuadHistos.h"
#include "AnaFillHits.h"
//#include "AnaMusip.h"
#include "musip/dqm/DQMManager.hpp"

#include "odbxx.h"
#include <boost/program_options.hpp>
#include <boost/property_tree/json_parser.hpp>
#include <boost/property_tree/ptree.hpp>
#include <iostream>
#include <filesystem>

namespace { // Use the unnamed namespace for things only used in this file

/** @brief Singleton class to hold the boost::property_tree configuration.
 *
 * Control flow for this is a little weird because we can't use any ODB methods until
 * after `manalyzer_main` is called - and we lose flow control to Midas at that point.
 * So we put code that accesses the ODB in the constructor, and only ask for an instance
 * right before Midas creates new TARunObjects, i.e. after `manalyzer_main` is called.
 * However, we also need to access the config before that to read from the json file, so
 * we have the config as a static member so that it can be retrieved at any point. Pretty
 * dumb but we need to work around Midas manalyzer.
 */
class Configuration {
    const std::string odbPath_;
    midas::odb odbConfig_;
    std::mutex configMutex_;
    static boost::property_tree::ptree config_;

    Configuration()
        : odbPath_("/Equipment/MinAna/Settings/") {

        if(TMFE::Instance()->fDB == 0) {
            // This will only happen if we are running offline. And if we are running offline
            // then we don't have access to the ODB. So don't try and read or set a watch.
            printf("Running offline, so won't try and get minalyzer configuration from the ODB\n");
            return;
        }

        // Connect to the ODB and iterate through the keys, updating the config with any settings we find.
        // Note that we don't bother with a thread lock since this is a singleton, so it will only be created
        // on a single thread.
        odbConfig_.connect(odbPath_);
        for(auto& subKey : odbConfig_) {
            recursiveApplyFromODB(subKey, subKey.get_odb().get_name());
        }

        // Set the watch so that the configuration gets updated when settings change. Note that
        // the configuration is only applied when TARunObject instances are created, i.e. at run
        // start.
        odbConfig_.watch(std::bind(&Configuration::watchCallback, this, std::placeholders::_1));
    }
    void watchCallback(midas::odb& odb) {
        // We need a thread lock, because we could try reading and writing at the same time from
        // different threads.
        std::lock_guard<std::mutex> lock = getThreadLock();

        std::string name;
        const std::string parentPath = odb.get_parent_path();
        if(parentPath.size() < odbPath_.size()) {
            name = odb.get_name();
        }
        else {
            name = parentPath.substr(odbPath_.size()) + "." + odb.get_name();
        }

        recursiveApplyFromODB(odb, name);
    }
    template<typename data_type>
    void setFromODB(midas::odb& odb, const std::string& parameterName) {
        if(odb.size() == 1) {
            const data_type valueFromODB = static_cast<data_type>(odb);
            const boost::optional<data_type> currentValue = config_.get_optional<data_type>(parameterName);
            // Only print info if the value is being changed to a different value
            if(currentValue.has_value() && (currentValue.value() != valueFromODB)) {
                printf("Config parameter %s overwritten by ODB.\n", parameterName.c_str());
            }
            config_.put(parameterName, valueFromODB);
        }
        else printf("Can't set '%s' because it is an array\n", parameterName.c_str());
    }
    void recursiveApplyFromODB(midas::odb& odb, const std::string& parameterName) {
        switch(odb.get_tid()) {
            case TID_UINT8    : setFromODB<uint8_t>(odb, parameterName); break;
            case TID_INT8     : setFromODB<int8_t>(odb, parameterName); break;
            // case TID_CHAR     : setFromODB<const char*>(odb, parameterName); break;
            case TID_UINT16   : setFromODB<uint16_t>(odb, parameterName); break;
            case TID_INT16    : setFromODB<int16_t>(odb, parameterName); break;
            case TID_UINT32   : setFromODB<uint32_t>(odb, parameterName); break;
            case TID_INT32    : setFromODB<int32_t>(odb, parameterName); break;
            case TID_BOOL     : setFromODB<bool>(odb, parameterName); break;
            case TID_FLOAT32  : setFromODB<float>(odb, parameterName); break;
            case TID_FLOAT64  : setFromODB<double>(odb, parameterName); break;
            case TID_STRING   : setFromODB<std::string>(odb, parameterName); break;
            case TID_INT64    : setFromODB<int64_t>(odb, parameterName); break;
            case TID_UINT64   : setFromODB<uint64_t>(odb, parameterName); break;
            // case TID_BITFIELD : printf("%s = TID_BITFIELD\n", parameterName.c_str()); break;
            // case TID_STRUCT   : printf("%s = TID_STRUCT\n", parameterName.c_str()); break;
            // case TID_LINK     : printf("%s = TID_LINK\n", parameterName.c_str()); break;
            // case TID_LAST     : printf("%s = TID_LAST\n", parameterName.c_str()); break;
            // case TID_ARRAY    : printf("%s = TID_ARRAY\n", parameterName.c_str()); break;
            case TID_KEY      :
                for(auto& subKey : odb) {
                    recursiveApplyFromODB(subKey, (parameterName.empty() ? "" : parameterName + ".") + subKey.get_odb().get_name());
                }
                break;
            default:
                fprintf(stderr, "Don't know how to handle ODB entry with tid %d\n", odb.get_tid());
                break;
        }
    } // end of method recursiveApplyFromODB
public:
    static Configuration& instance() {
        static Configuration onlyInstance;
        return onlyInstance;
    }

    /** @brief Gets the thread lock that protects the config. To release just let the variable go out of scope.
     *
     * Required because the ODB watch function could otherwise write to the config while it is being read
     * during construction of TARunObjects. */
    std::lock_guard<std::mutex> getThreadLock() { return std::lock_guard<std::mutex>(configMutex_); }

    // Unfortunately this has to be static, because we need to be able to retreive it before
    // accessing the ODB; and the ODB needs to be accessed in the constructor.
    static boost::property_tree::ptree& config() { return config_; }
};

// Definitions of the static members
boost::property_tree::ptree Configuration::config_;

/** @brief Basically the same as TAFactoryTemplate but passes on the boost::property_tree.
 *
 * The constructor takes the name of the config child entry that is used to configure the module.
 */
template <class T>
class TAFactoryTemplateWithConfig : public TAFactory {
    const std::string moduleName_;

    T* NewRunObject(TARunInfo* runinfo) override {
        Configuration& configuration = Configuration::instance();
        // We need to get a thread lock in case the ODB is modified while the run object
        // is reading the configuration.
        auto lock = configuration.getThreadLock();

        const auto& moduleConfig = configuration.config().get_child(moduleName_);
        return new T(moduleConfig, runinfo);
    }

public:
    TAFactoryTemplateWithConfig(const std::string_view name, bool enabledByDefault)
        : moduleName_(name) {
        auto& config = Configuration::config();
        // First see if the module has any kind of config. If there is one, then we enable
        // it even if it does not have an "enabled" entry.
        const bool hasConfig = config.get_child_optional(moduleName_).has_value();
        const bool enabled = config.get<bool>(moduleName_ + ".enabled", hasConfig || enabledByDefault);

        // We write this back into the config, so that the child entry exists if it didn't before.
        config.put(moduleName_ + ".enabled", enabled);
    }
};

/** @brief Does the same as TAFactoryTemplateWithConfig, but used when there is a custom TAFactory. This wraps the custom factory.
 *
 * Currently only used for AnaMusip. */
template <class T_wrapped_factory>
class TAFactoryWrapper : public TAFactory {
    const std::string moduleName_;
    std::unique_ptr<T_wrapped_factory> pWrappedFactory_;

    TARunObject* NewRunObject(TARunInfo* runinfo) override {
        // We need this here in case this is the first TARunObject created, because it triggers
        // reading from the ODB. Code with non-obvious side effects. Yay!
        Configuration& configuration = Configuration::instance();
        // We need to get a thread lock in case the ODB is modified while the run object
        // is reading the configuration.
        // The wrapped factory already has a reference to the config that this lock protects,
        // which is not obvious from how this code is written...
        auto lock = configuration.getThreadLock();

        return pWrappedFactory_->NewRunObject(runinfo);
    }

    void Usage() override {
        pWrappedFactory_->Usage();
    }

    void Init(const std::vector<std::string>& args) override {
        return pWrappedFactory_->Init(args);
    }

    void Finish() override {
        return pWrappedFactory_->Finish();
    }

public:
    TAFactoryWrapper(const std::string_view name, bool enabledByDefault)
        : moduleName_(name) {
        auto& config = Configuration::config();
        // First see if the module has any kind of config. If there is one, then we enable
        // it even if it does not have an "enabled" entry.
        const bool hasConfig = config.get_child_optional(moduleName_).has_value();
        const bool enabled = config.get<bool>(moduleName_ + ".enabled", hasConfig || enabledByDefault);

        // We write this back into the config, so that the child entry exists if it didn't before.
        config.put(moduleName_ + ".enabled", enabled);

        pWrappedFactory_ = std::make_unique<T_wrapped_factory>(config.get_child(moduleName_));
    }
};

} // namespace

void printUsage(std::ostream& out, const boost::program_options::options_description options) {
    out << "Usage: minalyzer [midas options] -- [minalyzer options]\n"
        << "To see [midas options] use: minalyzer --help (\"--help\" BEFORE the \"--\")\n"
        << "minalyzer options:\n";
    options.print(out);
#ifndef HAVE_musip
    out << "\nN.B. - minalyzer was compiled without musip, so options for connecting to the CDB are not available.\n";
#endif
}

int main(int argc, char* argv[]) {

    // Midas wants to process all options before `--`. We don't care about those, we only care about everything
    // after that. So figure out where/if this is present.
    int ourArgc = argc;
    char** ourArgv = argv;
    // Actually, we care if the user specified an output path with "-D".
    std::filesystem::path outputPath = "root_output_files";

    for(int index = 0; index < argc; ++index, --ourArgc, ++ourArgv) {
        const std::string_view arg(argv[index]); // easier interface for string operations

        if(arg.substr(0, 2) == "-D") {
            // Midas only allows setting as one argument, i.e. without a space. So just chop off the "-D".
            outputPath = arg.substr(2);
        }
        else if(arg == "--") break;
    }

    namespace po = boost::program_options;

    po::options_description commandLineOptions("General");
    commandLineOptions.add_options()("config", po::value<std::string>(), "JSON file to load configuration from")(
        "help", "help"
    );

    po::options_description configFileOptions("Configuration file overrides");
    configFileOptions.add_options()("cdb.enabled", po::value<bool>(), "Connect to the CDB")
        (
            "prompt",
            po::value<std::string>(),
            "A directory to search for the output from prompt analysis for previous runs"
        )
        (
            "prefill",
            po::value<std::string>(),
            "A root file to prefill DQM histograms with (cleared at next run start)"
        );

    po::options_description options;
    options.add(commandLineOptions).add(configFileOptions);

    po::variables_map variableMap;
    try {
        if(ourArgc > 0) { // If there is no "--" we have nothing to parse
            po::store(po::command_line_parser(ourArgc, ourArgv).options(options).run(), variableMap);
        }
    } catch(const std::exception& exception) {
        std::cerr << "Unable to parse command line: " << exception.what() << "\n\n";
        printUsage(std::cerr, options);
        return -1;
    }
    po::notify(variableMap);

    if(variableMap.count("help")) {
        printUsage(std::cout, options);
        return 0;
    }

    // If a config filename was specified on the command line, parse it
    boost::property_tree::ptree& configuration = Configuration::config();
    if(variableMap.count("config")) {
        const std::string configFilename = variableMap["config"].as<std::string>();
        try {
            boost::property_tree::read_json(configFilename, configuration);
        } catch(const std::exception& exception) {
            std::cerr << "Unable to parse the config file '" << configFilename << "' because: " << exception.what()
                      << "\n";
            return -1;
        }
    }

    // Overwrite the values read from the config file with the ones on the command line.
    for(const auto& pOption : configFileOptions.options()) {
        if(variableMap.count(pOption->long_name())) {
            // Only warn if it was also set in the config file
            if(configuration.get_optional<std::string>(pOption->long_name()).has_value()) {
                std::cout << "Command line option '--" << pOption->long_name() << "' overriding value in config file\n";
            }

            // I need to figure out a better way of doing this. It currently only works for specific parameter types.
            try {
                configuration.put(pOption->long_name(), variableMap[pOption->long_name()].as<bool>());
            } catch(const boost::bad_any_cast& exception) {
                // Try again but with a different type (not good code)
                configuration.put(pOption->long_name(), variableMap[pOption->long_name()].as<std::string>());
            }
        }
    }

    //
    // Add directories to where DQMManager will look for root files for previous runs. The
    // directories are searched in order until a file is found, so the earlier entries will
    // take precedence.
    //
    musip::dqm::DQMManager& dqmManager = musip::dqm::DQMManager::instance();
    // If a specified, put the directory for prompt analysis first because that is better
    // quality than the output from online analysis.
    if(configuration.count("prompt")) {
        const std::string promptDirectory = configuration.get<std::string>("prompt");
        std::cout << "Will look in directory " << promptDirectory << " for prompt results if old runs are requested.\n";
        dqmManager.addHistoryDirectory(promptDirectory);
    }
    // Add the directory where we save output, so that we can load it back in on request.
    std::cout << "Will look in directory " << outputPath << " for online results if old runs are requested.\n";
    dqmManager.addHistoryDirectory(outputPath);

    //
    // Pre-fill the current run with previous output in a root file. This is mainly used for
    // debugging custom pages etc. without having to start a run.
    //
    if(configuration.count("prefill")) {
        const std::string rootFilename = configuration.get<std::string>("prefill");
        std::cout << "Prefilling DQM histograms with data from " << rootFilename << "\n";
        dqmManager.addFromRootFile(rootFilename.c_str());
    }

    // We want to clear all plots at the start of each run. So create a new TARunObject
    // *before* all the other modules so that it gets executed first.
    // We can't use a TMFeRpcHandlerInterface::HandleBeginRun override for this in DQMManager
    // because that method is never called for offline files.
    struct ClearPlots : TARunObject {
        ClearPlots(TARunInfo* runinfo) : TARunObject(runinfo) { fModuleName = "ClearPlots"; }
        virtual void BeginRun(TARunInfo* runinfo) override {
            musip::dqm::DQMManager::instance().clearAll();
        }
    };
    TARegister clearPlots(new TAFactoryTemplate<ClearPlots>);

    // The first parameter in the constructor is the name of the config file entry for that module.
    // The second parameter is whether the module is enabled by default when not otherwise specified.
    TARegister fillhits(new TAFactoryTemplateWithConfig<AnaFillHits>("fillhits", true));
    TARegister quad(new TAFactoryTemplateWithConfig<AnaQuadHistos>("quad", true));
    //TARegister musip(new TAFactoryWrapper<AnaMusipFactory>("musip", true));

    // We want to save all plots at the end of each run. So create a new TARunObject
    // *after* all the other modules so that it gets executed last.
    // We can't use a TMFeRpcHandlerInterface::HandleEndRun override for this in DQMManager
    // because that method is never called for offline files.
    // We need a bit of extra boiler plate to get `outputPath` into the save function.
    struct SavePlotsFactory : TAFactory {
        const std::filesystem::path outputPath_;
        SavePlotsFactory(const std::filesystem::path& outputPath) : outputPath_(outputPath) {}

        struct SavePlots : TARunObject {
            const std::filesystem::path outputPath_;
            SavePlots(TARunInfo* runinfo, const std::filesystem::path& outputPath)
                : TARunObject(runinfo), outputPath_(outputPath) {
                fModuleName = "SavePlots";
            }

            virtual void EndRun(TARunInfo* runinfo) override {
                char filename[64];
                snprintf(filename, sizeof(filename), "dqm_histos_%05d.root", runinfo->fRunNo);
                const std::filesystem::path outputFilename = outputPath_ / filename;

                constexpr bool skipEmptyHistograms = false;
                musip::dqm::DQMManager::instance().saveAsRootFile(outputFilename.c_str(), skipEmptyHistograms);
            }
        };

        SavePlots* NewRunObject(TARunInfo* runinfo) override {
            return new SavePlots(runinfo, outputPath_);
        }
    };
    TARegister savePlots(new SavePlotsFactory(outputPath));

    return manalyzer_main(argc, argv);
}
