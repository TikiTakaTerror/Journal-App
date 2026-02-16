import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';

/// Application-facing orchestration boundary for all AI user flows.
abstract interface class AIOrchestrator {
  Future<String> generatePrompt(AISmartPromptRequest request);

  Future<String> reflectOnEntry(AIReflectionRequest request);

  Future<AIChatResponse> chatWithMemory(AIChatRequest request);
}
