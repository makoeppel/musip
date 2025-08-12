# Build Omega SCFE
cmake_minimum_required(VERSION 3.03)

project(omega VERSION 1.0)

find_package(Midas PATHS $ENV{MIDASSYS} REQUIRED)

#--- make sure the MIDAS_PREFIX system variable is present --------------------
if (NOT DEFINED ENV{MIDAS_PREFIX})
  message(FATAL_ERROR "The system variable MIDAS_PREFIX is not defined.")
endif (NOT DEFINED ENV{MIDAS_PREFIX})
message(STATUS "The install dir is: ${install_path}")


#--- check if the user want to install NOT under MIDAS_PREFIX -----------------
set(install_path "$ENV{MIDAS_PREFIX}/bin")
message(STATUS "The install dir is: ${install_path}")

#--- set default install prefix -----------------------------------------------
#include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/SetDefaultInstallPath.cmake)

set (DRIVERS
  $ENV{MIDASSYS}/drivers/class/multi.cxx
  $ENV{MIDAS_WORK}/drivers/device/omega_cn616a.cxx
  $ENV{MIDAS_WORK}/drivers/device/ets_logout.cxx
  $ENV{MIDAS_WORK}/drivers/bus/tcpip_rs232.cxx
)

add_executable(omega 
  omega_scfe.cxx 
  ${DRIVERS}
)

set_property(
  TARGET
    omega
  PROPERTY
    CXX_STANDARD 11
)

target_include_directories(omega 
  PRIVATE
    $ENV{MIDASSYS}/drivers
    $ENV{MIDASSYS}/include
    $ENV{MIDASSYS}/mscb/include
    $ENV{MIDAS_WORK}/drivers/bus
    $ENV{MIDAS_WORK}/drivers/device
)

target_link_libraries(omega 
  midas::mfe
  midas::midas
)

install(
  TARGETS
    omega
  RUNTIME DESTINATION
    ${install_path}
)

