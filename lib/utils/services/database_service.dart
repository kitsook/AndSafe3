import 'package:andsafe/models/signature.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

const _currentDatabaseVersion = 3;

class DatabaseHelper {
  Future<Database>? _database;

  Future<Database> getDatabase() {
    _database ??= _init();
    return _database!;
  }

  Future<Database> _init() async {
    String dbFullPath = join(await getDatabasesPath(), 'safe.db');
    return openDatabase(
      dbFullPath,
      onCreate: (db, version) async {
        // create tables on first run
        await db.execute(
            'create table notes (_id integer primary key autoincrement, cat_id integer not null, ' +
                'title text not null, body text not null, salt blob, iv blob, last_update date);');
        await db.execute(
            'create table signature (_id integer primary key autoincrement, plain text, payload text, ' +
                'salt blob, iv blob, ver integer);');

        await db
            .execute('create virtual table searchable ' + 'using fts3 (title)');
        await db.execute(
            'create index idx_notes_title_nocase on notes(title collate nocase);');
        await db.execute(
            'create index idx_notes_last_update on notes(last_update);');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 1) {
          // add virtual table for search function
          await db.transaction((txn) async {
            await txn.execute(
                'create virtual table searchable ' + 'using fts3 (title)');
            await txn.rawQuery(
                'insert into searchable (docid, title) select _id, title from notes;');
          });

          // update signature. use KCV concept and only store part of the encrypted payload
          await db.transaction((txn) async {
            await txn.rawQuery(
                'update signature set payload = substr(payload, 1, ' +
                    (signatureKeyCheckValueLengthInByte * 2).toString() +
                    ');');
            await txn.update('signature', {'ver': currentSignatureVer});
          });
        }

        if (oldVersion < 3) {
          await db.transaction((txn) async {
            await txn.execute('drop index if exists idx_notes_title;');
            await txn.execute(
                'create index idx_notes_title_nocase on notes(title collate nocase);');
            await txn.execute(
                'create index idx_notes_last_update on notes(last_update);');
          });
        }
      },
      version: _currentDatabaseVersion,
    );
  }
}
