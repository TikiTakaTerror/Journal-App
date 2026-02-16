class JournalEditorState {
  const JournalEditorState({
    this.title = '',
    this.content = '',
    this.tagsInput = '',
    this.isSaving = false,
    this.errorMessage,
    this.aiReflection,
    this.editingEntryId,
    this.editingCreatedAt,
  });

  final String title;
  final String content;
  final String tagsInput;
  final bool isSaving;
  final String? errorMessage;
  final String? aiReflection;
  final String? editingEntryId;
  final DateTime? editingCreatedAt;

  bool get canSave =>
      title.trim().isNotEmpty && content.trim().isNotEmpty && !isSaving;
  bool get isEditing => editingEntryId != null && editingCreatedAt != null;

  JournalEditorState copyWith({
    String? title,
    String? content,
    String? tagsInput,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? aiReflection,
    bool clearAiReflection = false,
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
      aiReflection: clearAiReflection
          ? null
          : (aiReflection ?? this.aiReflection),
      editingEntryId: clearEditing
          ? null
          : (editingEntryId ?? this.editingEntryId),
      editingCreatedAt: clearEditing
          ? null
          : (editingCreatedAt ?? this.editingCreatedAt),
    );
  }
}
