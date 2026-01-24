cmake_minimum_required(VERSION 3.14)
project(hv_fe)
if(NOT TARGET midas::midas)
    find_package(Midas REQUIRED PATHS $ENV{MIDASSYS})
endif()

add_executable(hvBox_quads_fe src/hvBox_quads_fe.cxx)
target_link_libraries(hvBox_quads_fe PRIVATE midas::mfed midas::mscb midas::drivers)

install(TARGETS hvBox_quads_fe DESTINATION bin)
