cmake_minimum_required(VERSION 3.18)
project(securebox)

include(../libsodium.cmake)
add_executable(${CMAKE_PROJECT_NAME} securebox.c)
add_dependencies(${CMAKE_PROJECT_NAME} libsodium)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE libsodium::libsodium)
