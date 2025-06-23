
/**
 * utility functions / macros / definitions
 *
 * @author      Moritz Kiehn <kiehn@physi.uni-heidelberg.de>
 * @author      Lennart Huth <huth@physi.uni-heidelberg.de>
 * @date        date
 * @copyright   "THE BEER-WARE LICENSE" (Revision 42)
 *              I wrote this file. As long as you retain this notice you can
 *              do whatever you want with this stuff. If we meet some day,
 *              and you think this stuff is worth it, you can buy me a beer
 *              in return. Moritz Kiehn
 */

#ifndef UTILITY_HPP_
#define UTILITY_HPP_

#include <boost/format.hpp>

#include <iostream>
#include <sstream>
#include <vector>

/**
 * recursive boost::format evalatuation w/ variadic parameters
 *
 * based on [https://stackoverflow.com/questions/18347957/a-convenient-logging-statement-for-c-using-boostformat].
 */
inline boost::format& eval_format(boost::format& fmt)
{
    return fmt;
}
template <typename T, typename... Params>
inline boost::format& eval_format(boost::format& fmt, T arg, Params... parameters)
{
    return eval_format(fmt % arg, parameters...);
}
template <typename... Params>
inline std::string eval_str(const std::string& str, Params... parameters)
{
    boost::format fmt(str);
    return eval_format(fmt, parameters...).str();
}

/**
 * logging functions using iostreams and boost::format
 */

inline void ERROR(std::string msg)
{
    std::cerr << "ERROR: " << msg << std::endl;
}
template <typename... Params>
inline void ERROR(std::string msg, Params... parameters)
{
    std::cerr << "ERROR: " << eval_str(msg, parameters...) << std::endl;
}

inline void DEBUG(std::string msg)
{
    std::cout << "DEBUG: " << msg << std::endl;
}
template <typename... Params>
inline void DEBUG(std::string msg, Params... parameters)
{
    std::cout << "DEBUG: " << eval_str(msg, parameters...) << std::endl;
}

/**
 * encoding / decoding of a 8 bit binary reflected graycode
 *
 * from [http://en.wikipedia.org/wiki/Gray_code]
 */

inline uint8_t graycode_decode(uint8_t gray)
{
    uint8_t mask;
    for (mask = gray >> 1; mask != 0; mask = mask >> 1) {
        gray = gray ^ mask;
    }
    return gray;
}
inline uint8_t graycode_encode(uint8_t binary)
{
    return (binary >> 1) ^ binary;
}




/**
 * @brief fileCheck
 * @param string name
 * @return true if file is existing, false else
 *
 * taken from stackoverflow.com
 */
inline bool fileCheck (const std::string& name) {
    if (FILE *file = fopen(name.c_str(), "r")) {
        std::cout<<"Checking file: " << name.c_str() << std::endl;
        fclose(file);
        return true;
    } else {
        return false;
    }
}


template <typename T>
std::vector<T> convert_to_vec(T t,std::string & s, std::string & seperator)
{
    std::stringstream stream(s);
    T value;
    std::vector<T> v;
    while(stream >> value)
    {
        v.push_back(value);
        std::string tmp;
        stream >> tmp;
        if(tmp!=seperator)
        {
            std::cout << "STRING CONVERSION ERROR!\t" << tmp << std::endl;

        }
    }
    return v;

}

template <typename T>
inline void convert_to_string(std::string & s, std::vector<T> const & v, std::string & seperator)
{
    std::stringstream stream;
    for(auto tmp : v)
        stream << tmp << seperator;
    s=stream.str();

}



#endif /* __UTILITY_HPP_UB6F0M92__ */
