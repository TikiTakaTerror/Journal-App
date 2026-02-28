enum SmartPromptStatus { idle, loading, success, error }

class SmartPromptState {
  const SmartPromptState({
    this.prompt,
    this.stalePrompt,
    this.status = SmartPromptStatus.idle,
    this.errorMessage,
    this.errorCode,
    this.retryable = false,
    this.lastUpdatedAt,
  });

  final String? prompt;
  final String? stalePrompt;
  final SmartPromptStatus status;
  final String? errorMessage;
  final String? errorCode;
  final bool retryable;
  final DateTime? lastUpdatedAt;

  bool get hasPrompt => displayPrompt != null && displayPrompt!.trim().isNotEmpty;
  bool get isLoading => status == SmartPromptStatus.loading;
  String? get displayPrompt => prompt ?? stalePrompt;

  SmartPromptState copyWith({
    String? prompt,
    bool clearPrompt = false,
    String? stalePrompt,
    bool clearStalePrompt = false,
    SmartPromptStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? errorCode,
    bool clearErrorCode = false,
    bool? retryable,
    DateTime? lastUpdatedAt,
    bool clearLastUpdatedAt = false,
  }) {
    return SmartPromptState(
      prompt: clearPrompt ? null : (prompt ?? this.prompt),
      stalePrompt: clearStalePrompt ? null : (stalePrompt ?? this.stalePrompt),
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      retryable: retryable ?? this.retryable,
      lastUpdatedAt: clearLastUpdatedAt
          ? null
          : (lastUpdatedAt ?? this.lastUpdatedAt),
    );
  }
}
