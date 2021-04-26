import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart' as sig;
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/helpers.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_derivators/api.dart';


const _scryptSaltLength = 32;
const _aesIvLength = 16;
const _aesKeyLength = 32;
const _signatureLength = 32;

//function to native scrypt
int Function(Pointer<Uint8> passwd, int passwdLen, Pointer<
    Uint8> salt, int saltLen, int N, int r, int p, Pointer<
    Uint8> buf, int bufLen)? _nativeScrypt;

Future<sig.Signature> createSignature(String password) async {
  final Uint8List salt = _generateRandomBytes(_scryptSaltLength);
  final Uint8List iv = _generateRandomBytes(_aesIvLength);
  final String plainText = _generateRandomString(_signatureLength);

  log.fine("Going to generate signature");
  Map data = Map();
  data['plainText'] = plainText;
  data['password'] = password;
  data['salt'] = salt;
  data['iv'] = iv;
  final signature =
      bytesToHexString(await compute(_encrypt, data, debugLabel: "encrypt"));
  log.fine("Generated signature");

  return sig.Signature(
    null,
    plainText,
    signature.substring(0, signatureKeyCheckValueLengthInByte * 2).toUpperCase(),
    salt,
    iv,
    currentSignatureVer,
  );
}

Future<bool> verifySignature(sig.Signature? signature, String? password) async {
  if (signature == null || password == null) {
    return false;
  }

  Map data = Map();
  data['payload'] = signature.payload;
  data['plain'] = signature.plain;
  data['password'] = password;
  data['salt'] = signature.salt;
  data['iv'] = signature.iv;

  return await _computeSignatureAndCompare(data);
}

Future<Note> createNote(int? id, int categoryId, String title, String plainText,
    String password, [DateTime? lastUpdated]) async {
  final Uint8List salt = _generateRandomBytes(_scryptSaltLength);
  final Uint8List iv = _generateRandomBytes(_aesIvLength);

  log.fine("Going to create an encrypted note");
  Map data = Map();
  data['plainText'] = plainText;
  data['password'] = password;
  data['salt'] = salt;
  data['iv'] = iv;
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
    lastUpdated == null? DateTime.now() : lastUpdated,
  );
}

Future<String> getNotePlainBody(Note note, String password) async {
  log.fine("Going to decrypt note body");
  Map data = Map();
  data['ciphertext'] = hexStringToBytes(note.body);
  data['password'] = password;
  data['salt'] = note.salt;
  data['iv'] = note.iv;

  final String plainText = utf8.decode(
      await compute(_decrypt, data, debugLabel: "decrypt"),
      allowMalformed: true);
  log.fine("Decrypted note body");
  return plainText;
}

Future<Uint8List> _encrypt(Map data) async {
  final String plainText = data['plainText'];
  final String password = data['password'];
  final Uint8List salt = data['salt'];
  final Uint8List iv = data['iv'];

  final Uint8List key = await _hashPassword(salt, password, _aesKeyLength);

  CipherParameters params = PaddedBlockCipherParameters(
      ParametersWithIV<KeyParameter>(KeyParameter(key), iv), null);
  final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
  log.fine("Going to init cipher");
  cipher.init(true, params);
  log.fine("Going to do actual encryption");
  return cipher.process(utf8.encode(plainText) as Uint8List);
}

Future<Uint8List> _decrypt(Map data) async {
  final Uint8List ciphertext = data['ciphertext'];
  final String password = data['password'];
  final Uint8List salt = data['salt'];
  final Uint8List iv = data['iv'];

  final Uint8List key = await _hashPassword(salt, password, _aesKeyLength);

  CipherParameters params = PaddedBlockCipherParameters(
      ParametersWithIV<KeyParameter>(KeyParameter(key), iv), null);
  final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
  cipher.init(false, params);
  return cipher.process(ciphertext);
}

Future<bool> _computeSignatureAndCompare(Map data) async {
  final String payload = data['payload'];
  final String plain = data['plain'];
  final String password = data['password'];
  final Uint8List salt = data['salt'];
  final Uint8List iv = data['iv'];

  try {
    if (payload.length == 0) {
      return false;
    }

    Map data = Map();
    data['plainText'] = plain;
    data['password'] = password;
    data['salt'] = salt;
    data['iv'] = iv;
    final String signature =
      bytesToHexString(await compute(_encrypt, data, debugLabel: "encrypt"));

    return payload.toUpperCase() == signature.toUpperCase().substring(0, payload.length);
  } catch (e) {
    log.severe('Failed to verify password');
  }
  return false;
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
    Uint8List salt, String password, int length) async {

  Pointer<Uint8>? saltBuffer;
  Pointer<Uint8>? passwordBuffer;
  Pointer<Uint8>? resultBuffer;
  try {
    if (_nativeScrypt == null) {
      final DynamicLibrary nativeScryptLib = Platform.isAndroid
          ? DynamicLibrary.open("libcrypto_scrypt.so")
          : DynamicLibrary.process();
      _nativeScrypt = nativeScryptLib
          .lookup<NativeFunction<Int32 Function(Pointer<Uint8>, IntPtr, Pointer<
          Uint8>, IntPtr, Uint64, Uint32, Uint32, Pointer<Uint8>, IntPtr)>>(
          "crypto_scrypt")
          .asFunction();
    }

    // TODO minimize memory copy
    saltBuffer = calloc<Uint8>(salt.length);
    saltBuffer.asTypedList(salt.length).setRange(0, salt.length, salt);

    // TODO minimize memory copy
    List<int> passwordEncoded = utf8.encode(password);
    passwordBuffer = calloc<Uint8>(passwordEncoded.length);
    passwordBuffer.asTypedList(passwordEncoded.length).setRange(0, passwordEncoded.length, passwordEncoded);

    resultBuffer = calloc<Uint8>(length);

    int errorCode = _nativeScrypt!(passwordBuffer, passwordEncoded.length, saltBuffer, salt.length, 16384, 8, 1, resultBuffer, length);
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
      calloc.free(passwordBuffer);
    }
    if (resultBuffer != null) {
      calloc.free(resultBuffer);
    }
  }

  log.fine("Deriving key...");
  final kd = KeyDerivator('scrypt');
  kd.init(ScryptParameters(16384, 8, 1, length, salt));
  final result = kd.process(utf8.encode(password) as Uint8List);
  log.fine("Key derived");
  return result;
}

