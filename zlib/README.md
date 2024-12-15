# ZLib CMake Build System

This CMake module provides a flexible way to build and integrate ZLib into your CMake projects. It is designed to be included in other CMake projects and handles the ZLib build configuration automatically.

## Prerequisites

- CMake 3.18 or higher
- A C compiler (gcc, clang, MSVC, or MinGW)

## Project Structure
```
.
├── example
│   ├── CMakeLists.txt
│   └── zlib_tool.c
├── README.md
└── zlib.cmake
```

## Project Integration

### Example CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.18)
project(ZLibExample)

# Include the ZLib build module
include(zlib.cmake)

# Your project configuration
add_executable(your_app main.c)
add_dependencies(your_app zlib)
target_link_libraries(your_app PRIVATE ZLIB::ZLIB)
```

## Build Options

The following options can be set before including the ZLib cmake file or via command line:

- **USE_SHARED** (Default: OFF)  
  Build ZLib as shared libraries (.dll/.so/.dylib) instead of static libraries (.lib/.a)

- **USE_SYSTEM** (Default: OFF)  
  Use ZLib libraries installed in the system instead of building from source

## Command Line Build Examples

### Basic Build
```bash
# Configure
cmake -B build \
    -DZLIB_DIR=/path/to/zlib-1.2.13.tar.gz

# Build
cmake --build build
```

### Using System ZLib
```bash
# Configure
cmake -B build -DUSE_SYSTEM=ON

# Build
cmake --build build
```

### Using Pre-built ZLib
```bash
# Configure
cmake -B build \
    -DZLIB_INCLUDE_DIR=/path/to/zlib/include \
    -DZLIB_LIB_DIR=/path/to/zlib/lib

# Build
cmake --build build
```

### Building Shared Libraries
```bash
# Configure
cmake -B build \
    -DZLIB_DIR=/path/to/zlib-1.2.13.tar.gz \
    -DUSE_SHARED=ON

# Build
cmake --build build
```

### Cross Compilation for Android
```bash
# Configure
cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-21 \
    -DZLIB_DIR=/path/to/zlib-1.2.13.tar.gz

# Build
cmake --build build
```

### Windows MSVC Build
```bat
:: Run from Visual Studio Command Prompt
cmake -B build ^
    -DZLIB_DIR=C:\path\to\zlib-1.2.13.tar.gz

cmake --build build --config Release
```

### Build with Specific Generator
```bash
# Configure with Ninja generator
cmake -B build \
    -GNinja \
    -DZLIB_DIR=/path/to/zlib-1.2.13.tar.gz

# Build
cmake --build build
```

## Platform Support

### Linux
- x86_64
- i386 (i686)
- ARM
- AArch64

### macOS
- x86_64
- ARM64 (Apple Silicon)

### Windows
#### MSVC
- x64 (AMD64)
- x86
- ARM64

#### MinGW
- x64 (AMD64)
- x86

## Build Methods

### 1. Using Source Archive
Provide the path to ZLib source archive:
```cmake
set(ZLIB_DIR "/path/to/zlib-1.2.13.tar.gz")
```

### 2. Using Pre-built ZLib
Specify include and library directories:
```cmake
set(ZLIB_INCLUDE_DIR "/path/to/zlib/include")
set(ZLIB_LIB_DIR "/path/to/zlib/lib")
```

### 3. Using System ZLib
Enable system ZLib usage:
```cmake
set(USE_SYSTEM ON)
```

## Troubleshooting

1. For Windows builds with MSVC, ensure you're running from a Visual Studio Command Prompt
2. For MinGW builds, ensure the correct version of MinGW is in your PATH
3. For cross-compilation, ensure all required toolchain components are properly installed and accessible

## Notes

- The build system automatically detects the appropriate library suffix based on your system (.dll/.so/.dylib for shared libraries, .lib/.a for static libraries)
- When building shared libraries on Windows, both DLL and import libraries (.lib) are generated
- Build parallelization is automatically configured based on the number of available CPU cores
- When cross-compiling, make sure your toolchain file properly sets up the target architecture and system
