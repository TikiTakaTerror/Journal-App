import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';

/// Request payload for context-aware smart prompt generation.
class AISmartPromptRequest {
  AISmartPromptRequest({
    List<String> recentThemes = const <String>[],
    this.moodHint,
    this.writingGoal,
  }) : recentThemes = _normalizeThemes(recentThemes);

  final List<String> recentThemes;
  final String? moodHint;
  final String? writingGoal;

  static List<String> _normalizeThemes(List<String> themes) {
    final normalized = <String>[];
    final seen = <String>{};

    for (final theme in themes) {
      final value = theme.trim().toLowerCase();
      if (value.isEmpty || seen.contains(value)) {
        continue;
      }
      seen.add(value);
      normalized.add(value);
    }

    return List<String>.unmodifiable(normalized);
  }
}

/// Request payload for reflection generation from a journal entry.
class AIReflectionRequest {
  const AIReflectionRequest({required this.entry});

  final JournalEntry entry;
}

/// Request payload for chat with memory-augmented context.
class AIChatRequest {
  AIChatRequest({
    required String userMessage,
    String memorySummary = '',
    List<AIChatMessage> chatHistory = const <AIChatMessage>[],
    List<JournalEntry> relevantEntries = const <JournalEntry>[],
  }) : userMessage = _normalizeUserMessage(userMessage),
       memorySummary = memorySummary.trim(),
       chatHistory = List<AIChatMessage>.unmodifiable(chatHistory),
       relevantEntries = List<JournalEntry>.unmodifiable(relevantEntries);

  final String userMessage;
  final String memorySummary;
  final List<AIChatMessage> chatHistory;
  final List<JournalEntry> relevantEntries;

  static String _normalizeUserMessage(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Chat userMessage cannot be empty.');
    }

    return normalized;
  }
}
