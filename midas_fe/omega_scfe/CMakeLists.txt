
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

