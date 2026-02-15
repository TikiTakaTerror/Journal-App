import 'package:ai_journal/app/app.dart';
import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

class _FakeJournalRepository implements JournalRepository {
  final List<JournalEntry> savedEntries = <JournalEntry>[];

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<JournalEntry?> getEntryById(String id) async => null;

  @override
  Future<List<JournalEntry>> listEntries({String? query, String? tag}) async {
    return savedEntries;
  }

  @override
  Future<void> upsertEntry(JournalEntry entry) async {
    savedEntries.add(entry);
  }
}
