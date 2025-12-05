cmake_minimum_required(VERSION 3.17)

project(quadana VERSION 0.1 LANGUAGES CXX)

message(STATUS "CMAKE_CURRENT_SOURCE_DIR = ${CMAKE_CURRENT_SOURCE_DIR}")

set(CMAKE_INSTALL_PREFIX "${CMAKE_SOURCE_DIR}/install" CACHE PATH "" FORCE)
set(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT FALSE)
message(STATUS "CMAKE_INSTALL_PREFIX: ${CMAKE_INSTALL_PREFIX}")

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
    COMPONENTS Core MathCore RIO Hist Tree Net RHTTP Gui XMLIO
)
find_package(Midas REQUIRED COMPONENTS manalyzer
    NO_DEFAULT_PATH PATHS "$ENV{MIDASSYS}"
)

add_subdirectory(midas_fe)
add_subdirectory(tools)
add_subdirectory(analyzer)
add_subdirectory(tests)

# automated linting and testing
find_program(CLANG_FORMAT_EXE NAMES clang-format)

if(CLANG_FORMAT_EXE)
    # Automatically format all source files
    file(GLOB_RECURSE CLANG_FORMAT_FILES
        "${CMAKE_SOURCE_DIR}/midas_fe/*.cpp"
        "${CMAKE_SOURCE_DIR}/midas_fe/*.h"
        "${CMAKE_SOURCE_DIR}/tests/*.cpp"
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
        "${CMAKE_SOURCE_DIR}/midas_fe/registers/*.h"
    )

    set(CPPLINT_COMMAND "")
    foreach(FILE ${CPPLINT_FILES})
        list(APPEND CPPLINT_COMMAND
            COMMAND ${CMAKE_COMMAND} -E echo "Linting ${FILE}"
            COMMAND ${CPPLINT_EXECUTABLE} --filter=-legal/copyright --linelength=100 ${FILE} || true
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

find_program(MKDOCS_EXECUTABLE mkdocs QUIET)

if(MKDOCS_EXECUTABLE)
    # Set docs directory and build output
    set(DOCS_SOURCE_DIR "${CMAKE_SOURCE_DIR}/docs")
    set(MKDOCS_CONFIG_FILE "${CMAKE_SOURCE_DIR}/mkdocs.yml")
    set(MKDOCS_OUTPUT_DIR "${CMAKE_BINARY_DIR}/site")

    # Custom target to build MkDocs documentation
    add_custom_target(doc_mkdocs
        COMMAND ${CMAKE_COMMAND} -E env
                MKDOCS_CONFIG_FILE=${MKDOCS_CONFIG_FILE}
                mkdocs build
                --config-file ${MKDOCS_CONFIG_FILE}
                --site-dir ${MKDOCS_OUTPUT_DIR}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Generating documentation with MkDocs"
        VERBATIM
    )

    add_custom_target(serve_mkdocs
        COMMAND ${MKDOCS_EXECUTABLE} serve
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Serving MkDocs documentation at http://127.0.0.1:8000/"
        USES_TERMINAL
    )
else()
    message(STATUS "Mkdocs not found, skipping documentation target")
endif()
