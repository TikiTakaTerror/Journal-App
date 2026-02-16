/// Response payload from memory-aware chat generation.
class AIChatResponse {
  AIChatResponse({
    required String message,
    this.memorySummaryUpdated = false,
    this.updatedMemorySummary,
  }) : message = _normalizeMessage(message) {
    if (memorySummaryUpdated &&
        (updatedMemorySummary == null ||
            updatedMemorySummary!.trim().isEmpty)) {
      throw const FormatException(
        'updatedMemorySummary is required when memorySummaryUpdated is true.',
      );
    }
  }

  final String message;
  final bool memorySummaryUpdated;
  final String? updatedMemorySummary;

  static String _normalizeMessage(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Chat response message cannot be empty.');
    }

    return normalized;
  }
}
