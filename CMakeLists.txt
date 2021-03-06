# Copyright 2015-2016. Hans J. Johnson <hans-johnson@uiowa.edu>
# Copyright 2017-2018. Damien Nguyen <damien.nguyen@alumni.epfl.ch>
# All rights reserved. Use of this source code is governed by
# a BSD-style license which can be found in the LICENSE file.
# \author Hans J. Johnson <hans-johnson@uiowa.edu>
# \author Damien Nguyen <damien.nguyen@alumni.epfl.ch>
cmake_minimum_required(VERSION 2.8.12)

project(bart C)
enable_language(C)

# Silence a CMake-warning about object libraries
if(CMAKE_VERSION VERSION_GREATER 3.0)
  cmake_policy(SET CMP0051 NEW)
  cmake_policy(SET CMP0057 NEW) # if IN_LIST
endif(CMAKE_VERSION VERSION_GREATER 3.0)

# http://stackoverflow.com/questions/24840030/forcing-c99-in-cmake-to-use-for-loop-initial-declaration
if (CMAKE_VERSION VERSION_LESS "3.1")
  if (CMAKE_C_COMPILER_ID STREQUAL "GNU" OR
      CMAKE_C_COMPILER_ID STREQUAL "Clang")
    set (CMAKE_C_FLAGS "--std=gnu11 ${CMAKE_C_FLAGS}")
  endif()
else()
  set (CMAKE_C_STANDARD 11)
endif()

set(CMAKE_DEBUG_POSTFIX "d")
set(CMAKE_RELWITHDEBINFO_POSTFIX "rd")
set(CMAKE_MINSIZEREL_POSTFIX "rm")

if ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang"
    OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fblocks")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fblocks")
endif()

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake ${CMAKE_MODULE_PATH})

#==============================================================================
# Options

include(${CMAKE_CURRENT_LIST_DIR}/cmake/bart_options.cmake)

# ==============================================================================

# --- Provide good defaults for searching for packages (i.e. ismrmrd)
set(CMAKE_PREFIX_PATH)
if(NOT CMAKE_PREFIX_PATH)
  list(APPEND CMAKE_PREFIX_PATH "/usr/local")
endif()
if(EXISTS $ENV{CMAKE_PREFIX_PATH})
  list(APPEND CMAKE_PREFIX_PATH $ENV{CMAKE_PREFIX_PATH})
endif()
if(EXISTS $ENV{ISMRMRD_HOME})
  list(APPEND CMAKE_PREFIX_PATH $ENV{ISMRMRD_HOME})
endif()
if(CMAKE_PREFIX_PATH)
  list(REMOVE_DUPLICATES CMAKE_PREFIX_PATH)
endif()
# message(STATUS "Looking for packages in : ${CMAKE_PREFIX_PATH}")

# --- Mac specific setup options
if(APPLE)
  # Look for MacPorts only as Homebrew users do not require any particular setup
  find_program(MACPORTS
    NAMES port
    PATHS /opt/local/bin /opt/local/sbin)
  if(MACPORTS)
    add_definitions(-DUSE_MACPORTS)
  endif(MACPORTS)
endif(APPLE)

# ==============================================================================

##- TODO option(BART_SLINK "Provide SLINK support" OFF)
# Set a default build type if none was specified
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  # Set the possible values of build type for cmake-gui
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "RelWithDebInfo")
endif()

find_package(ISMRMRD QUIET) ## if you can find ISMRMRD by default, then default configuration is ON
option(BART_ISMRMRD "Use external ISMRMRD package for reading/writing" ${ISMRMRD_FOUND})
if(BART_ISMRMRD)
  find_package(ISMRMRD REQUIRED)
endif()

## Compiler flags -- TODO This could be better, see ITK it won't work on windows builds
if(${CMAKE_BUILD_TYPE} MATCHES "Release")
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffast-math -O3") # -Wall -Wextra -Wmissing-prototypes")
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}  -ffast-math -O3") # -Wall -Wextra")
endif()

# ==============================================================================
# Find a BLAS-capable library

include(${CMAKE_CURRENT_LIST_DIR}/cmake/BARTFindBLASlib.cmake)

# Fix weird error when compiling on Mac...
if(APPLE)
  include_directories(${${LINALG_VENDOR_TGT}_INCLUDE_DIRS})
endif()

##======================================================================

execute_process(COMMAND ${CMAKE_CURRENT_LIST_DIR}/git-version.sh OUTPUT_VARIABLE BART_FULL_VERSION_STRING WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR})
string(STRIP ${BART_FULL_VERSION_STRING} BART_FULL_VERSION_STRING) ## Remove trailing whitespace (return characters)
string(REGEX REPLACE ".*v([0-9]*)\\.([0-9]*)\\.([0-9]*)-.*" "\\1" BART_VERSION_MAJOR "${BART_FULL_VERSION_STRING}")
string(REGEX REPLACE ".*v([0-9]*)\\.([0-9]*)\\.([0-9]*)-.*" "\\2" BART_VERSION_MINOR "${BART_FULL_VERSION_STRING}")
string(REGEX REPLACE ".*v([0-9]*)\\.([0-9]*)\\.([0-9]*)-.*" "\\3" BART_VERSION_PATCH "${BART_FULL_VERSION_STRING}")
message(STATUS "BART VERSION: ${BART_FULL_VERSION_STRING}:  ${BART_VERSION_MAJOR} ${BART_VERSION_MINOR} ${BART_VERSION_PATCH}")

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/version.inc.in "VERSION(\@BART_FULL_VERSION_STRING\@)")
configure_file(${CMAKE_CURRENT_BINARY_DIR}/version.inc.in ${CMAKE_CURRENT_BINARY_DIR}/version.inc @ONLY)

include_directories(${CMAKE_CURRENT_BINARY_DIR})

## ========== Process build_targets.mk
set (ALLPROGS "")
file(READ "${CMAKE_CURRENT_LIST_DIR}/build_targets.mk" bld_tgt_list_of_list)
# Convert file contents into a CMake list (where each element in the list
# is one line of the file)
#
string(REGEX REPLACE ";" "\\\\;" bld_tgt_list_of_list "${bld_tgt_list_of_list}")
string(REGEX REPLACE "\n" ";" bld_tgt_list_of_list "${bld_tgt_list_of_list}")
foreach(bld_tgt_line ${bld_tgt_list_of_list})
   if( "${bld_tgt_line}" MATCHES "^[^#].*=.*")
     string(REGEX REPLACE "^ *([^=]*) *= *(.*) *" "\\1" BLD_KEY "${bld_tgt_line}")
     string(REGEX REPLACE "^ *([^=]*) *= *(.*) *" "\\2" BLD_VALUE "${bld_tgt_line}")
     string(REPLACE " " ";" ${BLD_KEY} "${BLD_VALUE}")  ## Create a new variable called ${BLD_KEY}
     ## message(STATUS "KEY:${BLD_KEY}:    VALUE:${${BLD_KEY}}:")
     list(APPEND ALLPROGS ${${BLD_KEY}})
   endif()
endforeach()


if(BART_ISMRMRD)
  list(APPEND ALLPROGS ismrmrd) 
endif(BART_ISMRMRD)

if(BART_DISABLE_PNG)
  list(REMOVE_ITEM ALLPROGS "toimg")
endif(BART_DISABLE_PNG)

list(SORT ALLPROGS)


## BART Makefile depends heavily on pre-processor replacements
## on the command line rather than a library of common functionality
## that is used to compile code once and link many times.
## In this cmake build, it was choosen to generate separate files
## for separate build uses of each source file.
## This convoluted mechansims is needed to avoid changing
## any build organizaiton so that the Makefile build system is
## not changed at all.  A different organziation of the build
## proceedures could make this much less complicated.
##
## usage CONFIG_BY_REPLACEMENT( in.file out.file "at top string" match1 rep1 match2 rep2 .... matchN repN)
macro(CONFIG_BY_REPLACEMENT INFILE OUTFILE PREFIX )
  if(NOT EXISTS "${INFILE}")
    message(FATAL_ERROR "\n\nMISSING INPUT FILE \"${INFILE}\" for generating \"${OUTFILE}\"\n\n")
  endif()
  file(READ "${INFILE}" MAIN_TEMPLATE_STRING)

  set(all_repacement_pairs ${ARGN})
  list(LENGTH all_repacement_pairs RP_LENGTH)
  while(NOT ${RP_LENGTH} LESS 2)
    list(GET all_repacement_pairs 0 INSTRING)
    list(REMOVE_AT all_repacement_pairs 0 )
    list(LENGTH all_repacement_pairs RP_LENGTH)
    if(${RP_LENGTH} GREATER 0)
      list(GET all_repacement_pairs 0 OUTSTRING)
      list(REMOVE_AT all_repacement_pairs 0 )
      list(LENGTH all_repacement_pairs RP_LENGTH)
    else()
      message(FATAL_ERROR "Replacement pairs unmatched: ${ARGN}")
    endif()
  
    string(REPLACE "${INSTRING}" "${OUTSTRING}" MAIN_TEMPLATE_STRING "${MAIN_TEMPLATE_STRING}")
  endwhile()
  string(REPLACE "__EOL__" ";" MAIN_TEMPLATE_STRING "${MAIN_TEMPLATE_STRING}") ## UglyFix
  set(MAIN_TEMPLATE_STRING "${PREFIX}\n${MAIN_TEMPLATE_STRING}")
  
  if(EXISTS "${OUTFILE}" )
    file(READ "${OUTFILE}" PREVIOUS_CONTENT)
  else()
    set(PREVIOUS_CONTENT "")
  endif()
  string( COMPARE EQUAL "${PREVIOUS_CONTENT}" "${MAIN_TEMPLATE_STRING}" STRING_NO_CHANGE)
  if( NOT STRING_NO_CHANGE )
    file(WRITE "${OUTFILE}" "${MAIN_TEMPLATE_STRING}")
  endif()
endmacro()

set(BART_SUPPORT_LIBS calib misc dfwavelet grecon iter linops lowrank nlops noir noncart num sake sense simu wavelet)
if(BART_ISMRMRD)
  list(APPEND BART_SUPPORT_LIBS ismrm)
  link_directories(${ISMRMRD_LIBRARY_DIRS})
  include_directories(${ISMRMRD_INCLUDE_DIRS})
endif()

if(BART_NO_LAPACKE)
  list(APPEND BART_SUPPORT_LIBS lapacke)
endif(BART_NO_LAPACKE)

include_directories(${CMAKE_CURRENT_LIST_DIR}/src)

set(bart_support_SRCS "")
set(bart_support_CCSRCS "")
set(bart_support_CUSRCS "" CACHE INTERNAL "")
foreach(curr_lib ${BART_SUPPORT_LIBS})
    file(GLOB ${curr_lib}_SRCS "src/${curr_lib}/*.c")
    list(APPEND bart_support_SRCS ${${curr_lib}_SRCS})
  
    file(GLOB ${curr_lib}_CCSRCS "src/${curr_lib}/*.cc")
    list(APPEND bart_support_SRCS ${${curr_lib}_CCSRCS})

    if(USE_CUDA)
      file(GLOB ${curr_lib}_CUSRCS "src/${curr_lib}/*.cu")
      list(APPEND bart_support_CUSRCS ${${curr_lib}_CUSRCS})
    endif(USE_CUDA)
endforeach()

# ------------------------------------------------------------------------------
# These files need to be compiled separately since they might contain
# Python code

set(BARTSUPPORT_PYTHON_SEPARATE_COMPILATION_FILES
  "${CMAKE_CURRENT_LIST_DIR}/src/misc/mmiocc.cc"
  "${CMAKE_CURRENT_LIST_DIR}/src/misc/mmio.c"
  "${CMAKE_CURRENT_LIST_DIR}/src/misc/misc.c" CACHE INTERNAL "")
foreach(file ${BARTSUPPORT_PYTHON_SEPARATE_COMPILATION_FILES})
  list(REMOVE_ITEM bart_support_SRCS "${file}")
endforeach()

if(NOT BART_ENABLE_MEM_CFL)
  list(REMOVE_ITEM
    BARTSUPPORT_PYTHON_SEPARATE_COMPILATION_FILES
    "${CMAKE_CURRENT_LIST_DIR}/src/misc/mmiocc.cc")
endif(NOT BART_ENABLE_MEM_CFL)

# ------------------------------------------------------------------------------

if(BART_DISABLE_PNG)
  list(REMOVE_ITEM bart_support_SRCS "${CMAKE_CURRENT_LIST_DIR}/src/misc/png.c")
endif(BART_DISABLE_PNG)

set(LOG_BACKEND_SRCS "")
list(REMOVE_ITEM bart_support_SRCS "${CMAKE_CURRENT_LIST_DIR}/src/misc/UTrace.cc")
list(REMOVE_ITEM bart_support_SRCS "${CMAKE_CURRENT_LIST_DIR}/src/misc/Orchestra.cc")

if(BART_LOG_BACKEND)
  set(DEBUG_C_FILE "${CMAKE_CURRENT_LIST_DIR}/src/misc/debug.c")
  set(LOG_BACKEND_SRCS "${DEBUG_C_FILE}")
  
  if(BART_LOG_SIEMENS_BACKEND)
    if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/src/misc/UTrace.cc")
      set(_ERR "Could not find the src/misc/UTrace.cc file\n")
      set(_ERR "${_ERR}You can download a copy of UTrace.cc at:\n")
      set(_ERR "${_ERR}https://www.mr-idea.com/communities/idea/Lists/Customer/UTrace.cc\n")
      message(FATAL_ERROR "${_ERR}")
    endif()
    # No need to add any include paths as the required code was copied into UTrace.cc from Siemens' IDEA framework
    list(APPEND LOG_BACKEND_SRCS "${CMAKE_CURRENT_LIST_DIR}/src/misc/UTrace.cc")
  endif(BART_LOG_SIEMENS_BACKEND)

  # ------------------------------------
  
  if(BART_LOG_ORCHESTRA_BACKEND)
    set(OX_INSTALL_DIRECTORY "" CACHE PATH "Install directory of the GE Orchestra SDK")
    set(TOPDIR "${OX_INSTALL_DIRECTORY}/include")
    
    # Include recon libraries exported from the SDK CMake build
    set(RECON_LIBRARIES_INCLUDE_FILE ${OX_INSTALL_DIRECTORY}/lib/ReconLibraries.cmake)
    if(EXISTS ${RECON_LIBRARIES_INCLUDE_FILE})
      include (${RECON_LIBRARIES_INCLUDE_FILE})
    else(EXISTS ${RECON_LIBRARIES_INCLUDE_FILE})
      message("Could not find ${RECON_LIBRARIES_INCLUDE_FILE}")
      message(FATAL_ERROR "Verify that the CMake OX_INSTALL_DIRECTORY option is set correctly")
    endif(EXISTS ${RECON_LIBRARIES_INCLUDE_FILE})
    
    # Include Orchestra SDK build configuration
    include (${TOPDIR}/recon/SDK/product.cmake)

    # FIXME: need to check which libraries are actually required
    target_link_libraries(bartsupport Core Common Control System ${OX_3P_LIBS} ${OX_OS_LIBS})
    
    list(APPEND LOG_BACKEND_SRCS "${CMAKE_CURRENT_LIST_DIR}/src/misc/Orchestra.cc")
  endif(BART_LOG_ORCHESTRA_BACKEND)

  # ------------------------------------

  if(BART_LOG_GADGETRON_BACKEND)
    # Actually we do nothing here, Gagdetron will provide the vendor_log function
  endif(BART_LOG_GADGETRON_BACKEND)
endif(BART_LOG_BACKEND)

set(LOG_BACKEND_SRCS "${LOG_BACKEND_SRCS}" CACHE INTERNAL "")
foreach(file ${LOG_BACKEND_SRCS})
  list(REMOVE_ITEM bart_support_SRCS "${file}")
endforeach()

if(USE_CUDA)
  cuda_wrap_srcs(bartsupport_objs OBJ bartsupport_cuda_objs ${bart_support_CUSRCS})
else()
  set(bart_support_CUDA "")
endif(USE_CUDA)

add_library(bartsupport_objs OBJECT ${bart_support_SRCS})
bart_add_library(bartsupport STATIC $<TARGET_OBJECTS:bartsupport_objs> ${DEBUG_C_FILE} ${BARTSUPPORT_PYTHON_SEPARATE_COMPILATION_FILES} ${bartsupport_cuda_objs})

target_link_libraries(bartsupport PUBLIC ${LINALG_VENDOR_LIB} ${PNG_LIBRARIES} ${FFTWF_LIBRARIES})
if(BART_ISMRMRD)
  target_link_libraries(bartsupport PUBLIC ${ISMRMRD_LIBRARIES})
endif()
set_target_properties(bartsupport
  PROPERTIES
  EXPORT_NAME BARTSUPPORT
  INTERFACE_INCLUDE_DIRECTORIES $<INSTALL_INTERFACE:include/bart>)

## More crafty file manipulation so that we maintain backward comaptibility
## with the Makefile

## Generate combined programs
#==============================================
set(EXTERN_LIST "\n\n/* Generated by cmake */\n")
foreach(driver ${ALLPROGS})
   set(EXTERN_LIST "${EXTERN_LIST}extern int main_${driver}(int argc, char* argv[])__EOL__\n")
endforeach()
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/CombinedCode)
## Configure include header
CONFIG_BY_REPLACEMENT( "${CMAKE_CURRENT_LIST_DIR}/src/main.h" "${CMAKE_CURRENT_BINARY_DIR}/CombinedCode/config_main.h"
                       "/* Generated by cmake */"
                       "MAP(DECLMAIN, MAIN_LIST)" "${EXTERN_LIST}"
                       "misc/cppmap.h" "stdio.h")             ## Replacement 3 no longer need this include 
include_directories(${CMAKE_CURRENT_BINARY_DIR}/CombinedCode)

#==============================================
set(DRIVER_LIST "\n\n/* Generated by cmake */\n")
foreach(driver ${ALLPROGS})
   set(DRIVER_LIST "${DRIVER_LIST}{ main_${driver}, \"${driver}\" },\n")
endforeach()

set(ALL_BART_SRCS "")
set(ALL_BART_LIB_SRCS "")
foreach(curr_prog ${ALLPROGS})
  set(curr_prog_name "${CMAKE_CURRENT_LIST_DIR}/src/${curr_prog}.c")
  set(comb_prog_name "${CMAKE_CURRENT_BINARY_DIR}/CombinedCode/${curr_prog}.c")
  
  CONFIG_BY_REPLACEMENT( ${curr_prog_name} ${comb_prog_name}
    "/* Generated by cmake */\n#include \"config_main.h\""
    "MAP(DENTRY, MAIN_LIST)" "${DRIVER_LIST}")
  list(APPEND ALL_BART_SRCS ${comb_prog_name})
  list(APPEND ALL_BART_LIB_SRCS ${comb_prog_name})
endforeach()
foreach(curr_prog bart)
  CONFIG_BY_REPLACEMENT( "${CMAKE_CURRENT_LIST_DIR}/src/${curr_prog}.c" "${CMAKE_CURRENT_BINARY_DIR}/CombinedCode/${curr_prog}.c"
                         "#include \"config_main.h\""
                         "MAP(DENTRY, MAIN_LIST)" "${DRIVER_LIST}" ## Replacement 1
                         "main_bart" "main"                        ## Replacement 2
                         "misc/cppmap.h" "stdio.h")                ## Replacement 3 no longer need this include 
  CONFIG_BY_REPLACEMENT( "${CMAKE_CURRENT_LIST_DIR}/src/${curr_prog}.c" "${CMAKE_CURRENT_BINARY_DIR}/CombinedCode/${curr_prog}_lib.c"
                         "#include \"config_main.h\""
                         "MAP(DENTRY, MAIN_LIST)" "${DRIVER_LIST}" ## Replacement 1
                         "misc/cppmap.h" "stdio.h")                ## Replacement 2 no longer need this include 
  list(APPEND ALL_BART_SRCS "${CMAKE_CURRENT_BINARY_DIR}/CombinedCode/${curr_prog}.c")
  list(APPEND ALL_BART_LIB_SRCS "${CMAKE_CURRENT_BINARY_DIR}/CombinedCode/${curr_prog}_lib.c")
endforeach()

bart_add_executable(bart ${ALL_BART_SRCS} ${LOG_BACKEND_SRCS})
target_link_libraries(bart PRIVATE bartsupport)
set_target_properties(bart PROPERTIES EXPORT_NAME BART)

set(BARTMAIN_PYTHON_SEPARATE_COMPILATION_FILES
  "${CMAKE_CURRENT_BINARY_DIR}/CombinedCode/bart_lib.c" CACHE INTERNAL "")
foreach(file ${BARTMAIN_PYTHON_SEPARATE_COMPILATION_FILES})
  list(REMOVE_ITEM ALL_BART_LIB_SRCS "${file}")
endforeach()
      
add_library(bartmain_objs OBJECT ${ALL_BART_LIB_SRCS})
add_library(bartmain
  STATIC
  $<TARGET_OBJECTS:bartsupport_objs>
  $<TARGET_OBJECTS:bartmain_objs>
  ${LOG_BACKEND_SRCS}
  ${BARTSUPPORT_PYTHON_SEPARATE_COMPILATION_FILES}
  ${BARTMAIN_PYTHON_SEPARATE_COMPILATION_FILES}
  ${bartsupport_cuda_objs})

target_link_libraries(bartmain PUBLIC ${LINALG_VENDOR_LIB} ${PNG_LIBRARIES} ${FFTWF_LIBRARIES})
if(BART_ISMRMRD)
  target_link_libraries(bartmain PUBLIC ${ISMRMRD_LIBRARIES})
endif()

set_target_properties(bartmain
  PROPERTIES
  EXPORT_NAME BARTMAIN
  INTERFACE_INCLUDE_DIRECTORIES $<INSTALL_INTERFACE:include/bart>)

if(BART_ENABLE_MEM_CFL)
  set_target_properties(bartmain PROPERTIES LINKER_LANGUAGE CXX)
endif(BART_ENABLE_MEM_CFL)

# Workaround for possible name conflicts with libC's error function
target_compile_definitions(bartmain PRIVATE -Derror=bart_error__)
if(BART_LOG_BACKEND)
  # ensure that src/misc/misc.c will be compiled with logging backend support
  # but *ONLY* for the bartmain target
  target_compile_definitions(bartmain PRIVATE -DUSE_LOG_BACKEND)
endif(BART_LOG_BACKEND)

# ==============================================================================

if(BART_CREATE_PYTHON_MODULE)
  if(CMAKE_VERSION VERSION_LESS "3.12")
    find_package(PythonLibs REQUIRED)
    set(PYMODULE_INCLUDE_DIRS "${PYTHON_INCLUDE_DIRS}")
    set(PYMODULE_LIBRARIES "${PYTHON_LIBRARIES}")
  else(CMAKE_VERSION VERSION_LESS "3.12")
    find_package(Python REQUIRED COMPONENTS Development)
    set(PYMODULE_INCLUDE_DIRS "${Python_INCLUDE_DIRS}")
    set(PYMODULE_LIBRARIES "${Python_LIBRARIES}")
  endif(CMAKE_VERSION VERSION_LESS "3.12")

  set(PYBART_FUNCTION_PROTOTYPE "")
  set(PYBART_COMMANDS_MODULE_METHODS "")
  set(PYBART_COMMANDS_IMPLEMENTATION "")
  
  foreach(curr_prog ${ALLPROGS})
    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/src/${curr_prog}.c")
      set(PYBART_FUNCTION_PROTOTYPE "${PYBART_FUNCTION_PROTOTYPE}static PyObject* call_${curr_prog}(PyObject* self, PyObject* args);\n")
      set(PYBART_COMMANDS_MODULE_METHODS "${PYBART_COMMANDS_MODULE_METHODS}     {\"${curr_prog}\", call_${curr_prog}, METH_VARARGS, bart_subcommand_docstring},\n")
      set(PYBART_COMMANDS_IMPLEMENTATION "${PYBART_COMMANDS_IMPLEMENTATION}PyObject* call_${curr_prog} (PyObject* self, PyObject* args)\n{\n     enum { MAX_ARGS = 256 };\n     char* cmdline = NULL;\n     char output[256] = { \"\" };\n     if (!PyArg_ParseTuple(args, \"s\", &cmdline)) {\n	  Py_RETURN_NONE;\n     }\n\n     return call_submain(\"${curr_prog}\", cmdline);\n}\n\n")
    endif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/src/${curr_prog}.c")
  endforeach()

  configure_file(${CMAKE_CURRENT_LIST_DIR}/src/python/pyBART.c.in ${PROJECT_BINARY_DIR}/pyBART.c @ONLY)

  include_directories(${PYMODULE_INCLUDE_DIRS})
  bart_add_library(pyBART
    SHARED
    ${PROJECT_BINARY_DIR}/pyBART.c
    ${BARTSUPPORT_PYTHON_SEPARATE_COMPILATION_FILES}
    ${BARTMAIN_PYTHON_SEPARATE_COMPILATION_FILES}
    $<TARGET_OBJECTS:bartsupport_objs>
    $<TARGET_OBJECTS:bartmain_objs>)
  
  target_compile_definitions(pyBART PRIVATE -DBART_WITH_PYTHON)
  target_link_libraries(pyBART ${PYMODULE_LIBRARIES} ${PNG_LIBRARIES} ${FFTWF_LIBRARIES} ${LINALG_LIBRARIES})
  if(BART_ISMRMRD)
    target_link_libraries(pyBART ${ISMRMRD_LIBRARIES})
  endif()
  set_target_properties(pyBART
    PROPERTIES
    PREFIX ""
    EXPORT_NAME pyBART)
endif(BART_CREATE_PYTHON_MODULE)

#==============================================
# TODO: Matlab code

if(BART_MATLAB)
  find_package(Matlab REQUIRED)
  if(MATLAB_FOUND)
    message(STATUS "MATLAB LIBRARIES FOUND: ${MATLAB_LIBRARIES_DIR}")
    include_directories(${MATLAB_INCLUDE_DIR})
    bart_add_executable(mat2cfl ${CMAKE_CURRENT_LIST_DIR}/src/mat2cfl.c ${LOG_BACKEND_SRCS})
    target_link_libraries(mat2cfl bartsupport ${MATLAB_MAT_LIBRARY} ${MATLAB_ENG_LIBRARY} ${MATLAB_MX_LIBRARY})
    set(BART_MATLAB_TGT mat2cfl)
  endif()
endif()

#==============================================
# Testing code
include(CTest)
enable_testing()

if(BUILD_TESTING)
  file(GLOB utests_list_SRCS "${CMAKE_CURRENT_LIST_DIR}/utests/test_*.c")
  foreach(f ${utests_list_SRCS})
    file(STRINGS ${f} ut_register_lines
      REGEX "UT_REGISTER_TEST\\(.*\\)")
    string(REGEX
      REPLACE "UT_REGISTER_TEST\\(([a-zA-Z0-9_ ]+)\\)[\\r\\n\\t ]*\\;" "\\1"
      tests_list
      "${ut_register_lines}")

    get_filename_component(test_name ${f} NAME_WE)
    set(${test_name}_tests "")
    foreach(sub_test_name ${tests_list})
      set(${test_name}_tests "${${test_name}_tests}call_${sub_test_name},")
    endforeach()

    add_executable(${test_name} ${CMAKE_CURRENT_LIST_DIR}/utests/utest.c ${f})
    target_link_libraries(${test_name} bartsupport)
    target_compile_definitions(${test_name} PUBLIC UTESTS=${${test_name}_tests})
    add_test(${test_name} ${test_name})
  endforeach()
endif(BUILD_TESTING)

# ==============================================================================

include(${CMAKE_CURRENT_LIST_DIR}/cmake/bart_install.cmake)

# ==============================================================================

set(TARBALL_VERSION "${BART_VERSION_MAJOR}.${BART_VERSION_MINOR}.${BART_VERSION_PATCH}")
add_custom_target(tarball
  COMMAND git archive --prefix=bart-${TARBALL_VERSION}/ -o ${CMAKE_CURRENT_BINARY_DIR}/bart-${TARBALL_VERSION}.tar.gz v${TARBALL_VERSION}
  WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
  COMMENT "BUILD TARBALL FOR BART WITH LATEST VERSION"
  )

add_custom_target(doxygen
  COMMAND ${CMAKE_CURRENT_LIST_DIR}/makedoc.sh
  WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
  DEPENDS bart
  SOURCES makedoc.sh doxyconfig)

add_custom_target(bart.syms
  COMMAND ${CMAKE_CURRENT_LIST_DIR}/rules/make_symbol_table.sh $<TARGET_FILE:bart> ${CMAKE_CURRENT_BINARY_DIR}/bart.syms
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  DEPENDS bart
  SOURCES makedoc.sh doxyconfig)

if(BART_GENERATE_DOC)
  add_custom_command(TARGET bart
    POST_BUILD
    COMMAND ${CMAKE_CURRENT_LIST_DIR}/rules/update_commands.sh $<TARGET_FILE:bart> ${CMAKE_CURRENT_LIST_DIR}/doc/commands.txt ${ALLPROGS}
    )
endif(BART_GENERATE_DOC)

