import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/ai/infrastructure/local/local_memory_service.dart';
import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalMemoryService', () {
    test('persists chat messages and loads recent history', () async {
      final service = LocalMemoryService(
        store: _InMemoryKeyValueStore(),
        journalRepository: _FakeJournalRepository(),
      );

      await service.appendChatMessage(
        AIChatMessage.create(
          role: AIChatRole.user,
          content: 'First',
          createdAt: DateTime.utc(2026, 2, 26, 10),
        ),
      );
      await service.appendChatMessage(
        AIChatMessage.create(
          role: AIChatRole.assistant,
          content: 'Second',
          createdAt: DateTime.utc(2026, 2, 26, 10, 1),
        ),
      );

      final recent = await service.loadRecentChatMessages(limit: 1);
      expect(recent, hasLength(1));
      expect(recent.single.content, 'Second');
    });

    test('findRelevantEntries ranks overlapping entries first', () async {
      final repository = _FakeJournalRepository()
        ..entries.addAll([
          _entry(
            id: '1',
            title: 'Morning walk',
            content: 'A walk helped reduce stress before work.',
            tags: const ['wellness'],
          ),
          _entry(
            id: '2',
            title: 'Project planning',
            content: 'Work planning and sprint review.',
            tags: const ['work'],
          ),
        ]);

      final service = LocalMemoryService(
        store: _InMemoryKeyValueStore(),
        journalRepository: repository,
      );

      final results = await service.findRelevantEntries(
        query: 'stress from work and walking',
        limit: 2,
      );

      expect(results, hasLength(2));
      expect(results.first.title, 'Morning walk');
    });
  });
}

JournalEntry _entry({
  required String id,
  required String title,
  required String content,
  required List<String> tags,
}) {
  final now = DateTime.utc(2026, 2, 26, 10);
  return JournalEntry.create(
    id: id,
    title: title,
    content: content,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );
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

class _FakeJournalRepository implements JournalRepository {
  final List<JournalEntry> entries = <JournalEntry>[];

  @override
  Future<void> deleteEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<JournalEntry?> getEntryById(String id) async {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<List<JournalEntry>> listEntries({String? query, String? tag}) async {
    return List<JournalEntry>.from(entries);
  }

  @override
  Future<void> upsertEntry(JournalEntry entry) async {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
  }
}
