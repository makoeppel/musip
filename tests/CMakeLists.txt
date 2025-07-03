# Enable test discovery
enable_testing()

# Download and set up GoogleTest via FetchContent
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/heads/main.zip
)
# Prevent GoogleTest from overriding compiler/linker flags
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

# Add your test executable
add_executable(sample_test sample_test.cpp)
add_executable(bits_utils_test bits_utils_test.cpp)

# Link to GoogleTest libraries
target_link_libraries(sample_test gtest_main)
target_link_libraries(bits_utils_test gtest_main)

# Auto-discover and register tests
include(GoogleTest)
gtest_discover_tests(sample_test)
gtest_discover_tests(bits_utils_test)
