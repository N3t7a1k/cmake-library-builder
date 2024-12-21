cmake_minimum_required(VERSION 3.18)
if(NOT CMAKE_PROJECT_NAME)
  project(LibZip)
endif()
include(ExternalProject)
include(ProcessorCount)

option(USE_SHARED "Use shared libraries" OFF)
option(USE_SYSTEM "Use libraries installed in system" OFF)
option(ENABLE_CRYPTO "Enable encryption support" ON)

option(USE_OPENSSL "Use OpenSSL library" OFF)
option(USE_MBEDTLS "Use MbedTLS library" OFF)

if(ENABLE_CRYPTO)
    if(USE_OPENSSL AND USE_MBEDTLS)
        message(FATAL_ERROR "Only one crypto library can be enabled at a time")
    elseif(NOT USE_OPENSSL AND NOT USE_MBEDTLS)
        set(USE_OPENSSL ON)
        message(STATUS "No crypto library specified, defaulting to OpenSSL")
    endif()
endif()

add_library(libzip INTERFACE)

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(STATIC_LIB_SUFFIX ".lib")
  set(SHARED_LIB_SUFFIX ".dll")
  set(IMPORT_LIB_SUFFIX ".lib")
  set(LIB_PREFIX "")
else()
  set(STATIC_LIB_SUFFIX ".a")
  set(SHARED_LIB_SUFFIX ".so")
  set(IMPORT_LIB_SUFFIX "${SHARED_LIB_SUFFIX}")
  set(LIB_PREFIX "lib")
  if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(SHARED_LIB_SUFFIX ".dylib")
  endif()
endif()

if(NOT USE_SHARED)
  set(BUILD_SHARED_LIBS OFF)
  set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
endif()

macro(validate_dirs_for_cross_compile LIB_NAME INCLUDE_DIR LIB_DIR)
    if(CMAKE_CROSSCOMPILING)
        if(NOT DEFINED ${INCLUDE_DIR} OR NOT DEFINED ${LIB_DIR})
            message(FATAL_ERROR "Cross-compiling requires ${INCLUDE_DIR} and ${LIB_DIR} to be specified for ${LIB_NAME}")
        endif()
    endif()
endmacro()

macro(setup_zlib_target)
    if(NOT TARGET ZLIB::ZLIB)
        add_library(ZLIB::ZLIB UNKNOWN IMPORTED GLOBAL)
        if(USE_SHARED)
            if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
                set(ZLIB_LIB_NAME "zlib${SHARED_LIB_SUFFIX}")
            else()
                set(ZLIB_LIB_NAME "${LIB_PREFIX}z${SHARED_LIB_SUFFIX}")
            endif()
        else()
            if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
                set(ZLIB_LIB_NAME "zlib${STATIC_LIB_SUFFIX}")
            else()
                set(ZLIB_LIB_NAME "${LIB_PREFIX}z${STATIC_LIB_SUFFIX}")
            endif()
        endif()

        set(ZLIB_LIBRARY "${ZLIB_LIB_DIR}/${ZLIB_LIB_NAME}")
        if(NOT EXISTS "${ZLIB_LIBRARY}")
            message(FATAL_ERROR "ZLIB library not found at: ${ZLIB_LIBRARY}")
        endif()

        set_target_properties(ZLIB::ZLIB PROPERTIES
            IMPORTED_LOCATION "${ZLIB_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}"
        )
    endif()
endmacro()

macro(setup_crypto_library)
    if(NOT ENABLE_CRYPTO)
        return()
    endif()

    if(USE_OPENSSL)
        setup_openssl()
    elseif(USE_MBEDTLS)
        setup_mbedtls()
    endif()
endmacro()

macro(setup_openssl)
    validate_dirs_for_cross_compile("OpenSSL" OPENSSL_INCLUDE_DIR OPENSSL_LIB_DIR)
    
    if(NOT USE_SHARED)
        set(OPENSSL_USE_STATIC_LIBS ON)
    endif()
    
    if(DEFINED OPENSSL_INCLUDE_DIR AND DEFINED OPENSSL_LIB_DIR)
        get_filename_component(OPENSSL_INCLUDE_DIR "${OPENSSL_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
        get_filename_component(OPENSSL_LIB_DIR "${OPENSSL_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
        
        if(USE_SHARED)
            set(OPENSSL_CRYPTO_LIBRARY "${OPENSSL_LIB_DIR}/${LIB_PREFIX}crypto${SHARED_LIB_SUFFIX}")
        else()
            set(OPENSSL_CRYPTO_LIBRARY "${OPENSSL_LIB_DIR}/${LIB_PREFIX}crypto${STATIC_LIB_SUFFIX}")
        endif()
        
        if(NOT TARGET OpenSSL::Crypto)
            add_library(OpenSSL::Crypto UNKNOWN IMPORTED GLOBAL)
            set_target_properties(OpenSSL::Crypto PROPERTIES
                IMPORTED_LOCATION "${OPENSSL_CRYPTO_LIBRARY}"
                INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}")
        endif()
    else()
        find_package(OpenSSL REQUIRED)
        get_filename_component(OPENSSL_LIB_DIR "${OPENSSL_CRYPTO_LIBRARY}" DIRECTORY)
    endif()
endmacro()

macro(setup_mbedtls)
    validate_dirs_for_cross_compile("MbedTLS" MBEDTLS_INCLUDE_DIR MBEDTLS_LIB_DIR)

    if(USE_SHARED)
        if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
            set(MBEDTLS_LIB_NAME "mbedcrypto${SHARED_LIB_SUFFIX}")
        else()
            set(MBEDTLS_LIB_NAME "${LIB_PREFIX}mbedcrypto${SHARED_LIB_SUFFIX}")
        endif()
    else()
        if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
            set(MBEDTLS_LIB_NAME "mbedcrypto${STATIC_LIB_SUFFIX}")
        else()
            set(MBEDTLS_LIB_NAME "${LIB_PREFIX}mbedcrypto${STATIC_LIB_SUFFIX}")
        endif()
    endif()
    
    if(DEFINED MBEDTLS_INCLUDE_DIR AND DEFINED MBEDTLS_LIB_DIR)
        get_filename_component(MBEDTLS_INCLUDE_DIR "${MBEDTLS_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
        get_filename_component(MBEDTLS_LIB_DIR "${MBEDTLS_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
        set(MBEDTLS_CRYPTO_LIBRARY "${MBEDTLS_LIB_DIR}/${MBEDTLS_LIB_NAME}")

        if(NOT TARGET MbedTLS::mbedcrypto)
            add_library(MbedTLS::mbedcrypto UNKNOWN IMPORTED GLOBAL)
            set_target_properties(MbedTLS::mbedcrypto PROPERTIES
                IMPORTED_LOCATION "${MBEDTLS_CRYPTO_LIBRARY}"
                INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}")
        endif()
    else()
        find_path(MBEDTLS_INCLUDE_DIR
            NAMES mbedtls/ssl.h
            PATHS /usr/include /usr/local/include
            REQUIRED
        )
        
        find_library(MBEDTLS_CRYPTO_LIBRARY
            NAMES ${MBEDTLS_LIB_NAME}
            PATHS /usr/lib /usr/local/lib /usr/lib64 /usr/local/lib64
            REQUIRED
        )
        
        if(NOT TARGET MbedTLS::mbedcrypto)
            add_library(MbedTLS::mbedcrypto UNKNOWN IMPORTED GLOBAL)
            set_target_properties(MbedTLS::mbedcrypto PROPERTIES
                IMPORTED_LOCATION "${MBEDTLS_CRYPTO_LIBRARY}"
                INTERFACE_INCLUDE_DIRECTORIES "${MBEDTLS_INCLUDE_DIR}")
        endif()
    endif()
endmacro()

macro(setup_zip_target)
    if(NOT TARGET LIBZIP::LIBZIP)
        add_library(LIBZIP::LIBZIP UNKNOWN IMPORTED GLOBAL)
    endif()

    set_target_properties(LIBZIP::LIBZIP PROPERTIES
        IMPORTED_LOCATION "${LIBZIP_LIB_DIR}/${LIBZIP_LIB_NAME}"
        INTERFACE_INCLUDE_DIRECTORIES "${LIBZIP_INCLUDE_DIR}"
    )

    if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND USE_SHARED)
        set_target_properties(LIBZIP::LIBZIP PROPERTIES
            IMPORTED_IMPLIB "${LIBZIP_LIB_DIR}/${LIBZIP_IMPORT_LIB_NAME}"
        )
    endif()

    set_property(TARGET LIBZIP::LIBZIP APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES ZLIB::ZLIB)

    if(ENABLE_CRYPTO)
        if(USE_OPENSSL)
            set_property(TARGET LIBZIP::LIBZIP APPEND PROPERTY
                INTERFACE_LINK_LIBRARIES OpenSSL::Crypto)
        elseif(USE_MBEDTLS)
            set_property(TARGET LIBZIP::LIBZIP APPEND PROPERTY
                INTERFACE_LINK_LIBRARIES MbedTLS::mbedcrypto)
        endif()
    endif()

    if(TARGET libzip_build)
        add_dependencies(LIBZIP::LIBZIP libzip_build)
    endif()
endmacro()

if(USE_SHARED)
    set(LIBZIP_LIB_NAME "${LIB_PREFIX}zip${SHARED_LIB_SUFFIX}")
    if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        set(LIBZIP_IMPORT_LIB_NAME "${LIB_PREFIX}zip${IMPORT_LIB_SUFFIX}")
    endif()
else()
    set(LIBZIP_LIB_NAME "${LIB_PREFIX}zip${STATIC_LIB_SUFFIX}")
endif()

if(DEFINED ZLIB_INCLUDE_DIR AND DEFINED ZLIB_LIB_DIR)
    get_filename_component(ZLIB_INCLUDE_DIR "${ZLIB_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    get_filename_component(ZLIB_LIB_DIR "${ZLIB_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    setup_zlib_target()
else()
    if(CMAKE_CROSSCOMPILING)
        message(FATAL_ERROR "Cross-compiling requires ZLIB_INCLUDE_DIR and ZLIB_LIB_DIR to be specified")
    endif()

    if(NOT USE_SHARED)
        find_library(ZLIB_LIBRARY_STATIC 
            NAMES libz.a
            PATHS /usr/lib/x86_64-linux-gnu
            NO_DEFAULT_PATH
        )
        
        if(ZLIB_LIBRARY_STATIC)
            find_path(ZLIB_INCLUDE_DIR 
                NAMES zlib.h
                PATHS /usr/include
                REQUIRED
            )
            
            if(NOT TARGET ZLIB::ZLIB)
                add_library(ZLIB::ZLIB STATIC IMPORTED GLOBAL)
                set_target_properties(ZLIB::ZLIB PROPERTIES
                    IMPORTED_LOCATION "${ZLIB_LIBRARY_STATIC}"
                    INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}"
                )
            endif()
        else()
            find_package(ZLIB REQUIRED)
        endif()
    else()
        find_package(ZLIB REQUIRED)
    endif()
endif()

setup_crypto_library()

if(DEFINED LIBZIP_INCLUDE_DIR AND DEFINED LIBZIP_LIB_DIR)
    get_filename_component(LIBZIP_INCLUDE_DIR "${LIBZIP_INCLUDE_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    get_filename_component(LIBZIP_LIB_DIR "${LIBZIP_LIB_DIR}" ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    include_directories(${LIBZIP_INCLUDE_DIR})
    link_directories(${LIBZIP_LIB_DIR})
    setup_zip_target()

elseif(USE_SYSTEM)
    if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        find_path(LIBZIP_INCLUDE_DIR
            NAMES zip.h
            PATHS
                "$ENV{PROGRAMFILES}/libzip/include"
                "$ENV{PROGRAMFILES\(X86\)}/libzip/include"
                "$ENV{ProgramW6432}/libzip/include"
        )
        
        find_library(LIBZIP_LIBRARY
            NAMES ${LIBZIP_LIB_NAME} ${LIBZIP_IMPORT_LIB_NAME}
            PATHS
                "$ENV{PROGRAMFILES}/libzip/lib"
                "$ENV{PROGRAMFILES\(X86\)}/libzip/lib"
                "$ENV{ProgramW6432}/libzip/lib"
        )
    else()
        find_package(PkgConfig QUIET)
        if(PKG_CONFIG_FOUND)
            pkg_check_modules(PC_LIBZIP QUIET libzip)
        endif()

        find_path(LIBZIP_INCLUDE_DIR
            NAMES zip.h
            PATHS ${PC_LIBZIP_INCLUDEDIR} /usr/local/include /usr/include
        )

        find_library(LIBZIP_LIBRARY
            NAMES ${LIBZIP_LIB_NAME} zip
            PATHS ${PC_LIBZIP_LIBDIR} /usr/local/lib /usr/lib /usr/lib64
        )
    endif()

    if(LIBZIP_INCLUDE_DIR AND LIBZIP_LIBRARY)
        get_filename_component(LIBZIP_LIB_DIR "${LIBZIP_LIBRARY}" DIRECTORY)
        setup_zip_target()
    else()
        message(FATAL_ERROR "System LibZip not found. Please install LibZip development files or specify LIBZIP_INCLUDE_DIR and LIBZIP_LIB_DIR.")
    endif()

elseif(DEFINED LIBZIP_DIR AND EXISTS ${LIBZIP_DIR})
    set(OUTPUT_PATH "${CMAKE_BINARY_DIR}/out")
    set(SOURCE_PATH "${OUTPUT_PATH}/src")
    set(DESTINATION_PATH "${OUTPUT_PATH}/dst")
    
    file(MAKE_DIRECTORY "${SOURCE_PATH}")
    file(ARCHIVE_EXTRACT
        INPUT "${LIBZIP_DIR}"
        DESTINATION "${SOURCE_PATH}"
    )
    
    file(GLOB LIBZIP_EXTRACTED_DIRS "${SOURCE_PATH}/*")
    list(GET LIBZIP_EXTRACTED_DIRS 0 LIBZIP_SOURCE_PATH)

    set(LIBZIP_DIR ${DESTINATION_PATH})
    set(LIBZIP_INCLUDE_DIR "${LIBZIP_DIR}/include")
    set(LIBZIP_LIB_DIR "${LIBZIP_DIR}/lib")
    file(MAKE_DIRECTORY ${LIBZIP_INCLUDE_DIR})
    
    set(LIBZIP_CMAKE_ARGS 
        -DCMAKE_INSTALL_PREFIX=${DESTINATION_PATH}
        -DBUILD_SHARED_LIBS=${USE_SHARED}
        -DENABLE_CRYPTO=${ENABLE_CRYPTO}
        -DENABLE_OPENSSL=${USE_OPENSSL}
        -DENABLE_MBEDTLS=${USE_MBEDTLS}
        -DENABLE_GNUTLS=OFF
    )

    if(USE_OPENSSL AND DEFINED OPENSSL_INCLUDE_DIR)
        list(APPEND LIBZIP_CMAKE_ARGS
            -DOPENSSL_ROOT_DIR=${OPENSSL_LIB_DIR}
            -DOPENSSL_INCLUDE_DIR=${OPENSSL_INCLUDE_DIR}
            -DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_CRYPTO_LIBRARY}
        )
    endif()

    if(USE_MBEDTLS AND DEFINED MBEDTLS_INCLUDE_DIR)
        list(APPEND LIBZIP_CMAKE_ARGS
            -DMBEDTLS_INCLUDE_DIR=${MBEDTLS_INCLUDE_DIR}
            -DMBEDTLS_CRYPTO_LIBRARY=${MBEDTLS_CRYPTO_LIBRARY}
        )
    endif()

    ProcessorCount(NPROCS)
    if(NPROCS EQUAL 0)
        set(NPROCS 1)
    endif()

    set(MAKE_PARALLEL "")
    if(CMAKE_GENERATOR STREQUAL "Ninja" OR CMAKE_GENERATOR STREQUAL "Unix Makefiles")
        set(MAKE_PARALLEL "-j${NPROCS}")
    endif()

    ExternalProject_Add(libzip_build
        SOURCE_DIR ${LIBZIP_SOURCE_PATH}
        CMAKE_ARGS ${LIBZIP_CMAKE_ARGS}
        BUILD_COMMAND ${CMAKE_MAKE_PROGRAM} ${MAKE_PARALLEL}
        INSTALL_COMMAND ${CMAKE_MAKE_PROGRAM} ${MAKE_PARALLEL} install
        BUILD_BYPRODUCTS "${LIBZIP_LIB_DIR}/${LIBZIP_LIB_NAME}"
        LOG_CONFIGURE TRUE
        LOG_BUILD TRUE
        LOG_INSTALL TRUE
    )
    
    add_dependencies(libzip libzip_build)
    include_directories(${LIBZIP_INCLUDE_DIR})
    link_directories(${LIBZIP_LIB_DIR})
    setup_zip_target()
endif()

message(STATUS "LibZip Configuration Summary:")
message(STATUS "  Use System Library: ${USE_SYSTEM}")
message(STATUS "  Shared Build: ${USE_SHARED}")
message(STATUS "  Encryption Support: ${ENABLE_CRYPTO}")
if(USE_OPENSSL)
  message(STATUS "  Encryption Library: OpenSSL")
elseif(USE_MBEDTLS)
  message(STATUS "  Encryption Library: MbedTLS")
endif()
