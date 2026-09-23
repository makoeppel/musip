#ifndef ANAHITTREE_H
#define ANAHITTREE_H

#include "manalyzer.h"

#include <boost/property_tree/ptree_fwd.hpp>

class TTree;

class AnaHitTree : public TARunObject {
public:
    AnaHitTree(const boost::property_tree::ptree& config, TARunInfo* runinfo);
    ~AnaHitTree();

    void BeginRun(TARunInfo* runinfo);
    void EndRun(TARunInfo* runinfo);
    TAFlowEvent* Analyze(TARunInfo*, TMEvent*, TAFlags* flags, TAFlowEvent* flow);
    TAFlowEvent* AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow);

private:
    bool enabled_ {};
    bool write_triggerhits_ {};
    bool write_pixelhits_ {};
    TTree* tree_ {};

    //splitting of the hit vectors
    std::vector<uint32_t> trigger_channel_;
    std::vector<uint16_t> trigger_tot_;
    std::vector<double> trigger_time_;
    std::vector<uint64_t> trigger_timestamp_;

    std::vector<int64_t> l1_s1_time_;

    std::vector<int64_t> time_chip1;
    std::vector<int64_t> time_s1;

    std::vector<uint32_t> pixel_chipid_;
    std::vector<uint8_t> pixel_col_;
    std::vector<uint8_t> pixel_row_;
    std::vector<uint8_t> pixel_tot_;
    std::vector<double> pixel_time_;
    std::vector<uint64_t> pixel_timestamp_;

};

#endif