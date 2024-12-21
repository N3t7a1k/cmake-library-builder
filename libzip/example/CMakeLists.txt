cmake_minimum_required(VERSION 3.18)
project(zip_tool)

include(../libzip.cmake)
add_executable(${CMAKE_PROJECT_NAME} zip_tool.c)
add_dependencies(${CMAKE_PROJECT_NAME} libzip)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE LIBZIP::LIBZIP)
