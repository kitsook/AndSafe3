import 'package:andsafe/models/signature.dart';
import 'package:sqflite/sqflite.dart';

class SignatureService {
  final Database db;

  SignatureService(this.db);

  Future<bool> isPasswordSet() async {
    List<Map> rows = await db.rawQuery('SELECT COUNT(1) AS num FROM signature');
    if (rows.length == 0) {
      return false;
    }
    return rows[0]['num'] as int == 1;
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
    if (txn != null) return _generateSignature(sig, txn);
    await db.transaction((txn) => _generateSignature(sig, txn));
  }

  Future<Signature?> getSignature() async {
    List<Map> rows = await db.query(
      'signature',
      limit: 1,
    );
    return rows.length > 0
        ? Signature.fromMap(rows.first as Map<String, dynamic>)
        : null;
  }
}
