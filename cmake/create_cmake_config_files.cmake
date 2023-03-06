#######################################################################################################################
# create_cmake_config_files.cmake
#
# Create the Find${PROJECT_NAME}.cmake cmake macro and the ${PROJECT_NAME}-config shell script and installs them.
#
# Expects the following input variables:
#   ${PROJECT_NAME}_SOVERSION - version of the .so library file (or just MAJOR.MINOR without the patch level)
#   ${PROJECT_NAME}_INCLUDE_DIRS - list include directories needed when compiling against this project
#   ${PROJECT_NAME}_LIBRARY_DIRS - list of library directories needed when linking against this project
#   ${PROJECT_NAME}_LIBRARIES - list of additional libraries needed when linking against this project. The library
#                               provided by the project will be added automatically
#   ${PROJECT_NAME}_CXX_FLAGS - list of additional C++ compiler flags needed when compiling against this project
#   ${PROJECT_NAME}_LINKER_FLAGS - list of additional linker flags needed when linking against this project
#   ${PROJECT_NAME}_MEXFLAGS - (optional) mex compiler flags
#
#######################################################################################################################

#######################################################################################################################
#
# IMPORTANT NOTE:
#
# DO NOT MODIFY THIS FILE inside a project. Instead update the project-template repository and pull the change from
# there. Make sure to keep the file generic, since it will be used by other projects, too.
#
# If you have modified this file inside a project despite this warning, make sure to cherry-pick all your changes
# into the project-template repository immediately.
#
#######################################################################################################################

# for lib, which might be lib File or linker flag or imported target, 
# puts recursively resolved library list into ${linkLibs}, which will contain a library file list
# and recursively resolve link flags into ${linkFlags}
function(resolveImportedLib lib linkLibs linkFlags incDirs cxxFlags)
    set(linkLibs1 "")
    set(linkFlags1 "")
    set(incDirs1 "")
    set(cxxFlags1 "")
    if(lib MATCHES "/")         # library name contains slashes: link against the a file path name
        string(APPEND linkLibs1 " ${lib}")
    elseif(lib MATCHES "^[ \t]*-l")   # library name does not contain slashes but already the -l option: directly quote it
        string(APPEND linkLibs1 " ${lib}")
    elseif(lib MATCHES "::")    # library name is an imported target - we need to resolve it for Makefiles
        get_target_property(_libraryType ${lib} TYPE)
        if (${_libraryType} MATCHES "-NOTFOUND")
            message(FATAL_ERROR "dependency ${lib} was not found!")
        endif()
        if ((${_libraryType} MATCHES SHARED_LIBRARY) OR (${_libraryType} MATCHES STATIC_LIBRARY))
            # we cannot refer to ourselves as dependency -> leave out
            if(NOT (";${lib};" MATCHES ";.*::${PROJECT_NAME};"))
                get_property(lib_loc TARGET ${lib} PROPERTY LOCATION)
                message("imported target ${lib} is actual library. location=${lib_loc}")
                string(APPEND linkLibs1 " ${lib_loc}")
            endif()
        endif()
        get_target_property(_linkLibs ${lib} INTERFACE_LINK_LIBRARIES)
        if (NOT "${_linkLibs}" MATCHES "-NOTFOUND")
            message("imported target ${lib} is interface, recursively go over its interface requirements ${_linkLibs}")
            foreach(_lib ${_linkLibs})
                resolveImportedLib(${_lib} linkLibs2 linkFlags2 incDirs2 cxxFlags2)
                # TODO - we need to evaluate generator expressions somehow
                string(APPEND linkLibs1 " ${linkLibs2}")
                string(APPEND linkFlags1 " ${linkFlags2}")
                string(APPEND incDirs1 " ${incDirs2}")
                string(APPEND cxxFlags1 " ${cxxFlags2}")
            endforeach()
        endif()
        get_target_property(_incDirs ${lib} INTERFACE_INCLUDE_DIRECTORIES)
        if (NOT "${_incDirs}" MATCHES "-NOTFOUND")
            foreach(INCLUDE_DIR ${_incDirs})
                string(APPEND incDirs1 " ${INCLUDE_DIR}")
            endforeach()
        endif()
        get_target_property(_cxxFlags ${lib} INTERFACE_COMPILE_OPTIONS)
            if (NOT "${_cxxFlags}" MATCHES "-NOTFOUND")
            foreach(cxxFlag ${_cxxFlags})
                string(APPEND cxxFlags1 " ${cxxFlag}")
            endforeach()
        endif()
    else()                          # link against library with -l option
        string(APPEND linkFlags1 " -l${lib}")
    endif()
    
    set(${linkLibs} "${linkLibs1}" PARENT_SCOPE)
    set(${linkFlags} "${linkFlags1}" PARENT_SCOPE)
    set(${incDirs} "${incDirs1}" PARENT_SCOPE)
    set(${cxxFlags} "${cxxFlags1}" PARENT_SCOPE)
endfunction()


# if we already have cmake-exports for this project:
# sets the vars 
# ${PROJECT_NAME}_INCLUDE_DIRS, ${PROJECT_NAME}_CXX_FLAGS, ${PROJECT_NAME}_LINKER_FLAGS ${PROJECT_NAME}_LIBRARIES
# so that compatibility layer is provided automatically.
# ${PROJECT_NAME}_LIBRARY_DIRS is no longer used, ${PROJECT_NAME}_LIBRARIES is fully resolved.
if(${PROVIDES_EXPORTED_TARGETS})
    #  imported targets should be namespaced, so define namespaced alias
    add_library(ChimeraTK::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

    resolveImportedLib(ChimeraTK::${PROJECT_NAME} linkLibs linkFlags incDirs cxxFlags)

    message("old libset: ${${PROJECT_NAME}_LIBRARIES}")
    message("old linkflags: ${${PROJECT_NAME}_LINKER_FLAGS}")
    message("old cxxflags: ${${PROJECT_NAME}_CXX_FLAGS}")
    message("old incDirs: ${${PROJECT_NAME}_INCLUDE_DIRS}")
    set(${PROJECT_NAME}_INCLUDE_DIRS "${incDirs}" )
    set(${PROJECT_NAME}_LIBRARIES "${linkLibs}" )
    set(${PROJECT_NAME}_CXX_FLAGS "${cxxFlags}" )
    set(${PROJECT_NAME}_LINKER_FLAGS "${linkFlags}" )
    message("new libset: ${${PROJECT_NAME}_LIBRARIES}")
    message("new linkflags: ${${PROJECT_NAME}_LINKER_FLAGS}")
    message("new cxxflags: ${${PROJECT_NAME}_CXX_FLAGS}")
    message("new incDirs: ${${PROJECT_NAME}_INCLUDE_DIRS}")
endif()

# create variables for standard makefiles and pkgconfig
set(${PROJECT_NAME}_CXX_FLAGS_MAKEFILE "${${PROJECT_NAME}_CXX_FLAGS}")

string(REPLACE " " ";" LIST "${${PROJECT_NAME}_INCLUDE_DIRS}")
foreach(INCLUDE_DIR ${LIST})
  set(${PROJECT_NAME}_CXX_FLAGS_MAKEFILE "${${PROJECT_NAME}_CXX_FLAGS_MAKEFILE} -I${INCLUDE_DIR}")
endforeach()

set(${PROJECT_NAME}_LINKER_FLAGS_MAKEFILE "${${PROJECT_NAME}_LINKER_FLAGS} ${${PROJECT_NAME}_LINK_FLAGS}")

string(REPLACE " " ";" LIST "${${PROJECT_NAME}_LIBRARY_DIRS}")
foreach(LIBRARY_DIR ${LIST})
  set(${PROJECT_NAME}_LINKER_FLAGS_MAKEFILE "${${PROJECT_NAME}_LINKER_FLAGS_MAKEFILE} -L${LIBRARY_DIR}")
endforeach()

message("${PROJECT_NAME}: linker flags for makefile, before recursive lib resolution=|${${PROJECT_NAME}_LINKER_FLAGS_MAKEFILE}|")
string(REPLACE " " ";" LIST "${PROJECT_NAME} ${${PROJECT_NAME}_LIBRARIES}")
foreach(LIBRARY ${LIST})
    resolveImportedLib(${LIBRARY} linkLibs linkFlags incDirs cxxFlags)
    #message("for lib ${LIBRARY}: add linkLibs=|${linkLibs}| linkFlags=|${linkFlags}|")
    string(APPEND ${PROJECT_NAME}_LINKER_FLAGS_MAKEFILE " ${linkLibs}")
    string(APPEND ${PROJECT_NAME}_LINKER_FLAGS_MAKEFILE " ${linkFlags}")
endforeach()
message("${PROJECT_NAME}: linker flags for makefile=|${${PROJECT_NAME}_LINKER_FLAGS_MAKEFILE}|")

set(${PROJECT_NAME}_PUBLIC_DEPENDENCIES_L "")
foreach(DEPENDENCY ${${PROJECT_NAME}_PUBLIC_DEPENDENCIES})
    string(APPEND ${PROJECT_NAME}_PUBLIC_DEPENDENCIES_L "find_package(${DEPENDENCY} REQUIRED)\n")
endforeach()

if(TARGET ${PROJECT_NAME})
  # set _HAS_LIBRARY only if we have a true library, interface libraries (introduced for imported targets,
  #  e.g. header-only library) don't count.
  get_target_property(targetLoc ${PROJECT_NAME} TYPE)
  if(NOT "INTERFACE_LIBRARY" MATCHES "${targetLoc}")
    set(${PROJECT_NAME}_HAS_LIBRARY 1)
  endif()  
else()
  set(${PROJECT_NAME}_HAS_LIBRARY 0)
endif()


# we have nested @-statements, so we have to parse twice:

# create the cmake find_package configuration file
set(PACKAGE_INIT "@PACKAGE_INIT@") # replacement handled later, so leave untouched here
cmake_policy(SET CMP0053 NEW) # less warnings about irrelevant stuff in comments
configure_file(cmake/PROJECT_NAMEConfig.cmake.in.in "${PROJECT_BINARY_DIR}/cmake/Config.cmake.in" @ONLY)
if(${PROVIDES_EXPORTED_TARGETS})
    # we will configure later
else()
    configure_file(${PROJECT_BINARY_DIR}/cmake/${PROJECT_NAME}Config.cmake.in "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake" @ONLY)
endif()
configure_file(cmake/PROJECT_NAMEConfigVersion.cmake.in.in "${PROJECT_BINARY_DIR}/cmake/${PROJECT_NAME}ConfigVersion.cmake.in" @ONLY)
configure_file(${PROJECT_BINARY_DIR}/cmake/${PROJECT_NAME}ConfigVersion.cmake.in "${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)

# create the shell script for standard make files
configure_file(cmake/PROJECT_NAME-config.in.in "${PROJECT_BINARY_DIR}/cmake/${PROJECT_NAME}-config.in" @ONLY)
configure_file(${PROJECT_BINARY_DIR}/cmake/${PROJECT_NAME}-config.in "${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config" @ONLY)

# create the pkgconfig file
configure_file(cmake/PROJECT_NAME.pc.in.in "${PROJECT_BINARY_DIR}/cmake/${PROJECT_NAME}.pc.in" @ONLY)
configure_file(${PROJECT_BINARY_DIR}/cmake/${PROJECT_NAME}.pc.in "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.pc" @ONLY)

# install script for Makefiles
install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-config DESTINATION bin COMPONENT dev)

# install configuration file for pkgconfig
install(FILES "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.pc" DESTINATION share/pkgconfig COMPONENT dev)

if(${PROVIDES_EXPORTED_TARGETS})
    #  imported targets should be namespaced, so define namespaced alias
    add_library(ChimeraTK::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

    # defines CMAKE_INSTALL_LIBDIR etc
    include(GNUInstallDirs)

    # generate and install export file
    install(EXPORT ${PROJECT_NAME}Targets
            FILE ${PROJECT_NAME}Targets.cmake
            NAMESPACE ChimeraTK::
            DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}"
    )

    include(CMakePackageConfigHelpers)
    # create config file
    configure_package_config_file("${PROJECT_BINARY_DIR}/cmake/Config.cmake.in"
      "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
      INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}"
    )

    # remove any previously installed share/cmake-xx/Modules/Find<ProjectName>.cmake from this project since it does not harmonize with new Config
    set(fileToRemove "share/cmake-${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION}/Modules/Find${PROJECT_NAME}.cmake")
    install(CODE "FILE(REMOVE ${CMAKE_INSTALL_PREFIX}/${fileToRemove})")
else()
    # install same cmake configuration file another time into the Modules cmake subdirectory for compatibility reasons
    # We do this only if we did not move yet to exported target, since it does not harmonize 
    install(FILES "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
      DESTINATION share/cmake-${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION}/Modules RENAME Find${PROJECT_NAME}.cmake COMPONENT dev)

endif()

# install cmake find_package configuration file
install(FILES
          "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
          "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
        DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}"
        COMPONENT dev
)

