import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/contracts/ai_service.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';

/// Default orchestrator that delegates to a configured AI service.
class DefaultAIOrchestrator implements AIOrchestrator {
  DefaultAIOrchestrator({required AIService aiService})
    : _aiService = aiService;

  final AIService _aiService;

  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) {
    return _aiService.chatWithMemory(request);
  }

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) {
    return _aiService.generatePrompt(request);
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) {
    return _aiService.reflectOnEntry(request);
  }
}
