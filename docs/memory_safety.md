# Memory Safety Improvement Plan for AndSafe

This document outlines a phased approach to improving the memory safety of the AndSafe application, mitigating the risks associated with sensitive data (keys, salts, plaintext notes) persisting in the Dart heap.

## Overview

In a garbage-collected language like Dart, sensitive data held in immutable objects like `String` can linger in memory indefinitely, even after they are no longer in use. This plan moves from application-level patterns to low-level native memory management.

---

## Phase 1: Primitive Refactoring (The "Mutable Buffer" Pattern)
**Goal:** Eliminate the use of immutable `String` objects for sensitive data.

1.  **Standardize on `Uint8List`**:
    *   Refactor `AuthService`, `NoteService`, and `AndSafeCrypto` to handle keys, salts, IVs, and plaintext content exclusively as `Uint8List` (from `dart:typed_data`).
    *   Avoid any conversion of sensitive bytes back into `String` objects.
2.  **Implement Manual Zeroing**:
    *   Establish a pattern where every service receiving a `Uint8List` must call `.fillRange(0, length, 0)` on that buffer as soon as its purpose is fulfilled (e.g., immediately after encryption or after a UI component is disposed).
3.  **Minimize String Conversions**:
    *   Audit the codebase to ensure that `utf8.encode()` and `utf8.decode()` do not create long-lived `String` objects from sensitive data.

## Phase 2: Architectural Hardening (The "Scoped Lifecycle" Pattern)
**Goal:** Ensure sensitive data exists only within the narrowest possible scope of the application.

1.  **Isolate-Level Cleanup**:
    *   Since cryptographic functions use `compute()` (Isolates), ensure that the sensitive buffers within those Isolates are explicitly zeroed before the Isolate finishes its execution.
2.  **Scoped Memory Ownership**:
    *   Redesign data models so that `Note` objects primarily hold ciphertext.
    *   Plaintext content should only exist in temporary, short-lived `Uint8List` buffers used during the UI rendering phase.
3.  **Session-Based Purging**:
    *   Implement a "global wipe" mechanism triggered by `AuthService` during logout or app backgrounding.
    *   This mechanism should trigger a cascade of zeroing operations across all active services.

## Phase 3: Native Integration (The "Gold Standard" Pattern)
**Goal:** Move the most critical operations outside of the Dart Garbage Collector's control.

1.  **Use `dart:ffi` for Secret Storage**:
    *   Use the Foreign Function Interface (FFI) to allocate memory using C's `malloc`.
    *   Memory allocated via FFI is not managed by the Dart GC, allowing for deterministic wiping using `memset` and controlled deallocation via `free`.
2.  **Native Key Derivation**:
    *   Move `scrypt` key derivation to the Android native side (Kotlin or C++). This ensures the master key is derived and processed in a memory space that the Dart VM cannot inspect or move.
3.  **Hardware-Backed Wrapping**:
    *   Leverage the Android Keystore to wrap/unwrap keys, ensuring that the root of trust is tied to the device's hardware security module (HSM).

---

## Implementation Audit Checklist

*   [ ] **Search for `String`**: Identify all sensitive variables currently typed as `String`.
*   [ ] **Search for `utf8`**: Find where sensitive bytes are being converted to/from `String`.
*   [ ] **Log Audit**: Ensure no sensitive data or keys are being passed to `print()` or logging utilities.
*   [ ] **Isolate Audit**: Verify that data passed to `compute()` is zeroed before the worker thread exits.
