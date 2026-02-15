import 'dart:async';

import 'package:ai_journal/core/platform/platform_support.dart';
import 'package:ai_journal/core/security/flutter_secure_storage_key_provider.dart';
import 'package:ai_journal/features/journal/data/local/encrypted_database_factory.dart';
import 'package:ai_journal/features/journal/data/local/in_memory_journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/data/local/journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/data/local/sqflite_encrypted_database_factory.dart';
import 'package:ai_journal/features/journal/data/local/sqlite_journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_controller.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final encryptionKeyProvider = Provider<EncryptionKeyProvider>(
  (ref) => FlutterSecureStorageKeyProvider(),
);

final encryptedDatabaseFactoryProvider = Provider<EncryptedDatabaseFactory>(
  (ref) => const SqfliteEncryptedDatabaseFactory(),
);

final journalLocalStorageServiceProvider = Provider<JournalLocalStorageService>(
  (ref) {
    final service = supportsSqlCipher
        ? SqliteJournalLocalStorageService(
            databaseFactory: ref.watch(encryptedDatabaseFactoryProvider),
            keyProvider: ref.watch(encryptionKeyProvider),
            databasePathProvider: () async {
              final directory = await getApplicationSupportDirectory();
              return p.join(directory.path, 'journal.db');
            },
          )
        : InMemoryJournalLocalStorageService();

    ref.onDispose(() {
      unawaited(service.close());
    });

    return service;
  },
);

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepositoryImpl(
    storageService: ref.watch(journalLocalStorageServiceProvider),
  );
});

final journalSearchQueryProvider = StateProvider<String>((ref) => '');
final journalTagFilterProvider = StateProvider<String>((ref) => '');

final journalEntriesProvider = FutureProvider<List<JournalEntry>>((ref) async {
  final repository = ref.watch(journalRepositoryProvider);
  final query = ref.watch(journalSearchQueryProvider);
  final tag = ref.watch(journalTagFilterProvider);
  return repository.listEntries(query: query, tag: tag);
});

final _uuid = Uuid();

final journalEditorControllerProvider =
    StateNotifierProvider<JournalEditorController, JournalEditorState>((ref) {
      return JournalEditorController(
        repository: ref.watch(journalRepositoryProvider),
        idGenerator: _uuid.v4,
        now: DateTime.now,
      );
    });
