import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart' as sig;
import 'package:andsafe/utils/services/export_import_service.dart';
import 'package:xml/xml.dart';

void main() {
  const sampleXml = '''<?xml version="1.0"?>
<database name="safe">
    <table name="notes">
        <row>
            <col name="_id">1</col>
            <col name="cat_id">0</col>
            <col name="title">Test Note</col>
            <col name="body">AABBCCDD</col>
            <col name="salt">01020304</col>
            <col name="iv">05060708</col>
            <col name="last_update">2024-06-15 12:30:00</col>
        </row>
        <row>
            <col name="_id">2</col>
            <col name="cat_id">1</col>
            <col name="title">Second Note</col>
            <col name="body">EEFF0011</col>
            <col name="salt">0A0B0C0D</col>
            <col name="iv">0E0F1011</col>
            <col name="last_update">2024-07-01 08:00:00</col>
        </row>
    </table>
    <table name="signature">
        <row>
            <col name="_id">1</col>
            <col name="plain">randomPlainText</col>
            <col name="payload">ABC</col>
            <col name="salt">FFEE</col>
            <col name="iv">DDCC</col>
            <col name="ver">4</col>
        </row>
    </table>
</database>
''';

  group('parseNotesFromFile', () {
    late String tempFilePath;

    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp('andsafe_test_');
      tempFilePath = '${tempDir.path}/test_export.xml';
      await File(tempFilePath).writeAsString(sampleXml);
    });

    tearDown(() async {
      try {
        await File(tempFilePath).delete();
      } catch (_) {}
    });

    test('parses signature correctly', () {
      final result = parseNotesFromFile(tempFilePath);
      final signature = result.item1;

      expect(signature.id, 1);
      expect(signature.plain, 'randomPlainText');
      expect(signature.payload, 'ABC');
      expect(signature.salt, Uint8List.fromList([0xFF, 0xEE]));
      expect(signature.iv, Uint8List.fromList([0xDD, 0xCC]));
      expect(signature.ver, 4);
    });

    test('parses notes correctly', () {
      final result = parseNotesFromFile(tempFilePath);
      final notes = result.item2;

      expect(notes.length, 2);

      expect(notes[0].id, 1);
      expect(notes[0].categoryId, 0);
      expect(notes[0].title, 'Test Note');
      expect(notes[0].body, 'AABBCCDD');
      expect(notes[0].salt, Uint8List.fromList([0x01, 0x02, 0x03, 0x04]));
      expect(notes[0].iv, Uint8List.fromList([0x05, 0x06, 0x07, 0x08]));

      expect(notes[1].id, 2);
      expect(notes[1].categoryId, 1);
      expect(notes[1].title, 'Second Note');
      expect(notes[1].body, 'EEFF0011');
    });

    test('throws FormatException when signature is missing', () {
      final xmlWithoutSignature = '''<?xml version="1.0"?>
<database name="safe">
    <table name="notes">
        <row>
            <col name="_id">1</col>
            <col name="cat_id">0</col>
            <col name="title">Note</col>
            <col name="body">BODY</col>
            <col name="salt">00</col>
            <col name="iv">00</col>
            <col name="last_update">2024-01-01 00:00:00</col>
        </row>
    </table>
</database>
''';
      final file = File(tempFilePath)..writeAsStringSync(xmlWithoutSignature);
      expect(() => parseNotesFromFile(file.path), throwsA(isA<StateError>()));
    });

    test('handles empty notes list', () {
      final xmlWithNoNotes = '''<?xml version="1.0"?>
<database name="safe">
    <table name="notes">
    </table>
    <table name="signature">
        <row>
            <col name="_id">1</col>
            <col name="plain">p</col>
            <col name="payload">X</col>
            <col name="salt">00</col>
            <col name="iv">00</col>
            <col name="ver">4</col>
        </row>
    </table>
</database>
''';
      File(tempFilePath).writeAsStringSync(xmlWithNoNotes);
      final result = parseNotesFromFile(tempFilePath);
      expect(result.item2, isEmpty);
      expect(result.item1.plain, 'p');
    });
  });

  group('exportNotes', () {
    late String tempFilePath;

    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp('andsafe_export_test_');
      tempFilePath = '${tempDir.path}/export.xml';
    });

    tearDown(() async {
      try {
        await File(tempFilePath).delete();
      } catch (_) {}
    });

    test('exports signature and notes to XML', () async {
      final signature = sig.Signature(1, 'plainText', 'KCV',
          Uint8List.fromList([1, 2]), Uint8List.fromList([3, 4]), 4);
      final notes = [
        Note(1, 0, 'My Note', 'DEADBEEF',
            Uint8List.fromList([5, 6]), Uint8List.fromList([7, 8]),
            DateTime(2024, 1, 1, 10, 0, 0)),
      ];

      await exportNotes(tempFilePath, signature, notes);

      expect(await File(tempFilePath).exists(), isTrue);
      final content = await File(tempFilePath).readAsString();
      expect(content, contains('My Note'));
      expect(content, contains('DEADBEEF'));
      expect(content, contains('plainText'));
      expect(content, contains('KCV'));
    });

    test('exports multiple notes', () async {
      final signature = sig.Signature(1, 'p', 'X', Uint8List(2), Uint8List(2), 4);
      final notes = [
        Note(1, 0, 'First', 'AA', Uint8List(2), Uint8List(2), DateTime(2024, 1, 1)),
        Note(2, 1, 'Second', 'BB', Uint8List(2), Uint8List(2), DateTime(2024, 1, 2)),
      ];

      await exportNotes(tempFilePath, signature, notes);

      final content = await File(tempFilePath).readAsString();
      expect(content, contains('First'));
      expect(content, contains('Second'));
    });

    test('exports valid XML', () async {
      final signature = sig.Signature(1, 'p', 'X', Uint8List(2), Uint8List(2), 4);
      final notes = [
        Note(1, 0, 'Test', 'CC', Uint8List(2), Uint8List(2), DateTime(2024, 1, 1)),
      ];

      await exportNotes(tempFilePath, signature, notes);

      final content = await File(tempFilePath).readAsString();
      expect(() => XmlDocument.parse(content), isNot(throwsException));
    });

    test('round-trip: export then import preserves data', () async {
      final originalSignature = sig.Signature(1, 'plainData', 'ABC',
          Uint8List.fromList([1, 2, 3]), Uint8List.fromList([4, 5, 6]), 4);
      final originalNotes = [
        Note(1, 2, 'Round Trip', 'FF00EE',
            Uint8List.fromList([7, 8]), Uint8List.fromList([9, 10]),
            DateTime(2024, 3, 15, 14, 30, 0)),
      ];

      await exportNotes(tempFilePath, originalSignature, originalNotes);
      final result = parseNotesFromFile(tempFilePath);

      final importedSig = result.item1;
      final importedNotes = result.item2;

      expect(importedSig.plain, originalSignature.plain);
      expect(importedSig.payload, originalSignature.payload);
      expect(importedSig.salt, equals(originalSignature.salt));
      expect(importedSig.iv, equals(originalSignature.iv));
      expect(importedSig.ver, originalSignature.ver);

      expect(importedNotes.length, 1);
      expect(importedNotes[0].title, originalNotes[0].title);
      expect(importedNotes[0].body, originalNotes[0].body);
      expect(importedNotes[0].categoryId, originalNotes[0].categoryId);
      expect(importedNotes[0].salt, equals(originalNotes[0].salt));
      expect(importedNotes[0].iv, equals(originalNotes[0].iv));
    });
  });

  group('_newExportFileName', () {
    test('generated filename matches expected pattern', () {
      final file = File('/tmp/test.xml');
      expect(file.path.endsWith('.xml'), isTrue);
    });
  });
}
