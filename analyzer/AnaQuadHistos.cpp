#include "AnaQuadHistos.h"

#include <boost/property_tree/ptree.hpp>
#include "HitVectorFlowEvent.h"

#include "odbxx.h"

#include "musip/dqm/PlotCollection.hpp"
#include "musip/dqm/DQMManager.hpp"
#include <TH1D.h>
#include <numeric>

#include "json.h"
using json = nlohmann::json;

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
    using MD = musip::dqm::Metadata;

    /////////  1D histos  ///////////
    chipID = pPlotCollection_->getOrCreateHistogram1DD("chipID", 24, -0.5, 24 - 0.5, error);

    /////////  2D histos  ///////////
    h_rate_per_channel = pPlotCollection_->getOrCreateHistogram2DF("h_rate_per_channel", 24, -0.5, 24 - 0.5, 2048, -0.5, 10000 - 0.5, error);
    for (int i = 0; i < 12; i++) {
        mask_files.push_back({});
        char quadIDString[256];
        std::string directoryName = std::string("");
        // Create a name from the 4 chip IDs
        snprintf(quadIDString, sizeof(quadIDString), "%05i", i);
        hitmaps.push_back(pPlotCollection_->getOrCreateHistogram2DF(
            directoryName + "hitmap_" + quadIDString, 
            256, -0.5, 255.5,   // 2 * 256 columns
            250, -0.5, 249.5,   // 2 * 250 rows
            error,
            MD::Title("Hitmap"), 
            MD::AxisTitleX("Column"), 
            MD::AxisTitleY("Row")
        ));

        hitmaps_low_tot.push_back(pPlotCollection_->getOrCreateHistogram2DF(
            directoryName + "hitmap_low_tot_" + quadIDString, 
            256, -0.5, 255.5,   // 2 * 256 columns
            250, -0.5, 249.5,   // 2 * 250 rows
            error,
            MD::Title("Hitmap"), 
            MD::AxisTitleX("Column"), 
            MD::AxisTitleY("Row")
        ));

        hitmaps_high_tot.push_back(pPlotCollection_->getOrCreateHistogram2DF(
            directoryName + "hitmap_high_tot_" + quadIDString, 
            256, -0.5, 255.5,   // 2 * 256 columns
            250, -0.5, 249.5,   // 2 * 250 rows
            error,
            MD::Title("Hitmap"), 
            MD::AxisTitleX("Column"), 
            MD::AxisTitleY("Row")
        ));

        hitToT.push_back(pPlotCollection_->getOrCreateHistogram1DD(
            directoryName + "hitToT_" + quadIDString, 
            32, 0, 32,
            error,
            MD::Title("ToT")
        ));

        hitTime.push_back(pPlotCollection_->getOrCreateHistogram1DD(
            directoryName + "hitTime_" + quadIDString, 
            1<<11, -0.5, 2047.5,
            error,
            MD::Title("Time")
        ));

        hitToA.push_back(pPlotCollection_->getOrCreateHistogram1DD(
            directoryName + "hitToA_" + quadIDString, 
            5000, 0, 50000,
            error,
            MD::Title("Time of arrival")
        ));

        maskmap.push_back(pPlotCollection_->getOrCreateHistogram2DF(
            directoryName + "maskmap_" + quadIDString, 
            256, -0.5, 255.5,   // 2 * 256 columns
            250, -0.5, 249.5,   // 2 * 250 rows
            error,
            MD::Title("maskmap"), 
            MD::AxisTitleX("Column"), 
            MD::AxisTitleY("Row")
        ));
    }

    // combined histos
    for (int i = 0; i < 6; i++) {
        char quadIDString[256];
        std::string directoryName = std::string("");
        // Create a name from the 4 chip IDs
        snprintf(quadIDString, sizeof(quadIDString), "%05i", i);
        combinedHitmap.push_back(pPlotCollection_->getOrCreateHistogram2DF(
            directoryName + "combined_hitmap_" + quadIDString, 
            512, -0.5, 511.5,   // 2 * 256 columns
            500, -0.5, 499.5,   // 2 * 250 rows
            error,
            MD::Title("Combined Hitmap (4 sensors)"), 
            MD::AxisTitleX("Combined Column"), 
            MD::AxisTitleY("Combined Row")
        ));
    }

    // clear vectors
    vec_tot_noisy_pixels.clear();
}


std::pair<double, double> AnaQuadHistos::CalculateMeanAndSigma(const TH2F* hitmap) {

    //calculate mean of entries, then sigma, ignoring bins with 0 entry
    double sum = 0;
    std::vector<double> contents;

    for (int binx = 1; binx <= hitmap->GetXaxis()->GetNbins(); binx++) {
        for (int biny = 1; biny <= hitmap->GetYaxis()->GetNbins(); biny++) {
            if (hitmap->GetBinContent(binx, biny) < 0.00001) continue;
            sum += hitmap->GetBinContent(binx, biny);
            contents.push_back(hitmap->GetBinContent(binx, biny));
        }
    }

    double mean = (contents.size() > 0) ? sum / contents.size() : 0;
    double sigma = 0;
    for ( uint i = 0; i < contents.size(); i++ ) {
        sigma+=(mean-contents.at(i))*(mean-contents.at(i));
    }
    sigma = sqrt(sigma / contents.size());

    std::pair<double, double> MeanAndSigma_;
    MeanAndSigma_.first=mean;
    MeanAndSigma_.second=sigma;
    return MeanAndSigma_;
}

std::vector<uint8_t> AnaQuadHistos::create_mask_file(const TH2F* hitmap, uint32_t chipID, float noiseThreshold) {

    std::vector<uint8_t> vec;
    int Ncol = hitmap->GetXaxis()->GetNbins();
    int Nrow = hitmap->GetYaxis()->GetNbins();

    std::pair<double, double> MeanAndSigma = CalculateMeanAndSigma(hitmap);
    double mean = MeanAndSigma.first;
    double sigma = MeanAndSigma.second;
    double noiseLimit = mean + 3 * sigma;

    if (( Ncol != 256) || (Nrow != 250)) std::cout<< "WARNING! In DQAnomalyChecker::DetectAndMaskNoisyPixelsFromHitmap: Ncol vs Nrows in pixel hitmap doesn't match what is expected! Ncol = " << Ncol << ", Nrow = " << Nrow << ". The pixel mask might be nonsense."<< std::endl;

    int tot_noisy_pixels = 0;
    for (int binx = 1; binx <= Ncol; binx++) {
        for (int biny = 1; biny <= Nrow; biny++) {
            if (hitmap->GetBinContent(binx, biny) > noiseThreshold) { //noiseLimit) {
                vec.push_back(0x00);
                tot_noisy_pixels++;
                maskmap[chipID]->Fill(binx-1, biny-1);
            } else {
                vec.push_back(0x47);
            }
        }
        // fill up col
        // -- store 0xdada as end-of-col marker
        vec.push_back(0xda);
        vec.push_back(0xda);
        // -- store number of col
        vec.push_back(0xda);
        vec.push_back(binx-1);
        // -- store LVDS error flag
        vec.push_back(0xda);
        vec.push_back(0x00); // for now we don't use this
    }
    vec_tot_noisy_pixels.push_back(tot_noisy_pixels);

    return vec;
}

void AnaQuadHistos::EndRun(TARunInfo* runinfo) {

    printf("AnaQuadHistos::EndRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());

    // write mask file
    std::string path = "/home/pinky/bt2026/musip/output/maskfiles_analyzer";
    for ( int index = 0; index < 12; index++ ) {
        mask_files[index] = create_mask_file(hitmaps[index]->asRootObject("myHistogram", "My histogram title").get(), index, 0.5);

        std::string data = "/mask_" + std::to_string(index) + "_run_" + std::to_string(runinfo->fRunNo) + ".bin";

        // write new file
        std::ofstream out_file;
        out_file.open(path + data, std::ios::binary);
        out_file.write((char*) mask_files[index].data(), mask_files[index].size() * sizeof(uint8_t));
        out_file.close();
    }

    // write json for masking data
    json j;
    for (size_t i = 0; i < vec_tot_noisy_pixels.size(); ++i)
        j[std::to_string(i)] = vec_tot_noisy_pixels[i];
    std::ofstream file(path + "/mask_meta_run_" + std::to_string(runinfo->fRunNo) + ".json");
    file << j.dump(4);
    file.close();

}

TAFlowEvent* AnaQuadHistos::AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow) {

    if(!flow) return flow;

    HitVectorFlowEvent* hitevent = flow->Find<HitVectorFlowEvent>();
    if(!hitevent) return flow;

    std::vector<pixelhit> pixelhits;
    std::unordered_map<int, int> hits_per_channel;

    for ( auto& cur_hit : hitevent->hits ) {
        if (cur_hit.is_pixel()) {
            hits_per_channel[cur_hit.as_pixel().chipid()]++;
            pixelhits.push_back(cur_hit.as_pixel());
        }
    }

    std::sort(pixelhits.begin(), pixelhits.end(),
        [](const auto& a, const auto& b) {
            return a.time() < b.time();
    });

    if ( pixelhits.size() == 0 ) return flow;

    // get rate per chip
    float time_in_sec = (pixelhits.back().time() - pixelhits.front().time()) / 1e9;
    for (auto const& pair : hits_per_channel) {
        auto key = pair.first;
        h_rate_per_channel->Fill(key, hits_per_channel[key] / time_in_sec);
    }
    //printf("Event Time %i\n", (int) pixelhits.front().time() - (int) prev_time);
    prev_time = pixelhits.back().time();

    for ( auto hit : pixelhits ) {

        chipID->Fill(hit.chipid());

        if (hit.chipid() >= 24) continue;

        combinedHitmap[hit.layer()]->Fill(hit.globalcol(), hit.globalrow());

        hitmaps[hit.chipid()]->Fill(hit.col(), hit.row());
        // fill timing histogram
        uint32_t ckdivend = 0;
        uint32_t ckdivend2 = 31;
        uint32_t localTime = hit.time8ns() % (1 << 11);  // local pixel time is first 11 bits of the global time
        uint32_t cur_hitToA = localTime * 8/*ns*/ * (ckdivend + 1);
        uint32_t cur_hitToT = ( ( (0x1F+1) + hit.tot() -  ( (localTime * (ckdivend+1) / (ckdivend2+1) ) & 0x1F) ) & 0x1F);//  * 8 * (ckdivend2+1) ;
        hitToT[hit.chipid()]->Fill(cur_hitToT);
        hitToA[hit.chipid()]->Fill(cur_hitToA);
        hitTime[hit.chipid()]->Fill(localTime);

        if (cur_hitToT < 5) hitmaps_low_tot[hit.chipid()]->Fill(hit.col(), hit.row());
        else hitmaps_high_tot[hit.chipid()]->Fill(hit.col(), hit.row());

    }

    return flow;
}
