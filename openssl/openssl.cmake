cmake_minimum_required(VERSION 3.18)
include(ProcessorCount)
include(ExternalProject)

option(USE_SHARED "Use shared libraries" OFF)
option(USE_SYSTEM "Use libraries installed in system" OFF)
option(ENHANCE_SECURITY "Enhance OpenSSL security(e.g. TLS 1.3)" OFF)
option(ENABLE_TESTS "Enable OpenSSL tests" OFF)

function(detect_openssl_target)
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
      set(OPENSSL_TARGET "linux-x86_64" PARENT_SCOPE)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "i[3-6]86")
      set(OPENSSL_TARGET "linux-elf" PARENT_SCOPE)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "armv7l|armv8l|arm")
      set(OPENSSL_TARGET "linux-armv4" PARENT_SCOPE)
    elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
      set(OPENSSL_TARGET "linux-aarch64" PARENT_SCOPE)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "mips|mipsel")
      set(OPENSSL_TARGET "linux-generic32" PARENT_SCOPE)
    elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "riscv64")
      set(OPENSSL_TARGET "linux-generic64" PARENT_SCOPE)
    else()
      message(FATAL_ERROR "Unsupported Linux processor: ${CMAKE_SYSTEM_PROCESSOR}")
    endif()
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
      set(OPENSSL_TARGET "darwin64-x86_64" PARENT_SCOPE)
    elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64")
      set(OPENSSL_TARGET "darwin64-arm64" PARENT_SCOPE)
    else()
      message(FATAL_ERROR "Unsupported macOS processor: ${CMAKE_SYSTEM_PROCESSOR}")
    endif()
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    if(MSVC)
      if(CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
        set(OPENSSL_TARGET "VC-WIN64A" PARENT_SCOPE)
      elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86")
        set(OPENSSL_TARGET "VC-WIN32" PARENT_SCOPE)
      elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
        set(OPENSSL_TARGET "VC-WIN64-ARM" PARENT_SCOPE)
      else()
        message(FATAL_ERROR "Unsupported Windows processor: ${CMAKE_SYSTEM_PROCESSOR}")
      endif()
    else()
      if(CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
        set(OPENSSL_TARGET "mingw64" PARENT_SCOPE)
      elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86")
        set(OPENSSL_TARGET "mingw32" PARENT_SCOPE)
      else()
        message(FATAL_ERROR "Unsupported MinGW processor: ${CMAKE_SYSTEM_PROCESSOR}")
      endif()
    endif()
  else()
    message(FATAL_ERROR "Unsupported operating system: ${CMAKE_SYSTEM_NAME}")
  endif()
endfunction()

add_library(openssl INTERFACE)

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
  set(SSL_LIB_NAME "libssl${SHARED_LIB_SUFFIX}")
  set(CRYPTO_LIB_NAME "libcrypto${SHARED_LIB_SUFFIX}")
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(SSL_IMPORT_LIB_NAME "libssl${IMPORT_LIB_SUFFIX}")
    set(CRYPTO_IMPORT_LIB_NAME "libcrypto${IMPORT_LIB_SUFFIX}")
  endif()
else()
  set(SSL_LIB_NAME "libssl${STATIC_LIB_SUFFIX}")
  set(CRYPTO_LIB_NAME "libcrypto${STATIC_LIB_SUFFIX}")
endif()

if(${USE_SYSTEM})
  find_package(OpenSSL REQUIRED)
  message(STATUS "Using system OpenSSL: ${OPENSSL_VERSION}")
elseif(DEFINED OPENSSL_INCLUDE_DIR AND DEFINED OPENSSL_LIB_DIR)
  get_filename_component(OPENSSL_INCLUDE_DIR "${OPENSSL_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  get_filename_component(OPENSSL_LIB_DIR "${OPENSSL_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  message(STATUS "Using pre-built OpenSSL library in ${OPENSSL_LIB_DIR}")
  include_directories(${OPENSSL_INCLUDE_DIR})
  link_directories(${OPENSSL_LIB_DIR})
  add_library(OpenSSL::SSL UNKNOWN IMPORTED GLOBAL)
  add_library(OpenSSL::Crypto UNKNOWN IMPORTED GLOBAL)
  set_target_properties(OpenSSL::SSL PROPERTIES
    IMPORTED_LOCATION "${OPENSSL_LIB_DIR}/${SSL_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
  )
  set_target_properties(OpenSSL::Crypto PROPERTIES
    IMPORTED_LOCATION "${OPENSSL_LIB_DIR}/${CRYPTO_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
  )
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(OpenSSL::SSL PROPERTIES
      IMPORTED_IMPLIB "${OPENSSL_LIB_DIR}/${SSL_IMPORT_LIB_NAME}"
    )
    set_target_properties(OpenSSL::Crypto PROPERTIES
      IMPORTED_IMPLIB "${OPENSSL_LIB_DIR}/${CRYPTO_IMPORT_LIB_NAME}"
    )
  endif()
elseif(DEFINED OPENSSL_DIR AND EXISTS ${OPENSSL_DIR})
  find_package(Perl REQUIRED)
  if(NOT PERL_FOUND)
    message(FATAL_ERROR "Perl is required to build OpenSSL")
  endif()

  if(NOT DEFINED OPENSSL_TARGET)
    detect_openssl_target()
  endif()

  set(BUILD_OPTIONS "")
  if(USE_SHARED)
    list(APPEND BUILD_OPTIONS "shared")
  else()
    list(APPEND BUILD_OPTIONS "no-shared")
  endif()
  if(ENHANCE_SECURITY)
    list(APPEND BUILD_OPTIONS 
      "no-weak-ssl-ciphers"
      "enable-tls1_3"
      "no-deprecated"
    )
  endif()
  if(NOT ENABLE_TESTS)
    list(APPEND BUILD_OPTIONS "no-tests")
  endif()

  ProcessorCount(NPROCS)
  if(NPROCS EQUAL 0)
    set(NPROCS 1)
  endif()
  set(MAKE_PARALLEL "-j${NPROCS}")

  if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    if(MSVC)
      set(MAKE_COMMAND nmake)
      set(MAKE_PARALLEL "")
    else()
      set(MAKE_COMMAND mingw32-make)
    endif()
  else()
    set(MAKE_COMMAND make)
  endif()

  set(OUTPUT_PATH "${CMAKE_BINARY_DIR}/out")
  set(SOURCE_PATH "${OUTPUT_PATH}/src") 
  set(DESTINATION_PATH "${OUTPUT_PATH}/dst")
  file(MAKE_DIRECTORY "${SOURCE_PATH}")
  file(ARCHIVE_EXTRACT
    INPUT "${OPENSSL_DIR}"
    DESTINATION "${SOURCE_PATH}"
  )
  file(GLOB OPENSSL_EXTRACTED_DIRS "${SOURCE_PATH}/*")
  list(GET OPENSSL_EXTRACTED_DIRS 0 OPENSSL_SOURCE_PATH)
  message(STATUS "OpenSSL source path: ${OPENSSL_SOURCE_PATH}")

  set(OPENSSL_DIR ${DESTINATION_PATH})
  set(OPENSSL_INCLUDE_DIR "${OPENSSL_DIR}/include")
  set(OPENSSL_LIB_DIR "${OPENSSL_DIR}/lib")
  file(MAKE_DIRECTORY ${OPENSSL_INCLUDE_DIR})
  ExternalProject_Add(openssl_build
    SOURCE_DIR ${OPENSSL_SOURCE_PATH}
    CONFIGURE_COMMAND ${PERL_EXECUTABLE} Configure
      --prefix=${DESTINATION_PATH}
      --libdir=${OPENSSL_LIB_DIR}
      ${OPENSSL_TARGET}
      ${BUILD_OPTIONS}
      ${OPENSSL_CONFIGURE_EXTRA}
    BUILD_COMMAND ${MAKE_COMMAND} ${MAKE_PARALLEL}
    INSTALL_COMMAND ${MAKE_COMMAND} install_sw
    BUILD_IN_SOURCE TRUE
    BUILD_BYPRODUCTS 
      "${OPENSSL_LIB_DIR}/${SSL_LIB_NAME}"
      "${OPENSSL_LIB_DIR}/${CRYPTO_LIB_NAME}"
    LOG_CONFIGURE TRUE
    LOG_BUILD TRUE
    LOG_INSTALL TRUE
  )

  add_dependencies(openssl openssl_build)

  include_directories(${OPENSSL_INCLUDE_DIR})
  link_directories(${OPENSSL_LIB_DIR})
  add_library(OpenSSL::SSL UNKNOWN IMPORTED GLOBAL)
  add_library(OpenSSL::Crypto UNKNOWN IMPORTED GLOBAL)
  set_target_properties(OpenSSL::SSL PROPERTIES
    IMPORTED_LOCATION "${OPENSSL_LIB_DIR}/${SSL_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
  )
  set_target_properties(OpenSSL::Crypto PROPERTIES
    IMPORTED_LOCATION "${OPENSSL_LIB_DIR}/${CRYPTO_LIB_NAME}"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
  )
  if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
    set_target_properties(OpenSSL::SSL PROPERTIES
      IMPORTED_IMPLIB "${OPENSSL_LIB_DIR}/${SSL_IMPORT_LIB_NAME}"
    )
    set_target_properties(OpenSSL::Crypto PROPERTIES
      IMPORTED_IMPLIB "${OPENSSL_LIB_DIR}/${CRYPTO_IMPORT_LIB_NAME}"
    )
  endif()
else()
  message(FATAL_ERROR "Failed to build/load OpenSSL")
endif()

message(STATUS "Target: ${OPENSSL_TARGET}")
message(STATUS "Include directory: ${OPENSSL_INCLUDE_DIR}")
message(STATUS "Library directory: ${OPENSSL_LIB_DIR}")
