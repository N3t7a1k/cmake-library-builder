# OpenSSL CMake Build System

This CMake module provides a flexible way to build and integrate OpenSSL into your CMake projects. It is designed to be included in other CMake projects and handles the OpenSSL build configuration automatically.

## Prerequisites

- CMake 3.18 or higher
- Perl (required for building OpenSSL from source)
- A C compiler (gcc, clang, MSVC, or MinGW)

## Project Integration

### Project Structure
The module provides example client/server applications showing OpenSSL integration:
```
.
├── example
│   ├── client
│   │   ├── CMakeLists.txt
│   │   └── main.c
│   └── server
│       ├── CMakeLists.txt
│       └── main.c
├── openssl.cmake       # OpenSSL build module
├── README.md
└── toolchain.cmake.sample
```

### Example CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.18)
project(OpenSSLExample)

# Include the OpenSSL build module
include(openssl.cmake)

# Your project configuration
add_executable(your_app main.c)
add_dependencies(your_app openssl)
target_link_libraries(your_app PRIVATE OpenSSL::SSL OpenSSL::Crypto)
```

## Build Options

The following options can be set before including the OpenSSL cmake file or via command line:

- **USE_SHARED** (Default: OFF)  
  Build OpenSSL as shared libraries (.dll/.so/.dylib) instead of static libraries (.lib/.a)

- **USE_SYSTEM** (Default: OFF)  
  Use OpenSSL libraries installed in the system instead of building from source

- **ENHANCE_SECURITY** (Default: OFF)  
  Enable additional security features including:
  - TLS 1.3 support
  - Disable weak SSL ciphers
  - Disable deprecated features

- **ENABLE_TESTS** (Default: OFF)  
  Build and run OpenSSL test suite during the build process

## Command Line Build Examples

### Basic Build
```bash
# Configure
cmake -B build \
    -DOPENSSL_DIR=/path/to/openssl-3.0.0.tar.gz

# Build
cmake --build build
```

### Using System OpenSSL
```bash
# Configure
cmake -B build -DUSE_SYSTEM=ON

# Build
cmake --build build
```

### Using Pre-built OpenSSL
```bash
# Configure
cmake -B build \
    -DOPENSSL_INCLUDE_DIR=/path/to/openssl/include \
    -DOPENSSL_LIB_DIR=/path/to/openssl/lib

# Build
cmake --build build
```

### Building Shared Libraries
```bash
# Configure
cmake -B build \
    -DOPENSSL_DIR=/path/to/openssl-3.0.0.tar.gz \
    -DUSE_SHARED=ON

# Build
cmake --build build
```

### Enhanced Security Build
```bash
# Configure
cmake -B build \
    -DOPENSSL_DIR=/path/to/openssl-3.0.0.tar.gz \
    -DENHANCE_SECURITY=ON

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
    -DOPENSSL_DIR=/path/to/openssl-3.0.0.tar.gz

# Build
cmake --build build
```

### Cross Compilation with Custom Toolchain
```bash
# Configure
cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=/path/to/your-toolchain.cmake \
    -DOPENSSL_DIR=/path/to/openssl-3.0.0.tar.gz

# Build
cmake --build build
```

### Windows MSVC Build
```bat
:: Run from Visual Studio Command Prompt
cmake -B build ^
    -DOPENSSL_DIR=C:\path\to\openssl-3.0.0.tar.gz

cmake --build build --config Release
```

### Build with Specific Generator
```bash
# Configure with Ninja generator
cmake -B build \
    -GNinja \
    -DOPENSSL_DIR=/path/to/openssl-3.0.0.tar.gz

# Build
cmake --build build
```

### Clean Build
```bash
# Remove build directory and rebuild
rm -rf build
cmake -B build -DOPENSSL_DIR=/path/to/openssl-3.0.0.tar.gz
cmake --build build
```

## Platform Support

### Linux
- x86_64
- i386 (i686)
- ARM (armv7l, armv8l, arm)
- AArch64
- MIPS
- MIPSEL
- RISC-V (riscv64)

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
Provide the path to OpenSSL source archive:
```cmake
set(OPENSSL_DIR "/path/to/openssl-3.0.0.tar.gz")
```

### 2. Using Pre-built OpenSSL
Specify include and library directories:
```cmake
set(OPENSSL_INCLUDE_DIR "/path/to/openssl/include")
set(OPENSSL_LIB_DIR "/path/to/openssl/lib")
```

### 3. Using System OpenSSL
Enable system OpenSSL usage:
```cmake
set(USE_SYSTEM ON)
```

## Troubleshooting

1. If building from source fails, ensure Perl is installed and accessible in your PATH
2. For Windows builds with MSVC, ensure you're running from a Visual Studio Command Prompt
3. For MinGW builds, ensure the correct version of MinGW is in your PATH
4. For cross-compilation, ensure all required toolchain components are properly installed and accessible

## Notes

- The build system automatically detects the appropriate OpenSSL target based on your system architecture and compiler
- When building shared libraries on Windows, both DLL and import libraries (.lib) are generated
- Build parallelization is automatically configured based on the number of available CPU cores
- When cross-compiling, make sure your toolchain file properly sets up the target architecture and system
