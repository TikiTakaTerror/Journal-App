import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';

/// Centralized boundaries for context windowing and cost control.
class AIRequestLimits {
  AIRequestLimits({
    this.maxChatHistoryMessages = 12,
    this.maxRetrievedEntries = 5,
    this.maxInputCharacters = 12000,
    this.maxOutputTokens = 512,
  }) {
    if (maxChatHistoryMessages <= 0) {
      throw const FormatException('maxChatHistoryMessages must be > 0.');
    }
    if (maxRetrievedEntries <= 0) {
      throw const FormatException('maxRetrievedEntries must be > 0.');
    }
    if (maxInputCharacters <= 0) {
      throw const FormatException('maxInputCharacters must be > 0.');
    }
    if (maxOutputTokens <= 0) {
      throw const FormatException('maxOutputTokens must be > 0.');
    }
  }

  final int maxChatHistoryMessages;
  final int maxRetrievedEntries;
  final int maxInputCharacters;
  final int maxOutputTokens;

  List<AIChatMessage> trimChatHistory(List<AIChatMessage> history) {
    if (history.length <= maxChatHistoryMessages) {
      return List<AIChatMessage>.unmodifiable(history);
    }

    return List<AIChatMessage>.unmodifiable(
      history.sublist(history.length - maxChatHistoryMessages),
    );
  }

  List<JournalEntry> limitRetrievedEntries(List<JournalEntry> entries) {
    if (entries.length <= maxRetrievedEntries) {
      return List<JournalEntry>.unmodifiable(entries);
    }

    return List<JournalEntry>.unmodifiable(entries.take(maxRetrievedEntries));
  }

  String clipInput(String value) {
    final normalized = value.trim();
    if (normalized.length <= maxInputCharacters) {
      return normalized;
    }

    return normalized.substring(0, maxInputCharacters);
  }
}
