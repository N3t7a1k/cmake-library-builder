cmake_minimum_required(VERSION 3.18)
if(NOT CMAKE_PROJECT_NAME)
  project(LibNL)
endif()
include(ExternalProject)
include(ProcessorCount)

option(USE_SHARED "Use shared libraries" OFF)
option(USE_SYSTEM "Use libraries installed in system" OFF)

add_library(libnl INTERFACE)

set(STATIC_LIB_SUFFIX ".a")
set(SHARED_LIB_SUFFIX ".so")

if(USE_SHARED)
  set(LIBNL_LIB_NAME "libnl-3${SHARED_LIB_SUFFIX}")
else()
  set(LIBNL_LIB_NAME "libnl-3${STATIC_LIB_SUFFIX}")
endif()

ProcessorCount(NPROCS)
if(NPROCS EQUAL 0)
  set(NPROCS 1)
endif()

set(MAKE_PARALLEL "")
if(CMAKE_GENERATOR STREQUAL "Ninja" OR CMAKE_GENERATOR STREQUAL "Unix Makefiles")
  set(MAKE_PARALLEL "-j${NPROCS}")
endif()

if(${USE_SYSTEM})
  find_package(PkgConfig QUIET)
  if(PKG_CONFIG_FOUND)
    pkg_check_modules(PC_LIBNL QUIET libnl-3.0)
  endif()

  find_path(LIBNL_INCLUDE_DIR
    NAMES netlink/netlink.h
    PATHS
      ${PC_LIBNL_INCLUDEDIR}
      /usr/local/include/libnl3
      /usr/include/libnl3
  )

  find_library(LIBNL_LIBRARY
    NAMES ${LIBNL_LIB_NAME} nl-3
    PATHS
      ${PC_LIBNL_LIBDIR}
      /usr/local/lib
      /usr/lib
      /usr/lib64
  )

  if(LIBNL_INCLUDE_DIR AND LIBNL_LIBRARY)
    message(STATUS "Found system LibNL:")
    message(STATUS "  Include dir: ${LIBNL_INCLUDE_DIR}")
    message(STATUS "  Library: ${LIBNL_LIBRARY}")

    add_library(LIBNL::LIBNL UNKNOWN IMPORTED GLOBAL)
    set_target_properties(LIBNL::LIBNL PROPERTIES
      IMPORTED_LOCATION "${LIBNL_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${LIBNL_INCLUDE_DIR}"
    )
  else()
    message(FATAL_ERROR "System LibNL not found")
  endif()

elseif(DEFINED LIBNL_INCLUDE_DIR AND DEFINED LIBNL_LIB_DIR)
  get_filename_component(LIBNL_INCLUDE_DIR "${LIBNL_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  get_filename_component(LIBNL_LIB_DIR "${LIBNL_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  message(STATUS "Using pre-built LibNL library in ${LIBNL_LIB_DIR}")
  
  include_directories(${LIBNL_INCLUDE_DIR})
  link_directories(${LIBNL_LIB_DIR})
  
  add_library(LIBNL::LIBNL UNKNOWN IMPORTED GLOBAL)
  set_target_properties(LIBNL::LIBNL PROPERTIES
    IMPORTED_LOCATION "${LIBNL_LIB_DIR}/${LIBNL_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBNL_INCLUDE_DIR}"
  )

elseif(DEFINED LIBNL_DIR AND EXISTS ${LIBNL_DIR})
  set(OUTPUT_PATH "${CMAKE_BINARY_DIR}/out")
  set(SOURCE_PATH "${OUTPUT_PATH}/src")
  set(DESTINATION_PATH "${OUTPUT_PATH}/dst")
  
  file(MAKE_DIRECTORY "${SOURCE_PATH}")
  file(ARCHIVE_EXTRACT
    INPUT "${LIBNL_DIR}"
    DESTINATION "${SOURCE_PATH}"
  )
  
  file(GLOB LIBNL_EXTRACTED_DIRS "${SOURCE_PATH}/*")
  list(GET LIBNL_EXTRACTED_DIRS 0 LIBNL_SOURCE_PATH)
  message(STATUS "LibNL source path: ${LIBNL_SOURCE_PATH}")
  
  set(LIBNL_DIR ${DESTINATION_PATH})
  set(LIBNL_INCLUDE_DIR "${LIBNL_DIR}/include")
  set(LIBNL_LIB_DIR "${LIBNL_DIR}/lib")
  
  file(MAKE_DIRECTORY ${LIBNL_INCLUDE_DIR})

  if(USE_SHARED)
    set(LIBNL_CONFIGURE_FLAGS
      --includedir=${DESTINATION_PATH}/include)
  else()
    set(LIBNL_CONFIGURE_FLAGS
      --enable-static
      --disable-shared
      --includedir=${DESTINATION_PATH}/include)
  endif()

  ExternalProject_Add(libnl_build
    SOURCE_DIR ${LIBNL_SOURCE_PATH}
    CONFIGURE_COMMAND 
      ${LIBNL_SOURCE_PATH}/configure
      --prefix=${DESTINATION_PATH}
      ${LIBNL_CONFIGURE_FLAGS}
      ${LIBNL_CONFIGURE_EXTRA}
    BUILD_COMMAND make ${MAKE_PARALLEL}
    INSTALL_COMMAND make ${MAKE_PARALLEL} install
    COMMAND ${CMAKE_COMMAND} -E copy_directory 
      ${DESTINATION_PATH}/include/libnl3/netlink
      ${DESTINATION_PATH}/include/netlink
    COMMAND ${CMAKE_COMMAND} -E remove_directory
      ${DESTINATION_PATH}/include/libnl3
    BUILD_BYPRODUCTS "${LIBNL_LIB_DIR}/${LIBNL_LIB_NAME}"
    LOG_CONFIGURE TRUE
    LOG_BUILD TRUE
    LOG_INSTALL TRUE
  )
  
  add_dependencies(libnl libnl_build)
  
  include_directories(${LIBNL_INCLUDE_DIR})
  link_directories(${LIBNL_LIB_DIR})
  
  add_library(LIBNL::LIBNL UNKNOWN IMPORTED GLOBAL)
  set_target_properties(LIBNL::LIBNL PROPERTIES
    IMPORTED_LOCATION "${LIBNL_LIB_DIR}/${LIBNL_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBNL_INCLUDE_DIR}"
  )

else()
  message(FATAL_ERROR "Failed to build/load LibNL")
endif()

message(STATUS "Include directory: ${LIBNL_INCLUDE_DIR}")
message(STATUS "Library directory: ${LIBNL_LIB_DIR}")
