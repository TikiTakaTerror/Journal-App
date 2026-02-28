import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';
import 'package:ai_journal/features/ai/presentation/state/smart_prompt_controller.dart';
import 'package:ai_journal/features/ai/presentation/state/smart_prompt_state.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmartPromptController', () {
    test(
      'generatePrompt uses recent journal themes and stores response',
      () async {
        final repository = _FakeJournalRepository()
          ..savedEntries.addAll(<JournalEntry>[
            _entry(
              id: 'entry-1',
              title: 'Day 1',
              content: 'Work pressure was high.',
              tags: const <String>['work', 'stress'],
              hourOffset: 1,
            ),
            _entry(
              id: 'entry-2',
              title: 'Day 2',
              content: 'Breathing and walking helped.',
              tags: const <String>['stress', 'wellness'],
              hourOffset: 2,
            ),
          ]);
        final orchestrator = _FakeAIOrchestrator(
          generatedPrompt:
              'What is one small action that would make tomorrow calmer?',
        );
        final controller = SmartPromptController(
          repository: repository,
          aiOrchestrator: orchestrator,
          now: () => DateTime.utc(2026, 2, 26, 11),
        );

        await controller.generatePrompt();

        expect(
          controller.state.prompt,
          'What is one small action that would make tomorrow calmer?',
        );
        expect(controller.state.status, SmartPromptStatus.success);
        expect(controller.state.errorMessage, isNull);
        expect(controller.state.retryable, isFalse);
        expect(controller.state.lastUpdatedAt, DateTime.utc(2026, 2, 26, 11));
        expect(orchestrator.promptRequests, hasLength(1));
        expect(orchestrator.promptRequests.single.recentThemes, const <String>[
          'work',
          'stress',
          'wellness',
        ]);
      },
    );

    test('generatePrompt fails gracefully when AI is unavailable', () async {
      final controller = SmartPromptController(
        repository: _FakeJournalRepository(),
        aiOrchestrator: null,
      );

      await controller.generatePrompt();

      expect(controller.state.prompt, isNull);
      expect(controller.state.status, SmartPromptStatus.error);
      expect(controller.state.errorCode, 'ai_unavailable');
      expect(controller.state.retryable, isFalse);
      expect(controller.state.errorMessage, contains('Enable cloud AI'));
    });

    test('generatePrompt preserves stale prompt on failure', () async {
      final orchestrator = _TogglePromptAIOrchestrator();
      final controller = SmartPromptController(
        repository: _FakeJournalRepository(),
        aiOrchestrator: orchestrator,
      );

      await controller.generatePrompt();
      expect(controller.state.prompt, 'First prompt');

      orchestrator.shouldFail = true;
      await controller.generatePrompt();

      expect(controller.state.status, SmartPromptStatus.error);
      expect(controller.state.prompt, 'First prompt');
      expect(controller.state.stalePrompt, 'First prompt');
      expect(controller.state.displayPrompt, 'First prompt');
      expect(controller.state.retryable, isTrue);
    });

    test('retryLastPrompt delegates to generatePrompt', () async {
      final controller = SmartPromptController(
        repository: _FakeJournalRepository(),
        aiOrchestrator: _FakeAIOrchestrator(generatedPrompt: 'Retry prompt'),
      );

      await controller.retryLastPrompt();

      expect(controller.state.prompt, 'Retry prompt');
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
  final now = DateTime.utc(2026, 2, 16, 10 + hourOffset);
  return JournalEntry.create(
    id: id,
    title: title,
    content: content,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeJournalRepository implements JournalRepository {
  final List<JournalEntry> savedEntries = <JournalEntry>[];

  @override
  Future<void> deleteEntry(String id) async {
    savedEntries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<JournalEntry?> getEntryById(String id) async {
    for (final entry in savedEntries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<List<JournalEntry>> listEntries({String? query, String? tag}) async {
    return savedEntries;
  }

  @override
  Future<void> upsertEntry(JournalEntry entry) async {
    final index = savedEntries.indexWhere((saved) => saved.id == entry.id);
    if (index == -1) {
      savedEntries.add(entry);
      return;
    }

    savedEntries[index] = entry;
  }
}

class _FakeAIOrchestrator implements AIOrchestrator {
  _FakeAIOrchestrator({required this.generatedPrompt});

  final String generatedPrompt;
  final List<AISmartPromptRequest> promptRequests = <AISmartPromptRequest>[];

  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) async {
    return AIChatResponse(message: 'chat');
  }

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) async {
    promptRequests.add(request);
    return generatedPrompt;
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) async {
    return 'reflection';
  }
}

class _TogglePromptAIOrchestrator implements AIOrchestrator {
  bool shouldFail = false;

  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) async {
    throw Exception('not used');
  }

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) async {
    if (shouldFail) {
      throw Exception('boom');
    }
    return 'First prompt';
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) async {
    throw Exception('not used');
  }
}
