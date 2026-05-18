#include <cstring>
#include <iostream>
#include <iomanip>

#include "Mutrig3Config.h"
#include "odbxx.h"

using midas::odb;

namespace mutrig {


odb Mutrig3Config::MUTRIG_TDC_SETTINGS = {
//    {"vnpfc", std::array<uint16_t, 2>()},
//    {"vnpfc_offset", std::array<uint16_t, 2>()},
//    {"vnpfc_scale", std::array<bool, 2>()},
//    {"vncnt", std::array<uint16_t, 2>()},
//    {"vncnt_offset", std::array<uint16_t, 2>()},
//    {"vncnt_scale", std::array<bool, 2>()},
//    {"vnvcobuffer", std::array<uint16_t, 2>()},
//    {"vnvcobuffer_offset", std::array<uint16_t, 2>()},
//    {"vnvcobuffer_scale", std::array<bool, 2>()},
//    {"vnd2c", std::array<uint16_t, 2>()},
//    {"vnd2c_offset", std::array<uint16_t, 2>()},
//    {"vnd2c_scale", std::array<bool, 2>()},
//    {"vnpcp", std::array<uint16_t, 2>()},
//    {"vnpcp_offset", std::array<uint16_t, 2>()},
//    {"vnpcp_scale", std::array<bool, 2>()},
//    {"vnhitlogic", std::array<uint16_t, 2>()},
//    {"vnhitlogic_offset", std::array<uint16_t, 2>()},
//    {"vnhitlogic_scale", std::array<bool, 2>()},
//    {"vncntbuffer", std::array<uint16_t, 2>()},
//    {"vncntbuffer_offset", std::array<uint16_t, 2>()},
//    {"vncntbuffer_scale", std::array<bool, 2>()},
//    {"vnvcodelay", std::array<uint16_t, 2>()},
//    {"vnvcodelay_offset", std::array<uint16_t, 2>()},
//    {"vnvcodelay_scale", std::array<bool, 2>()},
//    {"latchbias", std::array<uint16_t, 2>()},
//    {"ms_limits", std::array<uint16_t, 2>()},
//    {"ms_switch_sel", std::array<bool, 2>()},
//    {"amon_en", std::array<bool, 2>()},
//    {"amon_dac", std::array<uint16_t, 2>()},
//    {"dmon_select", std::array<int16_t, 2>()}, //MT: New (channel wise before). Combine with enable flag ; disable when <
//    {"dmon_sw", std::array<bool, 2>()}, //MT: New (channel wise before)
//    {"dmon_1_en", std::array<bool, 2>()},
//    {"dmon_1_dac", std::array<uint16_t, 2>()},
//    {"dmon_2_en", std::array<bool, 2>()},
//    {"dmon_2_dac", std::array<uint16_t, 2>()},
//    {"lvds_tx_vcm", std::array<uint16_t, 2>()},
//    {"lvds_tx_bias", std::array<uint16_t, 2>()},
//    {"coin_xbar_lower_rx_ena", std::array<bool, 2>()},
//    {"coin_xbar_lower_tx_ena", std::array<bool, 2>()},
//    {"coin_xbar_lower_tx_vdac", std::array<uint16_t, 2>()},
//    {"coin_xbar_lower_tx_idac", std::array<uint16_t, 2>()},
//    {"coin_mat_xbl", std::array<uint16_t, 2>()},
//    {"coin_mat_xbu", std::array<uint16_t, 2>()},
//    {"coin_xbar_upper_rx_ena", std::array<bool, 2>()},
//    {"coin_xbar_upper_tx_ena", std::array<bool, 2>()},
//    {"coin_xbar_upper_tx_vdac", std::array<uint16_t, 2>()},
//    {"coin_xbar_upper_tx_idac", std::array<uint16_t, 2>()},
//    {"coin_wnd", std::array<uint16_t, 2>()},
    {"vnpfc", 8},
    {"vnpfc_offset", 3},
    {"vnpfc_scale", false},
    {"vncnt", 40},
    {"vncnt_offset", 3},
    {"vncnt_scale", false},
    {"vnvcobuffer", 0},
    {"vnvcobuffer_offset", 0},
    {"vnvcobuffer_scale", false},
    {"vnd2c", 31},
    {"vnd2c_offset", 3},
    {"vnd2c_scale", false},
    {"vnpcp", 24},
    {"vnpcp_offset", 3},
    {"vnpcp_scale", false},
    {"vnhitlogic", 24},
    {"vnhitlogic_offset", 3},
    {"vnhitlogic_scale", false},
    {"vncntbuffer", 7},
    {"vncntbuffer_offset", 3},
    {"vncntbuffer_scale", false},
    {"vnvcodelay", 22},
    {"vnvcodelay_offset", 3},
    {"vnvcodelay_scale", false},
    {"latchbias", 1800},
    {"ms_limits", 0},
    {"ms_switch_sel", false},
    {"amon_en", true},
    {"amon_dac", 63},
    {"dmon_select", -1}, //MT3: New (channel wise before). Combine with enable flag ; disable when <0
    {"dmon_sw", true}, //MT3: New (channel wise before)
    {"dmon_1_en", true},
    {"dmon_1_dac", 31},
    {"dmon_2_en", false},
    {"dmon_2_dac", 5},
    {"lvds_tx_vcm", 160},
    {"lvds_tx_bias", 1},
    {"coin_xbar_lower_rx_ena", false},
    {"coin_xbar_lower_tx_ena", false},
    {"coin_xbar_lower_tx_vdac", 0},
    {"coin_xbar_lower_tx_idac", 0},
    {"coin_mat_xbl", 0},
    {"coin_mat_xbu", 0},
    {"coin_xbar_upper_rx_ena", false},
    {"coin_xbar_upper_tx_ena", false},
    {"coin_xbar_upper_tx_vdac", 0},
    {"coin_xbar_upper_tx_idac", 0},
    {"coin_wnd", 0},

};

odb Mutrig3Config::MUTRIG_GLOBAL_SETTINGS = {
    {"ext_trig_mode", false},
    {"ext_trig_endtime_sign", false},
    {"ext_trig_offset", 8},
    {"ext_trig_endtime", 8},
    {"gen_idle", true},
    {"ms_debug", false},
    {"tx_mode",0},
/* removed in mutrig3 / replaced by tx_mode
    {"prbs_debug", false},
    {"prbs_single", false},
*/
    {"sync_ch_rst", true},
    {"disable_coarse", false},
    {"pll_setcoarse", false},
    {"pll_envomonitor", false},
    {"pll_lol_dbg", false},
    {"en_ch_evt_cnt", false},
};

odb Mutrig3Config::MUTRIG_CH_SETTINGS = {
//    {"mask",std::array<bool, 2>()},
//    {"recv_all",std::array<bool, 2>()},
//    {"tthresh", std::array<uint16_t, 2>()},
//    {"tthresh_sc", std::array<uint16_t, 2>()},
//    {"tthresh_offset", std::array<uint16_t, 2>()},
//    {"ethresh", std::array<uint16_t, 2>()},
//    {"ebias", std::array<uint16_t, 2>()},
//    {"sipm", std::array<uint16_t, 2>()},
//    {"inputbias", std::array<uint16_t, 2>()},
//    {"pole", std::array<uint16_t, 2>()},
//    {"pole_sc", std::array<uint16_t, 2>()},
//    {"ampcom", std::array<uint16_t, 2>()},
//    {"ampcom_sc", std::array<uint16_t, 2>()},
//    {"cml", std::array<uint16_t, 2>()},
//    {"cml_sc", std::array<uint16_t, 2>()},
//    {"amonctrl", std::array<uint16_t, 2>()},
//    {"comp_spi", std::array<uint16_t, 2>()},
//    {"coin_mat", std::array<uint16_t, 2>()},
//    {"tdctest_n",std::array<bool, 2>()},
//    {"sswitch",std::array<bool, 2>()},
//    {"delay",std::array<bool, 2>()},
//    {"pole_en_n",std::array<bool, 2>()},
//    {"energy_c_en",std::array<bool, 2>()},
//    {"energy_r_en",std::array<bool, 2>()},
//    {"cm_sensing_high_r",std::array<bool, 2>()},
//    {"amon_en_n",std::array<bool, 2>()},
//    {"edge",std::array<bool, 2>()},
//    {"edge_cml",std::array<bool, 2>()},
    {"mask", true},
    {"recv_all", false},
    {"tthresh", 0},
    {"tthresh_sc", 0},
    {"tthresh_offset", 0},
    {"ethresh", 0},
    {"ebias", 3},
    {"sipm", 32},
    {"inputbias", 4},
    {"pole", 15},
    {"pole_sc", 0},
    {"ampcom", 20},
    {"ampcom_sc", 2},
    {"cml", 0},
    {"cml_sc", 1},
    {"amonctrl", 0},
    {"comp_spi", 2},
    {"coin_mat", 0},
    {"tdctest_n", false},
    {"sswitch", true},
    {"delay", true},
    {"pole_en_n", false},
    {"energy_c_en", false},
    {"energy_r_en", false},
    {"cm_sensing_high_r", false},
    {"amon_en_n", true},
    {"edge", true},
    {"edge_cml", true},
};


Mutrig3Config::paras_t Mutrig3Config::parameters_tdc = {
        make_param("vnd2c_scale",        1, 1),
        make_param("vnd2c_offset",       2, 1),
        make_param("vnd2c",              6, 1),
        make_param("vncntbuffer_scale",  1, 1),
        make_param("vncntbuffer_offset", 2, 1),
        make_param("vncntbuffer",        6, 1),
        make_param("vncnt_scale",        1, 1),
        make_param("vncnt_offset",       2, 1),
        make_param("vncnt",              6, 1),
        make_param("vnpcp_scale",        1, 1),
        make_param("vnpcp_offset",       2, 1),
        make_param("vnpcp",              6, 1),
        make_param("vnvcodelay_scale",   1, 1),
        make_param("vnvcodelay_offset",  2, 1),
        make_param("vnvcodelay",         6, 1),
        make_param("vnvcobuffer_scale",  1, 1),
        make_param("vnvcobuffer_offset", 2, 1),
        make_param("vnvcobuffer",        6, 1),
        make_param("vnhitlogic_scale",   1, 1),
        make_param("vnhitlogic_offset",  2, 1),
        make_param("vnhitlogic",         6, 1),
        make_param("vnpfc_scale",        1, 1),
        make_param("vnpfc_offset",       2, 1),
        make_param("vnpfc",              6, 1),
        make_param("latchbias",          12, 0)
    };

Mutrig3Config::paras_t Mutrig3Config::parameters_ch = {
        make_param("energy_c_en",       1, 1), //old name: anode_flag
        make_param("energy_r_en",       1, 1), //old name: cathode_flag
        make_param("sswitch",           1, 1),
        make_param("cm_sensing_high_r", 1, 1), //old name: SorD; should be always '0'
        make_param("amon_en_n",         1, 1), //old name: SorD_not; 0: enable amon in the channel
        make_param("edge",              1, 1),
        make_param("edge_cml",          1, 1),
        make_param("cml_sc",            1, 1),
        //make_param("dmon_en",           1, 1),
        //make_param("dmon_sw",           1, 1),
        make_param("tdctest_n",         1, 1),
        make_param("amonctrl",          3, 1),
        make_param("comp_spi",          2, 1),
        make_param("tthresh_offset_1",  1, 1), //was sipm_sc. MT3: Repurposed
        make_param("sipm",              6, 1),
        make_param("tthresh_offset_2",  1, 1), //was part of tthreshold scale. MT3: Repurposed
        make_param("tthresh_sc",        2, 1), //was 3 bits long. MT3: Repurposed
        make_param("tthresh",           6, 1),
        make_param("ampcom_sc",         2, 1),
        make_param("ampcom",            6, 1),
        make_param("tthresh_offset_0",  1, 1), //was inputbias_sc. MT3: Repurposed
        make_param("inputbias",         6, 1),
        make_param("ethresh",           8, 1),
        make_param("ebias",             3, 1),
        make_param("pole_sc",           1, 1),
        make_param("pole",              6, 1),
        make_param("cml",               4, 1),
        make_param("delay",             1, 1),
        make_param("pole_en_n",         1, 1), //old name: dac_delay_bit1; 0: DAC_pole on
        make_param("mask",              1, 1),
        make_param("recv_all",          1, 1) //new in mutrig2
     };

Mutrig3Config::paras_t Mutrig3Config::parameters_header = {
        make_param("gen_idle",              1, 1),
        make_param("sync_ch_rst",           1, 1), // mutrig2: was recv_all, now setting to enable on-chip reset synchronizer
        make_param("ext_trig_mode",         1, 1), // new
        make_param("ext_trig_endtime_sign", 1, 1), // sign of the external trigger matching window, 1: end time is after the trigger; 0: end time is before the trigger
        make_param("ext_trig_offset",       4, 0), // offset of the external trigger matching window
        make_param("ext_trig_endtime",      4, 0), // end time of external trigger matching window
        make_param("ms_limits",             5, 0),
        make_param("ms_switch_sel",         1, 1),
        make_param("ms_debug",              1, 1),
        make_param("tx_mode",               3, 0), //MT3: combine flags to get more options
        make_param("pll_setcoarse",         1, 1),
        make_param("pll_envomonitor",       1, 1),
        make_param("disable_coarse",        1, 1),
        make_param("pll_lol_dbg",           1, 1),
        make_param("en_ch_evt_cnt",         1, 1),
        make_param("dmon_sel",              5, 1),
        make_param("dmon_sel_enable",       1, 1),
        make_param("dmon_sw",               1, 1)
    };

Mutrig3Config::paras_t Mutrig3Config::parameters_footer = {
//coincidence logic crossbar / lower
        make_param("coin_xbar_lower_rx_ena",  1, 1),
        make_param("coin_xbar_lower_tx_ena",  1, 1),
        make_param("coin_xbar_lower_tx_vdac", 8, 1),
        make_param("coin_xbar_lower_tx_idac", 6, 1),
//coincidence logic matrix
        make_param("coin_mat_xbl", 3, 1),
        make_param("coin_mat_0", 6, 1),
        make_param("coin_mat_1", 6, 1),
        make_param("coin_mat_2", 6, 1),
        make_param("coin_mat_3", 6, 1),
        make_param("coin_mat_4", 6, 1),
        make_param("coin_mat_5", 6, 1),
        make_param("coin_mat_6", 6, 1),
        make_param("coin_mat_7", 6, 1),
        make_param("coin_mat_8", 6, 1),
        make_param("coin_mat_9", 6, 1),
        make_param("coin_mat_10", 6, 1),
        make_param("coin_mat_11", 6, 1),
        make_param("coin_mat_12", 6, 1),
        make_param("coin_mat_13", 6, 1),
        make_param("coin_mat_14", 6, 1),
        make_param("coin_mat_15", 6, 1),
        make_param("coin_mat_16", 6, 1),
        make_param("coin_mat_17", 6, 1),
        make_param("coin_mat_18", 6, 1),
        make_param("coin_mat_19", 6, 1),
        make_param("coin_mat_20", 6, 1),
        make_param("coin_mat_21", 6, 1),
        make_param("coin_mat_22", 6, 1),
        make_param("coin_mat_23", 6, 1),
        make_param("coin_mat_24", 6, 1),
        make_param("coin_mat_25", 6, 1),
        make_param("coin_mat_26", 6, 1),
        make_param("coin_mat_27", 6, 1),
        make_param("coin_mat_28", 6, 1),
        make_param("coin_mat_29", 6, 1),
        make_param("coin_mat_30", 6, 1),
        make_param("coin_mat_31", 6, 1),
        make_param("coin_mat_xbu", 3, 1),
//coincidence logic crossbar / upper
        make_param("coin_xbar_upper_rx_ena",  1, 1),
        make_param("coin_xbar_upper_tx_ena",  1, 1),
        make_param("coin_xbar_upper_tx_vdac", 8, 1),
        make_param("coin_xbar_upper_tx_idac", 6, 1),

        make_param("coin_wnd",      1, 1),

        make_param("amon_en",       1, 1),
        make_param("amon_dac",      8, 1),
        make_param("dmon_1_en",     1, 1),
        make_param("dmon_1_dac",    8, 1),
        make_param("dmon_2_en",     1, 1),
        make_param("dmon_2_dac",    8, 1),
        make_param("lvds_tx_vcm",   8, 1), // new
        make_param("lvds_tx_bias",  6, 1)  // new
    };


Mutrig3Config::Mutrig3Config() {
    // populate name/offset map

    length_bits = 0;
    // header
    for(const auto& para : parameters_header )
        addPara(para, "");
    for(unsigned int ch = 0; ch < NMUTRIGCHANNELS; ++ch) {
        for(const auto& para : parameters_ch )
            addPara(para, "_"+std::to_string(ch));
    }
    for(const auto& para : parameters_tdc )
        addPara(para, "");
    for(const auto& para : parameters_footer )
        addPara(para, "");

    if(length_bits != 2662) {
        cm_msg(MERROR,"MutrigConfig","Bitpattern is not the correct size : %ld", length_bits);
    }
    // allocate memory for bitpattern
    length = length_bits/8;
    if( length_bits%8 > 0 ) length++;
    length_32bits = length/4;
    if( length%4 > 0 ) length_32bits++;
    bitpattern_r = new uint8_t[length_32bits*4];
    bitpattern_w = new uint8_t[length_32bits*4];
    reset();
}

Mutrig3Config::~Mutrig3Config() {
    delete[] bitpattern_r;
    delete[] bitpattern_w;
}

//JK: Doing a rewrite here

void Mutrig3Config::setParameterODBpp(std::string paraName, odb& o){
    setParameter(paraName, o[paraName]);
}

void Mutrig3Config::setASICParameterODBpp(std::string paraName, odb& o, int num){
    setParameter(paraName, o[paraName][num]);
}

void Mutrig3Config::setCHParameterODBpp(std::string paraName, odb& o, int channel, int gchannel){
    setParameter(paraName + "_" + std::to_string(channel) , o[paraName][gchannel]);
}



void Mutrig3Config::Parse_GLOBAL_from_struct(odb& o){
    //hard coded in order to avoid macro magic
//    setParameter("", mt_g.n_asics);
//    setParameter("", mt_g.n_channels);
    Mutrig3Config::setParameterODBpp("ext_trig_mode", o);
    Mutrig3Config::setParameterODBpp("ext_trig_endtime_sign", o);
    Mutrig3Config::setParameterODBpp("ext_trig_offset", o);
    Mutrig3Config::setParameterODBpp("ext_trig_endtime", o);
    Mutrig3Config::setParameterODBpp("gen_idle", o);
    Mutrig3Config::setParameterODBpp("ms_debug", o);
    Mutrig3Config::setParameterODBpp("tx_mode", o);
    Mutrig3Config::setParameterODBpp("sync_ch_rst", o);
    Mutrig3Config::setParameterODBpp("disable_coarse", o);
    Mutrig3Config::setParameterODBpp("pll_setcoarse", o);
    Mutrig3Config::setParameterODBpp("pll_envomonitor", o);
}

void Mutrig3Config::Parse_TDC_from_struct(odb& o, int tdc){
    Mutrig3Config::setASICParameterODBpp("vnpfc", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnpfc_offset", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnpfc_scale", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vncnt", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vncnt_offset", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vncnt_scale", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnvcobuffer", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnvcobuffer_offset", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnvcobuffer_scale", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnd2c", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnd2c_offset", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnd2c_scale", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnpcp", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnpcp_offset", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnpcp_scale", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnhitlogic", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnhitlogic_offset", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnhitlogic_scale", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vncntbuffer", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vncntbuffer_offset", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vncntbuffer_scale", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnvcodelay", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnvcodelay_offset", o, tdc);
    Mutrig3Config::setASICParameterODBpp("vnvcodelay_scale", o, tdc);
    Mutrig3Config::setASICParameterODBpp("latchbias", o, tdc);
    Mutrig3Config::setASICParameterODBpp("ms_limits", o, tdc);
    Mutrig3Config::setASICParameterODBpp("ms_switch_sel", o, tdc);
    Mutrig3Config::setASICParameterODBpp("amon_en", o, tdc);
    Mutrig3Config::setASICParameterODBpp("amon_dac", o, tdc);
    Mutrig3Config::setASICParameterODBpp("dmon_sw", o, tdc);
    Mutrig3Config::setASICParameterODBpp("dmon_1_en", o, tdc);
    Mutrig3Config::setASICParameterODBpp("dmon_1_dac", o, tdc);
    Mutrig3Config::setASICParameterODBpp("dmon_2_en", o, tdc);
    Mutrig3Config::setASICParameterODBpp("dmon_2_dac", o, tdc);
    Mutrig3Config::setASICParameterODBpp("lvds_tx_vcm", o, tdc);
    Mutrig3Config::setASICParameterODBpp("lvds_tx_bias", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_xbar_lower_rx_ena", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_xbar_lower_tx_ena", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_xbar_lower_tx_vdac", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_xbar_lower_tx_idac", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_xbar_upper_rx_ena", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_xbar_upper_tx_ena", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_xbar_upper_tx_vdac", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_xbar_upper_tx_idac", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_mat_xbl", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_mat_xbu", o, tdc);
    Mutrig3Config::setASICParameterODBpp("coin_wnd", o, tdc);
    //special assignments
    int dmon_select = o["dmon_select"][tdc];
    bool dmon_enable = (dmon_select >0);
    Mutrig3Config::setParameter("dmon_sel_enable", dmon_enable);
    Mutrig3Config::setParameter("dmon_sel", (dmon_select & 0x1f));

}

void Mutrig3Config::Parse_CH_from_struct(odb& o, int tdc, int channel){
    auto gchannel = tdc * 32 + channel;
    Mutrig3Config::setCHParameterODBpp("mask", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("recv_all", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("tthresh", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("tthresh_sc", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("ethresh", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("ebias", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("sipm", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("inputbias", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("pole", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("pole_sc", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("ampcom", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("ampcom_sc", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("cml", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("cml_sc", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("amonctrl", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("comp_spi", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("tdctest_n", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("sswitch", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("delay", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("pole_en_n", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("energy_c_en", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("energy_r_en", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("cm_sensing_high_r", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("amon_en_n", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("edge", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("edge_cml", o, channel, gchannel);
    Mutrig3Config::setCHParameterODBpp("coin_mat", o, channel, gchannel);
//special assignments
    uint8_t tthresh_offset=o["tthresh_offset"][gchannel];
    setParameter("tthresh_offset_2_" + std::to_string(channel), (tthresh_offset>>0)&1);
    setParameter("tthresh_offset_1_" + std::to_string(channel), (tthresh_offset>>1)&1);
    setParameter("tthresh_offset_0_" + std::to_string(channel), (tthresh_offset>>2)&1);
}

void Mutrig3Config::MapConfigFromDB(odb& settings_asics, int asic) {
    reset();
    // get global asic settings from odb;
    Parse_GLOBAL_from_struct(settings_asics["Global"]);

    // get tdcs asic settings from odb
    std::string path ="TDCs/";//+std::to_string(asic); This belongs to the previous ODB structure
    Parse_TDC_from_struct(settings_asics[path], asic);

    // get channels asic settings from odb
    for(unsigned int ch = 0; ch < NMUTRIGCHANNELS; ch++) {
        std::string path2 ="Channels/";
        //this is still the local channel
        Parse_CH_from_struct(settings_asics[path2], asic, ch);
    }
}

} // namespace mutrig
