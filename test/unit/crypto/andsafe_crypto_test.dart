import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart' as sig;
import 'package:andsafe/utils/andsafe_crypto.dart';

void main() {
  group('createNote / getNotePlainBody', () {
    test('create note and decrypt round-trip', () async {
      final password = Uint8List.fromList(utf8.encode('testpass123'));
      final plainText = 'This is a secret note with some content.';

      final note = await createNote(
        null, 0, 'Secret Note', plainText, password, version: 4,
      );

      expect(note.title, 'Secret Note');
      expect(note.categoryId, 0);
      expect(note.id, isNull);
      expect(note.body, isNot(plainText));
      expect(note.salt.length, 32);
      expect(note.iv.length, 16);

      final decrypted = await getNotePlainBody(note, password, version: 4);
      expect(decrypted, plainText);
    });

    test('decrypt with wrong password throws exception', () async {
      final password = Uint8List.fromList(utf8.encode('correct'));
      final wrongPassword = Uint8List.fromList(utf8.encode('wrong'));
      final plainText = 'Secret data';

      final note = await createNote(
        null, 0, 'Test', plainText, password, version: 4,
      );

      expect(
        () => getNotePlainBody(note, wrongPassword, version: 4),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('create note with custom id', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final note = await createNote(
        42, 1, 'Custom ID Note', 'body', password, version: 4,
      );
      expect(note.id, 42);
      expect(note.categoryId, 1);
    });

    test('create note with custom lastUpdated', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final customTime = DateTime(2023, 5, 15, 10, 30, 0);
      final note = await createNote(
        null, 0, 'Note', 'body', password, version: 4, lastUpdated: customTime,
      );
      expect(note.lastUpdate, customTime);
    });

    test('create note uses current time when lastUpdated not provided', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final before = DateTime.now();
      final note = await createNote(
        null, 0, 'Note', 'body', password, version: 4,
      );
      final after = DateTime.now();
      expect(note.lastUpdate.isAfter(before) || note.lastUpdate.isAtSameMomentAs(before), isTrue);
      expect(note.lastUpdate.isBefore(after) || note.lastUpdate.isAtSameMomentAs(after), isTrue);
    });

    test('single character plaintext round-trips correctly', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final note = await createNote(null, 0, 'Short', 'x', password, version: 4);
      final decrypted = await getNotePlainBody(note, password, version: 4);
      expect(decrypted, 'x');
    });

    test('unicode content round-trips correctly', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final plainText = 'Hello \u4f1a\u5b89\u5168 \ud83d\udd12 \u00e9\u00e8';
      final note = await createNote(null, 0, 'Unicode', plainText, password, version: 4);
      final decrypted = await getNotePlainBody(note, password, version: 4);
      expect(decrypted, plainText);
    });

    test('large content round-trips correctly', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final plainText = 'A' * 100000;
      final note = await createNote(null, 0, 'Large', plainText, password, version: 4);
      final decrypted = await getNotePlainBody(note, password, version: 4);
      expect(decrypted, plainText);
    });

    test('version 3 encrypt then decrypt round-trip', () async {
      final password = Uint8List.fromList(utf8.encode('testpass'));
      final plainText = 'Version 3 compatibility test';

      final note = await createNote(
        null, 0, 'V3 Note', plainText, password, version: 3,
      );

      final decrypted = await getNotePlainBody(note, password, version: 3);
      expect(decrypted, plainText);
    });

    test('different passwords produce different ciphertexts', () async {
      final pass1 = Uint8List.fromList(utf8.encode('password1'));
      final pass2 = Uint8List.fromList(utf8.encode('password2'));
      final plainText = 'same content';

      final note1 = await createNote(null, 0, 'N1', plainText, pass1, version: 4);
      final note2 = await createNote(null, 0, 'N2', plainText, pass2, version: 4);

      expect(note1.body, isNot(equals(note2.body)));
    });
  });

  group('createSignature / verifySignature', () {
    test('create signature and verify with correct password', () async {
      final password = Uint8List.fromList(utf8.encode('securePassword123'));
      final signature = await createSignature(password);

      expect(signature.plain, isNotEmpty);
      expect(signature.payload.length, 6);
      expect(signature.salt.length, 32);
      expect(signature.iv.length, 16);
      expect(signature.ver, 4);

      final isValid = await verifySignature(signature, password);
      expect(isValid, isTrue);
    });

    test('verify with wrong password returns false', () async {
      final password = Uint8List.fromList(utf8.encode('correct'));
      final wrongPassword = Uint8List.fromList(utf8.encode('wrong'));

      final signature = await createSignature(password);
      final isValid = await verifySignature(signature, wrongPassword);
      expect(isValid, isFalse);
    });

    test('verify with null signature returns false', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final isValid = await verifySignature(null, password);
      expect(isValid, isFalse);
    });

    test('verify with null password returns false', () async {
      final signature = await createSignature(Uint8List.fromList(utf8.encode('pass')));
      final isValid = await verifySignature(signature, null);
      expect(isValid, isFalse);
    });

    test('verify with both null returns false', () async {
      final isValid = await verifySignature(null, null);
      expect(isValid, isFalse);
    });

    test('multiple signatures with same password all verify', () async {
      final password = Uint8List.fromList(utf8.encode('sharedPassword'));
      final sig1 = await createSignature(password);
      final sig2 = await createSignature(password);

      expect(await verifySignature(sig1, password), isTrue);
      expect(await verifySignature(sig2, password), isTrue);
    });

    test('signature payload is uppercase hex', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final signature = await createSignature(password);
      expect(signature.payload, signature.payload.toUpperCase());
      expect(signature.payload, matches(RegExp(r'^[0-9A-F]+$')));
    });

    test('signature plain text is random alphanumeric', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final signature = await createSignature(password);
      expect(signature.plain.length, 32);
      expect(signature.plain, matches(RegExp(r'^[A-Za-z0-9_]+$')));
    });

    test('signature id is null (not yet persisted)', () async {
      final password = Uint8List.fromList(utf8.encode('pass'));
      final signature = await createSignature(password);
      expect(signature.id, isNull);
    });

    test('different passwords produce different signatures', () async {
      final pass1 = Uint8List.fromList(utf8.encode('password1'));
      final pass2 = Uint8List.fromList(utf8.encode('password2'));

      final sig1 = await createSignature(pass1);
      final sig2 = await createSignature(pass2);

      expect(sig1.payload, isNot(equals(sig2.payload)));
    });

    test('signature verifies after note creation with same password', () async {
      final password = Uint8List.fromList(utf8.encode('testpass'));

      final note = await createNote(null, 0, 'Test', 'body', password, version: 4);
      final signature = await createSignature(password);

      expect(await verifySignature(signature, password), isTrue);
      expect(await getNotePlainBody(note, password, version: 4), 'body');
    });
  });

  group('constants', () {
    test('currentSignatureVer is 4', () {
      expect(sig.currentSignatureVer, 4);
    });

    test('signatureKeyCheckValueLengthInByte is 3', () {
      expect(sig.signatureKeyCheckValueLengthInByte, 3);
    });
  });
}
