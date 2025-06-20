#include "AnaQuadHistos.h"

#include <boost/property_tree/ptree.hpp>
#include "HitVectorFlowEvent.h"

#include "odbxx.h"

#include "musip/dqm/PlotCollection.hpp"
#include "musip/dqm/DQMManager.hpp"
#include <TH1D.h>
#include <numeric>
AnaQuadHistos::AnaQuadHistos(const boost::property_tree::ptree& config, TARunInfo* runinfo)
    : TARunObject(runinfo)
{
    fModuleName = "QuadHistos";

    pPlotCollection_ = musip::dqm::DQMManager::instance().getOrCreateCollection("quad");
}

AnaQuadHistos::~AnaQuadHistos() {};

void AnaQuadHistos::BeginRun(TARunInfo* runinfo) {

    printf("QuadHistos::BeginRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());

    // Note: This error_code isn't checked anywhere yet, but we need it for DQM API.
    std::error_code error; // TODO: actually check this error code and print warnings

    /////////  1D histos  ///////////
    chipID = pPlotCollection_->getOrCreateHistogram1DD("chipID", 16, -0.5, 16 - 0.5, error);

}

void AnaQuadHistos::EndRun(TARunInfo* runinfo) {

    printf("AnaQuadHistos::EndRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());
}

TAFlowEvent* AnaQuadHistos::AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow) {

    if(!flow) return flow;

    HitVectorFlowEvent* hitevent = flow->Find<HitVectorFlowEvent>();
    if(!hitevent) return flow;

    for(auto& hit : hitevent->pixelhits) {
        chipID->Fill(hit.chipid());
    }

    return flow;
}
