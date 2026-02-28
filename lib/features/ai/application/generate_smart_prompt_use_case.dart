import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';

class GenerateSmartPromptUseCase {
  const GenerateSmartPromptUseCase({required AIOrchestrator orchestrator})
    : _orchestrator = orchestrator;

  final AIOrchestrator _orchestrator;

  Future<String> call(AISmartPromptRequest request) {
    return _orchestrator.generatePrompt(request);
  }
}
