#include "AnaTriggerHistos.h"

#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>

#include "AnalyzerEquipment.h"
#include "HitVectorFlowEvent.h"

#include "odbxx.h"

#include "musip/dqm/PlotCollection.hpp"
#include "musip/dqm/DQMManager.hpp"
#include <numeric>
#include <unordered_map>

AnaTriggerHistos::AnaTriggerHistos(const boost::property_tree::ptree& config, TARunInfo* runinfo)
    : TARunObject(runinfo)
{
    fModuleName = "TriggerHistos";

    pPlotCollection_ = musip::dqm::DQMManager::instance().getOrCreateCollection("trigger");
}

AnaTriggerHistos::~AnaTriggerHistos() {};

void AnaTriggerHistos::BeginRun(TARunInfo* runinfo) {

    printf("TriggerHistos::BeginRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());

    // Note: This error_code isn't checked anywhere yet, but we need it for DQM API.
    std::error_code error; // TODO: actually check this error code and print warnings
    using MD = musip::dqm::Metadata;

    /////////  1D histos  ///////////
    h_channel = pPlotCollection_->getOrCreateHistogram1DD("ChannelID", n_CHANNELS, -0.5, n_CHANNELS - 0.5, error);
    h_nHits = pPlotCollection_->getOrCreateHistogram1DD("nHits", 201, -0.5, 200.5, error);
    h_phaserf = pPlotCollection_->getOrCreateHistogram1DD("h_phaserf", 201, -0.5, 200.5, error);
    h_periodrf = pPlotCollection_->getOrCreateHistogram1DD("h_periodrf", 201, -0.5, 200.5, error);

    for (int ch = 0; ch < n_CHANNELS; ch++) {
        printf("Creating ToT histogram for channel %d\n", ch);
        h_tot_[ch] = pPlotCollection_->getOrCreateHistogram1DD(
            TString::Format("h_tot_%d", ch).Data(),
            256, 0, 256, error,
            MD::Title("ToT"),
            MD::AxisTitleX("ToT [ns]")
        );
        printf("Creating time diff histogram for channel %d\n", ch);
        h_time_diff_[ch] = pPlotCollection_->getOrCreateHistogram1DD(
            TString::Format("h_time_diff_%d", ch).Data(),
            2048, 0, 2048, error,
            MD::Title("Hit time - prev. hit time same channel"),
            MD::AxisTitleX("Time [ns]")
        );
    }

    /////////  2D histos  ///////////
    h_tof_rf = pPlotCollection_->getOrCreateHistogram2DI("ToF_ToT", 128, 0, 128, 32, 0, 32, error);
    h_channel_tot = pPlotCollection_->getOrCreateHistogram2DI("Channel_ToT", n_CHANNELS, -0.5, n_CHANNELS - 0.5, 256, 0, 256, error);
    h_channel_8ns = pPlotCollection_->getOrCreateHistogram2DI("Channel_8ns", n_CHANNELS, -0.5, n_CHANNELS - 0.5, 2048, 0, 0xFFFFFFF, error);
    h_channel_1ns = pPlotCollection_->getOrCreateHistogram2DI("Channel_1ns", n_CHANNELS, -0.5, n_CHANNELS - 0.5, 2048, 0, 0xFFFFF, error);
    h_channel_TimeStampDeltaSameChannel = pPlotCollection_->getOrCreateHistogram2DI("Channel_TimeStampDeltaSameChannel", n_CHANNELS, - 0.5, n_CHANNELS - 0.5, 2048, -2048, 2048, error);

    printf("Done setting up histograms\n");
}

void AnaTriggerHistos::EndRun(TARunInfo* runinfo) {
    printf("TriggerHistos::EndRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());
}

TAFlowEvent* AnaTriggerHistos::AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow) {

    if(!flow) return flow;

    HitVectorFlowEvent* hitevent = flow->Find<HitVectorFlowEvent>();
    if(!hitevent) return flow;

    std::vector<triggerhit> triggerhits;
    for ( auto& cur_hit : hitevent->hits )
        if (cur_hit.is_trigger())
            triggerhits.push_back(cur_hit.as_trigger());

    //fill event-based observables
    h_nHits->Fill(triggerhits.size());

    std::sort(triggerhits.begin(), triggerhits.end(),
        [](const auto& a, const auto& b) {
            return a.time() < b.time();
        });

    //loop over hits
    for(auto& hit : triggerhits) {
        auto last_hit = last_hits[hit.channel()];

        if (hit.channel() == 1) {
            saw_s1 = 1;
            last_s1 = hit;
        }

        // logic for RF
        if (saw_s1 == 1 && hit.channel() == 6) {
            cur_rf_hits.push_back(hit.time_1ns());
            int diff = (int) last_time_rf - (int) hit.time_1ns();
            // we had a 3 puls event before start again and wait for the next s1
            if (std::abs(diff) > 200 && last_time_rf != 0) {
                saw_s1 = 0;
                cur_rf_hits.clear();
                last_time_rf = 0;
            } else {
                last_time_rf = hit.time_1ns();
            }
            // we only look at the 4 pulses for now
            if ( cur_rf_hits.size() == 4 ) {
                std::sort(cur_rf_hits.begin(), cur_rf_hits.end());
                int scint_time = last_s1.time_1ns();
                int last_rf_time = cur_rf_hits[cur_rf_hits.size()-2];
                int64_t rf_phase = last_rf_time - scint_time;
                int rf_period = cur_rf_hits[cur_rf_hits.size()-1] - cur_rf_hits[cur_rf_hits.size()-2];
                h_tof_rf->Fill(rf_phase, last_s1.tot());
                h_phaserf->Fill(rf_phase);
                h_periodrf->Fill(rf_period);
                saw_s1 = 0;
                cur_rf_hits.clear();
            }
        }

        // fill 1D
        if ( hit.channel() == 0 )
            hit.Print();
        h_channel->Fill(hit.channel());
        if (hit.channel() < n_CHANNELS) {
            h_tot_[hit.channel()]->Fill(hit.tot());
            if (hit.time_8ns() == last_hits[hit.channel()].time_8ns())
                h_time_diff_[hit.channel()]->Fill((int) hit.time_1ns() - (int) last_hits[hit.channel()].time_1ns());
        }
        // fill 2D
        h_channel_tot->Fill(hit.channel(), hit.tot());
        h_channel_8ns->Fill(hit.channel(), hit.time_8ns());
        h_channel_1ns->Fill(hit.channel(), hit.time_1ns());

        //differences to previous hit
        if((last_hits.find(hit.channel()) != last_hits.end()) && ((last_hit.time()) != 0)) {
            int64_t timeStampDelta = hit.time() - last_hit.time();
            h_channel_TimeStampDeltaSameChannel->Fill(hit.channel(), timeStampDelta);
        }

        last_hits[hit.channel()] = hit;
    }

    return flow;

}
