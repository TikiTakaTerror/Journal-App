import 'package:ai_journal/features/journal/data/local/database_client.dart';
import 'package:ai_journal/features/journal/data/local/encrypted_database_factory.dart';
import 'package:ai_journal/features/journal/data/local/journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';

class SqliteJournalLocalStorageService implements JournalLocalStorageService {
  SqliteJournalLocalStorageService({
    required EncryptedDatabaseFactory databaseFactory,
    required EncryptionKeyProvider keyProvider,
    required Future<String> Function() databasePathProvider,
  }) : _databaseFactory = databaseFactory,
       _keyProvider = keyProvider,
       _databasePathProvider = databasePathProvider;

  static const String _tableName = 'journal_entries';

  final EncryptedDatabaseFactory _databaseFactory;
  final EncryptionKeyProvider _keyProvider;
  final Future<String> Function() _databasePathProvider;

  DatabaseClient? _database;
  Future<void>? _initialization;

  @override
  Future<void> initialize() {
    _initialization ??= _initializeInternal();
    return _initialization!;
  }

  Future<void> _initializeInternal() async {
    final key = await _keyProvider.getKey();
    if (key.trim().length < 16) {
      throw StateError('Database encryption key is too short.');
    }

    final path = await _databasePathProvider();
    _database = await _databaseFactory.open(
      path: path,
      password: key,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(_createSchemaSql);
      },
    );
  }

  @override
  Future<void> upsertEntry(JournalEntry entry) async {
    final db = await _getDatabase();
    await db.insertOrReplace(_tableName, entry.toMap());
  }

  @override
  Future<List<JournalEntry>> listEntries({String? query, String? tag}) async {
    final db = await _getDatabase();

    final clauses = <String>[];
    final args = <Object?>[];

    final normalizedQuery = query?.trim();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      final escaped = _escapeLike(normalizedQuery);
      clauses.add('(title LIKE ? ESCAPE "\\" OR content LIKE ? ESCAPE "\\")');
      args.add('%$escaped%');
      args.add('%$escaped%');
    }

    final normalizedTag = tag?.trim().toLowerCase();
    if (normalizedTag != null && normalizedTag.isNotEmpty) {
      clauses.add('tags_json LIKE ?');
      args.add('%"$normalizedTag"%');
    }

    final rows = await db.query(
      table: _tableName,
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at DESC',
    );

    return rows.map(JournalEntry.fromMap).toList(growable: false);
  }

  @override
  Future<JournalEntry?> getEntryById(String id) async {
    final db = await _getDatabase();
    final rows = await db.query(
      table: _tableName,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    if (rows.isEmpty) {
      return null;
    }

    return JournalEntry.fromMap(rows.first);
  }

  @override
  Future<void> deleteEntry(String id) async {
    final db = await _getDatabase();
    await db.delete(
      table: _tableName,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  @override
  Future<void> close() async {
    final db = _database;
    _database = null;
    _initialization = null;
    if (db != null) {
      await db.close();
    }
  }

  Future<DatabaseClient> _getDatabase() async {
    await initialize();
    final db = _database;
    if (db == null) {
      throw StateError('Database was not initialized.');
    }
    return db;
  }

  static String _escapeLike(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }

  static const String _createSchemaSql = '''
CREATE TABLE IF NOT EXISTS journal_entries (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  tags_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''';
}
