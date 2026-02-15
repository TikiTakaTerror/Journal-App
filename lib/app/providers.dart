import 'dart:async';

import 'package:ai_journal/core/platform/platform_support.dart';
import 'package:ai_journal/core/security/flutter_secure_storage_key_provider.dart';
import 'package:ai_journal/features/journal/data/local/encrypted_database_factory.dart';
import 'package:ai_journal/features/journal/data/local/journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:ai_journal/features/journal/data/local/sqflite_encrypted_database_factory.dart';
import 'package:ai_journal/features/journal/data/local/sqlite_journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/data/local/shared_prefs_journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/data/local/shared_preferences_key_value_store.dart';
import 'package:ai_journal/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_controller.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_state.dart';
import 'package:flutter/material.dart';
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

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SharedPreferencesKeyValueStore(),
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
        : SharedPrefsJournalLocalStorageService(
            store: ref.watch(keyValueStoreProvider),
          );

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
final selectedEntryIdProvider = StateProvider<String?>((ref) => null);
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final journalEntriesProvider = FutureProvider<List<JournalEntry>>((ref) async {
  final repository = ref.watch(journalRepositoryProvider);
  final query = ref.watch(journalSearchQueryProvider);
  final tag = ref.watch(journalTagFilterProvider);
  return repository.listEntries(query: query, tag: tag);
});

final selectedEntryProvider = Provider<AsyncValue<JournalEntry?>>((ref) {
  final selectedId = ref.watch(selectedEntryIdProvider);
  final entriesAsync = ref.watch(journalEntriesProvider);

  return entriesAsync.whenData((entries) {
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }

    for (final entry in entries) {
      if (entry.id == selectedId) {
        return entry;
      }
    }
    return null;
  });
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
