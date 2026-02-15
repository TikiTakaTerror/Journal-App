import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';

/// Low-level local persistence contract for journal entries.
abstract interface class JournalLocalStorageService {
  Future<void> initialize();

  Future<void> upsertEntry(JournalEntry entry);

  Future<List<JournalEntry>> listEntries({String? query, String? tag});

  Future<JournalEntry?> getEntryById(String id);

  Future<void> deleteEntry(String id);

  Future<void> close();
}
