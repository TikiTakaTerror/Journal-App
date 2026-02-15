import 'package:ai_journal/features/journal/data/local/journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';

/// Non-encrypted fallback used in unsupported environments.
class InMemoryJournalLocalStorageService implements JournalLocalStorageService {
  final Map<String, JournalEntry> _entries = <String, JournalEntry>{};

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteEntry(String id) async {
    _entries.remove(id);
  }

  @override
  Future<JournalEntry?> getEntryById(String id) async {
    return _entries[id];
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<List<JournalEntry>> listEntries({String? query, String? tag}) async {
    final normalizedQuery = query?.trim().toLowerCase();
    final normalizedTag = tag?.trim().toLowerCase();

    final filtered =
        _entries.values
            .where((entry) {
              final queryMatches =
                  normalizedQuery == null ||
                  normalizedQuery.isEmpty ||
                  entry.title.toLowerCase().contains(normalizedQuery) ||
                  entry.content.toLowerCase().contains(normalizedQuery);

              final tagMatches =
                  normalizedTag == null ||
                  normalizedTag.isEmpty ||
                  entry.tags.contains(normalizedTag);

              return queryMatches && tagMatches;
            })
            .toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return filtered;
  }

  @override
  Future<void> upsertEntry(JournalEntry entry) async {
    _entries[entry.id] = entry;
  }
}
