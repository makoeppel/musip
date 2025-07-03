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

# automated linting and testing
find_program(CLANG_FORMAT_EXE NAMES clang-format)

if(CLANG_FORMAT_EXE)
    # Automatically format all source files
    file(GLOB_RECURSE CLANG_FORMAT_FILES
        "${CMAKE_SOURCE_DIR}/midas_fe/*.cpp"
        "${CMAKE_SOURCE_DIR}/midas_fe/*.h"
    )

    add_custom_target(clangformat
        COMMAND clang-format -i ${CLANG_FORMAT_FILES}
        COMMENT "Running clang-format to fix code style"
    )
else()
    message(WARNING "clang-format not found. Skipping clang-format target.")
endif()

find_program(CPPLINT_EXECUTABLE cpplint)

if(CPPLINT_EXECUTABLE)
    file(GLOB_RECURSE CPPLINT_FILES
        "${CMAKE_SOURCE_DIR}/midas_fe/*.cpp"
        "${CMAKE_SOURCE_DIR}/midas_fe/*.h"
    )

    set(CPPLINT_COMMAND "")
    foreach(FILE ${CPPLINT_FILES})
        list(APPEND CPPLINT_COMMAND
            COMMAND ${CMAKE_COMMAND} -E echo "Linting ${FILE}"
            COMMAND ${CPPLINT_EXECUTABLE} --filter=-legal/copyright ${FILE} || true
        )
    endforeach()

    add_custom_target(cpplint
        ${CPPLINT_COMMAND}
        COMMENT "Running cpplint on all source files..."
        VERBATIM
    )
else()
    message(WARNING "cpplint not found. Skipping cpplint target.")
endif()

#add_subdirectory(tests)
