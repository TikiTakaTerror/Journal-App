import 'dart:async';

import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_privacy_policy.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_cloud_ai_service.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef EntryIdGenerator = String Function();
typedef Clock = DateTime Function();

class JournalEditorController extends StateNotifier<JournalEditorState> {
  JournalEditorController({
    required JournalRepository repository,
    required EntryIdGenerator idGenerator,
    required Clock now,
    AIOrchestrator? aiOrchestrator,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _now = now,
       _aiOrchestrator = aiOrchestrator,
       super(const JournalEditorState());

  final JournalRepository _repository;
  final EntryIdGenerator _idGenerator;
  final Clock _now;
  final AIOrchestrator? _aiOrchestrator;

  JournalEntry? _lastSavedEntry;
  int _reflectionGeneration = 0;

  void updateTitle(String value) {
    state = state.copyWith(
      title: value,
      clearErrorMessage: true,
      saveSucceeded: false,
      reflectionStatus: ReflectionStatus.idle,
      clearReflectionText: true,
      clearReflectionErrorMessage: true,
      clearReflectionErrorCode: true,
      reflectionRetryable: false,
    );
  }

  void updateContent(String value) {
    state = state.copyWith(
      content: value,
      clearErrorMessage: true,
      saveSucceeded: false,
      reflectionStatus: ReflectionStatus.idle,
      clearReflectionText: true,
      clearReflectionErrorMessage: true,
      clearReflectionErrorCode: true,
      reflectionRetryable: false,
    );
  }

  void updateTagsInput(String value) {
    state = state.copyWith(
      tagsInput: value,
      clearErrorMessage: true,
      saveSucceeded: false,
      reflectionStatus: ReflectionStatus.idle,
      clearReflectionText: true,
      clearReflectionErrorMessage: true,
      clearReflectionErrorCode: true,
      reflectionRetryable: false,
    );
  }

  void loadForEditing(JournalEntry entry) {
    _lastSavedEntry = null;
    _reflectionGeneration += 1;
    state = state.copyWith(
      title: entry.title,
      content: entry.content,
      tagsInput: entry.tags.join(', '),
      editingEntryId: entry.id,
      editingCreatedAt: entry.createdAt.toUtc(),
      clearErrorMessage: true,
      reflectionStatus: ReflectionStatus.idle,
      clearReflectionText: true,
      clearReflectionErrorMessage: true,
      clearReflectionErrorCode: true,
      reflectionRetryable: false,
      saveSucceeded: false,
    );
  }

  void clearEditor() {
    _lastSavedEntry = null;
    _reflectionGeneration += 1;
    state = const JournalEditorState();
  }

  Future<bool> save() async {
    if (!state.canSave) {
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      reflectionStatus: ReflectionStatus.idle,
      clearReflectionText: true,
      clearReflectionErrorMessage: true,
      clearReflectionErrorCode: true,
      reflectionRetryable: false,
      saveSucceeded: false,
    );

    try {
      final now = _now().toUtc();
      final isEditing = state.isEditing;
      final entry = JournalEntry.create(
        id: isEditing ? state.editingEntryId! : _idGenerator(),
        title: state.title,
        content: state.content,
        tags: _parseTags(state.tagsInput),
        createdAt: isEditing ? state.editingCreatedAt! : now,
        updatedAt: now,
      );

      await _repository.upsertEntry(entry);
      _lastSavedEntry = entry;

      final hasAi = _aiOrchestrator != null;
      state = state.copyWith(
        isSaving: false,
        saveSucceeded: true,
        editingEntryId: entry.id,
        editingCreatedAt: entry.createdAt,
        reflectionStatus: hasAi ? ReflectionStatus.loading : ReflectionStatus.idle,
        clearReflectionText: true,
        clearReflectionErrorMessage: true,
        clearReflectionErrorCode: true,
        reflectionRetryable: false,
      );

      if (hasAi) {
        final token = ++_reflectionGeneration;
        unawaited(_generateReflection(entry, token));
      }

      return true;
    } on FormatException catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Unable to save entry right now.',
      );
      return false;
    }
  }

  Future<void> retryReflection() async {
    final entry = _lastSavedEntry;
    if (entry == null || _aiOrchestrator == null) {
      return;
    }

    final token = ++_reflectionGeneration;
    state = state.copyWith(
      reflectionStatus: ReflectionStatus.loading,
      clearReflectionErrorMessage: true,
      clearReflectionErrorCode: true,
      reflectionRetryable: false,
      clearReflectionText: true,
    );
    await _generateReflection(entry, token);
  }

  Future<void> _generateReflection(JournalEntry entry, int token) async {
    final orchestrator = _aiOrchestrator;
    if (orchestrator == null) {
      return;
    }

    try {
      final reflection = await orchestrator.reflectOnEntry(
        AIReflectionRequest(entry: entry),
      );
      if (token != _reflectionGeneration) {
        return;
      }

      final normalized = reflection.trim();
      if (normalized.isEmpty) {
        state = state.copyWith(
          reflectionStatus: ReflectionStatus.idle,
          clearReflectionText: true,
          clearReflectionErrorMessage: true,
          clearReflectionErrorCode: true,
          reflectionRetryable: false,
        );
        return;
      }

      state = state.copyWith(
        reflectionStatus: ReflectionStatus.success,
        reflectionText: normalized,
        clearReflectionErrorMessage: true,
        clearReflectionErrorCode: true,
        reflectionRetryable: false,
      );
    } catch (error) {
      if (token != _reflectionGeneration) {
        return;
      }
      final mapped = _mapReflectionError(error);
      state = state.copyWith(
        reflectionStatus: ReflectionStatus.error,
        clearReflectionText: true,
        reflectionErrorMessage: mapped.message,
        reflectionErrorCode: mapped.code,
        reflectionRetryable: mapped.retryable,
      );
    }
  }

  _ReflectionError _mapReflectionError(Object error) {
    if (error is AIConsentException) {
      return const _ReflectionError(
        code: 'consent_required',
        message: 'Cloud AI is disabled in Settings.',
        retryable: false,
      );
    }
    if (error is OpenAIConfigurationException) {
      return const _ReflectionError(
        code: 'missing_api_key',
        message: 'Add an OpenAI API key in Settings to generate reflections.',
        retryable: false,
      );
    }
    if (error is OpenAIServiceException) {
      return _ReflectionError(
        code: error.code.name,
        message: error.message,
        retryable: error.retryable,
      );
    }

    return const _ReflectionError(
      code: 'unknown',
      message: 'Unable to generate AI reflection right now.',
      retryable: true,
    );
  }

  static List<String> _parseTags(String rawValue) {
    return rawValue
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
}

class _ReflectionError {
  const _ReflectionError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  final String code;
  final String message;
  final bool retryable;
}
