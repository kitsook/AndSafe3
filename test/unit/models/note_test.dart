import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:andsafe/models/note.dart';

void main() {
  group('Note.toMap', () {
    test('maps all fields correctly', () {
      final salt = Uint8List.fromList([1, 2, 3]);
      final iv = Uint8List.fromList([4, 5, 6]);
      final now = DateTime(2024, 6, 15, 12, 30, 0);

      final note = Note(42, 3, 'Test Title', 'encrypted body', salt, iv, now);
      final map = note.toMap();

      expect(map['_id'], 42);
      expect(map['cat_id'], 3);
      expect(map['title'], 'Test Title');
      expect(map['body'], 'encrypted body');
      expect(map['salt'], salt);
      expect(map['iv'], iv);
      expect(map['last_update'], now.millisecondsSinceEpoch ~/ 1000);
    });

    test('maps null id correctly', () {
      final note = Note(null, 0, '', '', Uint8List(0), Uint8List(0), DateTime.now());
      expect(note.toMap()['_id'], isNull);
    });

    test('converts DateTime to unix timestamp in seconds', () {
      final epoch = DateTime.utc(2000, 1, 1, 0, 0, 0);
      final note = Note(1, 0, '', '', Uint8List(0), Uint8List(0), epoch);
      final ts = note.toMap()['last_update'];
      expect(ts, epoch.millisecondsSinceEpoch ~/ 1000);
    });
  });

  group('Note.fromMap', () {
    test('recovers all fields from map', () {
      final salt = Uint8List.fromList([10, 20, 30]);
      final iv = Uint8List.fromList([40, 50, 60]);
      final timestamp = 1718451000;

      final data = <String, dynamic>{
        '_id': 42,
        'cat_id': 3,
        'title': 'Test Title',
        'body': 'encrypted body',
        'salt': salt,
        'iv': iv,
        'last_update': timestamp,
      };

      final note = Note.fromMap(data);

      expect(note.id, 42);
      expect(note.categoryId, 3);
      expect(note.title, 'Test Title');
      expect(note.body, 'encrypted body');
      expect(note.salt, equals(salt));
      expect(note.iv, equals(iv));
      expect(note.lastUpdate.millisecondsSinceEpoch, timestamp * 1000);
    });

    test('handles null id from map', () {
      final data = <String, dynamic>{
        '_id': null,
        'cat_id': 0,
        'title': '',
        'body': '',
        'salt': Uint8List(0),
        'iv': Uint8List(0),
        'last_update': 0,
      };

      final note = Note.fromMap(data);
      expect(note.id, isNull);
    });

    test('converts unix timestamp to DateTime correctly', () {
      final data = <String, dynamic>{
        '_id': 1,
        'cat_id': 0,
        'title': '',
        'body': '',
        'salt': Uint8List(0),
        'iv': Uint8List(0),
        'last_update': 946684800,
      };

      final note = Note.fromMap(data);
      expect(note.lastUpdate.millisecondsSinceEpoch, DateTime.utc(2000, 1, 1, 0, 0, 0).millisecondsSinceEpoch);
    });
  });

  group('round-trip', () {
    test('toMap then fromMap returns equivalent note', () {
      final salt = Uint8List.fromList([1, 2, 3, 4, 5]);
      final iv = Uint8List.fromList([6, 7, 8, 9, 10]);
      final now = DateTime(2024, 6, 15, 12, 30, 0);

      final original = Note(100, 2, 'My Note', 'secret data', salt, iv, now);
      final map = original.toMap();
      final recovered = Note.fromMap(map);

      expect(recovered.id, original.id);
      expect(recovered.categoryId, original.categoryId);
      expect(recovered.title, original.title);
      expect(recovered.body, original.body);
      expect(recovered.salt, equals(original.salt));
      expect(recovered.iv, equals(original.iv));
      expect(recovered.lastUpdate, original.lastUpdate);
    });

    test('round-trip with null id', () {
      final original = Note(null, 0, 'Untitled', '', Uint8List(16), Uint8List(16), DateTime.now());
      final map = original.toMap();
      final recovered = Note.fromMap(map);

      expect(recovered.id, isNull);
      expect(recovered.categoryId, 0);
      expect(recovered.title, 'Untitled');
    });
  });
}
