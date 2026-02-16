import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';

/// Core model-facing AI operations used by the application layer.
abstract interface class AIService {
  Future<String> generatePrompt(AISmartPromptRequest request);

  Future<String> reflectOnEntry(AIReflectionRequest request);

  Future<AIChatResponse> chatWithMemory(AIChatRequest request);
}
