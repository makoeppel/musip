#include "AnaMusip.h"
#include "AnalyzerEquipment.h"
#include <iomanip>
#include <iostream>
#include <string.h>

#include "root_helpers.h"

#include "json.h"
using json = nlohmann::json;

#include <boost/filesystem.hpp>
#include <boost/format.hpp>
#include <boost/range/adaptor/map.hpp>
using boost::adaptors::map_values;

AnaMusip::AnaMusip(const boost::property_tree::ptree& config, TARunInfo* runinfo, AnalyzerEquipment* eq)
    : TARunObject(runinfo) {
    fModuleName = "Musip";

    if(!enabled_) return;

    fEq = eq;

}

AnaMusip::~AnaMusip() {
}

void AnaMusip::BeginRun(TARunInfo* runinfo) {
    // If this module is disabled, don't do anything.
    if(!enabled_) {
        printf("AnaMusip::BeginRun, run %d - module is disabled\n", runinfo->fRunNo);
        return;
    }
}

void AnaMusip::EndRun(TARunInfo* runinfo) {
    // If this module is disabled, don't do anything.
    if(!enabled_) return;

    printf("Trirec::EndRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());

}

TAFlowEvent* AnaMusip::AnalyzeFlowEvent(TARunInfo* runinfo, TAFlags* flags, TAFlowEvent* flow) {
    // If this module is disabled, don't do anything.
    if(!enabled_) {
        *flags |= TAFlag_SKIP_PROFILE; // Set the profiler to ignore this module
        return flow;
    }

    if(!flow) return flow;

    if(fEq) {
        //fEq->EqSendEvent(event.data);
        fEq->EqWriteStatistics();
    }
    return flow;
}

void AnaMusipFactory::Init(const std::vector<std::string>& args) {

    if(TMFE::Instance()->fDB) {
        // This is only true if running online.
        // If we are offline, then we can't write into the stream so we don't create the FE equipment.

        fFe = new AnalyzerFrontend();
        fEq = new AnalyzerEquipment("MinAna", __FILE__);
        fFe->FeAddEquipment(fEq);

        TMFeResult r = fFe->FeInitEquipments(args);

        if(r.error_flag) {
            fprintf(stderr, "Cannot initialize equipments, error message: %s, bye.\n", r.error_message.c_str());
            fFe->fMfe->Disconnect();
            exit(1);
        }
    }
}

void AnaMusipFactory::Finish() {
    printf("Finish!\n");
    if(fFe) {
        delete fFe;
        fFe = NULL;
    }
}
