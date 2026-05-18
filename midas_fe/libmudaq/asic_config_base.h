/*
 * Generic ASIC configration class for the mudaq environment - to be used in libmupix (MupixConfig,MupixBoardConfig) and libMutrig (MutrigConfig).
 * Bitpattern assembly based on parameter lists and generic setters/getters - this needs to be defined in the inherited classes
 * Created by K. Briggl mostly based on code from S. Corrodi
 * Nov 2019
 * */

#ifndef ASIC_CONFIG_BASE_H
#define ASIC_CONFIG_BASE_H

#include "midas.h" // for return types

#include <map>
#include <sstream>
#include <string>
#include <tuple>
#include <vector>

namespace mudaq {

class ASICConfigBase {
public:
    ASICConfigBase();
    ~ASICConfigBase();

    size_t length_bits;      ///< length of bitpattern in bits
    size_t length;           ///< length of bitpattern in full bytes
    size_t length_32bits;    ///< length of bitpattern in 32bit words


    /**
     * set parameter in write bitpattern by name
     * return 0 if success
     */
    int setParameter(std::string name, uint32_t value, bool reverse = false);

    /**
     * get parameter from read bitpattern
     */
    uint32_t getParameter(std::string, bool reverse = false);

    /**
     * resets bitpattern
     * input r:
     */
    int reset(char o = 'b');

    /**
     * debug function to get the current pattern as string
     */
    std::string getPattern();
    //check if readback pattern matches written pattern
    //return SUCCESS when written and read back patterns match, FAILURE otherwise
    int VerifyReadbackPattern();
    //Get error message giving bitpattern verification error informations.
    //Valid after calling VerifyReadbackPattern()
    std::string GetVerificationError(){ return m_verification_error; };

    friend std::ostream& operator<<(std::ostream& os, const ASICConfigBase& config);

    uint8_t * bitpattern_r; ///< bitpattern to be written
    uint8_t * bitpattern_w; ///< readback bitpattern

protected:
    typedef std::tuple<unsigned int, size_t, std::vector<uint8_t>> para_offset_t;   ///< mutrig parameter offset/nbits/endianess pair (offset, endianess)
    typedef std::map<std::string, para_offset_t> paras_offset_t;    ///< mutrig parameters offset/nbits/endianess map
    paras_offset_t paras_offsets;                                   ///< initialized from parameters on construction
    //error message giving bitpattern verification error informations. Valid after calling VerifyReadbackPattern()
    std::string m_verification_error;

public:
    /**
     * ASIC parameters (name, number of bits, endianess)
     */
    typedef std::tuple<std::string, size_t, std::vector<uint8_t>> para_t;     ///< mutrig parameter (name, number of bits, bit order)
    //param from name,size,endianess
    static para_t make_param(std::string, size_t, bool);
    //param from name,size,bitorder-list
    static para_t make_param(std::string, size_t, std::vector<uint8_t>);
    //param from name,bitorder-string
    static para_t make_param(std::string, std::string);

    typedef std::vector<para_t> paras_t;                      ///< mutrig parameter in correct order (starting at bit offset 0)

    const paras_offset_t& getParameters() const { return paras_offsets; }

protected:
    void addPara(const para_t&, const std::string);
};

}// namespace mudaq

#endif // ASIC_CONFIG_BASE_H
