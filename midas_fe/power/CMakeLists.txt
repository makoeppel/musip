#

add_executable(power
    power_testbench.cpp
    GenesysDriver.cpp
    Keithley2611BDriver.cpp Keithley2612ADriver.cpp
    Keithley2400Driver.cpp Keithley2450Driver.cpp
    Keithley6487Driver.cpp
    BaseClient.cpp TCPClient.cpp SerialClient.cpp
    HMP4040Driver.cpp PowerDriver.cpp
)
target_link_libraries(power midas::mfed midas::drivers midas::mscb Boost::headers)

install(TARGETS power DESTINATION bin)
