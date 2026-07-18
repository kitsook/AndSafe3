<p align="center">
  <img src="https://user-images.githubusercontent.com/13360325/116012081-3924ca80-a5dd-11eb-89ab-9c8543302d7b.png" alt="AndSafe Logo" width="128"/>
</p>

<h1 align="center">AndSafe3</h1>

<p align="center">
  <strong>A secure, open-source encrypted notes application for Android</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#security">Security</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#faq">FAQ</a> •
  <a href="#license">License</a>
</p>

---

> **Note:** Due to changes in Google's developer profile policy, AndSafe3 is no longer listed on Google Play. You can build the application from source using the instructions below.

## Overview

AndSafe3 is an offline-first, client-side encrypted notes app built with [Flutter](https://flutter.dev/). It is the third-generation rewrite of the original AndroidSafe app, now fully open source under the MIT license.

All encryption and decryption happen entirely on-device — AndSafe3 has **no network functionality** and never transmits data to any server.

## Features

- 🔐 **AES-256-CBC Encryption** — Every note is individually encrypted using AES in CBC mode with a 256-bit key
- 🧂 **scrypt Key Derivation** — Password-based key derivation using scrypt (N=65536, r=8, p=1) with per-note salts
- 🔑 **Biometric Authentication** — Optional fingerprint / face unlock for session access
- 📂 **Import & Export** — Portable encrypted backup format; import notes from AndSafe v2
- 🔍 **Full-Text Search** — Fast, indexed search powered by SQLite FTS3
- 🌐 **Localization** — Internationalization support via Flutter's `intl` package
- 🛡️ **Screen Capture Protection** — Prevents screenshots of sensitive content
- 🖥️ **Cross-Platform Note Reader** — Read exported notes on desktop via the companion [PyAndSafe](https://github.com/kitsook/PyAndSafe) project

## Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/10f6a0a3-7325-42d0-b04d-0bb862eb23cf" width="200" alt="Note list view"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/9122b885-e487-414b-b320-bbff77c15d25" width="200" alt="Note editing view"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/25dbb8f5-99fc-4da8-b874-442a75ed3c6b" width="200" alt="Settings view"/>
</p>

## Architecture

AndSafe3 follows a clean, modular architecture built on the Provider pattern for dependency injection:

```
lib/
├── models/           # Domain objects (Note, Signature)
├── pages/            # UI page widgets (home, note list, note editor, etc.)
└── utils/
    ├── services/     # Service layer (NoteService, SignatureService, AuthService, DatabaseHelper)
    └── andsafe_crypto.dart   # Cryptographic primitives and key derivation
```

| Layer | Responsibility |
|-------|---------------|
| **UI (Pages)** | Presentation logic, user interactions |
| **Services** | Business logic, CRUD operations, authentication |
| **Database** | SQLite storage with FTS3 search indexing |
| **Crypto** | AES-CBC encryption, scrypt key derivation, KCV verification |

CPU-intensive cryptographic operations are executed in background Dart isolates via `compute()` to maintain a smooth UI.

For detailed architectural documentation, see [docs/technical-design.md](docs/technical-design.md).

## Security

### Encryption Specification

| Property | Value |
|----------|-------|
| Algorithm | AES-CBC with PKCS7 padding |
| Key Length | 256 bits |
| Key Derivation | scrypt (N=65536, r=8, p=1) |
| Salt | Unique per note |
| IV | Unique per note |
| AES Implementation | [Pointy Castle](https://pub.dev/packages/pointycastle) |
| scrypt Implementation | Native C via [Tarsnap/scrypt](https://github.com/Tarsnap/scrypt) |

### Password Verification

Password correctness is verified using a **Key Check Value (KCV)** mechanism rather than storing the password itself. A random plaintext string is encrypted and the resulting ciphertext (truncated to 3 bytes) is stored as the verification token. This avoids exposing high-entropy key material.

### Per-Note Key Derivation

Each note is encrypted with its own derived key. This design originates from the original AndroidSafe v1, which supported sharing individual encrypted notes. As a consequence, operations such as password changes or bulk imports require re-deriving keys and re-encrypting every note within an atomic database transaction.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.12.0)
- Android SDK with NDK (required for native scrypt compilation)

### Build & Run

```bash
# Clone the repository
git clone https://github.com/kitsook/AndSafe3.git
cd AndSafe3

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Running Tests

```bash
flutter test
```

## FAQ

<details>
<summary><strong>I forgot my password. Can you help me recover it?</strong></summary>

No. AndSafe3 uses client-side-only encryption with no backdoors. If you lose your password, your encrypted notes cannot be recovered.
</details>

<details>
<summary><strong>How do I back up my notes?</strong></summary>

Use the **Export notes** function within the app to save all notes to an encrypted backup file. Copy this file to your computer or external storage for safekeeping.

Although exported notes are encrypted, you should still protect the backup file as a best practice.
</details>

<details>
<summary><strong>Where are exported notes stored?</strong></summary>

- **AndSafe v2:** `AndroidSafeExports/` under internal storage.
- **AndSafe3:** When you export, the app opens a **system directory picker** (Android's Storage Access Framework) so you choose the destination folder yourself. The exported file is an XML file named with a timestamp, e.g., `AndSafe20260717_230000.xml`.

> [!NOTE]
> On modern Android (11+), the directory picker may restrict access to certain root-level folders (e.g., the top-level `Download` directory). You can typically select a subfolder within `Documents` or other user directories. Files saved to user-owned folders will **persist even if the app is uninstalled**.
</details>

<details>
<summary><strong>Can I import notes from a previous version?</strong></summary>

Yes. AndSafe3 can import notes exported from AndSafe v2. Export your notes in the older app, then use the import function in AndSafe3. Note that the reverse (v3 → v2) is not supported.
</details>

<details>
<summary><strong>How does search work?</strong></summary>

The full-text search matches from the **beginning of whole words** only. For example, if a note title is "Password for foobar.com", searching for "pass", "foo", or "com" will find it, but "bar" will not.

This is a limitation of the SQLite FTS3 engine used for backward compatibility.
</details>

<details>
<summary><strong>Can I read encrypted notes on my computer?</strong></summary>

Yes. The companion [PyAndSafe](https://github.com/kitsook/PyAndSafe) project provides a Python GUI application for reading exported AndSafe notes on desktop.
</details>

## Acknowledgements

- **App Icon:** From [DelliPack](https://www.smashingmagazine.com/2008/07/55-free-high-quality-icon-sets/#dellipack) by [Wendell Fernandes](http://dellustrations.deviantart.com/)
- **AES Implementation:** [Pointy Castle](https://pub.dev/packages/pointycastle)
- **scrypt Implementation:** [Colin Percival / Tarsnap](https://github.com/Tarsnap/scrypt)

## License

This project is licensed under the [MIT License](LICENSE).

Copyright © 2021 Clarence K.C. Ho
