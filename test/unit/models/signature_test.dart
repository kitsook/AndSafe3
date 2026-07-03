import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:andsafe/models/signature.dart';

void main() {
  group('Signature.toMap', () {
    test('maps all fields correctly', () {
      final salt = Uint8List.fromList([1, 2, 3]);
      final iv = Uint8List.fromList([4, 5, 6]);

      final sig = Signature(1, 'plainText', 'ABC', salt, iv, 4);
      final map = sig.toMap();

      expect(map['_id'], 1);
      expect(map['plain'], 'plainText');
      expect(map['payload'], 'ABC');
      expect(map['salt'], salt);
      expect(map['iv'], iv);
      expect(map['ver'], 4);
    });

    test('maps null id correctly', () {
      final sig = Signature(null, '', '', Uint8List(0), Uint8List(0), 4);
      expect(sig.toMap()['_id'], isNull);
    });
  });

  group('Signature.fromMap', () {
    test('recovers all fields from map', () {
      final salt = Uint8List.fromList([10, 20, 30]);
      final iv = Uint8List.fromList([40, 50, 60]);

      final data = <String, dynamic>{
        '_id': 1,
        'plain': 'myPlain',
        'payload': 'DEF',
        'salt': salt,
        'iv': iv,
        'ver': 3,
      };

      final sig = Signature.fromMap(data);

      expect(sig.id, 1);
      expect(sig.plain, 'myPlain');
      expect(sig.payload, 'DEF');
      expect(sig.salt, equals(salt));
      expect(sig.iv, equals(iv));
      expect(sig.ver, 3);
    });

    test('handles null id from map', () {
      final data = <String, dynamic>{
        '_id': null,
        'plain': '',
        'payload': '',
        'salt': Uint8List(0),
        'iv': Uint8List(0),
        'ver': 4,
      };

      final sig = Signature.fromMap(data);
      expect(sig.id, isNull);
    });
  });

  group('round-trip', () {
    test('toMap then fromMap returns equivalent signature', () {
      final salt = Uint8List.fromList([1, 2, 3, 4, 5]);
      final iv = Uint8List.fromList([6, 7, 8, 9, 10]);

      final original = Signature(100, 'plainData', 'KCV', salt, iv, 4);
      final map = original.toMap();
      final recovered = Signature.fromMap(map);

      expect(recovered.id, original.id);
      expect(recovered.plain, original.plain);
      expect(recovered.payload, original.payload);
      expect(recovered.salt, equals(original.salt));
      expect(recovered.iv, equals(original.iv));
      expect(recovered.ver, original.ver);
    });

    test('round-trip with null id', () {
      final original = Signature(null, 'p', 'X', Uint8List(16), Uint8List(16), 3);
      final map = original.toMap();
      final recovered = Signature.fromMap(map);

      expect(recovered.id, isNull);
      expect(recovered.plain, 'p');
      expect(recovered.payload, 'X');
      expect(recovered.ver, 3);
    });
  });

  group('constants', () {
    test('currentSignatureVer is 4', () {
      expect(currentSignatureVer, 4);
    });

    test('signatureKeyCheckValueLengthInByte is 3', () {
      expect(signatureKeyCheckValueLengthInByte, 3);
    });
  });
}
