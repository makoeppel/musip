cmake_minimum_required(VERSION 3.17)

project(quadana VERSION 0.1 LANGUAGES CXX)

message(STATUS "CMAKE_CURRENT_SOURCE_DIR = ${CMAKE_CURRENT_SOURCE_DIR}")

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT CMAKE_CXX_STANDARD)
   set(CMAKE_CXX_STANDARD 17)
endif()

find_package(Git 1.8 REQUIRED)
execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --long --dirty --abbrev=16 --all
    OUTPUT_STRIP_TRAILING_WHITESPACE
    OUTPUT_VARIABLE ANALYZER_GIT_REF
)
message(STATUS "ANALYZER_GIT_REF: ${ANALYZER_GIT_REF}")

# required packages
find_package(Boost 1.74 REQUIRED
    COMPONENTS filesystem program_options system
)
find_package(ROOT REQUIRED
    COMPONENTS MathCore RIO Hist Tree Net RHTTP Gui XMLIO
)
find_package(Midas REQUIRED COMPONENTS manalyzer
    NO_DEFAULT_PATH PATHS "$ENV{MIDASSYS}"
)

add_subdirectory(midas_fe)
add_subdirectory(tools)
add_subdirectory(analyzer)
#add_subdirectory(tests)
