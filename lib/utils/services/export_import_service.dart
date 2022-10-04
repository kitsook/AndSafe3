
import 'dart:io';
import 'dart:typed_data';

import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/helpers.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:convert/convert.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:tuple/tuple.dart';
import 'package:xml/xml.dart';

Tuple2<Signature, List<Note>> parseNotesFromFile(String theFileName) {
  List<Note> importedNotes = [];
  Signature importedSignature;

  final File file = new File(theFileName);
  final XmlDocument document = XmlDocument.parse(file.readAsStringSync());

  // parse signature
  final XmlElement? signatureRow = document
      .findAllElements('table')
      .where((node) => node.getAttribute('name') == 'signature').first.getElement('row');
  if (signatureRow == null) {
    log.severe("Cannot find signature in import file");
    throw FormatException("Cannot find signature in import file");
  }
  importedSignature = _parseSignatureRow(signatureRow);
  log.fine(importedSignature);

  // parse notes
  final Iterable<XmlElement> noteRows = document
      .findAllElements('table')
      .where((node) => node.getAttribute('name') == 'notes').first.findElements('row');
  for (var row in noteRows) {
    Note parsedNote = _parseNoteRow(row);
    importedNotes.add(parsedNote);
  }

  return Tuple2(importedSignature, importedNotes);
}

Future<void> exportNotes(String fullFilePath, Signature signature, List<Note> notes) async {
  final builder = XmlBuilder();
  final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  builder.processing('xml', 'version="1.0"');
  builder.element('database', nest: () {
    builder.attribute('name', 'safe');
    builder.element('table', nest: () {
      builder.attribute('name', 'notes');
      for (var note in notes) {
        builder.element('row', nest: () {
          builder.element('col', nest: () {
            builder.attribute('name', '_id');
            builder.text(note.id.toString());
          });

          builder.element('col', nest: () {
            builder.attribute('name', 'cat_id');
            builder.text(note.categoryId.toString());
          });
          builder.element('col', nest: () {
            builder.attribute('name', 'title');
            builder.text(note.title);
          });
          builder.element('col', nest: () {
            builder.attribute('name', 'body');
            builder.text(note.body);
          });
          builder.element('col', nest: () {
            builder.attribute('name', 'salt');
            builder.text(bytesToHexString(note.salt));
          });
          builder.element('col', nest: () {
            builder.attribute('name', 'iv');
            builder.text(bytesToHexString(note.iv));
          });
          builder.element('col', nest: () {
            builder.attribute('name', 'last_update');
            builder.text(formatter.format(note.lastUpdate));
          });
        });
      }
    });
    builder.element('table', nest: () {
      builder.attribute('name', 'signature');
      builder.element('row', nest: () {
        builder.element('col', nest: () {
          builder.attribute('name', '_id');
          builder.text('1');
        });
        builder.element('col', nest: () {
          builder.attribute('name', 'plain');
          builder.text(signature.plain);
        });
        builder.element('col', nest: () {
          builder.attribute('name', 'payload');
          builder.text(signature.payload);
        });
        builder.element('col', nest: () {
          builder.attribute('name', 'salt');
          builder.text(bytesToHexString(signature.salt));
        });
        builder.element('col', nest: () {
          builder.attribute('name', 'iv');
          builder.text(bytesToHexString(signature.iv));
        });
        builder.element('col', nest: () {
          builder.attribute('name', 'ver');
          builder.text(signature.ver);
        });
      });
    });
  });
  final bookshelfXml = builder.buildDocument();
  final outputFile = File(fullFilePath);
  await outputFile.writeAsString(bookshelfXml.toXmlString(pretty: true, indent: '    '), flush: true);
}

Future<String?> getNewExportFullFilePath() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }

  String? outputDir = await FilePicker.platform.getDirectoryPath();
  if (outputDir == null) {
    return null;
  }

  for (var i = 0; i < 5; i++) {
    String fullFilPath = p.join(outputDir, _newExportFileName());
    if (! await File(fullFilPath).exists()) {
      return fullFilPath;
    }
    await Future.delayed(const Duration(seconds: 1), () => '');
  }

  return null;
}

String _newExportFileName() {
  final DateFormat formatter = DateFormat('yyyyMMdd_HHmmss');
  return 'AndSafe' + formatter.format(DateTime.now()) + '.xml';
}

Signature _parseSignatureRow(XmlElement row) {
  return Signature(
    int.parse(row.findElements('col').where((node) => node.getAttribute('name') == '_id').first.text),
    row.findElements('col').where((node) => node.getAttribute('name') == 'plain').first.text,
    row.findElements('col').where((node) => node.getAttribute('name') == 'payload').first.text,
    hex.decode(row.findElements('col').where((node) => node.getAttribute('name') == 'salt').first.text) as Uint8List,
    hex.decode(row.findElements('col').where((node) => node.getAttribute('name') == 'iv').first.text) as Uint8List,
    int.parse(row.findElements('col').where((node) => node.getAttribute('name') == 'ver').first.text),
  );
}

Note _parseNoteRow(XmlElement row) {
  return Note(
    int.parse(row.findElements('col').where((node) => node.getAttribute('name') == '_id').first.text),
    int.parse(row.findElements('col').where((node) => node.getAttribute('name') == 'cat_id').first.text),
    row.findElements('col').where((node) => node.getAttribute('name') == 'title').first.text,
    row.findElements('col').where((node) => node.getAttribute('name') == 'body').first.text,
    hex.decode(row.findElements('col').where((node) => node.getAttribute('name') == 'salt').first.text) as Uint8List,
    hex.decode(row.findElements('col').where((node) => node.getAttribute('name') == 'iv').first.text) as Uint8List,
    DateTime.parse(row.findElements('col').where((node) => node.getAttribute('name') == 'last_update').first.text),
  );
}
