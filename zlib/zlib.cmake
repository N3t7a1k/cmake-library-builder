cmake_minimum_required(VERSION 3.18)
if(NOT CMAKE_PROJECT_NAME)
  project(Zlib)
endif()
include(ExternalProject)
include(ProcessorCount)

option(USE_SHARED "Use shared libraries" OFF)
option(USE_SYSTEM "Use libraries installed in system" OFF)

add_library(zlib INTERFACE)

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(STATIC_LIB_SUFFIX ".lib")
  set(SHARED_LIB_SUFFIX ".dll")
  set(IMPORT_LIB_SUFFIX ".lib")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(STATIC_LIB_SUFFIX ".a")
  set(SHARED_LIB_SUFFIX ".dylib")
  set(IMPORT_LIB_SUFFIX "${SHARED_LIB_SUFFIX}")
else()
  set(STATIC_LIB_SUFFIX ".a")
  set(SHARED_LIB_SUFFIX ".so")
  set(IMPORT_LIB_SUFFIX "${SHARED_LIB_SUFFIX}")
endif()

if(USE_SHARED)
  set(ZLIB_LIB_NAME "libz${SHARED_LIB_SUFFIX}")
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(ZLIB_IMPORT_LIB_NAME "libz${IMPORT_LIB_SUFFIX}")
  endif()
else()
  set(ZLIB_LIB_NAME "libz${STATIC_LIB_SUFFIX}")
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
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    find_path(ZLIB_INCLUDE_DIR
      NAMES zlib.h
      PATHS
        "$ENV{PROGRAMFILES}/zlib/include"
        "$ENV{PROGRAMFILES\(X86\)}/zlib/include"
        "$ENV{ProgramW6432}/zlib/include"
    )
    
    find_library(ZLIB_LIBRARY
      NAMES ${ZLIB_LIB_NAME} ${ZLIB_IMPORT_LIB_NAME}
      PATHS
        "$ENV{PROGRAMFILES}/zlib/lib"
        "$ENV{PROGRAMFILES\(X86\)}/zlib/lib"
        "$ENV{ProgramW6432}/zlib/lib"
    )
  else()
    find_package(PkgConfig QUIET)
    if(PKG_CONFIG_FOUND)
      pkg_check_modules(PC_ZLIB QUIET zlib)
    endif()

    find_path(ZLIB_INCLUDE_DIR
      NAMES zlib.h
      PATHS
        ${PC_ZLIB_INCLUDEDIR}
        /usr/local/include
        /usr/include
    )

    find_library(ZLIB_LIBRARY
      NAMES ${ZLIB_LIB_NAME} z
      PATHS
        ${PC_ZLIB_LIBDIR}
        /usr/local/lib
        /usr/lib
        /usr/lib64
    )
  endif()

  if(ZLIB_INCLUDE_DIR AND ZLIB_LIBRARY)
    message(STATUS "Found system ZLib:")
    message(STATUS "  Include dir: ${ZLIB_INCLUDE_DIR}")
    message(STATUS "  Library: ${ZLIB_LIBRARY}")

    add_library(ZLIB::ZLIB UNKNOWN IMPORTED GLOBAL)

    set_target_properties(ZLIB::ZLIB PROPERTIES
      IMPORTED_LOCATION "${ZLIB_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}"
    )

    if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
      get_filename_component(ZLIB_LIB_DIR "${ZLIB_LIBRARY}" DIRECTORY)
      set_target_properties(ZLIB::ZLIB PROPERTIES
        IMPORTED_IMPLIB "${ZLIB_LIBRARY}"
        IMPORTED_LOCATION "${ZLIB_LIB_DIR}/${ZLIB_LIB_NAME}"
      )
    endif()
  else()
    message(FATAL_ERROR "System ZLib not found")
  endif()
elseif(DEFINED ZLIB_INCLUDE_DIR AND DEFINED ZLIB_LIB_DIR)
  get_filename_component(ZLIB_INCLUDE_DIR "${ZLIB_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  get_filename_component(ZLIB_LIB_DIR "${ZLIB_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  message(STATUS "Using pre-built ZLib library in ${ZLIB_LIB_DIR}")
  
  include_directories(${ZLIB_INCLUDE_DIR})
  link_directories(${ZLIB_LIB_DIR})
  
  add_library(ZLIB::ZLIB UNKNOWN IMPORTED GLOBAL)
  
  set_target_properties(ZLIB::ZLIB PROPERTIES
    IMPORTED_LOCATION "${ZLIB_LIB_DIR}/${ZLIB_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}"
  )
  
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(ZLIB::ZLIB PROPERTIES
      IMPORTED_IMPLIB "${ZLIB_LIB_DIR}/${ZLIB_IMPORT_LIB_NAME}"
    )
  endif()
elseif(DEFINED ZLIB_DIR AND EXISTS ${ZLIB_DIR})
  set(OUTPUT_PATH "${CMAKE_BINARY_DIR}/out")
  set(SOURCE_PATH "${OUTPUT_PATH}/src")
  set(DESTINATION_PATH "${OUTPUT_PATH}/dst")
  
  file(MAKE_DIRECTORY "${SOURCE_PATH}")
  file(ARCHIVE_EXTRACT
    INPUT "${ZLIB_DIR}"
    DESTINATION "${SOURCE_PATH}"
  )
  
  file(GLOB ZLIB_EXTRACTED_DIRS "${SOURCE_PATH}/*")
  list(GET ZLIB_EXTRACTED_DIRS 0 ZLIB_SOURCE_PATH)
  message(STATUS "ZLib source path: ${ZLIB_SOURCE_PATH}")
  
  set(ZLIB_DIR ${DESTINATION_PATH})
  set(ZLIB_INCLUDE_DIR "${ZLIB_DIR}/include")
  set(ZLIB_LIB_DIR "${ZLIB_DIR}/lib")
  
  file(MAKE_DIRECTORY ${ZLIB_INCLUDE_DIR})

  ExternalProject_Add(zlib_build
    SOURCE_DIR ${ZLIB_SOURCE_PATH}
    CMAKE_ARGS
      -DCMAKE_INSTALL_PREFIX=${DESTINATION_PATH}
      ${ZLIB_CMAKE_EXTRA}
    BUILD_COMMAND ${CMAKE_MAKE_PROGRAM} ${MAKE_PARALLEL}
    INSTALL_COMMAND ${CMAKE_MAKE_PROGRAM} ${MAKE_PARALLEL} install
    BUILD_BYPRODUCTS "${ZLIB_LIB_DIR}/${ZLIB_LIB_NAME}"
    LOG_CONFIGURE TRUE
    LOG_BUILD TRUE
    LOG_INSTALL TRUE
  )
  
  add_dependencies(zlib zlib_build)
  
  include_directories(${ZLIB_INCLUDE_DIR})
  link_directories(${ZLIB_LIB_DIR})
  
  add_library(ZLIB::ZLIB UNKNOWN IMPORTED GLOBAL)
  
  set_target_properties(ZLIB::ZLIB PROPERTIES
    IMPORTED_LOCATION "${ZLIB_LIB_DIR}/${ZLIB_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}"
  )
  
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(ZLIB::ZLIB PROPERTIES
      IMPORTED_IMPLIB "${ZLIB_LIB_DIR}/${ZLIB_IMPORT_LIB_NAME}"
    )
  endif()
else()
  message(FATAL_ERROR "Failed to build/load ZLib")
endif()

message(STATUS "Include directory: ${ZLIB_INCLUDE_DIR}")
message(STATUS "Library directory: ${ZLIB_LIB_DIR}")
