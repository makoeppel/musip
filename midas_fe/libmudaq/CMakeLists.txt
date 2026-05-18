#

add_library(libmudaq STATIC
    mudaq_device.cpp
    FEBSlowcontrolInterface.cpp
    DummyFEBSlowcontrolInterface.cpp
    Mutrig3Config.cpp
    asic_config_base.cpp
    ../registers.h
)
target_include_directories(libmudaq PUBLIC
    .
)
target_link_libraries(libmudaq PUBLIC midas::midas)
