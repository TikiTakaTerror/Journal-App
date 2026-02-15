import 'dart:async';

import 'package:ai_journal/features/journal/data/local/database_client.dart';
import 'package:ai_journal/features/journal/data/local/encrypted_database_factory.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

class SqfliteEncryptedDatabaseFactory implements EncryptedDatabaseFactory {
  const SqfliteEncryptedDatabaseFactory();

  @override
  Future<DatabaseClient> open({
    required String path,
    required String password,
    required int version,
    required FutureOr<void> Function(DatabaseClient db, int version) onCreate,
  }) async {
    final db = await sqlcipher.openDatabase(
      path,
      password: password,
      version: version,
      onCreate: (database, databaseVersion) async {
        await onCreate(_SqfliteDatabaseClient(database), databaseVersion);
      },
    );

    return _SqfliteDatabaseClient(db);
  }
}

class _SqfliteDatabaseClient implements DatabaseClient {
  _SqfliteDatabaseClient(this._database);

  final sqlcipher.Database _database;

  @override
  Future<void> close() => _database.close();

  @override
  Future<int> delete({
    required String table,
    required String where,
    required List<Object?> whereArgs,
  }) {
    return _database.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<void> execute(String sql) => _database.execute(sql);

  @override
  Future<int> insertOrReplace(String table, Map<String, Object?> values) {
    return _database.insert(
      table,
      values,
      conflictAlgorithm: sqlcipher.ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Map<String, Object?>>> query({
    required String table,
    String? where,
    List<Object?> whereArgs = const <Object?>[],
    String? orderBy,
  }) async {
    final rows = await _database.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    return rows
        .map(
          (row) =>
              row.map((key, value) => MapEntry<String, Object?>(key, value)),
        )
        .toList(growable: false);
  }
}
