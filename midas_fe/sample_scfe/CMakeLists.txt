# Build sample SCFE
cmake_minimum_required(VERSION 3.03)

project(sample_scfe VERSION 1.0)

find_package(Midas PATHS $ENV{MIDASSYS} REQUIRED)

#--- make sure the MIDAS_PREFIX system variable is present --------------------
if (NOT DEFINED ENV{MIDAS_PREFIX})
  message(FATAL_ERROR "The system variable MIDAS_PREFIX is not defined.")
endif (NOT DEFINED ENV{MIDAS_PREFIX})
message(STATUS "The install dir is: ${install_path}")

#--- check if the user want to install NOT under MIDAS_PREFIX -----------------
#if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
#  set(install_path "$ENV{MIDAS_PREFIX}/bin")
#else (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(install_path "$ENV{MIDAS_PREFIX}/bin")
#endif (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
message(STATUS "The install dir is: ${install_path}")

#--- set default install prefix -----------------------------------------------
#include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/SetDefaultInstallPath.cmake)

set (DRIVERS
  $ENV{MIDASSYS}/drivers/class/multi.cxx
  tcpip_rs232.cxx
  lem_generic.cxx
  ets_logout.cxx
  LakeShore336.cxx
  bronkhorst.cxx
  thcd_100.cxx
)

add_executable(sample_scfe 
  sample_scfe.cxx 
  ${DRIVERS}
)

set_property(
  TARGET
    sample_scfe
  PROPERTY
    CXX_STANDARD 11
)

target_include_directories(sample_scfe 
  PRIVATE
    $ENV{MIDASSYS}/drivers
    $ENV{MIDASSYS}/include
    $ENV{MIDASSYS}/mscb/include
    $ENV{MIDAS_WORK}/drivers/bus
    $ENV{MIDAS_WORK}/drivers/class
    $ENV{MIDAS_WORK}/drivers/device
)

target_link_libraries(sample_scfe 
  midas::mfe
  midas::midas
)

install(
  TARGETS
    sample_scfe
  RUNTIME DESTINATION
    ${install_path}
)

