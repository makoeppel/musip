# Build lemvac SCFE
cmake_minimum_required(VERSION 3.03)

project(pump_scfe VERSION 1.0)

find_package(Midas PATHS $ENV{MIDASSYS} REQUIRED)

#--- make sure the MIDAS_PREFIX system variable is present --------------------
if (NOT DEFINED ENV{MIDAS_PREFIX})
  message(FATAL_ERROR "The system variable MIDAS_PREFIX is not defined.")
endif (NOT DEFINED ENV{MIDAS_PREFIX})

#--- check if the user want to install NOT under MIDAS_PREFIX -----------------
set(install_path "$ENV{MIDAS_PREFIX}/bin")
message(STATUS "The install dir is: ${install_path}")

#--- set default install prefix -----------------------------------------------
set (DRIVERS
  $ENV{MIDASSYS}/drivers/bus/null.cxx
  $ENV{MIDASSYS}/drivers/class/multi.cxx
  pump.cxx
  sps_tcpip.cxx
)

set (LIBS
  -ldl -lz -lpthread -lutil -lrt
)

add_executable(pump_scfe 
  pump_scfe.cxx 
  ${DRIVERS}
)

set_property(
  TARGET
    pump_scfe
  PROPERTY
    CXX_STANDARD 11
)

target_include_directories(pump_scfe 
  PRIVATE
    $ENV{MIDASSYS}/drivers
    $ENV{MIDASSYS}/include
    $ENV{MIDASSYS}/mscb/include
    $ENV{MIDAS_WORK}/drivers/bus
    $ENV{MIDAS_WORK}/drivers/class
    $ENV{MIDAS_WORK}/drivers/device
)

target_link_libraries(pump_scfe 
  midas::mfe
  midas::midas
  ${LIBS}
)

install(
  TARGETS
    pump_scfe
  RUNTIME DESTINATION
    ${install_path}
)

