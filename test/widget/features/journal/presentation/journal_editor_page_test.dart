import 'package:ai_journal/app/app.dart';
import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/ai/domain/contracts/ai_api_key_store.dart';
import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';
import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_detail_page.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_editor_page.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_home_page.dart';
import 'package:ai_journal/features/settings/presentation/pages/settings_page.dart';
import 'package:ai_journal/features/shell/presentation/pages/main_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows journal home empty state on launch', (tester) async {
    final fakeRepository = _FakeJournalRepository();

    await _pumpJournalApp(tester, repository: fakeRepository);

    expect(find.text('Journal'), findsAtLeastNWidgets(1));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('No journal entries yet.'), findsOneWidget);
    expect(find.byKey(MainShellPage.createEntryFabKey), findsOneWidget);
  });

  testWidgets('theme toggle updates icon', (tester) async {
    await _pumpJournalApp(tester, repository: _FakeJournalRepository());

    expect(find.byIcon(Icons.dark_mode), findsOneWidget);

    await tester.tap(find.byKey(MainShellPage.themeToggleButtonKey));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.light_mode), findsOneWidget);
  });

  testWidgets('create entry flow saves and renders card', (tester) async {
    final fakeRepository = _FakeJournalRepository();

    await _pumpJournalApp(tester, repository: fakeRepository);

    await tester.tap(find.byKey(MainShellPage.createEntryFabKey));
    await tester.pumpAndSettle();

    expect(find.text('New Entry'), findsOneWidget);

    await tester.enterText(
      find.byKey(JournalEditorPage.titleFieldKey),
      'A better day',
    );
    await tester.enterText(
      find.byKey(JournalEditorPage.contentFieldKey),
      'I took a walk and felt more grounded.',
    );
    await tester.enterText(
      find.byKey(JournalEditorPage.tagsFieldKey),
      'wellness, Morning Routine',
    );

    await tester.ensureVisible(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Entry saved locally'), findsOneWidget);
    await tester.ensureVisible(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(fakeRepository.savedEntries, hasLength(1));
    expect(fakeRepository.savedEntries.single.title, 'A better day');
    expect(fakeRepository.savedEntries.single.tags, const <String>[
      'wellness',
      'morning-routine',
    ]);

    expect(find.text('A better day'), findsOneWidget);
  });

  testWidgets('shows inline AI reflection section after save when available', (
    tester,
  ) async {
    final fakeRepository = _FakeJournalRepository();
    final fakeOrchestrator = _FakeAIOrchestrator(
      reflection:
          'You noticed what helped and repeated a healthy coping pattern.',
    );

    await _pumpJournalApp(
      tester,
      repository: fakeRepository,
      aiOrchestrator: fakeOrchestrator,
    );

    await tester.tap(find.byKey(MainShellPage.createEntryFabKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(JournalEditorPage.titleFieldKey), 'Day');
    await tester.enterText(
      find.byKey(JournalEditorPage.contentFieldKey),
      'I felt tense, then breathing helped.',
    );
    await tester.enterText(
      find.byKey(JournalEditorPage.tagsFieldKey),
      'wellness',
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(fakeOrchestrator.reflectionRequests, hasLength(1));
    expect(find.byKey(JournalEditorPage.reflectionDialogKey), findsOneWidget);
    expect(find.text('AI Reflection'), findsOneWidget);
    expect(
      find.text(
        'You noticed what helped and repeated a healthy coping pattern.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Day'), findsOneWidget);
  });

  testWidgets('generates smart prompt on journal home', (tester) async {
    final fakeRepository = _FakeJournalRepository()
      ..savedEntries.add(
        _buildEntry(
          id: 'entry-1',
          title: 'Seed title',
          content: 'Seed content',
          tags: const <String>['growth', 'focus'],
          hourOffset: 1,
        ),
      );
    final fakeOrchestrator = _FakeAIOrchestrator(
      reflection: 'unused',
      generatedPrompt: 'What is one small win you can build on tomorrow?',
    );

    await _pumpJournalApp(
      tester,
      repository: fakeRepository,
      aiOrchestrator: fakeOrchestrator,
    );

    expect(find.byKey(JournalHomePage.generatePromptButtonKey), findsOneWidget);

    await tester.tap(find.byKey(JournalHomePage.generatePromptButtonKey));
    await tester.pumpAndSettle();

    expect(fakeOrchestrator.promptRequests, hasLength(1));
    expect(find.byKey(JournalHomePage.promptTextKey), findsOneWidget);
    expect(
      find.text('What is one small win you can build on tomorrow?'),
      findsOneWidget,
    );
  });

  testWidgets('search and tag filters narrow home list', (tester) async {
    final fakeRepository = _FakeJournalRepository()
      ..savedEntries.addAll([
        _buildEntry(
          id: 'entry-work',
          title: 'Work Reflection',
          content: 'Focused sprint and planning.',
          tags: const <String>['work'],
          hourOffset: 1,
        ),
        _buildEntry(
          id: 'entry-calm',
          title: 'Morning Calm',
          content: 'Deep breathing helped a lot.',
          tags: const <String>['wellness'],
          hourOffset: 2,
        ),
      ]);

    await _pumpJournalApp(tester, repository: fakeRepository);

    await tester.enterText(find.byKey(JournalHomePage.searchFieldKey), 'calm');
    await tester.pumpAndSettle();

    expect(find.text('Work Reflection'), findsNothing);
    expect(find.text('Morning Calm'), findsOneWidget);

    await tester.enterText(find.byKey(JournalHomePage.searchFieldKey), '');
    await tester.enterText(find.byKey(JournalHomePage.tagFieldKey), 'work');
    await tester.pumpAndSettle();

    expect(find.text('Work Reflection'), findsOneWidget);
    expect(find.text('Morning Calm'), findsNothing);
  });

  testWidgets('detail edit delete flow updates and deletes entry', (
    tester,
  ) async {
    final fakeRepository = _FakeJournalRepository()
      ..savedEntries.add(
        _buildEntry(
          id: 'entry-1',
          title: 'Seed title',
          content: 'Seed content',
          tags: const <String>['growth'],
          hourOffset: 1,
        ),
      );

    await _pumpJournalApp(tester, repository: fakeRepository);

    await tester.tap(find.text('Seed title'));
    await tester.pumpAndSettle();

    expect(find.text('Entry Details'), findsOneWidget);
    expect(find.text('Seed content'), findsOneWidget);

    await tester.tap(find.byKey(JournalDetailPage.editButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(JournalEditorPage.contentFieldKey),
      'Updated content',
    );

    await tester.tap(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Updated content'), findsOneWidget);
    expect(fakeRepository.savedEntries.single.content, 'Updated content');

    await tester.tap(find.byKey(JournalDetailPage.deleteButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fakeRepository.savedEntries, isEmpty);
    expect(find.text('Entry Details'), findsNothing);
    expect(find.text('No journal entries yet.'), findsOneWidget);
  });

  testWidgets('settings tab exposes privacy toggles', (tester) async {
    await _pumpJournalApp(tester, repository: _FakeJournalRepository());

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('Privacy & Security'), findsOneWidget);
    expect(find.byKey(SettingsPage.openAiKeyStatusKey), findsOneWidget);
    expect(find.text('OpenAI key: Missing'), findsOneWidget);

    final localOnlyTile = tester.widget<SwitchListTile>(
      find.byKey(SettingsPage.localOnlyAiSwitchKey),
    );
    expect(localOnlyTile.value, isTrue);

    await tester.tap(find.byKey(SettingsPage.localOnlyAiSwitchKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(SettingsPage.cloudAiSwitchKey));
    await tester.pumpAndSettle();

    expect(find.text('Enable cloud AI processing?'), findsOneWidget);
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();

    final cloudTile = tester.widget<SwitchListTile>(
      find.byKey(SettingsPage.cloudAiSwitchKey),
    );
    expect(cloudTile.value, isTrue);
  });

  testWidgets('settings can store and remove OpenAI key locally', (tester) async {
    await _pumpJournalApp(tester, repository: _FakeJournalRepository());

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('OpenAI key: Missing'), findsOneWidget);
    expect(find.byKey(SettingsPage.openAiSetKeyButtonKey), findsOneWidget);

    await tester.ensureVisible(find.byKey(SettingsPage.openAiSetKeyButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SettingsPage.openAiSetKeyButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(SettingsPage.openAiApiKeyFieldKey),
      'sk-test-1234567890',
    );
    await tester.tap(find.text('Save key'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI key: Stored locally'), findsOneWidget);
    expect(find.byKey(SettingsPage.openAiReplaceKeyButtonKey), findsOneWidget);
    expect(find.byKey(SettingsPage.openAiRemoveKeyButtonKey), findsOneWidget);

    await tester.ensureVisible(find.byKey(SettingsPage.openAiRemoveKeyButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SettingsPage.openAiRemoveKeyButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI key: Missing'), findsOneWidget);
  });
}

Future<void> _pumpJournalApp(
  WidgetTester tester, {
  required _FakeJournalRepository repository,
  AIOrchestrator? aiOrchestrator,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 900));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final overrides = [
    journalRepositoryProvider.overrideWithValue(repository),
    keyValueStoreProvider.overrideWithValue(_InMemoryKeyValueStore()),
    aiApiKeyStoreProvider.overrideWithValue(_InMemoryAIApiKeyStore()),
  ];
  if (aiOrchestrator != null) {
    overrides.add(aiOrchestratorProvider.overrideWithValue(aiOrchestrator));
  }

  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const JournalApp()),
  );

  await tester.pumpAndSettle();
}

JournalEntry _buildEntry({
  required String id,
  required String title,
  required String content,
  required List<String> tags,
  required int hourOffset,
}) {
  final now = DateTime.utc(2026, 2, 15, 9 + hourOffset);
  return JournalEntry.create(
    id: id,
    title: title,
    content: content,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeJournalRepository implements JournalRepository {
  final List<JournalEntry> savedEntries = <JournalEntry>[];

  @override
  Future<void> deleteEntry(String id) async {
    savedEntries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<JournalEntry?> getEntryById(String id) async {
    for (final entry in savedEntries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<List<JournalEntry>> listEntries({String? query, String? tag}) async {
    final normalizedQuery = query?.trim().toLowerCase();
    final normalizedTag = tag?.trim().toLowerCase();

    final filtered =
        savedEntries
            .where((entry) {
              final matchesQuery =
                  normalizedQuery == null ||
                  normalizedQuery.isEmpty ||
                  entry.title.toLowerCase().contains(normalizedQuery) ||
                  entry.content.toLowerCase().contains(normalizedQuery);

              final matchesTag =
                  normalizedTag == null ||
                  normalizedTag.isEmpty ||
                  entry.tags.contains(normalizedTag);

              return matchesQuery && matchesTag;
            })
            .toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return filtered;
  }

  @override
  Future<void> upsertEntry(JournalEntry entry) async {
    final index = savedEntries.indexWhere(
      (existing) => existing.id == entry.id,
    );
    if (index == -1) {
      savedEntries.add(entry);
      return;
    }

    savedEntries[index] = entry;
  }
}

class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> readString(String key) async => _values[key];

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }
}

class _InMemoryAIApiKeyStore implements AIApiKeyStore {
  String? _apiKey;

  @override
  Future<AIApiKeySnapshot> clear() async {
    _apiKey = null;
    return const AIApiKeySnapshot(
      apiKey: null,
      protection: AIApiKeyStorageProtection.none,
    );
  }

  @override
  Future<AIApiKeySnapshot> read() async {
    return AIApiKeySnapshot(
      apiKey: _apiKey,
      protection: _apiKey == null
          ? AIApiKeyStorageProtection.none
          : AIApiKeyStorageProtection.secureStorage,
    );
  }

  @override
  Future<AIApiKeySnapshot> write(String apiKey) async {
    _apiKey = apiKey.trim();
    return AIApiKeySnapshot(
      apiKey: _apiKey,
      protection: AIApiKeyStorageProtection.secureStorage,
    );
  }
}

class _FakeAIOrchestrator implements AIOrchestrator {
  _FakeAIOrchestrator({
    required this.reflection,
    this.generatedPrompt = 'prompt',
  });

  final String reflection;
  final String generatedPrompt;
  final List<AIReflectionRequest> reflectionRequests = <AIReflectionRequest>[];
  final List<AISmartPromptRequest> promptRequests = <AISmartPromptRequest>[];

  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) async {
    return AIChatResponse(message: 'chat');
  }

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) async {
    promptRequests.add(request);
    return generatedPrompt;
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) async {
    reflectionRequests.add(request);
    return reflection;
  }
}
