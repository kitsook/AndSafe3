cmake_minimum_required(VERSION 3.4.1)

add_library(crypto_scrypt
            # as a shared library
            SHARED
            # source files
            src/main/native/crypto_scrypt-nosse.c src/main/native/sha256.c)

target_compile_definitions (crypto_scrypt PUBLIC HAVE_CONFIG_H)

