import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_privacy_policy.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_cloud_ai_service.dart';
import 'package:ai_journal/features/ai/presentation/state/smart_prompt_state.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmartPromptController extends StateNotifier<SmartPromptState> {
  SmartPromptController({
    required JournalRepository repository,
    required AIOrchestrator? aiOrchestrator,
    int maxThemes = 6,
    DateTime Function()? now,
  }) : _repository = repository,
       _aiOrchestrator = aiOrchestrator,
       _maxThemes = maxThemes,
       _now = now ?? DateTime.now,
       super(const SmartPromptState());

  final JournalRepository _repository;
  final AIOrchestrator? _aiOrchestrator;
  final int _maxThemes;
  final DateTime Function() _now;

  Future<void> generatePrompt({String? moodHint, String? writingGoal}) async {
    final orchestrator = _aiOrchestrator;
    if (orchestrator == null) {
      state = state.copyWith(
        status: SmartPromptStatus.error,
        stalePrompt: state.prompt ?? state.stalePrompt,
        errorCode: 'ai_unavailable',
        errorMessage:
            'Enable cloud AI in Settings and provide an API key to generate prompts.',
        retryable: false,
      );
      return;
    }

    state = state.copyWith(
      status: SmartPromptStatus.loading,
      stalePrompt: state.prompt ?? state.stalePrompt,
      clearErrorMessage: true,
      clearErrorCode: true,
      retryable: false,
    );

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

      final normalized = prompt.trim();
      state = state.copyWith(
        prompt: normalized,
        clearStalePrompt: true,
        status: SmartPromptStatus.success,
        clearErrorMessage: true,
        clearErrorCode: true,
        retryable: false,
        lastUpdatedAt: _now(),
      );
    } catch (error) {
      final mapped = _mapError(error);
      state = state.copyWith(
        status: SmartPromptStatus.error,
        stalePrompt: state.prompt ?? state.stalePrompt,
        errorCode: mapped.code,
        errorMessage: mapped.message,
        retryable: mapped.retryable,
      );
    }
  }

  Future<void> retryLastPrompt() {
    return generatePrompt();
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

  _PromptError _mapError(Object error) {
    if (error is AIConsentException) {
      return _PromptError(
        code: 'consent_required',
        message:
            'Cloud AI is disabled. Turn off local-only mode and enable cloud AI consent in Settings.',
        retryable: false,
      );
    }
    if (error is OpenAIConfigurationException) {
      return _PromptError(
        code: 'missing_api_key',
        message: 'Add an OpenAI API key in Settings to use cloud AI prompts.',
        retryable: false,
      );
    }
    if (error is OpenAIServiceException) {
      return _PromptError(
        code: error.code.name,
        message: error.message,
        retryable: error.retryable,
      );
    }

    return const _PromptError(
      code: 'unknown',
      message: 'Unable to generate prompt right now.',
      retryable: true,
    );
  }
}

class _PromptError {
  const _PromptError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  final String code;
  final String message;
  final bool retryable;
}
