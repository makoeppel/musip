#ifndef MUTRIG3_CONFIG_H
#define MUTRIG3_CONFIG_H

#include <string>
#include <tuple>
#include <map>
#include <vector>
#include <sstream>
#include "asic_config_base.h"
#include "odbxx.h"
#include "midas.h"  //for return types

using midas::odb;


namespace mutrig {

class Mutrig3Config:public mudaq::ASICConfigBase {
public:
    Mutrig3Config();
    ~Mutrig3Config();

    /**
     * Functions to parse MIDAS structs to MuTRiG patterns
     */
    void MapConfigFromDB(odb& settings_asics, int asic);
    void Parse_GLOBAL_from_struct(odb& o);
    void Parse_TDC_from_struct(odb& o);
    void Parse_TDC_from_struct(odb& o, int tdc);
    void Parse_CH_from_struct(odb& o, int tdc, int channel);
    void setASICParameterODBpp(std::string paraName, odb& o, int num);
    void setParameterODBpp(std::string paraName, odb& o);
    void setCHParameterODBpp(std::string paraName, odb& o, int channel, int gchannel);
 

//ODB stubs for setting up database
    static odb MUTRIG_TDC_SETTINGS;
    static odb MUTRIG_GLOBAL_SETTINGS;
    static odb MUTRIG_CH_SETTINGS;

private:
    static paras_t parameters_ch;                             ///< static which stores the parameters for each channel (name, nbits, endian)
    static paras_t parameters_tdc;                            ///< static which stores the parameters for the tdcs (name, nbits, endian)
    static paras_t parameters_header;                         ///< static which stores the parameters for the header (name, nbits, endian)
    static paras_t parameters_footer;                         ///< static which stores the parameters for the footer (name, nbits, endian)
    static constexpr uint32_t NMUTRIGCHANNELS = 32;           ///< static which stores the number of channels per asic
};

}// namespace mutrig

#endif // MUTRIG3_CONFIG_H
