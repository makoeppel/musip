#

set(minalyzer_analyzers_headers
    hits.h
    HitVectorFlowEvent.h
    AnaFillHits.h
    #AnaMusip.h
    AnaQuadHistos.h
    json.h
    root_helpers.h
)

set(minalyzer_analyzers_sources
    HitVectorFlowEvent.cpp
    AnaFillHits.cpp
    #AnaMusip.cpp
    AnaQuadHistos.cpp
)

#
# First we create an OBJECT library with everything except the `main` function so
# that it can be used in test fixtures.
#
add_library(minalyzer_analyzers OBJECT ${minalyzer_analyzers_sources} ${minalyzer_analyzers_headers})
target_include_directories(minalyzer_analyzers PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(minalyzer_analyzers PUBLIC
    minalyzerdqm
    manalyzer
    Boost::headers
    Boost::program_options
    ROOT::Core
    ROOT::RIO
    ROOT::Hist
    ROOT::ROOTNTuple
    ROOT::ROOTNTupleUtil
)

# I'm not entirely convinced these defines are necessary, but I don't want
# to break other systems so I'll leave them in for now.
target_compile_options(minalyzer_analyzers PUBLIC -DHAVE_ROOT -DHAVE_LIBZ -DHAVE_TMFE)
target_compile_definitions(minalyzer_analyzers PUBLIC -DANADIR="${CMAKE_CURRENT_SOURCE_DIR}")

#
# Then we create the executable with the `main` function and link everything else
# into that.
#
add_executable(quadana
    analyzer.cpp
)
target_link_libraries(quadana PUBLIC
    minalyzer_analyzers
    minalyzerdqm
)

install(TARGETS quadana DESTINATION bin)
