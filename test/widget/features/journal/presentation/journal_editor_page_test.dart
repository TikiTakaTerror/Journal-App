import 'package:ai_journal/app/app.dart';
import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows empty state when there are no saved entries', (
    tester,
  ) async {
    final fakeRepository = _FakeJournalRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const MaterialApp(home: JournalEditorPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Recent Entries'), findsOneWidget);
    expect(find.text('No journal entries yet.'), findsOneWidget);
  });

  testWidgets('theme toggle switches icon mode', (tester) async {
    final fakeRepository = _FakeJournalRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const JournalApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);

    await tester.tap(find.byKey(JournalEditorPage.themeToggleButtonKey));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.light_mode), findsOneWidget);
  });

  testWidgets('journal editor saves an entry through repository', (
    tester,
  ) async {
    final fakeRepository = _FakeJournalRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const JournalApp(),
      ),
    );

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
      'wellness, routine',
    );

    await tester.tap(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(fakeRepository.savedEntries, hasLength(1));
    expect(fakeRepository.savedEntries.single.title, 'A better day');
    expect(find.text('Entry saved'), findsOneWidget);
    expect(find.text('Recent Entries'), findsOneWidget);
    expect(find.text('A better day'), findsOneWidget);
  });

  testWidgets('save button is disabled when required fields are empty', (
    tester,
  ) async {
    final fakeRepository = _FakeJournalRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const MaterialApp(home: JournalEditorPage()),
      ),
    );

    final button = tester.widget<ElevatedButton>(
      find.byKey(JournalEditorPage.saveButtonKey),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('search and tag filters update recent entries list', (
    tester,
  ) async {
    final fakeRepository = _FakeJournalRepository()
      ..savedEntries.addAll([
        _buildEntry(
          id: 'entry-work',
          title: 'Work Reflection',
          content: 'Focused sprint and planning.',
          tags: const ['work'],
          hourOffset: 1,
        ),
        _buildEntry(
          id: 'entry-calm',
          title: 'Morning Calm',
          content: 'Deep breathing helped a lot.',
          tags: const ['wellness'],
          hourOffset: 2,
        ),
      ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const MaterialApp(home: JournalEditorPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsAtLeastNWidgets(1));

    await tester.enterText(
      find.byKey(JournalEditorPage.searchFieldKey),
      'calm',
    );
    await tester.pumpAndSettle();

    expect(find.text('Work Reflection'), findsNothing);
    expect(find.text('Morning Calm'), findsOneWidget);

    await tester.enterText(
      find.byKey(JournalEditorPage.searchFieldKey),
      'work',
    );
    await tester.pumpAndSettle();

    expect(find.text('Work Reflection'), findsOneWidget);
    expect(find.text('Morning Calm'), findsNothing);

    await tester.enterText(find.byKey(JournalEditorPage.searchFieldKey), '');
    await tester.enterText(
      find.byKey(JournalEditorPage.tagFilterFieldKey),
      'work',
    );
    await tester.pumpAndSettle();

    expect(find.text('Work Reflection'), findsOneWidget);
    expect(find.text('Morning Calm'), findsNothing);
  });

  testWidgets('tap entry shows details and enables edit update flow', (
    tester,
  ) async {
    final seed = _buildEntry(
      id: 'entry-1',
      title: 'Seed title',
      content: 'Seed content',
      tags: const ['growth'],
      hourOffset: 1,
    );
    final fakeRepository = _FakeJournalRepository()..savedEntries.add(seed);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const MaterialApp(home: JournalEditorPage()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(JournalEditorPage.mobileLayoutScrollKey),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seed title'), findsOneWidget);
    await tester.tap(find.text('Seed title'));
    await tester.pumpAndSettle();

    expect(find.text('Update Entry'), findsOneWidget);
    expect(find.text('Entry Details'), findsOneWidget);
    expect(find.text('Seed content'), findsWidgets);

    await tester.enterText(
      find.byKey(JournalEditorPage.contentFieldKey),
      'Updated content',
    );
    await tester.tap(find.byKey(JournalEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(fakeRepository.savedEntries, hasLength(1));
    expect(fakeRepository.savedEntries.single.id, 'entry-1');
    expect(fakeRepository.savedEntries.single.content, 'Updated content');
    expect(find.text('Entry updated'), findsOneWidget);
  });

  testWidgets('delete asks confirmation and supports undo restore', (
    tester,
  ) async {
    final fakeRepository = _FakeJournalRepository()
      ..savedEntries.add(
        _buildEntry(
          id: 'entry-delete',
          title: 'To Delete',
          content: 'Delete me',
          tags: const ['cleanup'],
          hourOffset: 1,
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const MaterialApp(home: JournalEditorPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('To Delete'), findsOneWidget);

    await tester.drag(
      find.byKey(JournalEditorPage.mobileLayoutScrollKey),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('delete_entry_entry-delete')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fakeRepository.savedEntries, isEmpty);
    expect(find.text('Entry deleted'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    expect(fakeRepository.savedEntries, hasLength(1));
    expect(fakeRepository.savedEntries.single.title, 'To Delete');
    expect(find.text('Entry restored'), findsOneWidget);
    expect(find.text('To Delete'), findsWidgets);
  });
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
