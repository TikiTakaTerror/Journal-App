import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalEditorController', () {
    test('save creates a new entry when not editing', () async {
      final repository = _FakeJournalRepository();
      final controller = JournalEditorController(
        repository: repository,
        idGenerator: () => 'generated-id',
        now: () => DateTime.utc(2026, 2, 16, 12),
      );

      controller
        ..updateTitle('New title')
        ..updateContent('New content')
        ..updateTagsInput('work,focus');

      final saved = await controller.save();

      expect(saved, isTrue);
      expect(repository.savedEntries, hasLength(1));
      expect(repository.savedEntries.single.id, 'generated-id');
      expect(repository.savedEntries.single.tags, const ['work', 'focus']);
      expect(controller.state.title, isEmpty);
      expect(controller.state.isEditing, isFalse);
    });

    test(
      'loadForEditing + save updates same id and preserves createdAt',
      () async {
        final repository = _FakeJournalRepository();
        final existing = JournalEntry.create(
          id: 'entry-1',
          title: 'Original',
          content: 'Original content',
          tags: const ['growth'],
          createdAt: DateTime.utc(2026, 2, 10, 8),
          updatedAt: DateTime.utc(2026, 2, 10, 8),
        );
        repository.savedEntries.add(existing);

        final controller = JournalEditorController(
          repository: repository,
          idGenerator: () => 'unused-id',
          now: () => DateTime.utc(2026, 2, 16, 12),
        );

        controller.loadForEditing(existing);
        controller.updateContent('Updated content');

        final saved = await controller.save();

        expect(saved, isTrue);
        expect(repository.savedEntries, hasLength(1));
        expect(repository.savedEntries.single.id, 'entry-1');
        expect(repository.savedEntries.single.createdAt, existing.createdAt);
        expect(
          repository.savedEntries.single.updatedAt,
          DateTime.utc(2026, 2, 16, 12),
        );
        expect(repository.savedEntries.single.content, 'Updated content');
      },
    );

    test('clearEditor resets editing state', () {
      final controller = JournalEditorController(
        repository: _FakeJournalRepository(),
        idGenerator: () => 'generated-id',
        now: () => DateTime.utc(2026, 2, 16, 12),
      );
      final existing = JournalEntry.create(
        id: 'entry-2',
        title: 'Something',
        content: 'content',
        tags: const ['tag'],
        createdAt: DateTime.utc(2026, 2, 10, 8),
        updatedAt: DateTime.utc(2026, 2, 10, 8),
      );

      controller.loadForEditing(existing);
      expect(controller.state.isEditing, isTrue);

      controller.clearEditor();

      expect(controller.state.isEditing, isFalse);
      expect(controller.state.title, isEmpty);
      expect(controller.state.content, isEmpty);
      expect(controller.state.tagsInput, isEmpty);
    });
  });
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
    return savedEntries;
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
