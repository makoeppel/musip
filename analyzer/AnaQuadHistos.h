#ifndef AnaQuadHistos_H
#define AnaQuadHistos_H

#include "manalyzer.h"
#include "musip/dqm/dqmfwd.hpp"
#include <boost/property_tree/ptree_fwd.hpp>

// Forward declarations
class TH1D;

class AnaQuadHistos : public TARunObject {
public:
    AnaQuadHistos(const boost::property_tree::ptree& config, TARunInfo* runinfo);
    ~AnaQuadHistos();
    void BeginRun(TARunInfo* runinfo);
    void EndRun(TARunInfo* runinfo);
    TAFlowEvent* Analyze(TARunInfo*, TMEvent*, TAFlags* flags, TAFlowEvent* flow) {
        // This function doesn't analyze anything, so we use flags
        // to have the profiler ignore it
        *flags |= TAFlag_SKIP_PROFILE;
        return flow;
    };
    TAFlowEvent* AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow);

protected:

    musip::dqm::PlotCollection* pPlotCollection_ {};

    //global 1D histos
    musip::dqm::Histogram1DD* chipID {};

};

#endif
