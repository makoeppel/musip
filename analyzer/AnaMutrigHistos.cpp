#include "AnaMutrigHistos.h"

#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>

#include "AnalyzerEquipment.h"
#include "HitVectorFlowEvent.h"

#include "odbxx.h"

#include "musip/dqm/PlotCollection.hpp"
#include "musip/dqm/DQMManager.hpp"
#include <numeric>
#include <unordered_map>

AnaMutrigHistos::AnaMutrigHistos(const boost::property_tree::ptree& config, TARunInfo* runinfo)
    : TARunObject(runinfo)
{
    fModuleName = "MutrigHistos";

    enabled_ = config.get<bool>("enabled", true);
    

    printf("<Beginning of %s Module configuration>\n", fModuleName.c_str());
    boost::property_tree::write_json(std::cout, config);
    printf("<End of %s Module configuration>\n", fModuleName.c_str());
    
    // If this module is disabled, don't do anything else.
    if(!enabled_) return;

    // parse mutrig -> channelpairs into vector<pair<int,int>> using boost::property_tree
    if (auto pairs_opt = config.get_child_optional("channelpairs")) {
        const boost::property_tree::ptree &pairs = *pairs_opt;
        for (const auto &entry : pairs) {
            const boost::property_tree::ptree &arr = entry.second;
            std::vector<int> vals;
            for (const auto &elem : arr) {
                try {
                    vals.push_back(elem.second.get_value<int>());
                } catch (...) {
                    // ignore malformed element
                }
            }
            if (vals.size() == 2) {
                channelpairs_[std::pair<int,int>(vals[0], vals[1])]= entry.first;
            }
        }
    }

    // parse mutrig -> tot_channels into vector<int>
    if (auto tot_opt = config.get_child_optional("tot_channels")) {
        const boost::property_tree::ptree &tot = *tot_opt;
        for (const auto &elem : tot) {
            try {
                tot_channels_.push_back(elem.second.get_value<int>());
            } catch (...) {
                // ignore malformed element
            }
        }
    }

    //parse enable flags for histograms
    tdiff_enabled_ = config.get<bool>("tdiff_enabled", true);
    timewalk_enabled_ = config.get<bool>("timewalk_enabled", false);
    tdiff_timewalk_enabled_ = config.get<bool>("tdiff_timewalk_enabled", false);
    ecorrelation_enabled_ = config.get<bool>("ecorrelation_enabled", false);
    
    //parse energy cuts for timewalk correction
    if (auto cuts_opt = config.get_child_optional("timewalk_energycuts")) {
        const boost::property_tree::ptree &cuts = *cuts_opt;
        for (const auto &entry : cuts) {
            const boost::property_tree::ptree &arr = entry.second;
            std::vector<int> vals;
            for (const auto &elem : arr) {
                try {
                    vals.push_back(elem.second.get_value<int>());
                } catch (...) {
                    // ignore malformed element
                }
            }
            if (vals.size() == 2) {
                timewalk_energycuts_[std::stoi(entry.first)] = std::make_pair(vals[0], vals[1]);
            }
        }
    }

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

    //TOT (Energy) of single channel -- create only for channels listed in tot_channels_ (configuration):
    for (int ch : tot_channels_) {
        printf("Creating ToT histogram for channel %d\n", ch);
        h_tot_[ch] = pPlotCollection_->getOrCreateHistogram1DD(
            TString::Format("h_tot_%d", ch).Data(),
            512, 0, 512, error
        );
    }

    //1D Time difference between hits between channels, paired in tdiff_channelpairs_ (configuration):
    for (const auto &chpair : channelpairs_) {
        printf("Creating histograms for channel pair \n");
        if(tdiff_enabled_ == true) {
            printf("Creating TimeStampDelta histogram for channel pair %s : (%d, %d)\n", chpair.second.c_str(), chpair.first.first, chpair.first.second);
            TString histoname = TString::Format("TimeStampDelta_%s", chpair.second.c_str());
            h_tdiff_channelpairs_[chpair.first] = pPlotCollection_->getOrCreateHistogram1DD(
                histoname.Data(),
                401, -2e2 * binsize_ns, 2e2 * binsize_ns, error
            );
        }
        if(tdiff_timewalk_enabled_ == true) {
            printf("Creating TimeStampDelta_Timewalk histogram for channel pair %s : (%d, %d)\n", chpair.second.c_str(), chpair.first.first, chpair.first.second);
            TString histoname = TString::Format("TimeStampDelta_Timewalk_%s", chpair.second.c_str());
            h_tdiff_tw_channelpairs_[chpair.first] = pPlotCollection_->getOrCreateHistogram1DD(
                histoname.Data(),
                401, -2e2 * binsize_ns, 2e2 * binsize_ns, error
            );
        }
        if(timewalk_enabled_ == true) {
            //create timewalk histogram for each channelpair
            printf("Creating Timewalk histograms for channel pair %s : (%d, %d)\n", chpair.second.c_str(), chpair.first.first, chpair.first.second);
            TString histoname = TString::Format("Timewalk_ChannelPair_%s", chpair.second.c_str());
            h_timewalk_[chpair.first] = pPlotCollection_->getOrCreateHistogram2DF(
                histoname.Data(),
                128, 0, 512,
                200, -2e2 * binsize_ns, 2e2 * binsize_ns,
                error
            );
        }

	if(ecorrelation_enabled_ == true) {
            //create e-e histogram for each channelpair
            printf("Creating E-E corellation histograms for channel pair %s : (%d, %d)\n", chpair.second.c_str(), chpair.first.first, chpair.first.second);
            TString histoname = TString::Format("Ecorrelation_ChannelPair_%s", chpair.second.c_str());
            h_ecorrelation_[chpair.first] = pPlotCollection_->getOrCreateHistogram2DF(
                histoname.Data(),
                128, 0, 512,
                128, 0, 512,
                error
            );
	
    //energy-energy corellation
    histoname = "ecorrelation";
	}
    }
    

    /////////  2D histos  ///////////
    //ToT (Energy) vs Channel:
    TString histoname = "Channel_ToT";
    h_channel_tot = pPlotCollection_->getOrCreateHistogram2DF(histoname.Data(), n_CHANNELS, -0.5, n_CHANNELS - 0.5, 512, 0, 512, error);
    //Coarse time vs ASIC:
    histoname = "ASIC_CoarseTime";
    h_ASIC_CoarseTime = pPlotCollection_->getOrCreateHistogram2DF(histoname.Data(), n_ASICs, -0.5, n_ASICs - 0.5, 0x7fff, 0, 0x7fff, error);
    //Fine time vs ASIC:
    histoname = "ASIC_FineTime";
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

    printf("Done setting up histograms\n");
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
    //loop over hits
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

        // fill per-channel ToT histogram only if this channel is in tot_channels_
        auto it = h_tot_.find(hit.channel());
        if (it != h_tot_.end()) {
            it->second->Fill(hit.tot());
        }

        h_channel_tot->Fill(hit.channel(), hit.tot()); // in units of 50ps

        h_ASIC_CoarseTime->Fill(hit.asic(), hit.timestamp()/32); // in units of 1.6ns
        h_ASIC_FineTime->Fill(hit.asic(), hit.finetime_extended());

        //differences to previous hit
        if((last_hits.find(hit.channel()) != last_hits.end()) && ((last_hit.timestamp()) != 0)) {
            int64_t timeStampDelta = hit.timestamp() - last_hit.timestamp(); // in units of 50ps
            h_channel_TimeStampDeltaSameChannel->Fill(hit.channel(), timeStampDelta*binsize_ns);
        }

        //time differences of hits in paired channel
        for (auto& hitB : hitevent->mutrighits) {
            if ( (hit.channel() >= hitB.channel()) ) continue;
            int64_t timeStampDelta = ((int64_t) hit.timestamp()) - hitB.timestamp(); // in units of 50ps
            if(abs(timeStampDelta * binsize_ns) >= 10) continue; // cut out 10ns

            
            auto itA = h_tdiff_channelpairs_.find(std::make_pair(hit.channel(), hitB.channel()));
            auto itB = h_tdiff_channelpairs_.find(std::make_pair(hitB.channel(), hit.channel()));
            //fill time difference histogram, if found
            if (itA != h_tdiff_channelpairs_.end())
                itA->second->Fill( timeStampDelta * binsize_ns );
                else if (itB != h_tdiff_channelpairs_.end())
                    itB->second->Fill( timeStampDelta * binsize_ns );

            //get energy cuts for timewalk correction
            auto cutItB = timewalk_energycuts_.find(hitB.channel());
            if( (cutItB != timewalk_energycuts_.end()) &&
                (cutItB->second.first < hitB.tot()) &&
                (cutItB->second.second > hitB.tot()) ) {
                    //fill timewalk 2D histogram for hitB
                    auto twItB = h_timewalk_.find(std::make_pair(hit.channel(), hitB.channel()));
                    if(twItB != h_timewalk_.end()) {
                        twItB->second->Fill(
                            hit.tot(),
                            timeStampDelta * binsize_ns
                        );
                    }
            }
	    //fill energy correlations
	    {
	        auto eeItB = h_ecorrelation_.find(std::make_pair(hit.channel(), hitB.channel()));
                if(eeItB != h_ecorrelation_.end()) {
                    eeItB->second->Fill(hit.tot(),hitB.tot());
                }
            }
        }

        last_hits[hit.channel()]=hit;
    }

    return flow;

}



