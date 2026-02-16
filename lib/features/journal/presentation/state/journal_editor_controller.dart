import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
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

  void updateTitle(String value) {
    state = state.copyWith(
      title: value,
      clearErrorMessage: true,
      clearAiReflection: true,
    );
  }

  void updateContent(String value) {
    state = state.copyWith(
      content: value,
      clearErrorMessage: true,
      clearAiReflection: true,
    );
  }

  void updateTagsInput(String value) {
    state = state.copyWith(
      tagsInput: value,
      clearErrorMessage: true,
      clearAiReflection: true,
    );
  }

  void loadForEditing(JournalEntry entry) {
    state = state.copyWith(
      title: entry.title,
      content: entry.content,
      tagsInput: entry.tags.join(', '),
      editingEntryId: entry.id,
      editingCreatedAt: entry.createdAt.toUtc(),
      clearErrorMessage: true,
      clearAiReflection: true,
    );
  }

  void clearEditor() {
    state = const JournalEditorState();
  }

  Future<bool> save() async {
    if (!state.canSave) {
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      clearAiReflection: true,
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
      final reflection = await _tryGenerateReflection(entry);
      state = JournalEditorState(aiReflection: reflection);
      return true;
    } on FormatException catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: error.message,
        clearAiReflection: true,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Unable to save entry right now.',
        clearAiReflection: true,
      );
      return false;
    }
  }

  Future<String?> _tryGenerateReflection(JournalEntry entry) async {
    final orchestrator = _aiOrchestrator;
    if (orchestrator == null) {
      return null;
    }

    try {
      final reflection = await orchestrator.reflectOnEntry(
        AIReflectionRequest(entry: entry),
      );
      final normalized = reflection.trim();
      return normalized.isEmpty ? null : normalized;
    } catch (_) {
      return null;
    }
  }

  static List<String> _parseTags(String rawValue) {
    return rawValue
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
}
