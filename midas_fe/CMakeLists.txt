#

add_subdirectory(libmudaq)

if(APPLE)
    message(WARNING "[online] we dont build kerneldriver")
    message(STATUS "[online] BUILD_KERNEL=${BUILD_KERNEL}")
    message(STATUS "[online] APPLE=${APPLE}")
else()
    add_subdirectory(kerneldriver)
endif()


add_executable(quads_config_fe quads_config_fe.cpp)
add_executable(quads_data_fe quads_data_fe.cpp)

target_link_libraries(quads_config_fe libmudaq midas::mfed)
target_link_libraries(quads_data_fe libmudaq midas::mfed)

install(TARGETS quads_config_fe quads_data_fe DESTINATION bin)
