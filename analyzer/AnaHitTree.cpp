#include "AnaHitTree.h"

#include "HitVectorFlowEvent.h"

#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>
#include <TTree.h>
#include <iostream>
AnaHitTree::AnaHitTree(const boost::property_tree::ptree& config, TARunInfo* runinfo)
    : TARunObject(runinfo)
    , enabled_(config.get<bool>("enabled", true)),
    write_mutrighits_(config.get<bool>("write_mutrighits", true)),
    write_pixelhits_(config.get<bool>("write_pixelhits", true)) 
{
    fModuleName = "HitTree";
    //printf("<Beginning of %s Module configuration>\n", fModuleName.c_str());
    //boost::property_tree::write_json(std::cout, config);
    //printf("<End of %s Module configuration>\n", fModuleName.c_str());
}

AnaHitTree::~AnaHitTree() = default;

void AnaHitTree::BeginRun(TARunInfo* runinfo) {
    if(!enabled_) return;


    printf("HitTree::BeginRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());

    runinfo->fRoot->fOutputFile->cd();
    tree_ = new TTree("hits", "MuPix and MuTRIG hits");

    tree_->Branch("mutrig_channel", &mutrig_channel_); //global channel number
    tree_->Branch("mutrig_tot", &mutrig_tot_); //tot in 1.6ns && scaled by FPGA
    tree_->Branch("mutrig_time", &mutrig_time_); //time in nano seconds
    tree_->Branch("mutrig_timestamp", &mutrig_timestamp_); //time in 50ps bins

    tree_->Branch("pixel_chipid", &pixel_chipid_); //chip id
    tree_->Branch("pixel_col", &pixel_col_); //column number
    tree_->Branch("pixel_row", &pixel_row_); //row number
    tree_->Branch("pixel_tot", &pixel_tot_);
    tree_->Branch("pixel_time", &pixel_time_); //time in 8 nano seconds (?)
    tree_->Branch("pixel_timestamp", &pixel_timestamp_); //time in 8 nano seconds (?)
}

void AnaHitTree::EndRun(TARunInfo* runinfo) {
    if(!enabled_) return;

    if(tree_) {
        runinfo->fRoot->fOutputFile->cd();
        tree_->Write();
    }
}

TAFlowEvent* AnaHitTree::Analyze(TARunInfo*, TMEvent*, TAFlags* flags, TAFlowEvent* flow) {
    *flags |= TAFlag_SKIP_PROFILE;
    return flow;
}

TAFlowEvent* AnaHitTree::AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow) {
    if(!enabled_) {
        *flags |= TAFlag_SKIP_PROFILE;
        return flow;
    }

    if(!flow || !tree_) return flow;

    auto* hitEvent = flow->Find<HitVectorFlowEvent>();
    if(!hitEvent) return flow;

    pixel_chipid_.clear();
    pixel_col_.clear();
    pixel_row_.clear();
    pixel_tot_.clear();
    pixel_time_.clear();
    pixel_timestamp_.clear();
    mutrig_channel_.clear();
    mutrig_tot_.clear();
    mutrig_time_.clear();
    mutrig_timestamp_.clear();

    for(const auto& currentHit : hitEvent->hits) {
        if(write_pixelhits_ && currentHit.is_pixel()) {
            auto spHit = currentHit.as_pixel();
            pixel_chipid_.push_back(spHit.chipid());
            pixel_col_.push_back(spHit.col());
            pixel_row_.push_back(spHit.row());
            pixel_tot_.push_back(spHit.tot());
            pixel_time_.push_back(spHit.time()*8); //convert to nano seconds
            pixel_timestamp_.push_back(spHit.timestamp());
        }
        if(write_mutrighits_ && currentHit.is_mutrig()) {
            auto spHit = currentHit.as_mutrig();
            mutrig_channel_.push_back(spHit.channel());
            mutrig_tot_.push_back(spHit.tot());
            mutrig_time_.push_back(spHit.time());
            mutrig_timestamp_.push_back(spHit.timestamp());
        }
    }

    tree_->Fill();
    return flow;
}