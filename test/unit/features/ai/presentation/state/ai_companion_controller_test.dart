import 'package:ai_journal/features/ai/application/chat_with_memory_use_case.dart';
import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/contracts/memory_service.dart';
import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';
import 'package:ai_journal/features/ai/presentation/state/ai_companion_controller.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AICompanionController', () {
    test('loads local memory and chat history on startup', () async {
      final memory = _FakeMemoryService(
        messages: <AIChatMessage>[
          AIChatMessage.create(
            role: AIChatRole.user,
            content: 'hello',
            createdAt: DateTime.utc(2026, 2, 26, 10),
          ),
        ],
        summary: 'Prior context',
      );

      final controller = AICompanionController(
        memoryService: memory,
        chatWithMemory: null,
      );

      await _flush();

      expect(controller.state.status, AICompanionStatus.ready);
      expect(controller.state.messages, hasLength(1));
      expect(controller.state.memorySummary, 'Prior context');
      expect(controller.state.cloudAvailable, isFalse);
    });

    test('sendMessage appends chat when cloud use case is available', () async {
      final memory = _FakeMemoryService();
      final chatUseCase = ChatWithMemoryUseCase(
        memoryService: memory,
        orchestrator: _FakeOrchestrator(),
        now: () => DateTime.utc(2026, 2, 26, 10),
        summaryRefreshInterval: 1,
      );
      final controller = AICompanionController(
        memoryService: memory,
        chatWithMemory: chatUseCase,
      );

      await _flush();
      await controller.sendMessage('Help me reflect');
      await _flush();

      expect(controller.state.status, AICompanionStatus.ready);
      expect(
        controller.state.messages.map((m) => m.content),
        contains('Help me reflect'),
      );
      expect(
        controller.state.messages.map((m) => m.content),
        contains('A grounded next step is to write one small plan.'),
      );
      expect(controller.state.memorySummary, isNotEmpty);
      expect(controller.state.cloudAvailable, isTrue);
    });
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeMemoryService implements MemoryService {
  _FakeMemoryService({
    List<AIChatMessage>? messages,
    this.summary = '',
  }) : _messages = messages ?? <AIChatMessage>[];

  final List<AIChatMessage> _messages;
  String summary;

  @override
  Future<void> appendChatMessage(AIChatMessage message) async {
    _messages.add(message);
  }

  @override
  Future<List<JournalEntry>> findRelevantEntries({
    required String query,
    required int limit,
  }) async {
    return <JournalEntry>[];
  }

  @override
  Future<String> loadMemorySummary() async => summary;

  @override
  Future<List<AIChatMessage>> loadRecentChatMessages({required int limit}) async {
    if (_messages.length <= limit) {
      return List<AIChatMessage>.from(_messages);
    }
    return List<AIChatMessage>.from(_messages.sublist(_messages.length - limit));
  }

  @override
  Future<void> saveMemorySummary(String summary) async {
    this.summary = summary;
  }
}

class _FakeOrchestrator implements AIOrchestrator {
  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) async {
    return AIChatResponse(
      message: 'A grounded next step is to write one small plan.',
    );
  }

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) async {
    return 'unused';
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) async {
    return 'unused';
  }
}
