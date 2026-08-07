cmake_minimum_required(VERSION 3.4.1)

add_library(crypto_scrypt
            # as a shared library
            SHARED
            # source files
            src/main/native/crypto_scrypt-nosse.c src/main/native/sha256.c)

target_compile_definitions (crypto_scrypt PUBLIC HAVE_CONFIG_H)

# Optimization flags for scrypt performance
target_compile_options(crypto_scrypt PRIVATE
    -O2
    -funroll-loops
    -fomit-frame-pointer
)

# Enable NEON on 32-bit ARM
if(ANDROID_ABI STREQUAL "armeabi-v7a")
    target_compile_options(crypto_scrypt PRIVATE -mfpu=neon)
endif()

# Enable ARMv8 Cryptography Extensions on 64-bit ARM
if(ANDROID_ABI STREQUAL "arm64-v8a")
    target_compile_options(crypto_scrypt PRIVATE -march=armv8-a+crypto)
endif()
