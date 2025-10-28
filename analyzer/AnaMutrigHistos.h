#ifndef ANATILEHISTOS_H
#define ANATILEHISTOS_H

#include "manalyzer.h"
#include "musip/dqm/dqmfwd.hpp"
#include <boost/property_tree/ptree_fwd.hpp>
#include "hits.h"

// Forward declarations
class TH1D;

class AnaMutrigHistos : public TARunObject {
public:
    AnaMutrigHistos(const boost::property_tree::ptree& config, TARunInfo* runinfo);
    ~AnaMutrigHistos();
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
    bool enabled_;
    static const int n_ASICs = 2;
    static const int n_CHANNELS = n_ASICs * 32;
    const double binsize_ns = 50e-3; //50ps

    musip::dqm::PlotCollection* pPlotCollection_ {};

    //global 1D histos
    musip::dqm::Histogram1DD* h_asic {}; // channel hitmap
    musip::dqm::Histogram1DD* h_channel {}; // channel hitmap
    musip::dqm::Histogram1DD* h_timeStampDeltaSameChannel {}; //time difference t-t_prev for the same channel, all combined

    musip::dqm::Histogram1DD* h_nHits {}; //number of hits per frame
    musip::dqm::Histogram1DD* h_nHitsDuplicate {}; //number of duplicate hits in frame

    musip::dqm::Histogram1DD* h_tot[n_CHANNELS] {}; //ToT of hits per channel

    //2D histos
    musip::dqm::Histogram2DF* h_channel_tot {}; //ToT vs channel
    musip::dqm::Histogram2DF* h_ASIC_CoarseTime {}; //course time vs asic id
    musip::dqm::Histogram2DF* h_ASIC_FineTime {}; //fine time vs asic id
    musip::dqm::Histogram2DF* h_channel_TimeStampDeltaSameChannel {}; //time difference t-t_prev for the same channel (tileid) vs tileid
    musip::dqm::Histogram2DF* h_channel_TimeStampDeltaAverageTime {}; //time difference between the hit and average time in an event vs TileID
    musip::dqm::Histogram2DF* h_channel_TimeStampRMSTime {}; //rms time of all hits vs TileID
    std::map<uint16_t, mutrighit> last_hits;
    
    // Tile clusters
    /*
    musip::dqm::Histogram1DI* TL_numberOfClusters = nullptr;
    musip::dqm::Histogram1DI* TL_numberOfHitsPerCluster = nullptr;
    musip::dqm::Histogram2DF* TL_ClustersSizevsNumberofCLusters  = nullptr; 
    musip::dqm::Histogram2DF* TL_ClustersSizevsMeanClusterTime  = nullptr; 
    musip::dqm::Histogram2DF* TL_ClusterNumbervsModuleID  = nullptr; 
    musip::dqm::Histogram2DF* TL_ClusterModuleIDvsModuleID  = nullptr; 
    */


    //
    // Members for handling running averages of event quantities.
    //
    /*
    size_t eventsToAverage_ = 10000; ///< The number of events to average over when calculating e.g. number of hits per event
    struct RollingAverage {
        size_t numberOfHits = 0;
        // ...other values...  if you add anything make sure to update the overloaded operators
        RollingAverage& operator+=(const RollingAverage& other);
        RollingAverage& operator-=(const RollingAverage& other);
    };
    std::deque<RollingAverage> previousEvents_; ///< A running count of the number of hits in each event. Used to update the average.
    RollingAverage totalOverEvents_; ///< The total of all events in previousEvents
    size_t eventsSinceOdbUpdate_;
    */
};

#endif
