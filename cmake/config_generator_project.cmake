#
# cmake include to be used for config generator based projects.
#
# Configuration packages for servers can have a very simple CMakeLists.txt like this:
#
#   PROJECT(exampleserver-config NONE)
#   cmake_minimum_required(VERSION 3.14)
#
#   # Note: Always keep MAJOR_VERSION and MINOR_VERSION identical to the server version. Count only the patch separately.
#   set(${PROJECT_NAME}_MAJOR_VERSION 01)
#   set(${PROJECT_NAME}_MINOR_VERSION 00)
#   set(${PROJECT_NAME}_PATCH_VERSION 00)
#   include(cmake/set_version_numbers.cmake)
#
#   include(cmake/config_generator_project.cmake)
#
cmake_minimum_required(VERSION 3.14)

# This function resolves links by copying the target file with the link name, instead of just copying the link
function(copy_with_resolved_links source_dir target_dir)
  file(GLOB_RECURSE file_list LIST_DIRECTORIES true "${source_dir}/*")
  file(MAKE_DIRECTORY "${target_dir}/temp")
  foreach(file ${file_list})
    file(RELATIVE_PATH rpath_file "${PROJECT_SOURCE_DIR}" ${file})
    get_filename_component(rpath_dir ${rpath_file} DIRECTORY)
    if(IS_DIRECTORY ${file})
      file(MAKE_DIRECTORY "${target_dir}/${rpath_file}")
    elseif(IS_SYMLINK ${file})
      file(READ_SYMLINK "${file}" link)
      get_filename_component(fn_target "${file}" NAME)
      get_filename_component(fn_link "${link}" NAME)
      if(NOT IS_ABSOLUTE ${link})
        get_filename_component(dir "${file}" DIRECTORY)
        file(COPY "${dir}/${link}" DESTINATION "${target_dir}/temp")
        file(RENAME "${target_dir}/temp/${fn_link}" "${target_dir}/${rpath_file}")
      else()
        file(COPY "${link}" DESTINATION "${target_dir}/temp")
        file(RENAME "${target_dir}/temp/${fn_link}" "${target_dir}/${rpath_file}")
      endif()
    else()
      file(COPY ${file} DESTINATION "${target_dir}/${rpath_dir}")
    endif()
  endforeach()
  file(REMOVE_RECURSE "${target_dir}/temp")
endfunction()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/Modules)

find_package(ConfigGenerator 02.00 REQUIRED)
list(APPEND CMAKE_MODULE_PATH ${ConfigGenerator_DIR}/shared)

set(DESTDIR share/ConfigGenerator-${PROJECT_NAME}-${${PROJECT_NAME}_MAJOR_VERSION}-${${PROJECT_NAME}_MINOR_VERSION})

# find all server type directories in our source directory and copy them to the build directory
file(GLOB hostlists RELATIVE ${PROJECT_SOURCE_DIR} */hostlist)
foreach(hostlist ${hostlists})
  string(REPLACE "/hostlist" "" servertype "${hostlist}")
# use function instead of: file(COPY "${PROJECT_SOURCE_DIR}/${servertype}" DESTINATION "${PROJECT_BINARY_DIR}")
  copy_with_resolved_links("${PROJECT_SOURCE_DIR}/${servertype}" "${PROJECT_BINARY_DIR}")
  list(APPEND servertypes "${servertype}")
endforeach()

# install server types (scripts are installed by upstream config generator project)
foreach(servertype ${servertypes})
  install(DIRECTORY "${servertype}/settings" DESTINATION "${DESTDIR}/${servertype}")
  install(DIRECTORY "${servertype}/templates" DESTINATION "${DESTDIR}/${servertype}")
  file(GLOB thefiles LIST_DIRECTORIES no "${servertype}/*")
  install(FILES ${thefiles} DESTINATION "${DESTDIR}/${servertype}")
endforeach()
