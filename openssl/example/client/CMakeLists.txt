cmake_minimum_required(VERSION 3.18)
project(tls_echo_client)

include("../../openssl.cmake")
add_executable(${CMAKE_PROJECT_NAME} main.c)
add_dependencies(${CMAKE_PROJECT_NAME} openssl)
target_link_libraries(${CMAKE_PROJECT_NAME}
    PRIVATE
    OpenSSL::SSL
    OpenSSL::Crypto
)
