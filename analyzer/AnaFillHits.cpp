#include "AnaFillHits.h"
#include "HitVectorFlowEvent.h"

#include <cstdint>
#include <iostream>
#include <regex>
#include <set>
#include <vector>
#include <iomanip>
#include "musip/dqm/PlotCollection.hpp"
#include "musip/dqm/DQMManager.hpp"
#include <boost/property_tree/ptree.hpp>

AnaFillHits::AnaFillHits(const boost::property_tree::ptree& config, TARunInfo* runinfo)
    : TARunObject(runinfo) {
    fModuleName = "AnaFillHits";

    enabled_ = config.get<bool>("enabled", true);
    // If this module is disabled, don't do anything else.
    if(!enabled_) return;

    pPlotCollection = musip::dqm::DQMManager::instance().getOrCreateCollection("DAQfills");

};

AnaFillHits::~AnaFillHits() {};

void AnaFillHits::BeginRun(TARunInfo* runinfo) {
    // If this module is disabled, don't do anything.
    if(!enabled_) {
        printf("AnaFillHits::BeginRun, run %d - module is disabled\n", runinfo->fRunNo);
        return;
    }

    printf("AnaFillHits::BeginRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());

    // Note: This error_code isn't checked anywhere yet, but we need it for DQM API.
    std::error_code error; // TODO: actually check this error code and print warnings
    SrNo = pPlotCollection->getOrCreateHistogram1DD("serialnumber", 250, 0, 2.0e05, error);
    timestamp = pPlotCollection->getOrCreateHistogram1DD("timestamp", 250, 0, 4.0e08, error);
    SrNo_ts = pPlotCollection->getOrCreateHistogram2DD("serialnumber_timestamp", 250, 0, 2.0e05, 250, 0, 4.0e08, error);
    SrNo_ts_mutrig = pPlotCollection->getOrCreateHistogram2DD("serialnumber_timestamp_mutrig", 250, 0, 2.0e05, 250, 0, 4.0e08, error);
    timePixelvsMutrig = pPlotCollection->getOrCreateHistogram1DD("timePixelvsMutrig", 2048, 0, 2048, error);

};

void AnaFillHits::EndRun(TARunInfo* runinfo) {
    // If this module is disabled, don't do anything.
    if(!enabled_) return;

    printf("AnaFillHits::EndRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());
};

TAFlowEvent* AnaFillHits::Analyze(TARunInfo* runinfo, TMEvent* event, TAFlags* flags, TAFlowEvent* flow) {
    // If this module is disabled, don't do anything.
    if(!enabled_) {
        *flags |= TAFlag_SKIP_PROFILE; // Set the profiler to ignore this module
        return flow;
    }

    // Only process readout events
    if(event->event_id != 301) return flow;

    // ----------------------------------------
    // Scan MIDAS banks
    // ----------------------------------------
    event->FindAllBanks();

    std::vector<hit> hits_;

    for(const auto& bank : event->banks) {
        const std::string firstTwoChars = bank.name.substr(0, 1);
        const char* rawData = event->GetBankData(&bank);

        // ----------------------------------------
        // HTxx bank: mixed hit bank
        // ----------------------------------------
        if(firstTwoChars == "H") {
            const hit* dataStart = reinterpret_cast<const hit*>(rawData);
            const hit* dataEnd   = reinterpret_cast<const hit*>(rawData + bank.data_size);

            hits_.reserve(hits_.size() + (dataEnd - dataStart));

            for(const hit* current = dataStart; current != dataEnd; ++current) {
                hits_.emplace_back(*current);
            }
        }
    }

    flow = new HitVectorFlowEvent(flow, std::move(hits_));
    // After a std::move, objects are in an undefined state. So we
    // reset as default constructed vectors.
    hits_ = std::vector<hit>();

    return flow;
}
