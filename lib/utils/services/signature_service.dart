import 'package:andsafe/models/signature.dart';
import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';

final _log = Logger('SignatureService');

class SignatureService {
  final Database db;

  SignatureService(this.db);

  Future<bool> isPasswordSet() async {
    try {
      List<Map> rows = await db.rawQuery('SELECT COUNT(1) AS num FROM signature');
      if (rows.length == 0) {
        return false;
      }
      return rows[0]['num'] as int == 1;
    } catch (e, stackTrace) {
      _log.severe('Failed to check if password is set', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _generateSignature(Signature sig, Transaction txn) async {
    await txn.delete(
      'signature',
    );
    await txn.insert(
      'signature',
      sig.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> generateSignature(Signature sig, [Transaction? txn]) async {
    try {
      if (txn != null) {
        await _generateSignature(sig, txn);
        return;
      }
      await db.transaction((txn) => _generateSignature(sig, txn));
    } catch (e, stackTrace) {
      _log.severe('Failed to generate signature', e, stackTrace);
      rethrow;
    }
  }

  Future<Signature?> getSignature() async {
    try {
      List<Map> rows = await db.query(
        'signature',
        limit: 1,
      );
      return rows.length > 0
          ? Signature.fromMap(rows.first as Map<String, dynamic>)
          : null;
    } catch (e, stackTrace) {
      _log.severe('Failed to get signature', e, stackTrace);
      rethrow;
    }
  }
}
