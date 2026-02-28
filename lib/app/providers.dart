import 'package:ai_journal/app/base_providers.dart';
import 'package:ai_journal/features/ai/ai_providers.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_controller.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

export 'package:ai_journal/app/base_providers.dart';
export 'package:ai_journal/features/ai/ai_providers.dart';

final _uuid = Uuid();

final journalEditorControllerProvider =
    StateNotifierProvider<JournalEditorController, JournalEditorState>((ref) {
      return JournalEditorController(
        repository: ref.watch(journalRepositoryProvider),
        idGenerator: _uuid.v4,
        now: DateTime.now,
        aiOrchestrator: ref.watch(aiOrchestratorProvider),
      );
    });
