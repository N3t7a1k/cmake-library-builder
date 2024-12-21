# LibNL CMake Build System
This CMake module provides a flexible way to build and integrate LibNL (Netlink Protocol Library) into your CMake projects. It is designed to be included in other CMake projects and handles the LibNL build configuration automatically.

## Prerequisites
- CMake 3.18 or higher
- A C compiler (gcc or clang)
- Linux system (LibNL is Linux-specific)
- Autotools (for building from source)

## Project Structure
```
.
├── example
│   ├── CMakeLists.txt
│   └── nlinfo.c
├── README.md
└── libnl.cmake
```

## Project Integration
### Example CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.18)
project(LibNLExample)

# Include the LibNL build module
include(libnl.cmake)

# Your project configuration
add_executable(your_app main.c)
add_dependencies(your_app libnl)
target_link_libraries(your_app PRIVATE LIBNL::LIBNL)
```

## Build Options
The following options can be set before including the LibNL cmake file or via command line:
- **USE_SHARED** (Default: OFF)  
  Build LibNL as shared libraries (.so) instead of static libraries (.a)
- **USE_SYSTEM** (Default: OFF)  
  Use LibNL libraries installed in the system instead of building from source

## Command Line Build Examples
### Basic Build
```bash
# Configure
cmake -B build \
    -DLIBNL_DIR=/path/to/libnl-3.x.x.tar.gz
# Build
cmake --build build
```

### Using System LibNL
```bash
# Configure
cmake -B build -DUSE_SYSTEM=ON
# Build
cmake --build build
```

### Using Pre-built LibNL
```bash
# Configure
cmake -B build \
    -DLIBNL_INCLUDE_DIR=/path/to/libnl/include \
    -DLIBNL_LIB_DIR=/path/to/libnl/lib
# Build
cmake --build build
```

### Building Shared Libraries
```bash
# Configure
cmake -B build \
    -DLIBNL_DIR=/path/to/libnl-3.x.x.tar.gz \
    -DUSE_SHARED=ON
# Build
cmake --build build
```

### Build with Specific Generator
```bash
# Configure with Ninja generator
cmake -B build \
    -GNinja \
    -DLIBNL_DIR=/path/to/libnl-3.x.x.tar.gz
# Build
cmake --build build
```

## Platform Support
### Linux
- x86_64
- i386 (i686)
- ARM
- AArch64

## Build Methods
### 1. Using Source Archive
Provide the path to LibNL source archive:
```cmake
set(LIBNL_DIR "/path/to/libnl-3.x.x.tar.gz")
```

### 2. Using Pre-built LibNL
Specify include and library directories:
```cmake
set(LIBNL_INCLUDE_DIR "/path/to/libnl/include")
set(LIBNL_LIB_DIR "/path/to/libnl/lib")
```

### 3. Using System LibNL
Enable system LibNL usage:
```cmake
set(USE_SYSTEM ON)
```

## Troubleshooting
1. Make sure you have Autotools installed when building from source
2. Check if pkg-config and libnl3 development files are installed when using system libraries
3. Verify that the include path points to the directory containing the `netlink` headers

## Notes
- LibNL is Linux-specific and will not work on other operating systems
- Build parallelization is automatically configured based on the number of available CPU cores
- The header files are automatically reorganized to maintain a consistent include structure
- When building from source, the configure script is automatically set up with appropriate flags
- The build system generates either static (.a) or shared (.so) libraries based on the USE_SHARED option
