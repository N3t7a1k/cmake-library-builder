cmake_minimum_required(VERSION 3.18)
include(ExternalProject)
include(ProcessorCount)

option(USE_SHARED "Use shared libraries" OFF)
option(USE_SYSTEM "Use libraries installed in system" OFF)

add_library(mbedtls INTERFACE)

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
  set(MBEDTLS_LIB_NAME "libmbedtls${SHARED_LIB_SUFFIX}")
  set(MBEDX509_LIB_NAME "libmbedx509${SHARED_LIB_SUFFIX}")
  set(MBEDCRYPTO_LIB_NAME "libmbedcrypto${SHARED_LIB_SUFFIX}")
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(MBEDTLS_IMPORT_LIB_NAME "libmbedtls${IMPORT_LIB_SUFFIX}")
    set(MBEDX509_IMPORT_LIB_NAME "libmbedx509${IMPORT_LIB_SUFFIX}")
    set(MBEDCRYPTO_IMPORT_LIB_NAME "libmbedcrypto${IMPORT_LIB_SUFFIX}")
  endif()
else()
  set(MBEDTLS_LIB_NAME "libmbedtls${STATIC_LIB_SUFFIX}")
  set(MBEDX509_LIB_NAME "libmbedx509${STATIC_LIB_SUFFIX}")
  set(MBEDCRYPTO_LIB_NAME "libmbedcrypto${STATIC_LIB_SUFFIX}")
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
    find_path(MBEDTLS_INCLUDE_DIR
      NAMES mbedtls/ssl.h
      PATHS
        "$ENV{PROGRAMFILES}/mbedtls/include"
        "$ENV{PROGRAMFILES\(X86\)}/mbedtls/include"
        "$ENV{ProgramW6432}/mbedtls/include"
    )
    
    find_library(MBEDTLS_LIBRARY
      NAMES ${MBEDTLS_LIB_NAME} ${MBEDTLS_IMPORT_LIB_NAME}
      PATHS
        "$ENV{PROGRAMFILES}/mbedtls/lib"
        "$ENV{PROGRAMFILES\(X86\)}/mbedtls/lib"
        "$ENV{ProgramW6432}/mbedtls/lib"
    )
    find_library(MBEDX509_LIBRARY
      NAMES ${MBEDX509_LIB_NAME} ${MBEDX509_IMPORT_LIB_NAME}
      PATHS
        "$ENV{PROGRAMFILES}/mbedtls/lib"
        "$ENV{PROGRAMFILES\(X86\)}/mbedtls/lib"
        "$ENV{ProgramW6432}/mbedtls/lib"
    )
    find_library(MBEDCRYPTO_LIBRARY
      NAMES ${MBEDCRYPTO_LIB_NAME} ${MBEDCRYPTO_IMPORT_LIB_NAME}
      PATHS
        "$ENV{PROGRAMFILES}/mbedtls/lib"
        "$ENV{PROGRAMFILES\(X86\)}/mbedtls/lib"
        "$ENV{ProgramW6432}/mbedtls/lib"
    )
  else()
    find_package(PkgConfig QUIET)
    if(PKG_CONFIG_FOUND)
      pkg_check_modules(PC_MBEDTLS QUIET mbedtls)
    endif()

    find_path(MBEDTLS_INCLUDE_DIR
      NAMES mbedtls/ssl.h
      PATHS
        ${PC_MBEDTLS_INCLUDEDIR}
        /usr/local/include
        /usr/include
      PATH_SUFFIXES mbedtls
    )

    find_library(MBEDTLS_LIBRARY
      NAMES ${MBEDTLS_LIB_NAME}
      PATHS
        ${PC_MBEDTLS_LIBDIR}
        /usr/local/lib
        /usr/lib
        /usr/lib64
    )
    find_library(MBEDX509_LIBRARY
      NAMES ${MBEDX509_LIB_NAME}
      PATHS
        ${PC_MBEDTLS_LIBDIR}
        /usr/local/lib
        /usr/lib
        /usr/lib64
    )
    find_library(MBEDCRYPTO_LIBRARY
      NAMES ${MBEDCRYPTO_LIB_NAME}
      PATHS
        ${PC_MBEDTLS_LIBDIR}
        /usr/local/lib
        /usr/lib
        /usr/lib64
    )
  endif()

  if(MBEDTLS_INCLUDE_DIR AND MBEDTLS_LIBRARY AND MBEDX509_LIBRARY AND MBEDCRYPTO_LIBRARY)
    message(STATUS "Found system MbedTLS:")
    message(STATUS "  Include dir: ${MBEDTLS_INCLUDE_DIR}")
    message(STATUS "  MbedTLS library: ${MBEDTLS_LIBRARY}")
    message(STATUS "  MbedX509 library: ${MBEDX509_LIBRARY}")
    message(STATUS "  MbedCrypto library: ${MBEDCRYPTO_LIBRARY}")

    add_library(MbedTLS::mbedtls UNKNOWN IMPORTED GLOBAL)
    add_library(MbedTLS::mbedx509 UNKNOWN IMPORTED GLOBAL)
    add_library(MbedTLS::mbedcrypto UNKNOWN IMPORTED GLOBAL)

    set_target_properties(MbedTLS::mbedtls PROPERTIES
      IMPORTED_LOCATION "${MBEDTLS_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}"
    )
    set_target_properties(MbedTLS::mbedx509 PROPERTIES
      IMPORTED_LOCATION "${MBEDX509_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}"
    )
    set_target_properties(MbedTLS::mbedcrypto PROPERTIES
      IMPORTED_LOCATION "${MBEDCRYPTO_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}"
    )

    if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
      get_filename_component(MBEDTLS_LIB_DIR "${MBEDTLS_LIBRARY}" DIRECTORY)
      set_target_properties(MbedTLS::mbedtls PROPERTIES
        IMPORTED_IMPLIB "${MBEDTLS_LIBRARY}"
        IMPORTED_LOCATION "${MBEDTLS_LIB_DIR}/${MBEDTLS_LIB_NAME}"
      )
      set_target_properties(MbedTLS::mbedx509 PROPERTIES
        IMPORTED_IMPLIB "${MBEDX509_LIBRARY}"
        IMPORTED_LOCATION "${MBEDTLS_LIB_DIR}/${MBEDX509_LIB_NAME}"
      )
      set_target_properties(MbedTLS::mbedcrypto PROPERTIES
        IMPORTED_IMPLIB "${MBEDCRYPTO_LIBRARY}"
        IMPORTED_LOCATION "${MBEDTLS_LIB_DIR}/${MBEDCRYPTO_LIB_NAME}"
      )
    endif()
  else()
    message(FATAL_ERROR "System MbedTLS not found")
  endif()
elseif(DEFINED MBEDTLS_INCLUDE_DIR AND DEFINED MBEDTLS_LIB_DIR)
  get_filename_component(MBEDTLS_INCLUDE_DIR "${MBEDTLS_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  get_filename_component(MBEDTLS_LIB_DIR "${MBEDTLS_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  message(STATUS "Using pre-built MbedTLS library in ${MBEDTLS_LIB_DIR}")
  
  include_directories(${MBEDTLS_INCLUDE_DIR})
  link_directories(${MBEDTLS_LIB_DIR})
  
  add_library(MbedTLS::mbedtls UNKNOWN IMPORTED GLOBAL)
  add_library(MbedTLS::mbedx509 UNKNOWN IMPORTED GLOBAL)
  add_library(MbedTLS::mbedcrypto UNKNOWN IMPORTED GLOBAL)
  
  set_target_properties(MbedTLS::mbedtls PROPERTIES
    IMPORTED_LOCATION "${MBEDTLS_LIB_DIR}/${MBEDTLS_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}"
  )
  set_target_properties(MbedTLS::mbedx509 PROPERTIES
    IMPORTED_LOCATION "${MBEDTLS_LIB_DIR}/${MBEDX509_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}"
  )
  set_target_properties(MbedTLS::mbedcrypto PROPERTIES
    IMPORTED_LOCATION "${MBEDTLS_LIB_DIR}/${MBEDCRYPTO_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}"
  )
  
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(MbedTLS::mbedtls PROPERTIES
      IMPORTED_IMPLIB "${MBEDTLS_LIB_DIR}/${MBEDTLS_IMPORT_LIB_NAME}"
    )
    set_target_properties(MbedTLS::mbedx509 PROPERTIES
      IMPORTED_IMPLIB "${MBEDTLS_LIB_DIR}/${MBEDX509_IMPORT_LIB_NAME}"
    )
    set_target_properties(MbedTLS::mbedcrypto PROPERTIES
      IMPORTED_IMPLIB "${MBEDTLS_LIB_DIR}/${MBEDCRYPTO_IMPORT_LIB_NAME}"
    )
  endif()
elseif(DEFINED MBEDTLS_DIR AND EXISTS ${MBEDTLS_DIR})
  set(OUTPUT_PATH "${CMAKE_BINARY_DIR}/out")
  set(SOURCE_PATH "${OUTPUT_PATH}/src")
  set(DESTINATION_PATH "${OUTPUT_PATH}/dst")
  
  file(MAKE_DIRECTORY "${SOURCE_PATH}")
  file(ARCHIVE_EXTRACT
    INPUT "${MBEDTLS_DIR}"
    DESTINATION "${SOURCE_PATH}"
  )
  
  file(GLOB MBEDTLS_EXTRACTED_DIRS "${SOURCE_PATH}/*")
  list(GET MBEDTLS_EXTRACTED_DIRS 0 MBEDTLS_SOURCE_PATH)
  message(STATUS "MbedTLS source path: ${MBEDTLS_SOURCE_PATH}")
  
  set(MBEDTLS_DIR ${DESTINATION_PATH})
  set(MBEDTLS_INCLUDE_DIR "${MBEDTLS_DIR}/include")
  set(MBEDTLS_LIB_DIR "${MBEDTLS_DIR}/lib")
  
  file(MAKE_DIRECTORY ${MBEDTLS_INCLUDE_DIR})

  ExternalProject_Add(mbedtls_build
    SOURCE_DIR ${MBEDTLS_SOURCE_PATH}
    CMAKE_ARGS
      -DCMAKE_INSTALL_PREFIX=${DESTINATION_PATH}
      -DUSE_SHARED_MBEDTLS_LIBRARY=${USE_SHARED}
      -DENABLE_TESTING=OFF
      -DENABLE_PROGRAMS=OFF
      ${MBEDTLS_CMAKE_EXTRA}
    BUILD_COMMAND ${CMAKE_MAKE_PROGRAM} ${MAKE_PARALLEL}
    INSTALL_COMMAND ${CMAKE_MAKE_PROGRAM} ${MAKE_PARALLEL} install
    BUILD_BYPRODUCTS
      "${MBEDTLS_LIB_DIR}/${MBEDTLS_LIB_NAME}"
      "${MBEDTLS_LIB_DIR}/${MBEDX509_LIB_NAME}"
      "${MBEDTLS_LIB_DIR}/${MBEDCRYPTO_LIB_NAME}"
    LOG_CONFIGURE TRUE
    LOG_BUILD TRUE
    LOG_INSTALL TRUE
  )
  
  add_dependencies(mbedtls mbedtls_build)
  
  include_directories(${MBEDTLS_INCLUDE_DIR})
  link_directories(${MBEDTLS_LIB_DIR})
  
  add_library(MbedTLS::mbedtls UNKNOWN IMPORTED GLOBAL)
  add_library(MbedTLS::mbedx509 UNKNOWN IMPORTED GLOBAL)
  add_library(MbedTLS::mbedcrypto UNKNOWN IMPORTED GLOBAL)
  
  set_target_properties(MbedTLS::mbedtls PROPERTIES
    IMPORTED_LOCATION "${MBEDTLS_LIB_DIR}/${MBEDTLS_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}"
  )
  set_target_properties(MbedTLS::mbedx509 PROPERTIES
    IMPORTED_LOCATION "${MBEDTLS_LIB_DIR}/${MBEDX509_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}"
  )
  set_target_properties(MbedTLS::mbedcrypto PROPERTIES
    IMPORTED_LOCATION "${MBEDTLS_LIB_DIR}/${MBEDCRYPTO_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}"
  )
  
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(MbedTLS::mbedtls PROPERTIES
      IMPORTED_IMPLIB "${MBEDTLS_LIB_DIR}/${MBEDTLS_IMPORT_LIB_NAME}"
    )
    set_target_properties(MbedTLS::mbedx509 PROPERTIES
      IMPORTED_IMPLIB "${MBEDX509_LIB_DIR}/${MBEDX509_IMPORT_LIB_NAME}"
    )
    set_target_properties(MbedTLS::mbedcrypto PROPERTIES
      IMPORTED_IMPLIB "${MBEDTLS_LIB_DIR}/${MBEDCRYPTO_IMPORT_LIB_NAME}"
    )
  endif()
else()
  message(FATAL_ERROR "Failed to build/load MbedTLS")
endif()

message(STATUS "Include directory: ${MBEDTLS_INCLUDE_DIR}")
message(STATUS "Library directory: ${MBEDTLS_LIB_DIR}")
