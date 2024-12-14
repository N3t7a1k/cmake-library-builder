# MbedTLS CMake Build System

This CMake module provides a flexible way to build and integrate MbedTLS into your CMake projects. It is designed to be included in other CMake projects and handles the MbedTLS build configuration automatically.

## Prerequisites

- CMake 3.18 or higher
- A C compiler (gcc, clang, MSVC, or MinGW)

## Project Structure

```
.
├── example
│   ├── client
│   └── server
├── mbedtls.cmake       # MbedTLS build module
└── README.md
```

### Example CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.18)
project(MbedTLSExample)

# Include the MbedTLS build module
include(mbedtls.cmake)

# Your project configuration
add_executable(your_app main.c)
target_link_libraries(your_app PRIVATE MbedTLS::mbedtls MbedTLS::mbedx509 MbedTLS::mbedcrypto)
```

## Build Options

The following options can be set before including the MbedTLS cmake file or via command line:

- **USE_SHARED** (Default: OFF)  
  Build MbedTLS as shared libraries (.dll/.so/.dylib) instead of static libraries (.lib/.a)

- **USE_SYSTEM** (Default: OFF)  
  Use MbedTLS libraries installed in the system instead of building from source

## Command Line Build Examples

### Basic Build
```bash
# Configure
cmake -B build \
    -DMBEDTLS_DIR=/path/to/mbedtls-3.4.0.tar.gz

# Build
cmake --build build
```

### Using System MbedTLS
```bash
# Configure
cmake -B build -DUSE_SYSTEM=ON

# Build
cmake --build build
```

### Using Pre-built MbedTLS
```bash
# Configure
cmake -B build \
    -DMBEDTLS_INCLUDE_DIR=/path/to/mbedtls/include \
    -DMBEDTLS_LIB_DIR=/path/to/mbedtls/lib

# Build
cmake --build build
```

### Building Shared Libraries
```bash
# Configure
cmake -B build \
    -DMBEDTLS_DIR=/path/to/mbedtls-3.4.0.tar.gz \
    -DUSE_SHARED=ON

# Build
cmake --build build
```

### Windows MSVC Build
```bat
:: Run from Visual Studio Command Prompt
cmake -B build ^
    -DMBEDTLS_DIR=C:\path\to\mbedtls-3.4.0.tar.gz

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
Provide the path to MbedTLS source archive:
```cmake
set(MBEDTLS_DIR "/path/to/mbedtls-3.4.0.tar.gz")
```

### 2. Using Pre-built MbedTLS
Specify include and library directories:
```cmake
set(MBEDTLS_INCLUDE_DIR "/path/to/mbedtls/include")
set(MBEDTLS_LIB_DIR "/path/to/mbedtls/lib")
```

### 3. Using System MbedTLS
Enable system MbedTLS usage:
```cmake
set(USE_SYSTEM ON)
```

## Library Components

MbedTLS consists of three main libraries that are provided as separate targets:

- **MbedTLS::mbedtls**: The main SSL/TLS library
- **MbedTLS::mbedx509**: X.509 certificate handling
- **MbedTLS::mbedcrypto**: Core cryptographic functions

## Troubleshooting

1. For Windows builds with MSVC, ensure you're running from a Visual Studio Command Prompt
2. For MinGW builds, ensure the correct version of MinGW is in your PATH
3. When using system libraries on Windows, make sure MbedTLS is installed in one of the standard Program Files locations
4. On Unix systems using system libraries, ensure development packages (headers) are installed

## Notes

- The build system automatically handles platform-specific library extensions (.dll, .so, .dylib)
- On Windows with shared libraries, both DLL and import libraries (.lib) are generated
- The module supports finding system-installed MbedTLS using pkg-config on Unix-like systems
- Build artifacts are placed in the build directory under 'out/dst' when building from source
