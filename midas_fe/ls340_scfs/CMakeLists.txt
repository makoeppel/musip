# Build LakeShore 340 SCFE
cmake_minimum_required(VERSION 3.03)

project(ls340_scfe VERSION 1.0)

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
  $ENV{MIDAS_WORK}/drivers/bus/tcpip_rs232.cxx
  $ENV{MIDAS_WORK}/drivers/class/lem_generic.cxx
  $ENV{MIDAS_WORK}/drivers/device/ets_logout.cxx
  LakeShore340.cxx
)

add_executable(ls340_scfe 
  ls340_scfe.cxx 
  ${DRIVERS}
)

set_property(
  TARGET
    ls340_scfe
  PROPERTY
    CXX_STANDARD 11
)

target_include_directories(ls340_scfe 
  PRIVATE
    .
    $ENV{MIDASSYS}/drivers
    $ENV{MIDASSYS}/include
    $ENV{MIDASSYS}/mscb/include
    $ENV{MIDAS_WORK}/drivers/bus
    $ENV{MIDAS_WORK}/drivers/class
    $ENV{MIDAS_WORK}/drivers/device
)

target_link_libraries(ls340_scfe 
  midas::mfe
  midas::midas
)

install(
  TARGETS
    ls340_scfe
  RUNTIME DESTINATION
    ${install_path}
)

