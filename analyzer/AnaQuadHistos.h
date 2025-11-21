#ifndef AnaQuadHistos_H
#define AnaQuadHistos_H

#include "manalyzer.h"
#include "musip/dqm/dqmfwd.hpp"
#include <boost/property_tree/ptree_fwd.hpp>
#include "hits.h"
#include <TH2F.h>

// Forward declarations
class TH1D;

class AnaQuadHistos : public TARunObject {
public:
    AnaQuadHistos(const boost::property_tree::ptree& config, TARunInfo* runinfo);
    ~AnaQuadHistos();
    void BeginRun(TARunInfo* runinfo);
    void EndRun(TARunInfo* runinfo);
    std::tuple<uint32_t, uint32_t> get_quad_global_col_row(pixelhit hit);
    std::vector<uint8_t> create_mask_file(const TH2F* hitmap, uint32_t chipID, float noiseThreshold);
    std::pair<double, double> CalculateMeanAndSigma(const TH2F* hitmap);
    TAFlowEvent* Analyze(TARunInfo*, TMEvent*, TAFlags* flags, TAFlowEvent* flow) {
        // This function doesn't analyze anything, so we use flags
        // to have the profiler ignore it
        *flags |= TAFlag_SKIP_PROFILE;
        return flow;
    };
    TAFlowEvent* AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow);

protected:

    musip::dqm::PlotCollection* pPlotCollection_ {};

    //global 1D histos
    musip::dqm::Histogram1DD* chipID {};
    std::vector<musip::dqm::Histogram2DF*> maskmap;
    std::vector<musip::dqm::Histogram2DF*> combinedHitmap;
    std::vector<musip::dqm::Histogram2DF*> hitmaps;
    std::vector<musip::dqm::Histogram1DD*> hitToT;
    std::vector<musip::dqm::Histogram1DD*> hitToA;
    std::vector<musip::dqm::Histogram1DD*> hitTime;
    std::vector<std::vector<uint8_t>> mask_files;

};

#endif
