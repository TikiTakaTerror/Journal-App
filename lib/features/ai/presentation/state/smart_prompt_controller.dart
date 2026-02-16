import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/presentation/state/smart_prompt_state.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmartPromptController extends StateNotifier<SmartPromptState> {
  SmartPromptController({
    required JournalRepository repository,
    required AIOrchestrator? aiOrchestrator,
    int maxThemes = 6,
  }) : _repository = repository,
       _aiOrchestrator = aiOrchestrator,
       _maxThemes = maxThemes,
       super(const SmartPromptState());

  final JournalRepository _repository;
  final AIOrchestrator? _aiOrchestrator;
  final int _maxThemes;

  Future<void> generatePrompt({String? moodHint, String? writingGoal}) async {
    final orchestrator = _aiOrchestrator;
    if (orchestrator == null) {
      state = state.copyWith(
        isLoading: false,
        clearPrompt: true,
        errorMessage:
            'Enable cloud AI in Settings and provide an API key to generate prompts.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final entries = await _repository.listEntries();
      final themes = _collectRecentThemes(entries);
      final prompt = await orchestrator.generatePrompt(
        AISmartPromptRequest(
          recentThemes: themes,
          moodHint: moodHint,
          writingGoal: writingGoal,
        ),
      );

      state = state.copyWith(
        prompt: prompt.trim(),
        isLoading: false,
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        clearPrompt: true,
        errorMessage: 'Unable to generate prompt right now.',
      );
    }
  }

  List<String> _collectRecentThemes(List<JournalEntry> entries) {
    final themes = <String>[];
    final seen = <String>{};

    for (final entry in entries) {
      for (final tag in entry.tags) {
        final normalized = tag.trim().toLowerCase();
        if (normalized.isEmpty || seen.contains(normalized)) {
          continue;
        }

        seen.add(normalized);
        themes.add(normalized);

        if (themes.length >= _maxThemes) {
          return List<String>.unmodifiable(themes);
        }
      }
    }

    return List<String>.unmodifiable(themes);
  }
}
