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
    using MD = musip::dqm::Metadata;

    /////////  1D histos  ///////////
    chipID = pPlotCollection_->getOrCreateHistogram1DD("chipID", 16, -0.5, 16 - 0.5, error);

    /////////  2D histos  ///////////
    for (int i = 0; i < 16; i++) {
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
    for (int i = 0; i < 4; i++) {
        char quadIDString[256];
        std::string directoryName = std::string("");
        // Create a name from the 4 chip IDs
        snprintf(quadIDString, sizeof(quadIDString), "%05i_%05i_%05i_%05i", 
                0+i*4, 1+i*4, 2+i*4, 3+i*4);
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
}

std::tuple<uint32_t, uint32_t> AnaQuadHistos::get_quad_global_col_row(pixelhit hit) {
    size_t chipPosition = hit.chipid() % 4;
    float combinedCol = hit.col();
    float combinedRow = hit.row();
    size_t layer = hit.chipid() / 4;

    switch(chipPosition) {
        case 0: // upper left - rotated 180°
            combinedCol = 255 - hit.col();  // flip horizontally
            combinedRow = 250 + (249 - hit.row());  // flip vertically + offset to upper half
            break;
        case 1: // upper right - rotated 180°
            combinedCol = 256 + (255 - hit.col());  // offset + flip horizontally
            combinedRow = 250 + (249 - hit.row());  // flip vertically + offset to upper half
            break;
        case 2: // lower left - no rotation
            // combinedCol and combinedRow already correct (0-255, 0-249)
            break;
        case 3: // lower right - no rotation
            combinedCol += 256;
            // combinedRow already correct (0-249)
            break;
    }

    float finalCol = combinedCol;
    float finalRow = combinedRow;

    switch(layer) {
        case 0: // Layer 0: 180° around z, then 180° around x
        case 2: // Layer 2: like layer 0
            // 180° around z: flip both col and row in the combined space
            finalCol = 511 - combinedCol;  // flip horizontally (0-511 range)
            finalRow = 499 - combinedRow;  // flip vertically (0-499 range)
            // 180° around x: flip row again (so row is back to normal, col stays flipped)
            finalRow = 499 - finalRow; // This makes finalRow = combinedRow again
            break;
        case 1: // Layer 1: 180° around z
            // if ( hit.chipid() == 4 )
            //     finalCol = 255 - combinedCol;  // flip horizontally (0-511 range)
        case 3: // Layer 3: like layer 1
            // 180° around z: flip both col and row in the combined space
            finalCol = 511 - combinedCol;  // flip horizontally (0-511 range)
            finalRow = 499 - combinedRow;  // flip vertically (0-499 range)
            break;
        default:
            // No rotation
            break;
    }

    return std::make_tuple(finalCol, finalRow);
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
            if (hitmap->GetBinContent(binx, biny) > noiseLimit) {
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

    return vec;
}

void AnaQuadHistos::EndRun(TARunInfo* runinfo) {

    printf("AnaQuadHistos::EndRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());

    // write mask file
    for ( int index = 0; index < 16; index++ ) {
        mask_files[index] = create_mask_file(hitmaps[index]->asRootObject("myHistogram", "My histogram title").get(), index, 0.5);

        std::string path = "/home/mu3e/mu3e/debug_online/online/userfiles/maskfiles/mask_analyser";
        std::string data = "/mask_" + std::to_string(index) + ".bin";

        // write new file
        std::ofstream out_file;
        out_file.open(path + data, std::ios::binary);
        out_file.write((char*) mask_files[index].data(), mask_files[index].size() * sizeof(uint8_t));
        out_file.close();
    }

}

TAFlowEvent* AnaQuadHistos::AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow) {

    if(!flow) return flow;

    HitVectorFlowEvent* hitevent = flow->Find<HitVectorFlowEvent>();
    if(!hitevent) return flow;

    for ( auto& hit : hitevent->pixelhits ) {
        chipID->Fill(hit.chipid());

        if (hit.chipid() > 16) continue;

        // fill hitmap histograms
        uint32_t col, row;
        std::tie(col, row) = get_quad_global_col_row(hit);
        if ( hit.chipid() < 4 ) combinedHitmap[0]->Fill(col, row);
        if ( hit.chipid() >= 4 && hit.chipid() < 8 ) combinedHitmap[1]->Fill(col, row);
        if ( hit.chipid() >= 8 && hit.chipid() < 12 ) combinedHitmap[2]->Fill(col, row);
        if ( hit.chipid() >= 12 ) combinedHitmap[3]->Fill(col, row);
        hitmaps[hit.chipid()]->Fill(hit.col(), hit.row());

        // fill timing histogram
        uint32_t ckdivend = 0;
        uint32_t ckdivend2 = 31;
        uint32_t localTime = hit.time() % (1 << 11);  // local pixel time is first 11 bits of the global time
        uint32_t cur_hitToA = localTime * 8/*ns*/ * (ckdivend + 1);
        uint32_t cur_hitToT = ( ( (0x1F+1) + hit.tot() -  ( (localTime * (ckdivend+1) / (ckdivend2+1) ) & 0x1F) ) & 0x1F);//  * 8 * (ckdivend2+1) ;
        hitToT[hit.chipid()]->Fill(cur_hitToT);
        hitToA[hit.chipid()]->Fill(cur_hitToA);
        hitTime[hit.chipid()]->Fill(localTime);

    }

    return flow;
}
