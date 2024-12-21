cmake_minimum_required(VERSION 3.18)
project(nlinfo)

include(../libnl.cmake)
add_executable(${CMAKE_PROJECT_NAME} nlinfo.c)
add_dependencies(${CMAKE_PROJECT_NAME} libnl)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE LIBNL::LIBNL)
