cmake_minimum_required(VERSION 3.18)
if(NOT CMAKE_PROJECT_NAME)
  project(LibPCAP)
endif()
include(ExternalProject)
include(ProcessorCount)

find_package(FLEX REQUIRED)
find_package(BISON REQUIRED)

option(USE_SHARED "Use shared libraries" OFF)
option(USE_SYSTEM "Use libraries installed in system" OFF)

option(USE_LIBNL "Enable libnl support" OFF)
option(USE_DBUS "Enable DBUS support" OFF)
option(USE_BLUETOOTH "Enable Bluetooth support" OFF)
option(USE_USB "Enable USB support" OFF)
option(USE_RDMA "Enable RDMA support" OFF)

add_library(libpcap INTERFACE)

set(LIB_PREFIX "lib")
set(STATIC_LIB_SUFFIX ".a")
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(SHARED_LIB_SUFFIX ".dylib")
else()
  set(SHARED_LIB_SUFFIX ".so")
endif()

if(USE_SHARED)
  set(LIBPCAP_LIB_NAME "${LIB_PREFIX}pcap${SHARED_LIB_SUFFIX}")
else()
  set(LIBPCAP_LIB_NAME "${LIB_PREFIX}pcap${STATIC_LIB_SUFFIX}")
endif()

macro(find_libnl)
  if(USE_SHARED)
    set(LIBNL_LIB_NAME "${LIB_PREFIX}nl-3${SHARED_LIB_SUFFIX}")
  else()
    set(LIBNL_LIB_NAME "${LIB_PREFIX}nl-3${STATIC_LIB_SUFFIX}")
  endif()

  if(DEFINED LIBNL_INCLUDE_DIR AND DEFINED LIBNL_LIB_DIR)
    get_filename_component(LIBNL_INCLUDE_DIR "${LIBNL_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    get_filename_component(LIBNL_LIB_DIR "${LIBNL_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    set(LIBNL_LIBRARY "${LIBNL_LIB_DIR}/${LIBNL_LIB_NAME}")

    add_library(LIBNL::LIBNL UNKNOWN IMPORTED GLOBAL)
    set_target_properties(LIBNL::LIBNL PROPERTIES
      IMPORTED_LOCATION "${LIBNL_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${LIBNL_INCLUDE_DIR}"
    )
  else()
    if(CMAKE_CROSSCOMPILING)
      message(FATAL_ERROR "Cross-compiling requires LIBNL_INCLUDE_DIR and LIBNL_LIB_DIR to be specified")
    endif()

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
      NAMES ${LIBNL_LIB_NAME}
      PATHS
        ${PC_LIBNL_LIBDIR}
        /usr/local/lib
        /usr/lib
        /usr/lib64
    )

    if(LIBNL_INCLUDE_DIR AND LIBNL_LIBRARY)
      add_library(LIBNL::LIBNL UNKNOWN IMPORTED GLOBAL)
      set_target_properties(LIBNL::LIBNL PROPERTIES
        IMPORTED_LOCATION "${LIBNL_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${LIBNL_INCLUDE_DIR}"
      )
    else()
      message(FATAL_ERROR "System LibNL not found. Please install libnl3-dev package or specify LIBNL_INCLUDE_DIR and LIBNL_LIB_DIR")
    endif()
  endif()
endmacro()

macro(setup_pcap_target)
  if(NOT TARGET PCAP::PCAP)
    add_library(PCAP::PCAP UNKNOWN IMPORTED GLOBAL)
  endif()

  if(TARGET libpcap_build)
    add_dependencies(PCAP::PCAP libpcap_build)
  endif()
  
  set_target_properties(PCAP::PCAP PROPERTIES
    IMPORTED_LOCATION "${LIBPCAP_LIB_DIR}/${LIBPCAP_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBPCAP_INCLUDE_DIR}"
  )

  if(USE_LIBNL)
    set_property(TARGET PCAP::PCAP APPEND PROPERTY
      INTERFACE_LINK_LIBRARIES LIBNL::LIBNL)
  endif()
endmacro()

if(UNIX AND NOT APPLE AND NOT DEFINED CMAKE_USE_LIBNL)
  set(USE_LIBNL ON)
endif()

if(USE_LIBNL)
  find_libnl()
endif()

if(USE_SYSTEM)
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
    NAMES ${LIBPCAP_LIB_NAME}
    PATHS
      ${PC_LIBPCAP_LIBDIR}
      /usr/local/lib
      /usr/lib
      /usr/lib64
  )

  if(LIBPCAP_INCLUDE_DIR AND LIBPCAP_LIBRARY)
    get_filename_component(LIBPCAP_LIB_DIR "${LIBPCAP_LIBRARY}" DIRECTORY)
    setup_pcap_target()
  else()
    message(FATAL_ERROR "System libpcap not found")
  endif()

elseif(DEFINED LIBPCAP_INCLUDE_DIR AND DEFINED LIBPCAP_LIB_DIR)
  get_filename_component(LIBPCAP_INCLUDE_DIR "${LIBPCAP_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  get_filename_component(LIBPCAP_LIB_DIR "${LIBNL_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  
  include_directories(${LIBPCAP_INCLUDE_DIR})
  link_directories(${LIBPCAP_LIB_DIR})
  setup_pcap_target()

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
  
  set(LIBPCAP_DIR ${DESTINATION_PATH})
  set(LIBPCAP_INCLUDE_DIR "${LIBPCAP_DIR}/include")
  set(LIBPCAP_LIB_DIR "${LIBPCAP_DIR}/lib")
  file(MAKE_DIRECTORY ${LIBPCAP_INCLUDE_DIR})

  include_directories(${LIBPCAP_INCLUDE_DIR})
  link_directories(${LIBPCAP_LIB_DIR})

  ProcessorCount(NPROCS)
  if(NPROCS EQUAL 0)
    set(NPROCS 1)
  endif()
  set(MAKE_PARALLEL "-j${NPROCS}")

  find_program(GNU_MAKE_COMMAND NAMES gmake make REQUIRED)
  set(MAKE_COMMAND ${GNU_MAKE_COMMAND})

  if(EXISTS "${LIBPCAP_SOURCE_PATH}/CMakeLists.txt")
    foreach(FEATURE IN ITEMS DBUS BLUETOOTH USB RDMA)
      if(USE_${FEATURE})
        set(DISABLE_${FEATURE} OFF)
      else()
        set(DISABLE_${FEATURE} ON)
      endif()
    endforeach()

    set(LIBPCAP_CMAKE_ARGS
      -DCMAKE_INSTALL_PREFIX:PATH=${DESTINATION_PATH}
      -DCMAKE_BUILD_TYPE:STRING=Release
      -DBUILD_SHARED_LIBS:BOOL=${USE_SHARED}
      -DDISABLE_DBUS:BOOL=${DISABLE_DBUS}
      -DDISABLE_BLUETOOTH:BOOL=${DISABLE_BLUETOOTH}
      -DDISABLE_USB:BOOL=${DISABLE_USB}
      -DDISABLE_RDMA:BOOL=${DISABLE_RDMA}
    )

    if(USE_LIBNL)
      list(APPEND LIBPCAP_CMAKE_ARGS
        -DBUILD_WITH_LIBNL=ON
        -DLIBNL_INCLUDE_DIR=${LIBNL_INCLUDE_DIR}
        -DLIBNL_LIBRARY=${LIBNL_LIBRARY}
      )
    else()
      list(APPEND LIBPCAP_CMAKE_ARGS -DBUILD_WITH_LIBNL=OFF)
    endif()

    ExternalProject_Add(libpcap_build
      SOURCE_DIR ${LIBPCAP_SOURCE_PATH}
      BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/libpcap-build
      CMAKE_ARGS ${LIBPCAP_CMAKE_ARGS}
      BUILD_COMMAND ${CMAKE_COMMAND} --build .
      INSTALL_COMMAND ${CMAKE_COMMAND} --install .
      BUILD_BYPRODUCTS "${LIBPCAP_LIB_DIR}/${LIBPCAP_LIB_NAME}"
      LOG_CONFIGURE TRUE
      LOG_BUILD TRUE
      LOG_INSTALL TRUE
    )
  else()
    set(CONFIGURE_OPTIONS)
    if(NOT USE_DBUS)
      list(APPEND CONFIGURE_OPTIONS "--disable-dbus")
    endif()
    if(NOT USE_BLUETOOTH)
      list(APPEND CONFIGURE_OPTIONS "--disable-bluetooth")
    endif()
    if(NOT USE_USB)
      list(APPEND CONFIGURE_OPTIONS "--disable-usb")
    endif()
    if(USE_LIBNL)
      list(APPEND CONFIGURE_OPTIONS
        "CPPFLAGS=-I${LIBNL_INCLUDE_DIR}"
        "LDFLAGS=-L${LIBNL_LIB_DIR} -lnl-3"
      )
    else()
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
      INSTALL_COMMAND ${MAKE_COMMAND} install
      BUILD_BYPRODUCTS "${LIBPCAP_LIB_DIR}/${LIBPCAP_LIB_NAME}"
      LOG_CONFIGURE TRUE
      LOG_BUILD TRUE
      LOG_INSTALL TRUE
    )
  endif()

  setup_pcap_target()
  add_dependencies(libpcap PCAP::PCAP)
else()
  message(FATAL_ERROR "Failed to build/load libpcap")
endif()
