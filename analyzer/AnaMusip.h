#ifndef AnaMusip_H
#define AnaMusip_H

#include <manalyzer.h>
#include <boost/property_tree/ptree_fwd.hpp>

#include "musip/dqm/dqmfwd.hpp"

#include <nlohmann/json.hpp>

class AnalyzerEquipment;
class AnalyzerFrontend;

class AnaMusip : public TARunObject {
public:
    AnaMusip(const boost::property_tree::ptree& config, TARunInfo* runinfo, AnalyzerEquipment* eq);
    ~AnaMusip();
    void BeginRun(TARunInfo* runinfo);
    void EndRun(TARunInfo* runinfo);
    TAFlowEvent* Analyze(TARunInfo*, TMEvent*, TAFlags* flags, TAFlowEvent* flow) {
        // This function doesn't analyze anything, so we use flags
        // to have the profiler ignore it
        *flags |= TAFlag_SKIP_PROFILE;
        return flow;
    }
    TAFlowEvent* AnalyzeFlowEvent(TARunInfo* runinfo, TAFlags* flags, TAFlowEvent* flow);

    AnalyzerEquipment* fEq = nullptr;

    nlohmann::json runJson;
    std::string eDisplayJSONAllRunFileName;

protected:
    bool online;
    bool enabled_;
};

class AnaMusipFactory : public TAFactory {
public:
    AnalyzerFrontend* fFe = nullptr;
    AnalyzerEquipment* fEq = nullptr;
    const boost::property_tree::ptree& config_;

    AnaMusipFactory(const boost::property_tree::ptree& config)
        : config_(config) {
    }

    void Usage() {
    }

    void Init(const std::vector<std::string>& args);

    void Finish();

    AnaMusip* NewRunObject(TARunInfo* runinfo) {
        return new AnaMusip(config_, runinfo, fEq);
    }
};

#endif
