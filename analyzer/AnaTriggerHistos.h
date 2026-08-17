#ifndef ANATRIGGERHISTOS_H
#define ANATRIGGERHISTOS_H

#include "manalyzer.h"
#include "musip/dqm/dqmfwd.hpp"
#include <boost/property_tree/ptree_fwd.hpp>
#include "hits.h"
#include <vector>
#include <utility>
#include <unordered_map>
#include <TH1D.h>

// Forward declarations
class TH1D;

class AnaTriggerHistos : public TARunObject {
public:
    AnaTriggerHistos(const boost::property_tree::ptree& config, TARunInfo* runinfo);
    ~AnaTriggerHistos();
    void BeginRun(TARunInfo* runinfo);
    void EndRun(TARunInfo* runinfo);
    TAFlowEvent* Analyze(TARunInfo*, TMEvent*, TAFlags* flags, TAFlowEvent* flow) {
        // This function doesn't analyze anything, so we use flags
        // to have the profiler ignore it
        *flags |= TAFlag_SKIP_PROFILE;
        return flow;
    };
    TAFlowEvent* AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow);

private:
    bool enabled_;
    static const int n_CHANNELS = 4;

    musip::dqm::PlotCollection* pPlotCollection_ {};

    //global 1D histos
    musip::dqm::Histogram1DD* h_channel {}; // channel hitmap
    musip::dqm::Histogram1DD* h_nHits {}; // hits per event
    musip::dqm::Histogram1DD* h_timeStampDeltaSameChannel {}; //time difference t-t_prev for the same channel, all combined

    std::unordered_map<int, musip::dqm::Histogram1DD*> h_tot_; //ToT of hits per channel
    //2D histos
    musip::dqm::Histogram2DF* h_channel_tot {}; //ToT vs channel
    musip::dqm::Histogram2DF* h_channel_8ns {}; //course time vs channel id
    musip::dqm::Histogram2DF* h_channel_1ns {}; //fine time vs channel id
    musip::dqm::Histogram2DF* h_channel_TimeStampDeltaSameChannel {}; //time difference t-t_prev for the same channel
    std::map<std::pair<int,int>, musip::dqm::Histogram2DF*> h_timewalk_; //timewalk histograms for each channel

    std::map<uint16_t, triggerhit> last_hits;

};

#endif
