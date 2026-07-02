import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:andsafe/utils/helpers.dart';

void main() {
  group('bytesToHexString', () {
    test('converts bytes to uppercase hex string', () {
      final bytes = Uint8List.fromList([0, 255, 170, 10]);
      expect(bytesToHexString(bytes), '00FFAA0A');
    });

    test('handles empty bytes', () {
      expect(bytesToHexString(Uint8List(0)), '');
    });

    test('handles single byte', () {
      expect(bytesToHexString(Uint8List.fromList([0])), '00');
      expect(bytesToHexString(Uint8List.fromList([15])), '0F');
      expect(bytesToHexString(Uint8List.fromList([255])), 'FF');
    });

    test('handles large byte array', () {
      final bytes = Uint8List(1024);
      for (int i = 0; i < bytes.length; i++) {
        bytes[i] = i % 256;
      }
      final hex = bytesToHexString(bytes);
      expect(hex.length, 2048);
      expect(hex, hex.toUpperCase());
    });
  });

  group('hexStringToBytes', () {
    test('converts hex string to bytes', () {
      expect(hexStringToBytes('00FFAA0A'), Uint8List.fromList([0, 255, 170, 10]));
    });

    test('handles empty string', () {
      expect(hexStringToBytes(''), Uint8List(0));
    });

    test('handles single byte hex', () {
      expect(hexStringToBytes('00'), Uint8List.fromList([0]));
      expect(hexStringToBytes('0F'), Uint8List.fromList([15]));
      expect(hexStringToBytes('FF'), Uint8List.fromList([255]));
    });

    test('is case insensitive', () {
      expect(hexStringToBytes('00ffaa0a'), hexStringToBytes('00FFAA0A'));
      expect(hexStringToBytes('0fFfAaAa'), hexStringToBytes('0FFFAAAA'));
    });

    test('handles large hex string', () {
      final hex = 'FF' * 512;
      final bytes = hexStringToBytes(hex);
      expect(bytes.length, 512);
      for (int b in bytes) {
        expect(b, 255);
      }
    });
  });

  group('round-trip', () {
    test('bytesToHexString then hexStringToBytes returns original', () {
      final original = Uint8List.fromList([0, 1, 2, 128, 255, 170, 10, 42]);
      final hex = bytesToHexString(original);
      final recovered = hexStringToBytes(hex);
      expect(recovered, equals(original));
    });

    test('round-trip with large random-like data', () {
      final original = Uint8List(256);
      for (int i = 0; i < original.length; i++) {
        original[i] = i;
      }
      final hex = bytesToHexString(original);
      final recovered = hexStringToBytes(hex);
      expect(recovered, equals(original));
    });

    test('hexStringToBytes then bytesToHexString returns uppercase', () {
      final original = 'aabbccdd';
      final bytes = hexStringToBytes(original);
      final hex = bytesToHexString(bytes);
      expect(hex, 'AABBCCDD');
    });
  });
}
