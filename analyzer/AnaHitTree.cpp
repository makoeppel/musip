#include "AnaHitTree.h"

#include "HitVectorFlowEvent.h"

#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>
#include <TTree.h>
#include <iostream>
AnaHitTree::AnaHitTree(const boost::property_tree::ptree& config, TARunInfo* runinfo)
    : TARunObject(runinfo)
    , enabled_(config.get<bool>("enabled", true)),
    write_triggerhits_(config.get<bool>("write_triggerhits", true)),
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
    tree_ = new TTree("hits", "MuPix and Trigger hits");

    tree_->Branch("trigger_channel", &trigger_channel_); //global channel number
    tree_->Branch("trigger_tot", &trigger_tot_); //tot in 1.6ns && scaled by FPGA
    tree_->Branch("trigger_time", &trigger_time_); // global time in 1ns seconds
    tree_->Branch("trigger_timestamp", &trigger_timestamp_); // trigger time in 1ns bins

    tree_->Branch("pixel_chipid", &pixel_chipid_); //chip id
    tree_->Branch("pixel_col", &pixel_col_); //column number
    tree_->Branch("pixel_row", &pixel_row_); //row number
    tree_->Branch("pixel_tot", &pixel_tot_);
    tree_->Branch("pixel_time", &pixel_time_); //time in 8 nano seconds (?)
    tree_->Branch("pixel_timestamp", &pixel_timestamp_); //time in 8 nano seconds (?)

    tree_->Branch("l1_s1_time", &l1_s1_time_); //time in 8 nano seconds (?)
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
    trigger_channel_.clear();
    trigger_tot_.clear();
    trigger_time_.clear();
    trigger_timestamp_.clear();
    l1_s1_time_.clear();

    for(const auto& currentHit : hitEvent->hits) {
        if(write_pixelhits_ && currentHit.is_pixel()) {
            auto spHit = currentHit.as_pixel();
            pixel_chipid_.push_back(spHit.chipid());
            pixel_col_.push_back(spHit.col());
            pixel_row_.push_back(spHit.row());
            pixel_tot_.push_back(spHit.tot());
            pixel_time_.push_back(spHit.time()*8); //convert to nano seconds
        }
        if(write_triggerhits_ && currentHit.is_trigger()) {
            auto spHit = currentHit.as_trigger();
            trigger_channel_.push_back(spHit.channel());
            trigger_tot_.push_back(spHit.tot());
            trigger_time_.push_back(spHit.time());
            trigger_timestamp_.push_back(spHit.time_1ns());
        }
    }

    tree_->Fill();
    return flow;
}