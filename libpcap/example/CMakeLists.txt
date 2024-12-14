cmake_minimum_required(VERSION 3.18)
project(packet_analyzer)

include(../libpcap.cmake)
add_executable(${CMAKE_PROJECT_NAME} packet_analyzer.c)
add_dependencies(${CMAKE_PROJECT_NAME} libpcap)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE PCAP::pcap)
if(USE_LIBNL)
  target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE nl-3 nl-genl-3)
endif()

if(WIN32)
  target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE ws2_32 iphlpapi)
endif()
