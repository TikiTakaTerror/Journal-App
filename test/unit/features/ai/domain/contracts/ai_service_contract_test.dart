import 'package:ai_journal/features/ai/domain/contracts/ai_service.dart';
import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AIService contract', () {
    test('supports prompt, reflection, and chat operations', () async {
      final service = _FakeAIService();
      final entry = JournalEntry.create(
        id: 'entry-1',
        title: 'Tough day',
        content: 'I struggled and then went for a walk.',
        tags: const ['wellness'],
        createdAt: DateTime.utc(2026, 2, 16, 10),
        updatedAt: DateTime.utc(2026, 2, 16, 10),
      );

      final prompt = await service.generatePrompt(
        AISmartPromptRequest(
          recentThemes: <String>['focus', 'stress'],
          moodHint: 'overwhelmed',
        ),
      );

      final reflection = await service.reflectOnEntry(
        AIReflectionRequest(entry: entry),
      );

      final chat = await service.chatWithMemory(
        AIChatRequest(
          userMessage: 'What pattern do you see?',
          memorySummary: 'User feels better after movement.',
          chatHistory: <AIChatMessage>[
            AIChatMessage.create(
              role: AIChatRole.user,
              content: 'I feel anxious.',
              createdAt: DateTime.utc(2026, 2, 16, 10, 30),
            ),
          ],
          relevantEntries: <JournalEntry>[entry],
        ),
      );

      expect(prompt, isNotEmpty);
      expect(reflection, isNotEmpty);
      expect(chat.message, isNotEmpty);
    });
  });
}

class _FakeAIService implements AIService {
  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) async {
    return AIChatResponse(
      message:
          'You frequently regulate stress by moving your body and writing after hard days.',
      updatedMemorySummary: request.memorySummary,
      memorySummaryUpdated: false,
    );
  }

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) async {
    return 'What was one moment today that shifted your mood?';
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) async {
    return 'You identified stress early and used a healthy coping action.';
  }
}
