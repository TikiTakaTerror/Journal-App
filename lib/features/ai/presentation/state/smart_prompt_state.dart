class SmartPromptState {
  const SmartPromptState({
    this.prompt,
    this.isLoading = false,
    this.errorMessage,
  });

  final String? prompt;
  final bool isLoading;
  final String? errorMessage;

  bool get hasPrompt => prompt != null && prompt!.trim().isNotEmpty;

  SmartPromptState copyWith({
    String? prompt,
    bool? isLoading,
    String? errorMessage,
    bool clearPrompt = false,
    bool clearErrorMessage = false,
  }) {
    return SmartPromptState(
      prompt: clearPrompt ? null : (prompt ?? this.prompt),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
