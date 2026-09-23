cmake_minimum_required(VERSION 3.14)
project(hv_fe)
if(NOT TARGET midas::midas)
    find_package(Midas REQUIRED PATHS $ENV{MIDASSYS})
endif()

add_executable(hv_fe
    src/hv_fe.cxx
    src/mdev_hv4.cxx
    src/mdev_tti_ql564p.cxx
)
target_link_libraries(hv_fe PRIVATE midas::mfed midas::mscb midas::drivers)

#add_executable(hvBox_quads_fe src/hvBox_quads_fe.cxx)
#target_link_libraries(hvBox_quads_fe PRIVATE midas::mfed midas::mscb midas::drivers)

install(TARGETS hv_fe DESTINATION bin)
