cmake_minimum_required(VERSION 3.18)
if(NOT CMAKE_PROJECT_NAME)
  project(LibSodium)
endif()
include(ExternalProject)
include(ProcessorCount)

option(USE_SHARED "Use shared libraries" OFF)
option(USE_SYSTEM "Use libraries installed in system" OFF)

add_library(libsodium INTERFACE)

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(STATIC_LIB_SUFFIX ".lib")
  set(SHARED_LIB_SUFFIX ".dll")
  set(IMPORT_LIB_SUFFIX ".lib")
  set(CONFIGURE_COMMAND "")
  set(BUILD_COMMAND "")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(STATIC_LIB_SUFFIX ".a")
  set(SHARED_LIB_SUFFIX ".dylib")
  set(IMPORT_LIB_SUFFIX "${SHARED_LIB_SUFFIX}")
  set(CONFIGURE_COMMAND sh configure)
  set(BUILD_COMMAND make)
else()
  set(STATIC_LIB_SUFFIX ".a")
  set(SHARED_LIB_SUFFIX ".so")
  set(IMPORT_LIB_SUFFIX "${SHARED_LIB_SUFFIX}")
  set(CONFIGURE_COMMAND sh configure)
  set(BUILD_COMMAND make)
endif()

if(USE_SHARED)
  set(LIBSODIUM_LIB_NAME "libsodium${SHARED_LIB_SUFFIX}")
  set(LIBSODIUM_LIB_NAME "libsodium${SHARED_LIB_SUFFIX}")
  list(APPEND CONFIGURE_OPTIONS "--enable-shared")
  list(APPEND CONFIGURE_OPTIONS "--disable-static")
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(LIBSODIUM_IMPORT_LIB_NAME "libsodium${IMPORT_LIB_SUFFIX}")
  endif()
else()
  set(LIBSODIUM_LIB_NAME "libsodium${STATIC_LIB_SUFFIX}")
  list(APPEND CONFIGURE_OPTIONS "--enable-static")
  list(APPEND CONFIGURE_OPTIONS "--disable-shared")
endif()

ProcessorCount(NPROCS)
if(NPROCS EQUAL 0)
  set(NPROCS 1)
endif()

set(MAKE_PARALLEL "-j${NPROCS}")

if(${USE_SYSTEM})
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    find_path(LIBSODIUM_INCLUDE_DIR
      NAMES sodium.h
      PATHS
        "$ENV{PROGRAMFILES}/libsodium/include"
        "$ENV{PROGRAMFILES\(X86\)}/libsodium/include"
        "$ENV{ProgramW6432}/libsodium/include"
    )
    
    find_library(LIBSODIUM_LIBRARY
      NAMES ${LIBSODIUM_LIB_NAME} ${LIBSODIUM_IMPORT_LIB_NAME}
      PATHS
        "$ENV{PROGRAMFILES}/libsodium/lib"
        "$ENV{PROGRAMFILES\(X86\)}/libsodium/lib"
        "$ENV{ProgramW6432}/libsodium/lib"
    )
  else()
    find_package(PkgConfig QUIET)
    if(PKG_CONFIG_FOUND)
      pkg_check_modules(PC_LIBSODIUM QUIET libsodium)
    endif()

    find_path(LIBSODIUM_INCLUDE_DIR
      NAMES sodium.h
      PATHS
        ${PC_LIBSODIUM_INCLUDEDIR}
        /usr/local/include
        /usr/include
    )

    find_library(LIBSODIUM_LIBRARY
      NAMES ${LIBSODIUM_LIB_NAME} libsodium
      PATHS
        ${PC_LIBSODIUM_LIBDIR}
        /usr/local/lib
        /usr/lib
        /usr/lib64
    )
  endif()

  if(LIBSODIUM_INCLUDE_DIR AND LIBSODIUM_LIBRARY)
    message(STATUS "Found system libsodium:")
    message(STATUS "  Include dir: ${LIBSODIUM_INCLUDE_DIR}")
    message(STATUS "  Library: ${LIBSODIUM_LIBRARY}")

    add_library(libsodium::libsodium UNKNOWN IMPORTED GLOBAL)

    set_target_properties(libsodium::libsodium PROPERTIES
      IMPORTED_LOCATION "${LIBSODIUM_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${LIBSODIUM_INCLUDE_DIR}"
    )

    if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
      get_filename_component(LIBSODIUM_LIB_DIR "${LIBSODIUM_LIBRARY}" DIRECTORY)
      set_target_properties(libsodium::libsodium PROPERTIES
        IMPORTED_IMPLIB "${LIBSODIUM_LIBRARY}"
        IMPORTED_LOCATION "${LIBSODIUM_LIB_DIR}/${LIBSODIUM_LIB_NAME}"
      )
    endif()
  else()
    message(FATAL_ERROR "System libsodium not found")
  endif()
elseif(DEFINED LIBSODIUM_INCLUDE_DIR AND DEFINED LIBSODIUM_LIB_DIR)
  get_filename_component(LIBSODIUM_INCLUDE_DIR "${LIBSODIUM_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  get_filename_component(LIBSODIUM_LIB_DIR "${LIBSODIUM_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  message(STATUS "Using pre-built libsodium library in ${LIBSODIUM_LIB_DIR}")
  
  include_directories(${LIBSODIUM_INCLUDE_DIR})
  link_directories(${LIBSODIUM_LIB_DIR})
  
  add_library(libsodium::libsodium UNKNOWN IMPORTED GLOBAL)
  
  set_target_properties(libsodium::libsodium PROPERTIES
    IMPORTED_LOCATION "${LIBSODIUM_LIB_DIR}/${LIBSODIUM_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBSODIUM_INCLUDE_DIR}"
  )
  
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(libsodium::libsodium PROPERTIES
      IMPORTED_IMPLIB "${LIBSODIUM_LIB_DIR}/${LIBSODIUM_IMPORT_LIB_NAME}"
    )
  endif()
elseif(DEFINED LIBSODIUM_DIR AND EXISTS ${LIBSODIUM_DIR})
  set(OUTPUT_PATH "${CMAKE_BINARY_DIR}/out")
  set(SOURCE_PATH "${OUTPUT_PATH}/src")
  set(DESTINATION_PATH "${OUTPUT_PATH}/dst")
  
  file(MAKE_DIRECTORY "${SOURCE_PATH}")
  file(ARCHIVE_EXTRACT
    INPUT "${LIBSODIUM_DIR}"
    DESTINATION "${SOURCE_PATH}"
  )
  
  file(GLOB LIBSODIUM_EXTRACTED_DIRS "${SOURCE_PATH}/*")
  list(GET LIBSODIUM_EXTRACTED_DIRS 0 LIBSODIUM_SOURCE_PATH)
  message(STATUS "libsodium source path: ${LIBSODIUM_SOURCE_PATH}")
  
  set(LIBSODIUM_DIR ${DESTINATION_PATH})
  set(LIBSODIUM_INCLUDE_DIR "${LIBSODIUM_DIR}/include")
  set(LIBSODIUM_LIB_DIR "${LIBSODIUM_DIR}/lib")
  
  file(MAKE_DIRECTORY ${LIBSODIUM_INCLUDE_DIR})

  ExternalProject_Add(libsodium_build
    SOURCE_DIR ${LIBSODIUM_SOURCE_PATH}
    CONFIGURE_COMMAND 
      ${CMAKE_COMMAND} -E chdir <SOURCE_DIR>
      ${CONFIGURE_COMMAND} --prefix=${DESTINATION_PATH} ${CONFIGURE_OPTIONS}
    BUILD_COMMAND 
      ${CMAKE_COMMAND} -E chdir <SOURCE_DIR>
      ${BUILD_COMMAND} ${MAKE_PARALLEL}
    INSTALL_COMMAND 
      ${CMAKE_COMMAND} -E chdir <SOURCE_DIR>
      ${BUILD_COMMAND} install
    BUILD_BYPRODUCTS "${LIBSODIUM_LIB_DIR}/${LIBSODIUM_LIB_NAME}"
    LOG_CONFIGURE TRUE
    LOG_BUILD TRUE
    LOG_INSTALL TRUE
  )
  
  add_dependencies(libsodium libsodium_build)
  
  include_directories(${LIBSODIUM_INCLUDE_DIR})
  link_directories(${LIBSODIUM_LIB_DIR})
  
  add_library(libsodium::libsodium UNKNOWN IMPORTED GLOBAL)
  
  set_target_properties(libsodium::libsodium PROPERTIES
    IMPORTED_LOCATION "${LIBSODIUM_LIB_DIR}/${LIBSODIUM_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBSODIUM_INCLUDE_DIR}"
  )
  
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(libsodium::libsodium PROPERTIES
      IMPORTED_IMPLIB "${LIBSODIUM_LIB_DIR}/${LIBSODIUM_IMPORT_LIB_NAME}"
    )
  endif()
else()
  message(FATAL_ERROR "Failed to build/load libsodium")
endif()

message(STATUS "Include directory: ${LIBSODIUM_INCLUDE_DIR}")
message(STATUS "Library directory: ${LIBSODIUM_LIB_DIR}")
