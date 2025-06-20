#pragma once

#include <cinttypes>

namespace musip::dqm {

template<typename xaxis_type, typename content_type> class BasicHistogram1D;
template<typename xaxis_type, typename yaxis_type, typename content_type> class BasicHistogram2D;
template<typename xaxis_type, typename yaxis_type, typename content_type> class BasicRollingHistogram2D;

using Histogram1DF = BasicHistogram1D<float,float>;
using Histogram1DD = BasicHistogram1D<double,double>;
using Histogram1DI = BasicHistogram1D<float,uint32_t>;
using Histogram2DF = BasicHistogram2D<float,float,float>;
using Histogram2DD = BasicHistogram2D<double,double,double>;
using Histogram2DI = BasicHistogram2D<float,float,uint32_t>;
using RollingHistogram2DF = BasicRollingHistogram2D<float,float,float>;

class PlotCollection;
class DQMManager;

enum class Lock { PerformLock, AlreadyLocked };

} // end of namespace musip::dqm
