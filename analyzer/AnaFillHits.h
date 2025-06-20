#ifndef ANAFILLHITS_H
#define ANAFILLHITS_H

#include "manalyzer.h"
#include <filesystem>
#include <map>
#include <vector>
#include <boost/property_tree/ptree_fwd.hpp>
#include <boost/optional.hpp>
#include "musip/dqm/dqmfwd.hpp"
#include "hits.h"

class AnaFillHits : public TARunObject {
public:
    AnaFillHits(const boost::property_tree::ptree& config, TARunInfo* runinfo);
    ~AnaFillHits();
    void BeginRun(TARunInfo* runinfo);
    void EndRun(TARunInfo* runinfo);
    TAFlowEvent* Analyze(TARunInfo* runinfo, TMEvent* event, TAFlags* flags, TAFlowEvent* flow);
    TAFlowEvent* AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow) {
        // This function doesn't analyze anything, so we use flags
        // to have the profiler ignore it
        *flags |= TAFlag_SKIP_PROFILE;
        return flow;
    }

    bool enabled_;
    // We might be asked to do some sorting and merging. To do this we need to
    // store the various hits between events, so that they can all be put into
    // a HitVectorFlowEvent all at the same time.
    std::vector<pixelhit> pixelHits_;

protected:
    // Copy pasted from AnaPixelHistos.h
    // Members for handling running averages of event quantities.
    //
    musip::dqm::PlotCollection* pPlotCollection = nullptr;
    musip::dqm::Histogram1DD* SrNo = nullptr;
    musip::dqm::Histogram1DD* timestamp = nullptr;
    musip::dqm::Histogram2DD* SrNo_ts = nullptr;
};

#endif
