#
# CMakeLists.txt for scshv20_scfe
#
# MK Spetember 2024
#

cmake_minimum_required(VERSION 3.03)

project(scshv20_scfe)

find_package(Midas PATHS $ENV{MIDASSYS} REQUIRED)

#--- make sure the MIDAS_PREFIX system variable is present --------------------
if (NOT DEFINED ENV{MIDAS_PREFIX})
  message(FATAL_ERROR "The system variable MIDAS_PREFIX is not defined.")
endif (NOT DEFINED ENV{MIDAS_PREFIX})
message(STATUS "The install dir is: ${install_path}")

#--- check if the user want to install NOT under MIDAS_PREFIX -----------------
set(install_path "$ENV{MIDAS_PREFIX}/bin")
message(STATUS "The install dir is: ${install_path}")

# main frontend executable
add_executable(scshv20_scfe 
  scshv20_scfe.cxx scshv20.cxx
)

target_include_directories(scshv20_scfe 
  PRIVATE
    $ENV{MIDASSYS}/drivers
    $ENV{MIDASSYS}/include
    $ENV{MIDASSYS}/mscb/include
    $ENV{MIDAS_WORK}/drivers/bus
    $ENV{MIDAS_WORK}/drivers/class
    $ENV{MIDAS_WORK}/drivers/device
)

target_link_libraries(scshv20_scfe midas::drivers midas::mscb midas::mfe)
install(TARGETS scshv20_scfe DESTINATION bin)
