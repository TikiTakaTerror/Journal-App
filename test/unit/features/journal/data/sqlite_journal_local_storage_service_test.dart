import 'dart:async';

import 'package:ai_journal/features/journal/data/local/database_client.dart';
import 'package:ai_journal/features/journal/data/local/encrypted_database_factory.dart';
import 'package:ai_journal/features/journal/data/local/sqlite_journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SqliteJournalLocalStorageService', () {
    late _FakeDatabaseClient fakeDatabase;
    late _FakeEncryptedDatabaseFactory fakeFactory;
    late _FakeEncryptionKeyProvider keyProvider;
    late SqliteJournalLocalStorageService service;

    setUp(() {
      fakeDatabase = _FakeDatabaseClient();
      fakeFactory = _FakeEncryptedDatabaseFactory(fakeDatabase);
      keyProvider = _FakeEncryptionKeyProvider('super-secure-key-1234567890');
      service = SqliteJournalLocalStorageService(
        databaseFactory: fakeFactory,
        keyProvider: keyProvider,
        databasePathProvider: () async => '/tmp/journal.db',
      );
    });

    test('initialize opens encrypted database and creates schema', () async {
      await service.initialize();

      expect(fakeFactory.openPath, '/tmp/journal.db');
      expect(fakeFactory.openPassword, 'super-secure-key-1234567890');
      expect(
        fakeDatabase.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS journal_entries'),
        ),
        isTrue,
      );
    });

    test(
      'upsertEntry persists entry map and listEntries maps response',
      () async {
        await service.initialize();

        final entry = JournalEntry.create(
          id: 'entry-1',
          title: 'How I felt',
          content: 'Writing helps me focus.',
          tags: const ['focus', 'routine'],
          createdAt: DateTime.utc(2026, 2, 15, 9),
          updatedAt: DateTime.utc(2026, 2, 15, 9, 5),
        );

        await service.upsertEntry(entry);

        expect(fakeDatabase.insertedTable, 'journal_entries');
        expect(fakeDatabase.insertedMap?['id'], 'entry-1');

        fakeDatabase.queryRows = [entry.toMap()];
        final entries = await service.listEntries(
          query: 'focus',
          tag: 'routine',
        );

        expect(entries, [entry]);
        expect(fakeDatabase.lastQueryWhere, contains('title LIKE ?'));
        expect(fakeDatabase.lastQueryWhere, contains('tags_json LIKE ?'));
        expect(fakeDatabase.lastQueryWhereArgs, <Object?>[
          '%focus%',
          '%focus%',
          '%"routine"%',
        ]);
      },
    );

    test('deleteEntry removes entry by id', () async {
      await service.initialize();

      await service.deleteEntry('entry-4');

      expect(fakeDatabase.deletedTable, 'journal_entries');
      expect(fakeDatabase.deletedWhere, 'id = ?');
      expect(fakeDatabase.deletedWhereArgs, <Object?>['entry-4']);
    });
  });
}

class _FakeEncryptionKeyProvider implements EncryptionKeyProvider {
  _FakeEncryptionKeyProvider(this.key);

  final String key;

  @override
  Future<String> getKey() async => key;
}

class _FakeEncryptedDatabaseFactory implements EncryptedDatabaseFactory {
  _FakeEncryptedDatabaseFactory(this.database);

  final _FakeDatabaseClient database;
  String? openPath;
  String? openPassword;

  @override
  Future<DatabaseClient> open({
    required String path,
    required String password,
    required int version,
    required FutureOr<void> Function(DatabaseClient db, int version) onCreate,
  }) async {
    openPath = path;
    openPassword = password;
    await onCreate(database, version);
    return database;
  }
}

class _FakeDatabaseClient implements DatabaseClient {
  final List<String> executedSql = <String>[];
  String? insertedTable;
  Map<String, Object?>? insertedMap;
  List<Map<String, Object?>> queryRows = <Map<String, Object?>>[];
  String? lastQueryWhere;
  List<Object?>? lastQueryWhereArgs;
  String? deletedTable;
  String? deletedWhere;
  List<Object?>? deletedWhereArgs;

  @override
  Future<void> close() async {}

  @override
  Future<int> delete({
    required String table,
    required String where,
    required List<Object?> whereArgs,
  }) async {
    deletedTable = table;
    deletedWhere = where;
    deletedWhereArgs = whereArgs;
    return 1;
  }

  @override
  Future<void> execute(String sql) async {
    executedSql.add(sql);
  }

  @override
  Future<int> insertOrReplace(String table, Map<String, Object?> values) async {
    insertedTable = table;
    insertedMap = values;
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> query({
    required String table,
    String? where,
    List<Object?> whereArgs = const <Object?>[],
    String? orderBy,
  }) async {
    lastQueryWhere = where;
    lastQueryWhereArgs = whereArgs;
    return queryRows;
  }
}
