class JournalEditorState {
  const JournalEditorState({
    this.title = '',
    this.content = '',
    this.tagsInput = '',
    this.isSaving = false,
    this.errorMessage,
  });

  final String title;
  final String content;
  final String tagsInput;
  final bool isSaving;
  final String? errorMessage;

  bool get canSave =>
      title.trim().isNotEmpty && content.trim().isNotEmpty && !isSaving;

  JournalEditorState copyWith({
    String? title,
    String? content,
    String? tagsInput,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return JournalEditorState(
      title: title ?? this.title,
      content: content ?? this.content,
      tagsInput: tagsInput ?? this.tagsInput,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
