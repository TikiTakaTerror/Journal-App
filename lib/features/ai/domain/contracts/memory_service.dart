import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';

/// Persistent memory contract for chat history, summaries, and retrieval.
abstract interface class MemoryService {
  Future<void> appendChatMessage(AIChatMessage message);

  Future<List<AIChatMessage>> loadRecentChatMessages({required int limit});

  Future<String> loadMemorySummary();

  Future<void> saveMemorySummary(String summary);

  Future<List<JournalEntry>> findRelevantEntries({
    required String query,
    required int limit,
  });
}
