import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';

class SummarizeMemoryUseCase {
  const SummarizeMemoryUseCase({this.maxSummaryLength = 280});

  final int maxSummaryLength;

  String call({
    required List<AIChatMessage> recentMessages,
    required String existingSummary,
  }) {
    final userMessages = recentMessages
        .where((message) => message.role == AIChatRole.user)
        .map((message) => message.content)
        .toList(growable: false);
    final assistantMessages = recentMessages
        .where((message) => message.role == AIChatRole.assistant)
        .map((message) => message.content)
        .toList(growable: false);

    final bullets = <String>[];
    if (existingSummary.trim().isNotEmpty) {
      bullets.add('Prior context: ${existingSummary.trim()}');
    }
    if (userMessages.isNotEmpty) {
      bullets.add('Recent user focus: ${userMessages.take(3).join(' | ')}');
    }
    if (assistantMessages.isNotEmpty) {
      bullets.add(
        'Helpful responses: ${assistantMessages.take(2).join(' | ')}',
      );
    }

    final summary = bullets.join(' / ').trim();
    if (summary.length <= maxSummaryLength) {
      return summary;
    }
    return summary.substring(0, maxSummaryLength).trim();
  }
}
