cmake_minimum_required(VERSION 3.18)
if(NOT CMAKE_PROJECT_NAME)
  project(LibPCAP)
endif()
include(ExternalProject)
include(ProcessorCount)

find_package(FLEX)
if(NOT FLEX_FOUND)
  find_program(FLEX_EXECUTABLE NAMES win_flex lex)
  if(NOT FLEX_EXECUTABLE)
    message(FATAL_ERROR "flex, win_flex, or lex is required to build libpcap. Please install flex package.")
  endif()
endif()

find_package(BISON)
if(NOT BISON_FOUND)
  find_program(BISON_EXECUTABLE NAMES win_bison yacc)
  if(NOT BISON_EXECUTABLE)
    message(FATAL_ERROR "bison, win_bison, or yacc is required to build libpcap. Please install bison package.")
  endif()
endif()

option(USE_SHARED "Use shared libraries" OFF)
option(USE_SYSTEM "Use libraries installed in system" OFF)

option(USE_LIBNL "Enable libnl support" OFF)
option(USE_DBUS "Enable DBUS support" OFF)
option(USE_BLUETOOTH "Enable Bluetooth support" OFF)
option(USE_USB "Enable USB support" OFF)
option(USE_RDMA "Enable RDMA support" OFF)

add_library(libpcap INTERFACE)

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(STATIC_LIB_SUFFIX ".lib")
  set(SHARED_LIB_SUFFIX ".dll")
  set(IMPORT_LIB_SUFFIX ".lib")
  set(LIBPCAP_PREFIX "")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(STATIC_LIB_SUFFIX ".a")
  set(SHARED_LIB_SUFFIX ".dylib")
  set(IMPORT_LIB_SUFFIX "${SHARED_LIB_SUFFIX}")
  set(LIBPCAP_PREFIX "lib")
else()
  set(STATIC_LIB_SUFFIX ".a")
  set(SHARED_LIB_SUFFIX ".so")
  set(IMPORT_LIB_SUFFIX "${SHARED_LIB_SUFFIX}")
  set(LIBPCAP_PREFIX "lib")
endif()

if(USE_SHARED)
  set(LIBPCAP_NAME "${LIBPCAP_PREFIX}pcap${SHARED_LIB_SUFFIX}")
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(LIBPCAP_IMPORT_NAME "wpcap${IMPORT_LIB_SUFFIX}")
  endif()
else()
  set(LIBPCAP_NAME "${LIBPCAP_PREFIX}pcap${STATIC_LIB_SUFFIX}")
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(LIBPCAP_NAME "wpcap${STATIC_LIB_SUFFIX}")
  endif()
endif()

if(${USE_SYSTEM})
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    find_path(LIBPCAP_INCLUDE_DIR
      NAMES pcap/pcap.h pcap.h
      PATHS
        "$ENV{PROGRAMFILES}/WpdPack/Include"
        "$ENV{PROGRAMFILES\(X86\)}/WpdPack/Include"
        "$ENV{ProgramW6432}/WpdPack/Include"
    )
    
    find_library(LIBPCAP_LIBRARY
      NAMES ${LIBPCAP_NAME} ${LIBPCAP_IMPORT_NAME}
      PATHS
        "$ENV{PROGRAMFILES}/WpdPack/Lib"
        "$ENV{PROGRAMFILES\(X86\)}/WpdPack/Lib"
        "$ENV{ProgramW6432}/WpdPack/Lib"
        "$ENV{PROGRAMFILES}/WpdPack/Lib/x64"
        "$ENV{PROGRAMFILES\(X86\)}/WpdPack/Lib/x64"
        "$ENV{ProgramW6432}/WpdPack/Lib/x64"
    )
  else()
    find_package(PkgConfig QUIET)
    if(PKG_CONFIG_FOUND)
      pkg_check_modules(PC_LIBPCAP QUIET libpcap)
    endif()

    find_path(LIBPCAP_INCLUDE_DIR
      NAMES pcap/pcap.h pcap.h
      PATHS
        ${PC_LIBPCAP_INCLUDEDIR}
        /usr/local/include
        /usr/include
    )

    find_library(LIBPCAP_LIBRARY
      NAMES ${LIBPCAP_NAME}
      PATHS
        ${PC_LIBPCAP_LIBDIR}
        /usr/local/lib
        /usr/lib
        /usr/lib64
    )
  endif()

  if(LIBPCAP_INCLUDE_DIR AND LIBPCAP_LIBRARY)
    message(STATUS "Found system libpcap:")
    message(STATUS "  Include dir: ${LIBPCAP_INCLUDE_DIR}")
    message(STATUS "  Library: ${LIBPCAP_LIBRARY}")

    add_library(PCAP::pcap UNKNOWN IMPORTED GLOBAL)
    set_target_properties(PCAP::pcap PROPERTIES
      IMPORTED_LOCATION "${LIBPCAP_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${LIBPCAP_INCLUDE_DIR}"
    )

    if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
      get_filename_component(LIBPCAP_LIB_DIR "${LIBPCAP_LIBRARY}" DIRECTORY)
      set_target_properties(PCAP::pcap PROPERTIES
        IMPORTED_IMPLIB "${LIBPCAP_LIBRARY}"
        IMPORTED_LOCATION "${LIBPCAP_LIB_DIR}/${LIBPCAP_NAME}"
      )
    endif()
  else()
    message(FATAL_ERROR "System libpcap not found")
  endif()
elseif(DEFINED LIBPCAP_INCLUDE_DIR AND DEFINED LIBPCAP_LIB_DIR)
  get_filename_component(LIBPCAP_INCLUDE_DIR "${LIBPCAP_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  get_filename_component(LIBPCAP_LIB_DIR "${LIBPCAP_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  message(STATUS "Using pre-built libpcap library in ${LIBPCAP_LIB_DIR}")
  
  include_directories(${LIBPCAP_INCLUDE_DIR})
  link_directories(${LIBPCAP_LIB_DIR})
  
  add_library(PCAP::pcap UNKNOWN IMPORTED GLOBAL)
  
  set_target_properties(PCAP::pcap PROPERTIES
    IMPORTED_LOCATION "${LIBPCAP_LIB_DIR}/${LIBPCAP_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBPCAP_INCLUDE_DIR}"
  )
  
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(PCAP::pcap PROPERTIES
      IMPORTED_IMPLIB "${LIBPCAP_LIB_DIR}/${LIBPCAP_IMPORT_NAME}"
    )
  endif()
elseif(DEFINED LIBPCAP_DIR AND EXISTS ${LIBPCAP_DIR})
  set(OUTPUT_PATH "${CMAKE_BINARY_DIR}/out")
  set(SOURCE_PATH "${OUTPUT_PATH}/src")
  set(DESTINATION_PATH "${OUTPUT_PATH}/dst")
  
  file(MAKE_DIRECTORY "${SOURCE_PATH}")
  file(ARCHIVE_EXTRACT
    INPUT "${LIBPCAP_DIR}"
    DESTINATION "${SOURCE_PATH}"
  )
  
  file(GLOB LIBPCAP_EXTRACTED_DIRS "${SOURCE_PATH}/*")
  list(GET LIBPCAP_EXTRACTED_DIRS 0 LIBPCAP_SOURCE_PATH)
  message(STATUS "libpcap source path: ${LIBPCAP_SOURCE_PATH}")
  
  set(LIBPCAP_DIR ${DESTINATION_PATH})
  set(LIBPCAP_INCLUDE_DIR "${LIBPCAP_DIR}/include")
  set(LIBPCAP_LIB_DIR "${LIBPCAP_DIR}/lib")
  
  file(MAKE_DIRECTORY ${LIBPCAP_INCLUDE_DIR})

  ProcessorCount(NPROCS)
  if(NPROCS EQUAL 0)
    set(NPROCS 1)
  endif()
  set(MAKE_PARALLEL "-j${NPROCS}")

  find_program(GNU_MAKE_COMMAND NAMES gmake make)
  if(NOT GNU_MAKE_COMMAND)
    message(FATAL_ERROR "GNU Make is required for building libpcap")
  endif()
  set(MAKE_COMMAND ${GNU_MAKE_COMMAND})

  if(UNIX AND NOT APPLE AND NOT DEFINED CMAKE_USE_LIBNL)
    set(USE_LIBNL ON)
  endif()

  if(EXISTS "${LIBPCAP_SOURCE_PATH}/CMakeLists.txt")
    message(STATUS "Using CMake build for libpcap")

    if(USE_DBUS)
      set(DISABLE_DBUS OFF)
    else()
      set(DISABLE_DBUS ON)
    endif()
    
    if(USE_BLUETOOTH)
      set(DISABLE_BLUETOOTH OFF)
    else()
      set(DISABLE_BLUETOOTH ON)
    endif()
    
    if(USE_USB)
      set(DISABLE_USB OFF)
    else()
      set(DISABLE_USB ON)
    endif()

    if(USE_RDMA)
      set(DISABLE_RDMA OFF)
    else()
      set(DISABLE_RDMA ON)
    endif()

    if(USE_LIBNL)
      set(LIBNL_ARG "-DBUILD_WITH_LIBNL=ON")
    else()
      set(LIBNL_ARG "-DBUILD_WITH_LIBNL=OFF")
    endif()

    ExternalProject_Add(libpcap_build
      SOURCE_DIR ${LIBPCAP_SOURCE_PATH}
      BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/libpcap-build
      CMAKE_ARGS
        -DCMAKE_INSTALL_PREFIX:PATH=${DESTINATION_PATH}
        -DCMAKE_BUILD_TYPE:STRING=Release
        -DBUILD_SHARED_LIBS:BOOL=${USE_SHARED}
        -DDISABLE_DBUS:BOOL=${DISABLE_DBUS}
        -DDISABLE_BLUETOOTH:BOOL=${DISABLE_BLUETOOTH}
        -DDISABLE_USB:BOOL=${DISABLE_USB}
        -DDISABLE_RDMA:BOOL=${DISABLE_RDMA}
        ${LIBNL_ARG}
        ${LIBPCAP_CMAKE_EXTRA}
      BUILD_COMMAND ${CMAKE_COMMAND} --build .
      INSTALL_COMMAND ${CMAKE_COMMAND} --install .
      BUILD_BYPRODUCTS
        "${LIBPCAP_LIB_DIR}/${LIBPCAP_NAME}"
      LOG_CONFIGURE TRUE
      LOG_BUILD TRUE
      LOG_INSTALL TRUE
    )
  else()
    message(STATUS "Using autotools build for libpcap")
    if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
      message(FATAL_ERROR "Autotools build is not supported on Windows")
    endif()
    
    set(CONFIGURE_OPTIONS "")
    if(NOT USE_DBUS)
      list(APPEND CONFIGURE_OPTIONS "--disable-dbus")
    endif()
    if(NOT USE_BLUETOOTH)
      list(APPEND CONFIGURE_OPTIONS "--disable-bluetooth")
    endif()
    if(NOT USE_USB)
      list(APPEND CONFIGURE_OPTIONS "--disable-usb")
    endif()
    if(NOT USE_LIBNL)
      list(APPEND CONFIGURE_OPTIONS "--disable-libnl")
    endif()
    
    ExternalProject_Add(libpcap_build
      SOURCE_DIR ${LIBPCAP_SOURCE_PATH}
      BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/libpcap-build
      CMAKE_GENERATOR "Unix Makefiles"
      CONFIGURE_COMMAND 
        "${LIBPCAP_SOURCE_PATH}/configure"
        --prefix=${DESTINATION_PATH}
        ${CONFIGURE_OPTIONS}
        $<IF:$<BOOL:${USE_SHARED}>,--enable-shared,--disable-shared>
        ${LIBPCAP_CONFIGURE_EXTRA}
      BUILD_COMMAND ${MAKE_COMMAND} ${MAKE_PARALLEL}
      INSTALL_COMMAND ${MAKE_COMMAND} ${MAKE_PARALLEL} install
      BUILD_BYPRODUCTS
        "${LIBPCAP_LIB_DIR}/${LIBPCAP_NAME}"
      LOG_CONFIGURE TRUE
      LOG_BUILD TRUE
      LOG_INSTALL TRUE
    )
  endif()
  
  add_dependencies(libpcap libpcap_build)
  
  include_directories(${LIBPCAP_INCLUDE_DIR})
  link_directories(${LIBPCAP_LIB_DIR})
  
  add_library(PCAP::pcap UNKNOWN IMPORTED GLOBAL)
  
  set_target_properties(PCAP::pcap PROPERTIES
    IMPORTED_LOCATION "${LIBPCAP_LIB_DIR}/${LIBPCAP_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBPCAP_INCLUDE_DIR}"
  )
  
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(PCAP::pcap PROPERTIES
      IMPORTED_IMPLIB "${LIBPCAP_LIB_DIR}/${LIBPCAP_IMPORT_NAME}"
    )
  endif()
else()
  message(FATAL_ERROR "Failed to build/load libpcap")
endif()

message(STATUS "Include directory: ${LIBPCAP_INCLUDE_DIR}")
message(STATUS "Library directory: ${LIBPCAP_LIB_DIR}")
