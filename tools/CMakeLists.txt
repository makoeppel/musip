#
# Configuration for the DQM components.
#
set(musip_dqm_headers
    include/musip/TDACFile.hpp
    include/musip/HitmapFile.hpp
    include/musip/dqm/dqmfwd.hpp
    include/musip/dqm/detail.hpp
    include/musip/dqm/DQMManager.hpp
    include/musip/dqm/PlotSource.hpp
    include/musip/dqm/Metadata.hpp
    include/musip/dqm/PlotCollection.hpp
    include/musip/dqm/BasicHistogram1D.hpp
    include/musip/dqm/BasicHistogram2D.hpp
    include/musip/dqm/BasicRollingHistogram2D.hpp
    include/musip/dqm/HistogramEncoder.hpp
)

set(musip_dqm_sources
    src/TDACFile.cpp
    src/HitmapFile.cpp
    src/DQMManager.cpp
    src/Metadata.cpp
    src/PlotCollection.cpp
    src/HistogramEncoder.cpp
)

add_library(minalyzerdqm OBJECT ${musip_dqm_sources} ${musip_dqm_headers})
target_include_directories(minalyzerdqm PUBLIC include ${ROOT_INCLUDE_DIRS})
target_link_libraries(minalyzerdqm PUBLIC midas::midas Boost::headers)
target_link_libraries(minalyzerdqm PRIVATE ROOT::Core ROOT::Hist)

#
# Add the proxy server. This listens for histogram requests and forwards on to multiple
# instances of DQM clients. When results are returned, they're added up into a single histogram
# and returned to the original caller.
#
add_executable(dqmproxy src/dqmproxy_main.cpp)
target_link_libraries(dqmproxy PRIVATE minalyzerdqm)

#
# Add the plot server. This just listens for requests for plots like minalyzer does, serving old
# runs from root files. But it doesn't read any new data or do anything with the midas data stream
# so never fills new plots.
#
add_executable(plotserver src/plotserver_main.cpp)
target_link_libraries(plotserver PRIVATE minalyzerdqm)

#
# A little command line tool for writing simple TDAC files (all on, all off etc).
#
add_executable(writetdacs src/writetdacs.cpp src/TDACFile.cpp)
target_include_directories(writetdacs PUBLIC include)
