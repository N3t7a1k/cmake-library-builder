cmake_minimum_required(VERSION 3.18)
project(zlib_tool)

include(../zlib.cmake)
add_executable(${CMAKE_PROJECT_NAME} zlib_tool.c)
add_dependencies(${CMAKE_PROJECT_NAME} zlib)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE ZLIB::ZLIB)
