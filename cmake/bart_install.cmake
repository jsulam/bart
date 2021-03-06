# Copyright 2018. Damien Nguyen <damien.nguyen@alumni.epfl.ch>
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# \author Damien Nguyen <damien.nguyen@alumni.epfl.ch>

include(GNUInstallDirs)

set(INSTALL_CONFIGDIR  ${CMAKE_INSTALL_LIBDIR}/cmake/BART)
set(INSTALL_INCLUDEDIR ${CMAKE_INSTALL_INCLUDEDIR}/bart)

# ==============================================================================

# Install the documentation
file(GLOB DOCS "${PROJECT_SOURCE_DIR}/doc/*.txt")
list(APPEND ${PROJECT_SOURCE_DIR}/README)
install(FILES ${DOCS} DESTINATION ${CMAKE_INSTALL_DOCDIR})

# Install the header files
install(DIRECTORY ${PROJECT_SOURCE_DIR}/src/
  DESTINATION ${INSTALL_INCLUDEDIR}
  FILES_MATCHING
  PATTERN "*.h"
  PATTERN "*.hh")

# Separate if users want minimalistic installation
install(FILES ${PROJECT_SOURCE_DIR}/src/bart_embed_api.h
  DESTINATION ${INSTALL_INCLUDEDIR}
  COMPONENT for_embedding)

# Install all of the targets (except bartmain)
set(BART_TARGET_LIST bart bartsupport ${BART_MATLAB_TGT} pyBART)
foreach(target ${BART_TARGET_LIST})
  if(TARGET ${target})
    install(TARGETS ${target}
      EXPORT bart-targets
      RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
      LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
      ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
  endif()
endforeach()

# Install bartmain separately to allow installation only of bartmain
install(TARGETS bartmain
  EXPORT bart-targets-for-embedding
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  COMPONENT for_embedding
  )

# ==============================================================================
# Now take care of exporting all the information for inclusion in other CMake
# projects

set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/BART)


# Write a CMake file with information about the version of BART being compiled
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
  ${CMAKE_CURRENT_BINARY_DIR}/BARTConfigVersion.cmake
  VERSION "${BART_VERSION_MAJOR}.${BART_VERSION_MINOR}.${BART_VERSION_PATCH}"
  COMPATIBILITY AnyNewerVersion)

# Write a CMake config file
configure_package_config_file(${CMAKE_CURRENT_LIST_DIR}/BARTConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/BARTConfig.cmake
  INSTALL_DESTINATION ${INSTALL_CONFIGDIR})

#Install the config, configversion and custom find modules
install(FILES
  ${CMAKE_CURRENT_LIST_DIR}/BARTFindBLASlib.cmake
  ${CMAKE_CURRENT_LIST_DIR}/FindATLAS.cmake
  ${CMAKE_CURRENT_LIST_DIR}/FindLAPACKE.cmake
  ${CMAKE_CURRENT_LIST_DIR}/FindOpenBLAS.cmake
  ${CMAKE_CURRENT_LIST_DIR}/FindlibFlame.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/BARTConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/BARTConfigVersion.cmake
  DESTINATION ${INSTALL_CONFIGDIR}
  COMPONENT for_embedding
  )

# Write a CMake file with all the targets information
export(EXPORT bart-targets FILE ${CMAKE_CURRENT_BINARY_DIR}/BARTTargets.cmake NAMESPACE BART::)

# Install the CMake target file
install(EXPORT bart-targets
  FILE BARTTargets.cmake
  NAMESPACE BART::
  DESTINATION ${INSTALL_CONFIGDIR}
  )

install(EXPORT bart-targets-for-embedding
  FILE BARTTargetsForEmbedding.cmake
  NAMESPACE BART::
  DESTINATION ${INSTALL_CONFIGDIR}
  COMPONENT for_embedding
  )

export(PACKAGE BART)

# ==============================================================================
# Add a few convenience targets

add_custom_target(install_for_embedding
  COMMAND ${CMAKE_COMMAND} -DCOMPONENT=for_embedding -P ${CMAKE_BINARY_DIR}/cmake_install.cmake)
add_custom_target (uninstall
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/uninstall.cmake)
