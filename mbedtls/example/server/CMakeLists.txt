cmake_minimum_required(VERSION 3.18)
project(tls_echo_server)

include("../../mbedtls.cmake")
add_executable(${CMAKE_PROJECT_NAME} main.c)
add_dependencies(${CMAKE_PROJECT_NAME} mbedtls)
target_link_libraries(${CMAKE_PROJECT_NAME}
    PRIVATE
    MbedTLS::mbedtls
    MbedTLS::mbedx509
    MbedTLS::mbedcrypto
)
