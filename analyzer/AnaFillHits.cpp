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

    eventheader h;
    h.event_id = event->event_id;
    h.trigger_mask = event->trigger_mask;
    h.serial_number = event->serial_number;
    h.midas_time_stamp = event->time_stamp;
    h.data_size = event->data_size;

    uint32_t sr_num = 0;
    sr_num = h.serial_number;
    SrNo->Fill(static_cast<double>(sr_num));

    event->FindAllBanks(); // Scan for all banks. This call is required to make event->banks valid.
    // Loop over all banks and check the names to see if we should process them
    for(const auto& bank : event->banks) {
        //
        // Multiple "events" can now be put into one, but with bank names with an index
        // in it (since 1 Midas event must have unique bank names).
        // We also need to support the old bank names though, so there are a lot of checks on
        // bank names here, but the data is in the same format.
        //

        // Check if we have one of these banks with an index in it like PSxx where xx is 00->99
        // in ASCII. So we check if the third and fourth characters are in the ASCII range 48 to 57.
        const bool isIndexedName = (bank.name[2] >= 48 && bank.name[2] <= 57) && (bank.name[3] >= 48 && bank.name[3] <= 57);
        const std::string_view firstTwoChars(bank.name.data(), 2);

        const char* rawData = event->GetBankData(&bank);

        // First check for DSIN slow control banks. Old name was DSIN, new name is DS00-DS99.
        // We just want to pull out the timestamp.
        uint32_t sr_num = 0;
        uint64_t timestampFromDSIN = 0;
        if(bank.name == "DSIN" || (isIndexedName && firstTwoChars == "DS")) {
            const febdata* febData = reinterpret_cast<const febdata*>(rawData);
            sr_num = h.serial_number;
            timestampFromDSIN = (uint64_t(febData->ts_high) << 16) | febData->ts_low;
            SrNo->Fill(static_cast<double>(sr_num));
            timestamp->Fill(static_cast<double>(timestampFromDSIN));
            SrNo_ts->Fill(static_cast<double>(sr_num), static_cast<double>(timestampFromDSIN));
        }
        // Old pixel bank name is PHIT, or DHPS for debug hits from the switching board.
        // New name is PS00-PS99.
        else if(bank.name == "PHIT" || bank.name == "DHPS" || (isIndexedName && firstTwoChars == "PS")) {
            const pixelhit* dataStart = reinterpret_cast<const pixelhit*>(rawData);
            const pixelhit* dataEnd = reinterpret_cast<const pixelhit*>(rawData + bank.data_size);

            pixelHits_.reserve(pixelHits_.size() + (dataEnd - dataStart));
            for(const pixelhit* current = dataStart; current != dataEnd; ++current) {
                // If we got this far through the loop, we passed all checks and we want the hit
                pixelHits_.emplace_back(*current);
            } // end of loop over all pixelhits
        }
    } // end of loop over all Midas banks

    flow = new HitVectorFlowEvent(flow, h, std::move(pixelHits_));
    // After a std::move, objects are in an undefined state. So we
    // reset as default constructed vectors.
    pixelHits_ = std::vector<pixelhit>();

    return flow;
}