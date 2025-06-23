#

add_subdirectory(libmudaq)

if(NOT BUILD_KERNEL OR APPLE)
    message(WARNING "[online] we dont build kerneldriver")
    message(STATUS "[online] BUILD_KERNEL=${BUILD_KERNEL}")
    message(STATUS "[online] APPLE=${APPLE}")
else()
    add_subdirectory(kerneldriver)
endif()


add_executable(quad_fe quad_fe.cpp)

target_link_libraries(quad_fe libmudaq midas::mfed)

install(TARGETS quad_fe DESTINATION bin)
