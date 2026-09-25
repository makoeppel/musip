#include "AnaTriggerHistos.h"

#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>

#include "AnalyzerEquipment.h"
#include "HitVectorFlowEvent.h"

#include "odbxx.h"

#include "musip/dqm/PlotCollection.hpp"
#include "musip/dqm/DQMManager.hpp"
#include <numeric>
#include <unordered_map>

#include <TH2I.h>
#include <TLine.h>
#include <TF1.h>
#include <TCanvas.h>
#include <TStyle.h>
#include <TLatex.h>
#include <TPaveText.h>

AnaTriggerHistos::AnaTriggerHistos(const boost::property_tree::ptree& config, TARunInfo* runinfo)
    : TARunObject(runinfo)
{
    fModuleName = "TriggerHistos";

    pPlotCollection_ = musip::dqm::DQMManager::instance().getOrCreateCollection("trigger");
}

AnaTriggerHistos::~AnaTriggerHistos() {};

void AnaTriggerHistos::BeginRun(TARunInfo* runinfo) {

    printf("TriggerHistos::BeginRun, run %d, file %s\n", runinfo->fRunNo, runinfo->fFileName.c_str());

    // Note: This error_code isn't checked anywhere yet, but we need it for DQM API.
    std::error_code error; // TODO: actually check this error code and print warnings
    using MD = musip::dqm::Metadata;

    /////////  1D histos  ///////////
    proton_current = pPlotCollection_->getOrCreateHistogram1DD("proton_current", 2048, 0 - 0.5, 4096 - 0.5, error);
    l1_s1_time = pPlotCollection_->getOrCreateHistogram1DD("l1_s1_time", 2048, -2048 - 0.5, 2048 - 0.5, error);
    l1_s1_time_corrected = pPlotCollection_->getOrCreateHistogram1DD("l1_s1_time_corrected", 2048, -2048 - 0.5, 2048 - 0.5, error);
    h_channel = pPlotCollection_->getOrCreateHistogram1DD("ChannelID", n_CHANNELS, -0.5, n_CHANNELS - 0.5, error);
    h_nHits = pPlotCollection_->getOrCreateHistogram1DD("nHits", 201, -0.5, 200.5, error);
    h_phaserf = pPlotCollection_->getOrCreateHistogram1DD("h_phaserf", 201, -0.5, 200.5, error);
    h_periodrf = pPlotCollection_->getOrCreateHistogram1DD("h_periodrf", 201, -0.5, 200.5, error);

    for (int ch = 0; ch < n_CHANNELS; ch++) {
        printf("Creating ToT histogram for channel %d\n", ch);
        h_tot_[ch] = pPlotCollection_->getOrCreateHistogram1DD(
            TString::Format("h_tot_%d", ch).Data(),
            256, 0, 256, error,
            MD::Title("ToT"),
            MD::AxisTitleX("ToT [ns]")
        );
        printf("Creating time diff histogram for channel %d\n", ch);
        h_time_diff_[ch] = pPlotCollection_->getOrCreateHistogram1DD(
            TString::Format("h_time_diff_%d", ch).Data(),
            2048, 0, 2048, error,
            MD::Title("Hit time - prev. hit time same channel"),
            MD::AxisTitleX("Time [ns]")
        );
    }

    /////////  2D histos  ///////////
    h_l1_s1_time_vs_time = pPlotCollection_->getOrCreateHistogram2DF("l1_s1_time_vs_time", 1000, -0.5, 1e6 - 0.5, 256, -256 - 0.5, 256 - 0.5, error);
    h_rate_per_channel = pPlotCollection_->getOrCreateHistogram2DF("h_rate_per_channel", 24, -0.5, 24 - 0.5, 2048, -0.5, 10000 - 0.5, error);
    h_tof_rf = pPlotCollection_->getOrCreateHistogram2DI("ToF_ToT", 128, 0, 128, 32, 0, 32, error);
    h_tot_l1_vs_s1 = pPlotCollection_->getOrCreateHistogram2DI("ToT_l1_vs_s1", 32, 0 - 0.5, 32 - 0.5, 256, 0 - 0.5, 256 - 0.5, error);
    h_timewalk_l1_vs_time_s1 = pPlotCollection_->getOrCreateHistogram2DI("timewalk_l1_vs_time_s1", 256, -128 - 0.5, 128 - 0.5, 32, 0 - 0.5, 32 - 0.5, error);
    h_timewalk_corrected_l1_vs_time_s1 = pPlotCollection_->getOrCreateHistogram2DI("timewalk_corrected_l1_vs_time_s1", 256, -128 - 0.5, 128 - 0.5, 32, 0 - 0.5, 32 - 0.5, error);
    h_channel_tot = pPlotCollection_->getOrCreateHistogram2DI("Channel_ToT", n_CHANNELS, -0.5, n_CHANNELS - 0.5, 256, 0, 256, error);
    h_channel_8ns = pPlotCollection_->getOrCreateHistogram2DI("Channel_8ns", n_CHANNELS, -0.5, n_CHANNELS - 0.5, 2048, 0, 0xFFFFFFF, error);
    h_channel_1ns = pPlotCollection_->getOrCreateHistogram2DI("Channel_1ns", n_CHANNELS, -0.5, n_CHANNELS - 0.5, 2048, 0, 0xFFFFF, error);
    h_channel_TimeStampDeltaSameChannel = pPlotCollection_->getOrCreateHistogram2DI("Channel_TimeStampDeltaSameChannel", n_CHANNELS, - 0.5, n_CHANNELS - 0.5, 2048, -2048, 2048, error);

    printf("Done setting up histograms\n");
}

void AnaTriggerHistos::EndRun(TARunInfo* runinfo) {
    auto rootHist = h_timewalk_l1_vs_time_s1->asRootObject("timewalk", "C1-S1 time walk;#Deltat [ns];ToT");
    auto time_diff_corrected = l1_s1_time_corrected->asRootObject("histo", "C1-S1 time corrected;#Deltat [ns];#");

    TH2I* h = rootHist.get();
    TH1D* h_corrected = time_diff_corrected.get();
    h_corrected->GetXaxis()->SetRangeUser(-100.0, 100.0);

    TF1 doubleGaus("doubleGaus", "[0]*exp(-0.5*pow((x-[1])/[2],2)) + [3]*exp(-0.5*pow((x-[1])/[4],2))", -60.0, 60.0);

    double maxBin = h_corrected->GetMaximum();
    double initialMean = h_corrected->GetBinCenter(h_corrected->GetMaximumBin());
    doubleGaus.SetParameters(maxBin, initialMean, 5.0, maxBin * 0.3, 15.0);

    h_corrected->Fit(&doubleGaus, "RQ");

    double mean = doubleGaus.GetParameter(1);
    double sigma1 = doubleGaus.GetParameter(2);
    double sigma2 = doubleGaus.GetParameter(4);
    double A1 = doubleGaus.GetParameter(0);
    double A2 = doubleGaus.GetParameter(3);

    double meanErr = doubleGaus.GetParError(1);
    double sigma1Err = doubleGaus.GetParError(2);
    double sigma2Err = doubleGaus.GetParError(4);

    double effectiveRMS = std::sqrt((A1 * std::pow(sigma1, 3) + A2 * std::pow(sigma2, 3)) / (A1 * sigma1 + A2 * sigma2));

    std::cout << "Double Gaussian fit:\n"
              << "  Mean      = " << mean << " +/- " << meanErr << " ns\n"
              << "  Sigma 1   = " << sigma1 << " +/- " << sigma1Err << " ns\n"
              << "  Sigma 2   = " << sigma2 << " +/- " << sigma2Err << " ns\n"
              << "  Effective RMS = " << effectiveRMS << " ns\n";

    TCanvas* canvas = new TCanvas("timewalk_canvas", "C1-S1 Time Walk", 1400, 700);
    canvas->Divide(2, 1);

    canvas->cd(1);
    gPad->SetRightMargin(0.15);
    h->SetStats(0);
    h->GetXaxis()->SetTitle("#Deltat = C1 - S1 [ns]");
    h->GetYaxis()->SetTitle("ToT");
    h->Draw("COLZ");

    canvas->cd(2);
    gPad->SetGridx();
    gPad->SetGridy();

    h_corrected->SetStats(0);
    h_corrected->SetMarkerStyle(20);
    h_corrected->SetMarkerSize(0.8);
    h_corrected->SetMarkerColor(kBlue);
    h_corrected->SetLineColor(kBlue);
    h_corrected->GetXaxis()->SetTitle("#Deltat = C1 - S1 [ns]");
    h_corrected->GetYaxis()->SetTitle("#");
    h_corrected->SetTitle("C1-S1 Time Corrected;#Deltat = C1 - S1 [ns];#");
    h_corrected->Draw("E1");

    doubleGaus.SetLineColor(kRed);
    doubleGaus.SetLineWidth(3);
    doubleGaus.Draw("SAME");
    gPad->Update();

    TLine meanLine(mean, gPad->GetUymin(), mean, gPad->GetUymax());
    meanLine.SetLineColor(kGreen + 2);
    meanLine.SetLineStyle(2);
    meanLine.SetLineWidth(2);
    meanLine.Draw("SAME");

    TPaveText pave(0.60, 0.68, 0.88, 0.88, "NDC");
    pave.SetFillStyle(0);
    pave.SetBorderSize(0);
    pave.SetTextSize(0.032);
    pave.AddText(TString::Format("#sigma_{1} = %.2f #pm %.2f ns", sigma1, sigma1Err));
    pave.Draw("SAME");

    canvas->SaveAs(TString::Format("timewalk_run_%d.pdf", runinfo->fRunNo));
    delete canvas;
}

TAFlowEvent* AnaTriggerHistos::AnalyzeFlowEvent(TARunInfo*, TAFlags* flags, TAFlowEvent* flow) {

    if(!flow) return flow;

    HitVectorFlowEvent* hitevent = flow->Find<HitVectorFlowEvent>();
    if(!hitevent) return flow;

    std::vector<triggerhit> triggerhits;
    std::unordered_map<int, int> hits_per_channel;

    for ( auto& cur_hit : hitevent->hits ) {
        if (cur_hit.is_trigger()) {
            hits_per_channel[cur_hit.as_trigger().channel()]++;
            triggerhits.push_back(cur_hit.as_trigger());
        }
    }

    //fill event-based observables
    h_nHits->Fill(triggerhits.size());

    std::sort(triggerhits.begin(), triggerhits.end(),
        [](const auto& a, const auto& b) {
            return a.ts_header() < b.ts_header();
        });

    // get rate per channel
    float time_in_sec = ((triggerhits.back().ts_header() - triggerhits.front().ts_header()) * 16) / 1e6;
    for (auto const& pair : hits_per_channel) {
        auto key = pair.first;
        h_rate_per_channel->Fill(key, hits_per_channel[key] / time_in_sec);
    }

    //loop over hits
    for(auto& hit : triggerhits) {
        auto last_hit = last_hits[hit.channel()];

        if (hit.channel() == 7)
            proton_current->Fill(hit.time_1ns());

        if (hit.channel() == 1) {
            saw_s1 = 1;
            last_s1 = hit;
        }

        // logic for RF
        if (saw_s1 == 1 && hit.channel() == 6) {
            cur_rf_hits.push_back(hit.time_1ns());
            int diff = (int) last_time_rf - (int) hit.time_1ns();
            // we had a 3 puls event before start again and wait for the next s1
            if (std::abs(diff) > 200 && last_time_rf != 0) {
                saw_s1 = 0;
                cur_rf_hits.clear();
                last_time_rf = 0;
            } else {
                last_time_rf = hit.time_1ns();
            }
            // we only look at the 4 pulses for now
            if ( cur_rf_hits.size() == 4 ) {
                std::sort(cur_rf_hits.begin(), cur_rf_hits.end());
                int scint_time = last_s1.time_1ns();
                int last_rf_time = cur_rf_hits[cur_rf_hits.size()-2];
                int64_t rf_phase = last_rf_time - scint_time;
                int rf_period = cur_rf_hits[cur_rf_hits.size()-1] - cur_rf_hits[cur_rf_hits.size()-2];
                h_tof_rf->Fill(rf_phase, last_s1.tot());
                h_phaserf->Fill(rf_phase);
                h_periodrf->Fill(rf_period);
                saw_s1 = 0;
                cur_rf_hits.clear();
            }
        }

        // fill 1D
        if ( hit.channel() == 0 )
            hit.Print();
        h_channel->Fill(hit.channel());
        if (hit.channel() < n_CHANNELS) {
            h_tot_[hit.channel()]->Fill(hit.tot());
            if (hit.time_8ns() == last_hits[hit.channel()].time_8ns())
                h_time_diff_[hit.channel()]->Fill((int) hit.time_1ns() - (int) last_hits[hit.channel()].time_1ns());
        }
        // fill 2D
        h_channel_tot->Fill(hit.channel(), hit.tot());
        h_channel_8ns->Fill(hit.channel(), hit.time_8ns());
        h_channel_1ns->Fill(hit.channel(), hit.time_1ns());

        //differences to previous hit
        if((last_hits.find(hit.channel()) != last_hits.end()) && ((last_hit.time()) != 0)) {
            int64_t timeStampDelta = hit.time() - last_hit.time();
            h_channel_TimeStampDeltaSameChannel->Fill(hit.channel(), timeStampDelta);
        }

        last_hits[hit.channel()] = hit;
    }

    // correlation between S1 and L1
    std::vector<triggerhit> s1_hits;
    std::vector<pixelhit> ch1_hits;

    for(const auto& currentHit : hitevent->hits) {
        if(currentHit.is_pixel())
            if (currentHit.as_pixel().chipid() == 1)
                ch1_hits.push_back(currentHit.as_pixel());
        if(currentHit.is_trigger()) {
            if (currentHit.as_trigger().channel() == 1)
                s1_hits.push_back(currentHit.as_trigger());
        }
    }

    std::sort(s1_hits.begin(), s1_hits.end(),
        [](const auto& a, const auto& b) {
            return a.time_1ns() < b.time_1ns();
        });
    std::sort(ch1_hits.begin(), ch1_hits.end(),
        [](const auto& a, const auto& b) {
            return a.time() < b.time();
        });

    for (auto s1_hit : s1_hits) {
        for (auto ch1_hit : ch1_hits) {
            if (std::abs((int) (ch1_hit.time() & 0xFFFFF) - (int) s1_hit.time_1ns()) < 2048) {
                l1_s1_time->Fill((int) (ch1_hit.time() & 0xFFFFF) - (int) s1_hit.time_1ns());
                h_l1_s1_time_vs_time->Fill(ch1_hit.ts_header() % (int) 1e6, (int) (ch1_hit.time() & 0xFFFFF) - (int) s1_hit.time_1ns());
                uint32_t ckdivend = 0;
                uint32_t ckdivend2 = 31;
                uint32_t localTime = ch1_hit.time8ns() % (1 << 11);  // local pixel time is first 11 bits of the global time
                uint32_t cur_hitToA = localTime * 8/*ns*/ * (ckdivend + 1);
                uint32_t cur_hitToT = ( ( (0x1F+1) + ch1_hit.tot() -  ( (localTime * (ckdivend+1) / (ckdivend2+1) ) & 0x1F) ) & 0x1F);//  * 8 * (ckdivend2+1) ;
                h_tot_l1_vs_s1->Fill(cur_hitToT, s1_hit.tot());
                if ( timeWalkValid[cur_hitToT] ) {
                    l1_s1_time_corrected->Fill((int) (ch1_hit.time() & 0xFFFFF) - (int) s1_hit.time_1ns() - timeWalkCorrection[cur_hitToT]);
                }
                if (std::abs((int) (ch1_hit.time() & 0xFFFFF) - (int) s1_hit.time_1ns()) < 128) {
                    h_timewalk_l1_vs_time_s1->Fill((int) (ch1_hit.time() & 0xFFFFF) - (int) s1_hit.time_1ns(), cur_hitToT);
                    if ( timeWalkValid[cur_hitToT] ) {
                        double dt = (int)(ch1_hit.time() & 0xFFFFF) - (int)s1_hit.time_1ns();
                        double corrected_dt = dt - timeWalkCorrection[cur_hitToT];
                        h_timewalk_corrected_l1_vs_time_s1->Fill(corrected_dt, cur_hitToT);
                    }
                }
            }
        }
    }

    // create tot correction
    for (int tot = 0; tot < 32; ++tot) {
        auto rootHist =
            h_timewalk_l1_vs_time_s1
                ->asRootObject("myHistogram", "My histogram title");

        int ybin = rootHist.get()->GetYaxis()->FindBin(tot);

        double sum = 0.0;
        double sumw = 0.0;

        for (int xbin = 1; xbin <= rootHist.get()->GetNbinsX(); ++xbin) {

            double n = rootHist.get()->GetBinContent(xbin, ybin);

            if (n <= 0)
                continue;

            double dt = rootHist.get()->GetXaxis()->GetBinCenter(xbin);

            sum  += n * dt;
            sumw += n;
        }

        if (sumw >= 100) {
            timeWalkCorrection[tot] = sum / sumw;
            timeWalkValid[tot] = true;
        }
        else {
            timeWalkValid[tot] = false;
        }
    }

    return flow;

}
