import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart' as sig;
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/helpers.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/services/note_service.dart';
import 'package:andsafe/utils/services/signature_service.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_derivators/api.dart';

const _scryptSaltLength = 32;
const _aesIvLength = 16;
const _aesKeyLength = 32;
const _signatureLength = 32;
const _scryptR = 8;
const _scryptP = 1;

//function to native scrypt
int Function(
    Pointer<Uint8> passwd,
    int passwdLen,
    Pointer<Uint8> salt,
    int saltLen,
    int N,
    int r,
    int p,
    Pointer<Uint8> buf,
    int bufLen)? _nativeScrypt;

int _getScryptN(int version) {
  switch (version) {
    case 3:
      return 16384;
    case 4:
      return 65536;
    default:
      throw ArgumentError('Unknown scrypt version: $version');
  }
}

Future<sig.Signature> createSignature(Uint8List password) async {
  final Uint8List salt = _generateRandomBytes(_scryptSaltLength);
  final Uint8List iv = _generateRandomBytes(_aesIvLength);
  final String plainText = _generateRandomString(_signatureLength);

  log.fine("Going to generate signature");
  Map data = Map();
  data['plainText'] = plainText;
  data['password'] = password;
  data['salt'] = salt;
  data['iv'] = iv;
  data['version'] = currentSignatureVer;
  final signature =
      bytesToHexString(await compute(_encrypt, data, debugLabel: "encrypt"));
  log.fine("Generated signature");

  return sig.Signature(
    null,
    plainText,
    signature
        .substring(0, signatureKeyCheckValueLengthInByte * 2)
        .toUpperCase(),
    salt,
    iv,
    currentSignatureVer,
  );
}

Future<bool> verifySignature(
    sig.Signature? signature, Uint8List? password) async {
  if (signature == null || password == null) {
    return false;
  }

  Map data = Map();
  data['payload'] = signature.payload;
  data['plain'] = signature.plain;
  data['password'] = password;
  data['salt'] = signature.salt;
  data['iv'] = signature.iv;
  data['version'] = signature.ver;

  return await _computeSignatureAndCompare(data);
}

Future<Note> createNote(
    int? id, int categoryId, String title, String plainText, Uint8List password,
    {required int version, DateTime? lastUpdated}) async {
  final Uint8List salt = _generateRandomBytes(_scryptSaltLength);
  final Uint8List iv = _generateRandomBytes(_aesIvLength);

  log.fine("Going to create an encrypted note");
  Map data = Map();
  data['plainText'] = plainText;
  data['password'] = password;
  data['salt'] = salt;
  data['iv'] = iv;
  data['version'] = version;
  final ciphertext =
      bytesToHexString(await compute(_encrypt, data, debugLabel: "encrypt"));
  log.fine("Generated ciphertext");

  return Note(
    id,
    categoryId,
    title,
    ciphertext.toUpperCase(),
    salt,
    iv,
    lastUpdated ?? DateTime.now(),
  );
}

Future<String> getNotePlainBody(
    Note note, Uint8List password, {required int version}) async {
  log.fine("Going to decrypt note body");
  Map data = Map();
  data['ciphertext'] = hexStringToBytes(note.body);
  data['password'] = password;
  data['salt'] = note.salt;
  data['iv'] = note.iv;
  data['version'] = version;

  final String plainText = utf8.decode(
      await compute(_decrypt, data, debugLabel: "decrypt"),
      allowMalformed: true);
  log.fine("Decrypted note body");
  return plainText;
}

Future<Uint8List> _encrypt(Map data) async {
  final String plainText = data['plainText'];
  final Uint8List password = data['password'];
  final Uint8List salt = data['salt'];
  final Uint8List iv = data['iv'];
  final int version = data['version'];

  final Uint8List key = await _hashPassword(salt, password, _aesKeyLength, version);

  CipherParameters params = PaddedBlockCipherParameters(
      ParametersWithIV<KeyParameter>(KeyParameter(key), iv), null);
  final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
  log.fine("Going to init cipher");
  cipher.init(true, params);
  log.fine("Going to do actual encryption");
  final result = cipher.process(utf8.encode(plainText));

  // Zero out the isolate's copy of password and key
  password.fillRange(0, password.length, 0);
  key.fillRange(0, key.length, 0);

  return result;
}

Future<Uint8List> _decrypt(Map data) async {
  final Uint8List ciphertext = data['ciphertext'];
  final Uint8List password = data['password'];
  final Uint8List salt = data['salt'];
  final Uint8List iv = data['iv'];
  final int version = data['version'];

  final Uint8List key = await _hashPassword(salt, password, _aesKeyLength, version);

  CipherParameters params = PaddedBlockCipherParameters(
      ParametersWithIV<KeyParameter>(KeyParameter(key), iv), null);
  final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
  cipher.init(false, params);
  final result = cipher.process(ciphertext);

  // Zero out the isolate's copy of password and key
  password.fillRange(0, password.length, 0);
  key.fillRange(0, key.length, 0);

  return result;
}

Future<bool> _computeSignatureAndCompare(Map data) async {
  final String payload = data['payload'];
  final String plain = data['plain'];
  final Uint8List password = data['password'];
  final Uint8List salt = data['salt'];
  final Uint8List iv = data['iv'];
  final int version = data['version'];

  try {
    if (payload.length == 0) {
      return false;
    }

    Map data = Map();
    data['plainText'] = plain;
    data['password'] = password;
    data['salt'] = salt;
    data['iv'] = iv;
    data['version'] = version;
    final String signature =
        bytesToHexString(await compute(_encrypt, data, debugLabel: "encrypt"));

    return payload.toUpperCase() ==
        signature.toUpperCase().substring(0, payload.length);
  } catch (e) {
    log.severe('Failed to verify password');
  }

  return false;
}

Future<void> migrateAllNotes(
    NoteService noteService,
    SignatureService signatureService,
    Uint8List password,
    int oldVersion,
    Future<void> Function(int current, int total) onProgress) async {
  final notes = await noteService.getNotes();
  final total = notes.length;
  final database = noteService.db;

  // Re-create signature with new scrypt params BEFORE the transaction.
  // This runs scrypt on an isolate and must happen outside the txn.
  sig.Signature newSignature = await createSignature(password);

  // Single transaction: all note updates + signature replacement
  await database.transaction((txn) async {
    // Replace signature (re-encrypted with N=65536)
    await signatureService.generateSignature(newSignature, txn);

    for (int i = 0; i < total; i++) {
      await onProgress(i + 1, total);
      final note = notes[i];

      // Decrypt with old params — runs on isolate, outside txn
      String plaintext =
          await getNotePlainBody(note, password, version: oldVersion);

      // Re-encrypt with new params — runs on isolate
      Note newNote = await createNote(
          note.id,
          note.categoryId,
          note.title,
          plaintext,
          password,
          version: currentSignatureVer,
          lastUpdated: note.lastUpdate);

      // Save in place within transaction
      await noteService.updateNote(newNote, txn);
    }
  });
}

Uint8List _generateRandomBytes(int numByte) {
  final random = Random.secure();
  return Uint8List.fromList(
      List<int>.generate(numByte, (i) => random.nextInt(256)));
}

String _generateRandomString(int length) {
  const chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890_';
  final random = Random.secure();
  return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
}

Future<Uint8List> _hashPassword(
    Uint8List salt, Uint8List password, int length, int version) async {
  final int n = _getScryptN(version);
  Pointer<Uint8>? saltBuffer;
  Pointer<Uint8>? passwordBuffer;
  Pointer<Uint8>? resultBuffer;
  try {
    if (_nativeScrypt == null) {
      final DynamicLibrary nativeScryptLib = Platform.isAndroid
          ? DynamicLibrary.open("libcrypto_scrypt.so")
          : DynamicLibrary.process();
      _nativeScrypt = nativeScryptLib
          .lookup<
              NativeFunction<
                  Int32 Function(
                      Pointer<Uint8>,
                      IntPtr,
                      Pointer<Uint8>,
                      IntPtr,
                      Uint64,
                      Uint32,
                      Uint32,
                      Pointer<Uint8>,
                      IntPtr)>>("crypto_scrypt")
          .asFunction();
    }

    // TODO minimize memory copy
    saltBuffer = calloc<Uint8>(salt.length);
    saltBuffer.asTypedList(salt.length).setRange(0, salt.length, salt);

    // TODO minimize memory copy
    passwordBuffer = calloc<Uint8>(password.length);
    passwordBuffer
        .asTypedList(password.length)
        .setRange(0, password.length, password);

    resultBuffer = calloc<Uint8>(length);

    int errorCode = _nativeScrypt!(passwordBuffer, password.length, saltBuffer,
        salt.length, n, _scryptR, _scryptP, resultBuffer, length);
    if (errorCode == 0) {
      return Uint8List.fromList(resultBuffer.asTypedList(length));
    }
  } catch (e) {
    log.fine('Failed to use native scrypt');
    log.fine(e);
  } finally {
    if (saltBuffer != null) {
      calloc.free(saltBuffer);
    }
    if (passwordBuffer != null) {
      passwordBuffer
          .asTypedList(password.length)
          .fillRange(0, password.length, 0);
      calloc.free(passwordBuffer);
    }
    if (resultBuffer != null) {
      calloc.free(resultBuffer);
    }
  }

  // fallback to Dart version
  log.fine("Deriving key...");
  final kd = KeyDerivator('scrypt');
  kd.init(ScryptParameters(n, _scryptR, _scryptP, length, salt));
  final result = kd.process(password);
  password.fillRange(0, password.length, 0);
  log.fine("Key derived");
  return result;
}
