# LibSodium CMake Build System

This CMake module provides a flexible way to build and integrate LibSodium into your CMake projects. It is designed to be included in other CMake projects and handles the LibSodium build configuration automatically.

## Prerequisites
- CMake 3.18 or higher
- A C compiler (gcc, clang, MSVC, or MinGW)
- Autotools (for Unix-like systems)

## Project Structure
```
.
├── example
│   ├── CMakeLists.txt
│   └── sodium_tool.c
├── README.md
└── libsodium.cmake
```

## Project Integration
### Example CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.18)
project(LibSodiumExample)

# Include the LibSodium build module
include(libsodium.cmake)

# Your project configuration
add_executable(your_app main.c)
add_dependencies(your_app libsodium)
target_link_libraries(your_app PRIVATE libsodium::libsodium)
```

## Build Options
The following options can be set before including the LibSodium cmake file or via command line:
- **USE_SHARED** (Default: OFF)  
  Build LibSodium as shared libraries (.dll/.so/.dylib) instead of static libraries (.lib/.a)
- **USE_SYSTEM** (Default: OFF)  
  Use LibSodium libraries installed in the system instead of building from source

## Command Line Build Examples
### Basic Build
```bash
# Configure
cmake -B build \
    -DLIBSODIUM_DIR=/path/to/libsodium-1.0.18.tar.gz
# Build
cmake --build build
```

### Using System LibSodium
```bash
# Configure
cmake -B build -DUSE_SYSTEM=ON
# Build
cmake --build build
```

### Using Pre-built LibSodium
```bash
# Configure
cmake -B build \
    -DLIBSODIUM_INCLUDE_DIR=/path/to/libsodium/include \
    -DLIBSODIUM_LIB_DIR=/path/to/libsodium/lib
# Build
cmake --build build
```

### Building Shared Libraries
```bash
# Configure
cmake -B build \
    -DLIBSODIUM_DIR=/path/to/libsodium-1.0.18.tar.gz \
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
    -DLIBSODIUM_DIR=/path/to/libsodium-1.0.18.tar.gz
# Build
cmake --build build
```

### Windows MSVC Build
```bat
:: Run from Visual Studio Command Prompt
cmake -B build ^
    -DLIBSODIUM_DIR=C:\path\to\libsodium-1.0.18.tar.gz
cmake --build build --config Release
```

### Build with Specific Generator
```bash
# Configure with Ninja generator
cmake -B build \
    -GNinja \
    -DLIBSODIUM_DIR=/path/to/libsodium-1.0.18.tar.gz
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
#### MSVC (Requires manual build script)
- x64 (AMD64)
- x86
- ARM64

#### MinGW
- x64 (AMD64)
- x86

## Build Methods
### 1. Using Source Archive
Provide the path to LibSodium source archive:
```cmake
set(LIBSODIUM_DIR "/path/to/libsodium-1.0.18.tar.gz")
```

### 2. Using Pre-built LibSodium
Specify include and library directories:
```cmake
set(LIBSODIUM_INCLUDE_DIR "/path/to/libsodium/include")
set(LIBSODIUM_LIB_DIR "/path/to/libsodium/lib")
```

### 3. Using System LibSodium
Enable system LibSodium usage:
```cmake
set(USE_SYSTEM ON)
```

## Unix Build Process
On Unix-like systems (Linux, macOS), the build process uses the following steps:
1. Extract source archive if provided
2. Configure using autotools (`./configure`)
3. Build using make
4. Install to the specified prefix

## Windows Build Process
On Windows:
- MSVC: Requires manual build script (not currently supported in the automated build)
- MinGW: Similar to Unix build process using MSYS2/MinGW environment

## Troubleshooting
1. For Unix systems, ensure autotools (autoconf, automake) are installed
2. For Windows builds with MSVC, manual build script is required
3. For MinGW builds, ensure the correct version of MinGW is in your PATH
4. For cross-compilation, ensure all required toolchain components are properly installed and accessible

## Notes
- The build system automatically detects the appropriate library suffix based on your system (.dll/.so/.dylib for shared libraries, .lib/.a for static libraries)
- When building shared libraries on Windows, both DLL and import libraries (.lib) are generated
- Build parallelization is automatically configured based on the number of available CPU cores
- Windows MSVC builds currently require manual intervention due to the different build system used by LibSodium on Windows
- The configure script on Unix systems automatically handles platform-specific optimizations
