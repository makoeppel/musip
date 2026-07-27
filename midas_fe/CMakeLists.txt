#

add_subdirectory(libmudaq)
add_subdirectory(power)
add_subdirectory(hv_control)

add_executable(quads_config_fe quads_config_fe.cpp)
add_executable(readout_fe readout_fe.cpp)

target_link_libraries(quads_config_fe libmudaq midas::mfed)
target_link_libraries(readout_fe libmudaq midas::mfed)

install(TARGETS quads_config_fe readout_fe DESTINATION bin)
