//

#include "asic_config_base.h"

#include <algorithm>
#include <iomanip>
#include <iostream>
#include <iterator>

#include <cstring>

namespace mudaq {

ASICConfigBase::para_t ASICConfigBase::make_param(std::string name, size_t nbits, bool endianess){
    std::vector<uint8_t> bitorder(nbits);
    if(endianess)
        for(size_t i=0;i<nbits;i++) bitorder[i]=i;
    else
        for(size_t i=0;i<nbits;i++) bitorder[i]=nbits-1-i;
    return std::make_tuple(name,nbits,bitorder);
}

ASICConfigBase::para_t ASICConfigBase::make_param(std::string name, size_t nbits, std::vector<uint8_t> bitorder){
    return std::make_tuple(name,nbits,bitorder);
}

ASICConfigBase::para_t ASICConfigBase::make_param(std::string name, std::string bitorderstring){
    std::istringstream is(bitorderstring);
    std::vector<unsigned int> order_t;
    std::vector<uint8_t> order;
    order_t.assign(std::istream_iterator<unsigned int>( is ), std::istream_iterator<unsigned int>() );

    for (unsigned int i = 0; i < order_t.size(); ++ i) {
        for (unsigned int n = 0; n < order_t.size(); ++n) {
            if (order_t.at(n) == i) {
                order.push_back((uint8_t)n);
            }
        }
    }
    //std::reverse(order.begin(), order.end());
    size_t sizze = (size_t)order.size();
    return std::make_tuple(name,sizze,order);
}

void ASICConfigBase::addPara(const para_t& para, const std::string postfix) {
    paras_offsets[std::get<0>(para)+postfix] = std::make_tuple(length_bits, std::get<1>(para), std::get<2>(para));
//reporting
//    printf("%s\t[%lu:%lu] (",(std::get<0>(para)+postfix).c_str(),length_bits,length_bits+std::get<1>(para));
//    for(size_t i=0;i<std::get<1>(para);i++) printf("%d ",std::get<2>(para)[i]);
//    printf(")\n");
//reporting

    length_bits += std::get<1>(para);
}

ASICConfigBase::ASICConfigBase(){
/*
    //assemble the pattern from the list of parameters. Needs to be done in inherited classes, here only for reference!
    // populate name/offset map
    length_bits = 0;
    // header
    for(const auto& para : parameters_header )
        addPara(para, "");
    for(unsigned int ch = 0; ch < nch; ++ch) {
        for(const auto& para : parameters_ch )
            addPara(para, "_"+std::to_string(ch));
    }
    for(const auto& para : parameters_tdc )
        addPara(para, "");
    //for(const auto& para : parameters_tdc ) addPara(para, "_right");
    for(const auto& para : parameters_footer )
        addPara(para, "");

    // allocate memory for bitpattern
    length = length_bits/8;
    if( length_bits%8 > 0 ) length++;
    length_32bits = length/4;
    if( length%4 > 0 ) length_32bits++;
    bitpattern_r = new uint8_t[length_32bits*4];
    bitpattern_w = new uint8_t[length_32bits*4];
    reset();
*/
}

ASICConfigBase::~ASICConfigBase(){
/*
 *  to be done in the inherited class
    delete[] bitpattern_r;
    delete[] bitpattern_w;
*/
}

int ASICConfigBase::setParameter(std::string name, uint32_t value, bool reverse) {
    auto para = paras_offsets.find(name);
    if( para == paras_offsets.end() ) {
        std::cerr << "Parameter '" << name << "' is not present in mutrig config" << std::endl;
        return 1; // parameter name not present
    }
    size_t offset;
    size_t nbits;
    std::vector<uint8_t> bitorder;
    std::tie(offset, nbits, bitorder) = para->second;
    if( (value >> nbits) != 0 ) {
        std::cerr << "Value '" << value << "' outside of range of " << nbits << " bits for '" << name << "'" << std::endl;
        return 2; // out of range
    }
    //printf("offset=%lu n=%lu\n",offset,nbits);
    uint32_t mask = 0x01;
    for(unsigned int pos = 0; (pos < nbits); pos++, mask <<= 1) {
        unsigned int n = (offset+bitorder.at(nbits-pos-1))%8;
        unsigned int b = (offset+bitorder.at(nbits-pos-1))/8;
        if (reverse) {
            n = (offset + nbits -1 - bitorder.at(pos))%8;
            b = (offset + nbits -1 - bitorder.at(pos))/8;
            //unsigned int b2 = length_bits/8;
            unsigned int b2 = length-1;
            b = b2 -b;
        }
        //printf("b:%3.3u.%1.1u = %u\n",b,n,mask&value);
        if ((mask & value) != 0 ) bitpattern_w[b] |=   1 << n;  // set nth bit
        else                      bitpattern_w[b] &= ~(1 << n); // clear nth bit
    }
    return 0;
}

uint32_t ASICConfigBase::getParameter(std::string name, bool reverse) {
    auto para = paras_offsets.find(name);
    if( para == paras_offsets.end() ) {
        std::cerr << "Parameter '" << name << "' is not present in mutrig config" << std::endl;
        return uint32_t(-1); // parameter name not present
    }
    unsigned int offset;
    size_t nbits;
    std::vector<uint8_t> bitorder;
    std::tie(offset, nbits, bitorder) = para->second;

    uint32_t value = 0;
    for(unsigned int pos = 0; pos < nbits; pos++) {
        unsigned int n = offset+bitorder.at(nbits-pos-1)%8;
        unsigned int b = offset+bitorder.at(nbits-pos-1)/8;
        if (reverse) {
            n = (offset + nbits -1 - bitorder.at(pos))%8;
            b = (offset + nbits -1 - bitorder.at(pos))/8;
            unsigned int b2 = length_bits/8;
            b = b2 -b;
        }
        value += ( ( (bitpattern_r[b] & (1 << n)) != 0 ) << pos);
    }
    return value;
}

int ASICConfigBase::reset(char o) {
    switch(o) {
      case 'r': std::memset(bitpattern_r, 0, length_32bits*4);
                break;
      case 'w': std::memset(bitpattern_w, 0, length_32bits*4);
                break;
      default:  std::memset(bitpattern_r, 0, length_32bits*4);
                std::memset(bitpattern_w, 0, length_32bits*4);
    }
    return 0;
}

std::string ASICConfigBase::getPattern() {
    std::stringstream buffer;
    buffer << *this;
    return buffer.str();
}

int ASICConfigBase::VerifyReadbackPattern(){
    m_verification_error="";
    for(size_t i=0;i<length-1;++i){
        if(bitpattern_w[i]!=bitpattern_r[i]){
        m_verification_error="Write/Read mismatch at byte "+std::to_string(i)+", written value "+std::to_string(bitpattern_w[i])+" vs. "+std::to_string(bitpattern_r[i]);
        return FE_ERR_HW;
    }
    }
    for(size_t i=0;i<length_bits%8;i++){
        if((bitpattern_w[length-1]&(1<<i))!=(bitpattern_r[length-1]&(1<<i))){
        m_verification_error="Write/Read mismatch at last byte ("+std::to_string(i)+"), written value "+std::to_string(bitpattern_w[i])+" vs. "+std::to_string(bitpattern_r[i]);
        return FE_ERR_HW;
    }

    }
    return FE_SUCCESS;
}

std::ostream& operator<<(std::ostream& os, const ASICConfigBase& config) {
    os << " bitpattern: (" << config.length << "/" << config.length_bits << ") 0x" << std::hex;
    os << std::endl<<" write: 0x" << std::hex;
    for( unsigned int i = 0; i < config.length; i++) os << std::setw(2) << std::setfill('0') << ((uint16_t)config.bitpattern_w[config.length - i - 1]); // << " ";// << config.bitpattern_r[i] << " ";
    //os << std::endl;
    os << std::endl<<" read:  0x" << std::hex;
    for( unsigned int i = 0; i < config.length; i++) os << std::setw(2) << std::setfill('0') << ((uint16_t)config.bitpattern_r[config.length - i - 1]);
    os << std::endl;
    os << std::dec;
    //std::cout << "bitpattern write: 0x" << std::hex << std::setw(2) << std::setfill('0') << config.bitpattern_w[0] << std::endl;
    return os;
}


} // namespace mudaq
