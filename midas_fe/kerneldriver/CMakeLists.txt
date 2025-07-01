#

project(mudaq-driver LANGUAGES C CXX)

if(NOT CMAKE_GENERATOR STREQUAL "Unix Makefiles")
    message(WARNING "[common/kerneldriver] using non-Makefile generator -> skip kerneldriver")
    return()
endif()

set(MODULE_SOURCES mudaq.c mudaq.h mudaq_fops.h)

# to use specific version of kernel headers:
# - locate available kernel headers versions in `/usr/lib/modules` directory
# - set KMODULE_KERNEL_RELEASE variable to one of the available versions
#set(KMODULE_KERNEL_RELEASE 6.0.0)

list(APPEND CMAKE_PREFIX_PATH "${CMAKE_CURRENT_SOURCE_DIR}/dmabuf/cmake")
find_package(kmodule REQUIRED)
add_kmodule(${PROJECT_NAME}
    NAME mudaq
    ${MODULE_SOURCES}
)
add_dependencies(${PROJECT_NAME}-insmod ${PROJECT_NAME}-rmmod)

get_directory_property(parent_dir PARENT_DIRECTORY)
if(NOT parent_dir)
    add_custom_target(insmod
        COMMAND sudo chmod a+rw /dev/mudaq0
        COMMAND sudo chmod a+rw /dev/mudaq0_dmabuf
        VERBATIM
        DEPENDS ${PROJECT_NAME}-insmod
    )
endif()
