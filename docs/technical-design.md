# AndSafe Technical Design & Developer Guide

## System Overview
AndSafe is a secure, client-side encrypted notes application built with Flutter and SQLite. The codebase is designed around offline-first security, biometric authentication, and modular architecture.

---

## Directory Structure
* `lib/models/`: Holds domain objects (`Note`, `Signature`).
* `lib/pages/`: Contains all UI page widgets (`home.dart`, `note_list.dart`, `note_edit.dart`, etc.).
* `lib/utils/services/`: Services representing different domains (`NoteService`, `SignatureService`, `DatabaseHelper`, `AuthService`).
* `lib/utils/andsafe_crypto.dart`: Cryptographic primitives, algorithms, and key derivation logic.

---

## Database Design

The application uses SQLite as its primary storage engine.

### Tables

#### 1. `notes`
Holds all note records.
* `_id`: `INTEGER PRIMARY KEY AUTOINCREMENT`
* `cat_id`: `INTEGER NOT NULL`
* `title`: `TEXT NOT NULL` (plaintext note title, searchable)
* `body`: `TEXT NOT NULL` (encrypted ciphertext of note body)
* `salt`: `BLOB` (salt used for PBKDF2/scrypt key derivation)
* `iv`: `BLOB` (AES initialization vector)
* `last_update`: `DATE` (timestamp of the last modification)

#### 2. `signature`
Password verifier table implementing a Key Check Value (KCV) mechanism.
* `_id`: `INTEGER PRIMARY KEY AUTOINCREMENT`
* `plain`: `TEXT` (random plaintext string generated upon password setup)
* `payload`: `TEXT` (encrypted ciphertext of `plain`, truncated to 3 bytes / 6 hex characters)
* `salt`: `BLOB`
* `iv`: `BLOB`
* `ver`: `INTEGER` (signature format version)

#### 3. `searchable`
SQLite FTS3 virtual table used for case-insensitive note search.
* `title`: `TEXT`
* Maps to `notes._id` via the `docid` column.

### Indexes
* `idx_notes_title_nocase` on `notes(title collate nocase)`: Optimizes case-insensitive sorting by title.
* `idx_notes_last_update` on `notes(last_update)`: Optimizes sorting by modification date.

---

## Architectural & Data Flow Patterns

### 1. Separation of Concerns (SoC)
* **`DatabaseHelper`**: Manages opening the SQLite connection, creating tables (`onCreate`), and running migration steps (`onUpgrade`).
* **`NoteService`**: Houses all note CRUD methods (insert, update, delete, get, search).
* **`SignatureService`**: Handles signature generation, validation, and retrieval.
* **`AuthService`**: Manages session state, biometric authentication, password validation, and initiates key migrations.

### 2. Dependency Injection & State Management
Services are supplied down the widget tree using the `provider` package. In `main.dart`, services are initialized with a raw `Database` connection:
```dart
Provider<NoteService>.value(value: noteService)
Provider<SignatureService>.value(value: signatureService)
```
UI widgets retrieve services directly from their `BuildContext` (e.g. `Provider.of<NoteService>(context, listen: false)`).

---

## Cryptographic Design

### 1. Key Derivation & Specs
* **Version 4 (Current)**:
  * Key Derivation: `scrypt` with parameters `N = 65536`, `r = 8`, `p = 1`, key length = 32 bytes.
  * Encryption: AES-CBC (using PKCS7 padding).
* **Version 3 (Legacy)**:
  * Key Derivation: PBKDF2 with HMAC-SHA256, 10,000 iterations.
* **Key Check Value (KCV) Verification**:
  * To verify password correctness, the application encrypts the random signature `plain` string and compares the resulting ciphertext (truncated to the KCV length of 3 bytes) with the stored `payload`. This avoids storing user passwords or exposing high-entropy key verification blocks.

### 2. Note Migration Pipeline
When the user changes their password or upgrades signature versions:
1. Load all notes into memory.
2. Derives new key using `createSignature()` outside the transaction.
3. Wraps the migration loop inside an atomic SQLite `db.transaction()` block:
   * Generates and inserts the new signature record.
   * For each note, decrypts the body using the old password/version.
   * Re-encrypts the body with the new password/version.
   * Updates the note record.
4. Any failure inside the block aborts the operation and rolls back the database state.

---

## Technical Constraints & Edge Cases

### 1. SQLite Max Variable Parameter Limit
SQLite throws a crash if a query receives more than 999 positional host arguments (`?`).
* **Scenario**: Querying a set of IDs: `_id IN (?, ?, ..., ?)`.
* **Fix**: `NoteService.getNotes` partitions the list of requested IDs into chunks of 999, runs a separate query for each chunk, aggregates the rows, and performs a secondary deterministic sort in Dart.

### 2. Deterministic Sorting
To prevent UI sorting discrepancies across platforms, sorting conditions must always be deterministic by using tie-breakers:
* **Sort by Title**: `title COLLATE NOCASE ASC/DESC, last_update DESC, _id DESC`
* **Sort by Last Update**: `last_update ASC/DESC, _id DESC`

### 3. Isolation Boundaries (Isolates)
Because cryptographic functions (key derivation, encryption, decryption) are CPU-heavy, they are always executed inside background Dart isolates using the `compute()` utility. They must not run on the main UI thread to prevent stuttering.

### 4. Error Handling & Resiliency Strategy
All database helper initialization, note, and signature queries are wrapped inside structured `try-catch` blocks at the service boundary.
* **Logging**: Catastrophic database issues (such as table creation failures, structural upgrade errors, or query locks) are logged with a severity of `severe` including the exception details and complete stack trace using service-specific logs (e.g., `NoteService`, `SignatureService`, `DatabaseHelper`).
* **Flow Control**: Service operations log errors and immediately `rethrow` the exceptions. This ensures that caller layers (such as `AuthService` or UI pages) can handle the exception, abort ongoing multi-step processes safely, and present user-friendly Snackbars or dialogs.

---

## Static Analysis & Coding Standards

The project uses `flutter_lints` to enforce coding style and guidelines.

* **Configuration**: The rules are configured in `analysis_options.yaml` at the project root.
* **Strict Compliance**: The codebase is 100% compliant with the recommended Flutter static analysis preset. No rules are disabled, guaranteeing clean static analysis runs.
* **File Naming**: All files must follow the standard Dart `snake_case` convention. For example, the theme changing class file is named `theme_changer.dart`.
