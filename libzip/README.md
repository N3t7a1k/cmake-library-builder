# LibZip CMake Build System
This CMake module provides a flexible way to build and integrate LibZip into your CMake projects. It is designed to be included in other CMake projects and handles the LibZip build configuration automatically.

## Prerequisites
- CMake 3.18 or higher
- A C compiler (gcc, clang, MSVC, or MinGW)
- ZLIB library (automatically detected)
- For encryption: OpenSSL or MbedTLS

## Project Structure
```
.
├── example
│   ├── CMakeLists.txt
│   └── zip_tool.c
├── README.md
└── libzip.cmake
```

## Project Integration
### Example CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.18)
project(LibZipExample)

# Include the LibZip build module
include(libzip.cmake)

# Your project configuration
add_executable(your_app main.c)
target_link_libraries(your_app PRIVATE LIBZIP::LIBZIP)
```

## Build Options
The following options can be set before including the LibZip cmake file or via command line:

- **USE_SHARED** (Default: OFF)  
  Build LibZip as shared libraries (.dll/.so/.dylib) instead of static libraries (.lib/.a)
- **USE_SYSTEM** (Default: OFF)  
  Use LibZip libraries installed in the system instead of building from source
- **ENABLE_CRYPTO** (Default: ON)  
  Enable encryption support
- **USE_OPENSSL** (Default: OFF)  
  Use OpenSSL for encryption support
- **USE_MBEDTLS** (Default: OFF)  
  Use MbedTLS for encryption support

## Command Line Build Examples
### Basic Build
```bash
# Configure
cmake -B build \
    -DLIBZIP_DIR=/path/to/libzip-1.9.2.tar.gz
# Build
cmake --build build
```

### Using System LibZip
```bash
# Configure
cmake -B build -DUSE_SYSTEM=ON
# Build
cmake --build build
```

### Using Pre-built LibZip
```bash
# Configure
cmake -B build \
    -DLIBZIP_INCLUDE_DIR=/path/to/libzip/include \
    -DLIBZIP_LIB_DIR=/path/to/libzip/lib
# Build
cmake --build build
```

### Building with OpenSSL Support
```bash
# Configure with system OpenSSL
cmake -B build \
    -DLIBZIP_DIR=/path/to/libzip-1.9.2.tar.gz \
    -DENABLE_CRYPTO=ON \
    -DUSE_OPENSSL=ON

# Configure with specific OpenSSL installation
cmake -B build \
    -DLIBZIP_DIR=/path/to/libzip-1.9.2.tar.gz \
    -DENABLE_CRYPTO=ON \
    -DUSE_OPENSSL=ON \
    -DOPENSSL_INCLUDE_DIR=/path/to/openssl/include \
    -DOPENSSL_LIB_DIR=/path/to/openssl/lib
```

### Building with MbedTLS Support
```bash
# Configure with system MbedTLS
cmake -B build \
    -DLIBZIP_DIR=/path/to/libzip-1.9.2.tar.gz \
    -DENABLE_CRYPTO=ON \
    -DUSE_MBEDTLS=ON

# Configure with specific MbedTLS installation
cmake -B build \
    -DLIBZIP_DIR=/path/to/libzip-1.9.2.tar.gz \
    -DENABLE_CRYPTO=ON \
    -DUSE_MBEDTLS=ON \
    -DMBEDTLS_INCLUDE_DIR=/path/to/mbedtls/include \
    -DMBEDTLS_LIB_DIR=/path/to/mbedtls/lib
```

### Cross-Compilation
```bash
# Configure with toolchain and crypto library paths
cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=/path/to/toolchain.cmake \
    -DLIBZIP_DIR=/path/to/libzip-1.9.2.tar.gz \
    -DENABLE_CRYPTO=ON \
    -DUSE_OPENSSL=ON \
    -DOPENSSL_INCLUDE_DIR=/path/to/openssl/include \
    -DOPENSSL_LIB_DIR=/path/to/openssl/lib
```

## Platform Support
### Linux
- x86_64
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
Provide the path to LibZip source archive:
```cmake
set(LIBZIP_DIR "/path/to/libzip-1.9.2.tar.gz")
```

### 2. Using Pre-built LibZip
Specify include and library directories:
```cmake
set(LIBZIP_INCLUDE_DIR "/path/to/libzip/include")
set(LIBZIP_LIB_DIR "/path/to/libzip/lib")
```

### 3. Using System LibZip
Enable system LibZip usage:
```cmake
set(USE_SYSTEM ON)
```

## Encryption Support
LibZip supports two encryption backends:
- OpenSSL (default when encryption is enabled)
- MbedTLS

Only one encryption backend can be enabled at a time. If both backends are specified, an error will be raised.

For cross-compilation or specific installations, you must provide the include and library directories for the chosen crypto library:
```cmake
# For OpenSSL
set(OPENSSL_INCLUDE_DIR "/path/to/openssl/include")
set(OPENSSL_LIB_DIR "/path/to/openssl/lib")

# For MbedTLS
set(MBEDTLS_INCLUDE_DIR "/path/to/mbedtls/include")
set(MBEDTLS_LIB_DIR "/path/to/mbedtls/lib")
```

## Troubleshooting
1. For Windows builds with MSVC, ensure you're running from a Visual Studio Command Prompt
2. Make sure ZLIB is properly installed and can be found by CMake
3. When using encryption, ensure the chosen crypto library is installed and accessible
4. For cross-compilation, crypto library paths must be specified explicitly
5. For system installations on Windows, check standard installation paths (%PROGRAMFILES%/libzip)

## Notes
- The build system automatically detects the appropriate library suffix based on your system (.dll/.so/.dylib for shared libraries, .lib/.a for static libraries)
- When building shared libraries on Windows, both DLL and import libraries (.lib) are generated
- Build parallelization is automatically configured based on the number of available CPU cores
- Cross-compilation is fully supported with explicit crypto library paths
