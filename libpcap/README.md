# libpcap CMake Build System

This CMake module provides a flexible way to build and integrate libpcap into your CMake projects. It supports both building from source and using pre-built/system libraries.

## Prerequisites

- CMake 3.18 or higher
- Flex and Bison
- C compiler (gcc, clang, MSVC, or MinGW)
- GNU Make (for autotools build when CMake build is not available)
- libnl (optional, for Linux network interface handling)

## Project Structure

```
.
├── CMakeLists.txt       # Main CMake configuration file
└── README.md
```

## Build Options

The following options can be configured:

- **USE_SHARED** (Default: OFF)  
  Build/use shared libraries instead of static libraries

- **USE_SYSTEM** (Default: OFF)  
  Use system-installed libpcap instead of building from source

- **USE_LIBNL** (Default: ON on Linux, OFF otherwise)  
  Enable libnl support for enhanced network interface handling on Linux

- **USE_DBUS** (Default: OFF)  
  Enable D-Bus support

- **USE_BLUETOOTH** (Default: OFF)  
  Enable Bluetooth support

- **USE_USB** (Default: OFF)  
  Enable USB support

- **USE_RDMA** (Default: OFF)  
  Enable RDMA support

## Usage Methods

### 1. Using System libpcap
```cmake
set(USE_SYSTEM ON)
```

### 2. Using Pre-built libpcap
```cmake
set(LIBPCAP_INCLUDE_DIR "/path/to/libpcap/include")
set(LIBPCAP_LIB_DIR "/path/to/libpcap/lib")
```

### 3. Building from Source Archive
```cmake
set(LIBPCAP_DIR "/path/to/libpcap-source.tar.gz")
```

## Command Line Examples

### Basic Build
```bash
cmake -B build \
    -DLIBPCAP_DIR=/path/to/libpcap-source.tar.gz
cmake --build build
```

### Using System Library
```bash
cmake -B build -DUSE_SYSTEM=ON
cmake --build build
```

### Pre-built Library
```bash
cmake -B build \
    -DLIBPCAP_INCLUDE_DIR=/path/to/include \
    -DLIBPCAP_LIB_DIR=/path/to/lib
cmake --build build
```

### With libnl Support
```bash
# Using system libnl
cmake -B build \
    -DLIBPCAP_DIR=/path/to/libpcap-source.tar.gz \
    -DUSE_LIBNL=ON

# Using specific libnl installation
cmake -B build \
    -DLIBPCAP_DIR=/path/to/libpcap-source.tar.gz \
    -DUSE_LIBNL=ON \
    -DLIBNL_INCLUDE_DIR=/path/to/libnl/include \
    -DLIBNL_LIB_DIR=/path/to/libnl/lib
```

### Cross-Compilation
```bash
cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=/path/to/toolchain.cmake \
    -DLIBPCAP_DIR=/path/to/libpcap-source.tar.gz \
    -DUSE_LIBNL=ON \
    -DLIBNL_INCLUDE_DIR=/path/to/cross/libnl/include \
    -DLIBNL_LIB_DIR=/path/to/cross/libnl/lib
```

## Platform Support

- Linux (x86_64, i386, ARM, AArch64)
- macOS (x86_64, ARM64)
- Windows (MSVC x64/x86, MinGW x64/x86)

## Build System Details

The build system automatically:
- Selects between CMake and autotools build based on source configuration
- Determines appropriate library suffixes (.dll/.so/.dylib for shared, .lib/.a for static)
- Configures build parallelization based on CPU cores
- Places build artifacts in `build/out/dst` when building from source

## libnl Support on Linux

When USE_LIBNL is enabled:

1. System libnl:
```cmake
set(USE_LIBNL ON)  # Uses pkg-config to locate libnl
```

2. Custom libnl:
```cmake
set(USE_LIBNL ON)
set(LIBNL_INCLUDE_DIR "/path/to/libnl/include")
set(LIBNL_LIB_DIR "/path/to/libnl/lib")
```

Note: For cross-compilation, LIBNL_INCLUDE_DIR and LIBNL_LIB_DIR must be specified explicitly.

## Troubleshooting

1. For MSVC builds: Run from Visual Studio Command Prompt
2. For MinGW builds: Ensure correct MinGW version is in PATH
3. For system libraries on Windows: Install WinPcap/Npcap
4. For Unix system libraries: Install development packages
5. Ensure Flex and Bison are in PATH
6. For cross-compilation: Specify all dependency paths explicitly
7. For libnl support: Install libnl3-dev or equivalent
