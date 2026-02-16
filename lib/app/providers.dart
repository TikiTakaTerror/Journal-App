import 'dart:async';

import 'package:ai_journal/features/ai/application/default_ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_privacy_policy.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_cloud_ai_service.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_config.dart';
import 'package:ai_journal/features/ai/presentation/state/smart_prompt_controller.dart';
import 'package:ai_journal/features/ai/presentation/state/smart_prompt_state.dart';
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
import 'package:ai_journal/features/settings/data/local/app_settings_local_service.dart';
import 'package:ai_journal/features/settings/domain/models/app_settings.dart';
import 'package:ai_journal/features/settings/presentation/state/app_settings_controller.dart';
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

final appSettingsLocalServiceProvider = Provider<AppSettingsLocalService>((
  ref,
) {
  return AppSettingsLocalService(store: ref.watch(keyValueStoreProvider));
});

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
      return AppSettingsController(
        service: ref.watch(appSettingsLocalServiceProvider),
      );
    });

final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(appSettingsControllerProvider);
  return settings.darkMode ? ThemeMode.dark : ThemeMode.light;
});

final openAIConfigProvider = Provider<OpenAIConfig>((ref) {
  return OpenAIConfig.fromEnvironment();
});

final aiPrivacyPolicyProvider = Provider<AIPrivacyPolicy>((ref) {
  final settings = ref.watch(appSettingsControllerProvider);
  return AIPrivacyPolicy(
    localOnlyAi: settings.localOnlyAi,
    cloudAiConsent: settings.cloudAiConsent,
  );
});

final aiOrchestratorProvider = Provider<AIOrchestrator?>((ref) {
  final config = ref.watch(openAIConfigProvider);
  final policy = ref.watch(aiPrivacyPolicyProvider);

  if (!policy.canUseCloud || !config.hasApiKey) {
    return null;
  }

  final service = OpenAICloudAIService(config: config, privacyPolicy: policy);
  ref.onDispose(service.dispose);
  return DefaultAIOrchestrator(aiService: service);
});

final smartPromptControllerProvider =
    StateNotifierProvider<SmartPromptController, SmartPromptState>((ref) {
      return SmartPromptController(
        repository: ref.watch(journalRepositoryProvider),
        aiOrchestrator: ref.watch(aiOrchestratorProvider),
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

final journalAllEntriesProvider = FutureProvider<List<JournalEntry>>((
  ref,
) async {
  final repository = ref.watch(journalRepositoryProvider);
  return repository.listEntries();
});

final journalEntryProvider = FutureProvider.family<JournalEntry?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(journalRepositoryProvider);
  return repository.getEntryById(id);
});

final _uuid = Uuid();

final journalEditorControllerProvider =
    StateNotifierProvider<JournalEditorController, JournalEditorState>((ref) {
      return JournalEditorController(
        repository: ref.watch(journalRepositoryProvider),
        idGenerator: _uuid.v4,
        now: DateTime.now,
        aiOrchestrator: ref.watch(aiOrchestratorProvider),
      );
    });
