import 'dart:async';

import 'package:ai_journal/features/ai/application/chat_with_memory_use_case.dart';
import 'package:ai_journal/features/ai/domain/contracts/memory_service.dart';
import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_cloud_ai_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AICompanionStatus { idle, loading, ready, sending, error }

class AICompanionState {
  const AICompanionState({
    this.status = AICompanionStatus.idle,
    this.messages = const <AIChatMessage>[],
    this.memorySummary = '',
    this.errorMessage,
    this.errorCode,
    this.retryable = false,
    this.lastUserDraft,
    this.cloudAvailable = false,
    this.relevantEntriesCount = 0,
  });

  final AICompanionStatus status;
  final List<AIChatMessage> messages;
  final String memorySummary;
  final String? errorMessage;
  final String? errorCode;
  final bool retryable;
  final String? lastUserDraft;
  final bool cloudAvailable;
  final int relevantEntriesCount;

  bool get isLoading => status == AICompanionStatus.loading;
  bool get isSending => status == AICompanionStatus.sending;

  AICompanionState copyWith({
    AICompanionStatus? status,
    List<AIChatMessage>? messages,
    String? memorySummary,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? errorCode,
    bool clearErrorCode = false,
    bool? retryable,
    String? lastUserDraft,
    bool clearLastUserDraft = false,
    bool? cloudAvailable,
    int? relevantEntriesCount,
  }) {
    return AICompanionState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      memorySummary: memorySummary ?? this.memorySummary,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      retryable: retryable ?? this.retryable,
      lastUserDraft: clearLastUserDraft
          ? null
          : (lastUserDraft ?? this.lastUserDraft),
      cloudAvailable: cloudAvailable ?? this.cloudAvailable,
      relevantEntriesCount: relevantEntriesCount ?? this.relevantEntriesCount,
    );
  }
}

class AICompanionController extends StateNotifier<AICompanionState> {
  AICompanionController({
    required MemoryService memoryService,
    required ChatWithMemoryUseCase? chatWithMemory,
  }) : _memoryService = memoryService,
       _chatWithMemory = chatWithMemory,
       super(
         AICompanionState(
           status: AICompanionStatus.loading,
           cloudAvailable: chatWithMemory != null,
         ),
       ) {
    unawaited(load());
  }

  final MemoryService _memoryService;
  final ChatWithMemoryUseCase? _chatWithMemory;

  Future<void> load() async {
    state = state.copyWith(
      status: AICompanionStatus.loading,
      clearErrorMessage: true,
      clearErrorCode: true,
      retryable: false,
      cloudAvailable: _chatWithMemory != null,
    );
    try {
      final messages = await _memoryService.loadRecentChatMessages(limit: 24);
      final summary = await _memoryService.loadMemorySummary();
      state = state.copyWith(
        status: AICompanionStatus.ready,
        messages: List<AIChatMessage>.unmodifiable(messages),
        memorySummary: summary,
      );
    } catch (_) {
      state = state.copyWith(
        status: AICompanionStatus.error,
        errorCode: 'memory_load_failed',
        errorMessage: 'Unable to load local chat memory right now.',
        retryable: true,
      );
    }
  }

  Future<void> sendMessage(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (_chatWithMemory == null) {
      state = state.copyWith(
        status: AICompanionStatus.error,
        errorCode: 'cloud_ai_unavailable',
        errorMessage:
            'Cloud AI is unavailable. Enable consent and add a key in Settings to use the companion.',
        retryable: false,
        lastUserDraft: normalized,
        cloudAvailable: false,
      );
      return;
    }

    state = state.copyWith(
      status: AICompanionStatus.sending,
      clearErrorMessage: true,
      clearErrorCode: true,
      retryable: false,
      lastUserDraft: normalized,
      cloudAvailable: true,
    );

    try {
      final result = await _chatWithMemory.call(normalized);
      final updatedMessages = <AIChatMessage>[
        ...state.messages,
        result.userMessage,
        result.assistantMessage,
      ];

      state = state.copyWith(
        status: AICompanionStatus.ready,
        messages: List<AIChatMessage>.unmodifiable(updatedMessages),
        memorySummary: result.memorySummary,
        clearLastUserDraft: true,
        relevantEntriesCount: result.relevantEntriesCount,
      );
    } catch (error) {
      final mapped = _mapError(error);
      state = state.copyWith(
        status: AICompanionStatus.error,
        errorCode: mapped.code,
        errorMessage: mapped.message,
        retryable: mapped.retryable,
      );
    }
  }

  Future<void> retryLast() async {
    final draft = state.lastUserDraft;
    if (draft == null || draft.trim().isEmpty) {
      return;
    }
    await sendMessage(draft);
  }

  _CompanionError _mapError(Object error) {
    if (error is OpenAIServiceException) {
      return _CompanionError(
        code: error.code.name,
        message: error.message,
        retryable: error.retryable,
      );
    }
    return const _CompanionError(
      code: 'unknown',
      message: 'Unable to send message right now.',
      retryable: true,
    );
  }
}

class _CompanionError {
  const _CompanionError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  final String code;
  final String message;
  final bool retryable;
}
