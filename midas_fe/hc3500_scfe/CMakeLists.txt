# Build Tectra HC3500 PSU SCFE (UDIAN AI-516P, modbus)
cmake_minimum_required(VERSION 3.03)

project(hc3500_scfe VERSION 1.0)

find_package(Midas PATHS $ENV{MIDASSYS} REQUIRED)

#--- make sure the MIDAS_PREFIX system variable is present --------------------
if (NOT DEFINED ENV{MIDAS_PREFIX})
  message(FATAL_ERROR "The system variable MIDAS_PREFIX is not defined.")
endif (NOT DEFINED ENV{MIDAS_PREFIX})
message(STATUS "The install dir is: ${install_path}")

#--- check if the user want to install NOT under MIDAS_PREFIX -----------------
set(install_path "$ENV{MIDAS_PREFIX}/bin")
message(STATUS "The install dir is: ${install_path}")

set (DRIVERS
  $ENV{MIDASSYS}/drivers/class/multi.cxx
  tcpip_rs232.cxx
  hc3500.cxx
)

set (LIBS
  -lz -lpthread -lutil -lrt
)

add_executable(HC3500_scfe 
  hc3500_scfe.cxx 
  ${DRIVERS}
)

set_property(
  TARGET
    HC3500_scfe
  PROPERTY
    CXX_STANDARD 11
)

target_include_directories(HC3500_scfe 
  PRIVATE
    $ENV{MIDASSYS}/drivers
    $ENV{MIDASSYS}/include
    $ENV{MIDASSYS}/mscb/include
    $ENV{MIDAS_WORK}/drivers/bus
    $ENV{MIDAS_WORK}/drivers/class
    $ENV{MIDAS_WORK}/drivers/device
)

target_link_libraries(HC3500_scfe 
  $ENV{MIDAS_PREFIX}/lib/libmfe.a 
  $ENV{MIDAS_PREFIX}/lib/libmidas.a
  ${LIBS}
)

install(
  TARGETS
    HC3500_scfe
  RUNTIME DESTINATION
    ${install_path}
)

