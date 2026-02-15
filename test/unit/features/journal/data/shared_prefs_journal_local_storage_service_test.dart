import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:ai_journal/features/journal/data/local/shared_prefs_journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedPrefsJournalLocalStorageService', () {
    test('persists entries and restores across service instances', () async {
      final store = _InMemoryKeyValueStore();
      final serviceA = SharedPrefsJournalLocalStorageService(store: store);

      await serviceA.initialize();
      final entry = _entry(
        id: 'entry-1',
        title: 'Persist me',
        content: 'Persistent content',
        tags: const ['offline'],
        hourOffset: 1,
      );
      await serviceA.upsertEntry(entry);

      final serviceB = SharedPrefsJournalLocalStorageService(store: store);
      await serviceB.initialize();

      final restored = await serviceB.listEntries();
      expect(restored, [entry]);
    });

    test('filters by query and tag', () async {
      final service = SharedPrefsJournalLocalStorageService(
        store: _InMemoryKeyValueStore(),
      );
      await service.initialize();

      await service.upsertEntry(
        _entry(
          id: 'entry-work',
          title: 'Work Day',
          content: 'Finished sprint tasks.',
          tags: const ['work'],
          hourOffset: 1,
        ),
      );
      await service.upsertEntry(
        _entry(
          id: 'entry-health',
          title: 'Health',
          content: 'Meditation helped calm my mind.',
          tags: const ['wellness'],
          hourOffset: 2,
        ),
      );

      final queryFiltered = await service.listEntries(query: 'calm');
      expect(queryFiltered.map((entry) => entry.id), ['entry-health']);

      final tagFiltered = await service.listEntries(tag: 'work');
      expect(tagFiltered.map((entry) => entry.id), ['entry-work']);
    });

    test('deleteEntry removes item', () async {
      final service = SharedPrefsJournalLocalStorageService(
        store: _InMemoryKeyValueStore(),
      );
      await service.initialize();

      await service.upsertEntry(
        _entry(
          id: 'entry-delete',
          title: 'Delete',
          content: 'Delete me',
          tags: const ['cleanup'],
          hourOffset: 1,
        ),
      );

      await service.deleteEntry('entry-delete');

      final remaining = await service.listEntries();
      expect(remaining, isEmpty);
    });

    test('handles malformed stored payload safely', () async {
      final store = _InMemoryKeyValueStore()
        ..writeStringSync('journal_entries_v1', 'not-json');

      final service = SharedPrefsJournalLocalStorageService(store: store);
      await service.initialize();

      expect(await service.listEntries(), isEmpty);
    });
  });
}

JournalEntry _entry({
  required String id,
  required String title,
  required String content,
  required List<String> tags,
  required int hourOffset,
}) {
  final now = DateTime.utc(2026, 2, 20, 10 + hourOffset);
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

  void writeStringSync(String key, String value) {
    _values[key] = value;
  }
}
