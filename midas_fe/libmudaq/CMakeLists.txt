#

add_library(libmudaq STATIC
    mudaq_device.cpp
    FEBSlowcontrolInterface.cpp
    ../registers.h
)
target_include_directories(libmudaq PUBLIC
    .
)
target_link_libraries(libmudaq PUBLIC midas::midas)
