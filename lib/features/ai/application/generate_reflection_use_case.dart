import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';

class GenerateReflectionUseCase {
  const GenerateReflectionUseCase({required AIOrchestrator orchestrator})
    : _orchestrator = orchestrator;

  final AIOrchestrator _orchestrator;

  Future<String> call(AIReflectionRequest request) {
    return _orchestrator.reflectOnEntry(request);
  }
}
