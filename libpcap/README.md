# libpcap CMake Build System

This CMake module provides a flexible way to build and integrate libpcap into your CMake projects. It is designed to be included in other CMake projects and handles the libpcap build configuration automatically.

## Prerequisites

- CMake 3.18 or higher
- Flex and Bison (or equivalents: win_flex/win_bison, lex/yacc)
- A C compiler (gcc, clang, MSVC, or MinGW)
- GNU Make (for autotools build when CMake build is not available)

## Project Structure

```
.
├── example
│   ├── CMakeLists.txt
│   └── packet_analyzer.c
├── libpcap.cmake       # libpcap build module
└── README.md

```

### Example CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.18)
project(LibpcapExample)

# Include the libpcap build module
include(libpcap.cmake)

# Your project configuration
add_executable(packet_analyzer packet_analyzer.c)
target_link_libraries(packet_analyzer PRIVATE PCAP::pcap)
```

## Build Options

The following options can be set before including the libpcap cmake file or via command line:

- **USE_SHARED** (Default: OFF)  
  Build libpcap as shared libraries (.dll/.so/.dylib) instead of static libraries (.lib/.a)

- **USE_SYSTEM** (Default: OFF)  
  Use libpcap libraries installed in the system instead of building from source

- **USE_LIBNL** (Default: ON)  
  Enable libnl support for enhanced network interface handling on Linux

- **USE_DBUS** (Default: OFF)  
  Enable D-Bus support for Bluetooth capture

- **USE_BLUETOOTH** (Default: OFF)  
  Enable Bluetooth packet capture support

- **USE_USB** (Default: OFF)  
  Enable USB packet capture support

- **USE_RDMA** (Default: OFF)  
  Enable RDMA capture support (only available in libpcap 1.8.0 and later with CMake build)

## Command Line Build Examples

### Basic Build
```bash
# Configure
cmake -B build \
    -DLIBPCAP_DIR=/path/to/libpcap-1.10.4.tar.gz
# Build
cmake --build build
```

### Using System libpcap
```bash
# Configure
cmake -B build -DUSE_SYSTEM=ON
# Build
cmake --build build
```

### Using Pre-built libpcap
```bash
# Configure
cmake -B build \
    -DLIBPCAP_INCLUDE_DIR=/path/to/libpcap/include \
    -DLIBPCAP_LIB_DIR=/path/to/libpcap/lib
# Build
cmake --build build
```

### Building Shared Libraries
```bash
# Configure
cmake -B build \
    -DLIBPCAP_DIR=/path/to/libpcap-1.10.4.tar.gz \
    -DUSE_SHARED=ON
# Build
cmake --build build
```

### Windows MSVC Build
```bat
:: Run from Visual Studio Command Prompt
cmake -B build ^
    -DLIBPCAP_DIR=C:\path\to\libpcap-1.10.4.tar.gz
cmake --build build --config Release
```

## Platform Support

### Linux
- x86_64
- i386
- ARM
- AArch64

### macOS
- x86_64
- ARM64 (Apple Silicon)

### Windows
- MSVC (x64, x86)
- MinGW (x64, x86)

## Build Methods

### 1. Using Source Archive
Provide the path to libpcap source archive:
```cmake
set(LIBPCAP_DIR "/path/to/libpcap-1.10.4.tar.gz")
```

### 2. Using Pre-built libpcap
Specify include and library directories:
```cmake
set(LIBPCAP_INCLUDE_DIR "/path/to/libpcap/include")
set(LIBPCAP_LIB_DIR "/path/to/libpcap/lib")
```

### 3. Using System libpcap
Enable system libpcap usage:
```cmake
set(USE_SYSTEM ON)
```

## Library Components

libpcap is provided as a single target:
- **PCAP::pcap**: The main packet capture library

## Build System Selection

The build system automatically selects between CMake and autotools build based on the libpcap version:
- For libpcap 1.8.0 and later: Uses CMake build system
- For earlier versions: Uses autotools build system
- On Windows: Only CMake build is supported

## Troubleshooting

1. For Windows builds with MSVC, ensure you're running from a Visual Studio Command Prompt
2. For MinGW builds, ensure the correct version of MinGW is in your PATH
3. When using system libraries on Windows, make sure WinPcap/Npcap is installed
4. On Unix systems using system libraries, ensure development packages (headers) are installed
5. Make sure Flex and Bison are installed and available in your PATH

## Notes

- The build system automatically handles platform-specific library extensions (.dll, .so, .dylib)
- On Windows with shared libraries, both DLL and import libraries (.lib) are generated
- The module supports finding system-installed libpcap using pkg-config on Unix-like systems
- Build artifacts are placed in the build directory under 'out/dst' when building from source
- For optimal performance on Linux, it's recommended to keep USE_LIBNL enabled
