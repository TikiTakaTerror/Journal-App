enum ReflectionStatus { idle, loading, success, error }

class JournalEditorState {
  const JournalEditorState({
    this.title = '',
    this.content = '',
    this.tagsInput = '',
    this.isSaving = false,
    this.errorMessage,
    this.reflectionStatus = ReflectionStatus.idle,
    this.reflectionText,
    this.reflectionErrorMessage,
    this.reflectionErrorCode,
    this.reflectionRetryable = false,
    this.saveSucceeded = false,
    this.editingEntryId,
    this.editingCreatedAt,
  });

  final String title;
  final String content;
  final String tagsInput;
  final bool isSaving;
  final String? errorMessage;
  final ReflectionStatus reflectionStatus;
  final String? reflectionText;
  final String? reflectionErrorMessage;
  final String? reflectionErrorCode;
  final bool reflectionRetryable;
  final bool saveSucceeded;
  final String? editingEntryId;
  final DateTime? editingCreatedAt;

  @Deprecated('Use reflectionText')
  String? get aiReflection => reflectionText;

  bool get canSave =>
      title.trim().isNotEmpty && content.trim().isNotEmpty && !isSaving;
  bool get isEditing => editingEntryId != null && editingCreatedAt != null;
  bool get canRetryReflection =>
      reflectionStatus == ReflectionStatus.error && reflectionRetryable;
  bool get hasReflection =>
      reflectionText != null && reflectionText!.trim().isNotEmpty;

  JournalEditorState copyWith({
    String? title,
    String? content,
    String? tagsInput,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
    ReflectionStatus? reflectionStatus,
    String? reflectionText,
    bool clearReflectionText = false,
    String? reflectionErrorMessage,
    bool clearReflectionErrorMessage = false,
    String? reflectionErrorCode,
    bool clearReflectionErrorCode = false,
    bool? reflectionRetryable,
    bool? saveSucceeded,
    String? editingEntryId,
    DateTime? editingCreatedAt,
    bool clearEditing = false,
  }) {
    return JournalEditorState(
      title: title ?? this.title,
      content: content ?? this.content,
      tagsInput: tagsInput ?? this.tagsInput,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      reflectionStatus: reflectionStatus ?? this.reflectionStatus,
      reflectionText: clearReflectionText
          ? null
          : (reflectionText ?? this.reflectionText),
      reflectionErrorMessage: clearReflectionErrorMessage
          ? null
          : (reflectionErrorMessage ?? this.reflectionErrorMessage),
      reflectionErrorCode: clearReflectionErrorCode
          ? null
          : (reflectionErrorCode ?? this.reflectionErrorCode),
      reflectionRetryable: reflectionRetryable ?? this.reflectionRetryable,
      saveSucceeded: saveSucceeded ?? this.saveSucceeded,
      editingEntryId: clearEditing
          ? null
          : (editingEntryId ?? this.editingEntryId),
      editingCreatedAt: clearEditing
          ? null
          : (editingCreatedAt ?? this.editingCreatedAt),
    );
  }
}
