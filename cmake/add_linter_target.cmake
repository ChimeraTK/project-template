if (ENABLE_TIDY_WHILE_BUILDING)
set(CMAKE_CXX_CLANG_TIDY /usr/bin/clang-tidy-14;-config-file=${CMAKE_SOURCE_DIR}/.clang-tidy)
set(CMAKE_C_CLANG_TIDY /usr/bin/clang-tidy-14;-config-file=${CMAKE_SOURCE_DIR}/.clang-tidy)
endif()
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_custom_target(run-linter run-clang-tidy-14 -header-filter ".*")
add_custom_target(fix-linter run-clang-tidy-14 -header-filter ".*" -fix -format)


