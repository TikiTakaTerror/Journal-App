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
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _now = now,
       super(const JournalEditorState());

  final JournalRepository _repository;
  final EntryIdGenerator _idGenerator;
  final Clock _now;

  void updateTitle(String value) {
    state = state.copyWith(title: value, clearErrorMessage: true);
  }

  void updateContent(String value) {
    state = state.copyWith(content: value, clearErrorMessage: true);
  }

  void updateTagsInput(String value) {
    state = state.copyWith(tagsInput: value, clearErrorMessage: true);
  }

  Future<bool> save() async {
    if (!state.canSave) {
      return false;
    }

    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      final now = _now().toUtc();
      final entry = JournalEntry.create(
        id: _idGenerator(),
        title: state.title,
        content: state.content,
        tags: _parseTags(state.tagsInput),
        createdAt: now,
        updatedAt: now,
      );
      await _repository.upsertEntry(entry);
      state = const JournalEditorState();
      return true;
    } on FormatException catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Unable to save entry right now.',
      );
      return false;
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
