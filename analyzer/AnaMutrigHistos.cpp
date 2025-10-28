#include "AnaMutrigHistos.h"

#include <boost/property_tree/ptree.hpp>
#include "AnalyzerEquipment.h"
#include "HitVectorFlowEvent.h"

#include "odbxx.h"

#include "musip/dqm/PlotCollection.hpp"
#include "musip/dqm/DQMManager.hpp"
#include <numeric>

AnaMutrigHistos::AnaMutrigHistos(const boost::property_tree::ptree& config, TARunInfo* runinfo)
    : TARunObject(runinfo)
{
    fModuleName = "MutrigHistos";

    enabled_ = config.get<bool>("enabled", true);
    // If this module is disabled, don't do anything else.
    if(!enabled_) return;

    /*
    online = false;
    if(TMFE::Instance()->fDB) {
        online = true;
        printf("Running online\n");
    }
    else printf("Running offline\n");
    */

    pPlotCollection_ = musip::dqm::DQMManager::instance().getOrCreateCollection("mutrig");
}

AnaMutrigHistos::~AnaMutrigHistos() {};

void AnaMutrigHistos::BeginRun(TARunInfo* runinfo) {
    // If this module is disabled, don't do anything.
    if(!enabled_) {
        printf("AnaMutrigHistos::BeginRun, run %d - module is disabled\n", runinfo->fRunNo);
        return;
    }

    printf("MutrigHistos::BeginRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());

    // Note: This error_code isn't checked anywhere yet, but we need it for DQM API.
    std::error_code error; // TODO: actually check this error code and print warnings


    /////////  1D histos  ///////////
    h_channel = pPlotCollection_->getOrCreateHistogram1DD("ChannelID", n_CHANNELS, -0.5, n_CHANNELS - 0.5, error);
    h_asic    = pPlotCollection_->getOrCreateHistogram1DD("ASIC", n_ASICs, -0.5, n_ASICs - 0.5, error);

    //Number of hits per event:
    h_nHits           = pPlotCollection_->getOrCreateHistogram1DD("nHits", 201, -0.5, 200.5, error);
    //Number of duplicate hits (ChannelID is plotted):
    h_nHitsDuplicate  = pPlotCollection_->getOrCreateHistogram1DD("nHitsDuplicate", 2, -0.5, 1.5, error);

    //TOT (Energy) of single channel
    for(int i=0; i<n_CHANNELS ; i++){
        h_tot[i] = pPlotCollection_->getOrCreateHistogram1DD(TString::Format("h_tot_%d",i).Data(), 512, 0, 512, error);
    }

    /////////  2D histos  ///////////
    //ToT (Energy) vs Channel:
    TString histoname = "Channel_ToT";
    h_channel_tot = pPlotCollection_->getOrCreateHistogram2DF(histoname.Data(), n_CHANNELS, -0.5, n_CHANNELS - 0.5, 512, 0, 512, error);
    //Coarse time vs ASIC:
    histoname = "h_ASIC_CoarseTime";
    h_ASIC_CoarseTime = pPlotCollection_->getOrCreateHistogram2DF(histoname.Data(), n_ASICs, -0.5, n_ASICs - 0.5, 0x7fff, 0, 0x7fff, error);
    //Fine time vs ASIC:
    histoname = "h_ASIC_FineTime";
    h_ASIC_FineTime = pPlotCollection_->getOrCreateHistogram2DF(histoname.Data(), n_ASICs, -0.5, n_ASICs - 0.5, 0x1f,    0, 0x1f, error);
    //delta times between consecutive hits in 1 channel (2D)
    histoname = "Channel_TimeStampDeltaSameChannel";
    h_channel_TimeStampDeltaSameChannel = pPlotCollection_->getOrCreateHistogram2DF(histoname.Data(), n_CHANNELS,               - 0.5,                 n_CHANNELS - 0.5,  2048, -1e6 * binsize_ns, 1e6 * binsize_ns, error);
    //delta times between the hit and average time in an event vs ChannelID
    histoname = "Channel_TimeStampDeltaAverageTime";
    h_channel_TimeStampDeltaAverageTime = pPlotCollection_->getOrCreateHistogram2DF(histoname.Data(), n_CHANNELS,               - 0.5,                 n_CHANNELS - 0.5,  2048, -6e9, 6e9, error);
    //delta times between the hit and rms time in an event vs ChannelID
    histoname = "Channel_TimeStampRMSTime";
    h_channel_TimeStampRMSTime = pPlotCollection_->getOrCreateHistogram2DF(histoname.Data(), n_CHANNELS,               - 0.5,                 n_CHANNELS - 0.5,  2048, -6e9, 6e9, error);

    // Mutrig clustering histograms
    /*
    TL_numberOfClusters = pPlotCollection_->getOrCreateHistogram1DI("MutrigClustersPerEvent", 30, -0.5, 29.5, error); // how many cluster we expect in one event (frame)?
    TL_numberOfHitsPerCluster = pPlotCollection_->getOrCreateHistogram1DI("MutrigHitsPerCluster", 20, -0.5, 19.5, error); // how big are the clusters?
    TL_ClustersSizevsNumberofCLusters = pPlotCollection_->getOrCreateHistogram2DF("MutrigClusterSizevsNumberofClusters", 20, -0.5, 19.5, 30, -0.5, 29.5, error); // how big are the clusters?
    TL_ClustersSizevsMeanClusterTime = pPlotCollection_->getOrCreateHistogram2DF("MutrigClusterSizevsMeanClusterTime", 20, -0.5, 19.5, 2048, 0, 6e9, error);
    TL_ClusterNumbervsModuleID = pPlotCollection_->getOrCreateHistogram2DF("MutrigClusterNumbervsmModuleID", n_FEBs, -0.5, n_FEBs - 0.5, 30, -0.5, 29.5, error);
    TL_ClusterModuleIDvsModuleID = pPlotCollection_->getOrCreateHistogram2DF("ModuleIDClusterCorrelations", n_FEBs, -0.5, n_FEBs - 0.5, n_FEBs, -0.5, n_FEBs - 0.5, error);
    */

    /*
    if(online) {
        eventsSinceOdbUpdate_ = 0;
        midas::odb odbRollingAverages = { { "hitsPerEvent", 0.0f } };
        odbRollingAverages.connect(
            "/Equipment/MinAna/Variables/RollingAverages", true
        ); // `true` to overwrite existing values
    }
    */
}

void AnaMutrigHistos::EndRun(TARunInfo* runinfo) {
    // If this module is disabled, don't do anything.
    if(!enabled_) return;

    printf("MutrigHistos::EndRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());
}

TAFlowEvent* AnaMutrigHistos::AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow) {
    // If this module is disabled, don't do anything.
    if(!enabled_) {
        *flags |= TAFlag_SKIP_PROFILE; // Set the profiler to ignore this module
        return flow;
    }

    if(!flow) return flow;

    HitVectorFlowEvent* hitevent = flow->Find<HitVectorFlowEvent>();
    if(!hitevent) return flow;

    //calculate event-based observables
    double average_timestamp = std::accumulate(
           hitevent->mutrighits.begin(),
           hitevent->mutrighits.end(),
           0.0,
           [](double a, mutrighit const b) -> double{ return a+b.timestamp();}
        ) / hitevent->mutrighits.size();

    double rms_timestamp = sqrt(std::accumulate(
           hitevent->mutrighits.begin(),
           hitevent->mutrighits.end(),
           0.0,
           [average_timestamp](double a, mutrighit const b) -> double{ return a + (average_timestamp - b.timestamp())*(average_timestamp - b.timestamp());}
        ) / hitevent->mutrighits.size());


    //fill event-based observables
    h_nHits->Fill(hitevent->mutrighits.size());

    for(auto& hit : hitevent->mutrighits) {
        int cnt =0;
        auto last_hit = last_hits[hit.channel()];

        h_asic->Fill(hit.asic());
        h_channel->Fill(hit.channel());

        h_channel_tot->Fill(hit.channel(), hit.tot());
        h_channel_TimeStampDeltaAverageTime->Fill(hit.channel(), hit.timestamp() - average_timestamp);
        h_channel_TimeStampRMSTime->Fill(hit.channel(), rms_timestamp);

        h_nHitsDuplicate->Fill(
               (hit.timestamp() == last_hit.timestamp())
            && (hit.tot()    == last_hit.tot())
            && (hit.channel()   == last_hit.channel())
        );

	    if(hit.channel() <= n_CHANNELS)
	        h_tot[hit.channel()]->Fill(hit.tot());

        h_channel_tot->Fill(hit.channel(), hit.tot()); // in units of 50ps

        h_ASIC_CoarseTime->Fill(hit.asic(), hit.timestamp()/32); // in units of 1.6ns
        h_ASIC_FineTime->Fill(hit.asic(), hit.finetime_extended());

        //differences to previous hit
        if((last_hits.find(hit.channel()) != last_hits.end()) && ((last_hit.timestamp()) != 0)) {
            int64_t timeStampDelta = hit.timestamp() - last_hit.timestamp(); // in units of 50ps
            h_channel_TimeStampDeltaSameChannel->Fill(hit.channel(), timeStampDelta*binsize_ns);
        }


	    last_hits[hit.channel()]=hit;
    }

    return flow;
}
