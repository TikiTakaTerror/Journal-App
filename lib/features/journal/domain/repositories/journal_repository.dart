import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';

/// Repository contract used by presentation layer.
abstract interface class JournalRepository {
  Future<void> upsertEntry(JournalEntry entry);

  Future<List<JournalEntry>> listEntries({String? query, String? tag});

  Future<JournalEntry?> getEntryById(String id);

  Future<void> deleteEntry(String id);
}
