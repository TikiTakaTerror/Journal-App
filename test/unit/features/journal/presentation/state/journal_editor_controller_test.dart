import 'dart:async';

import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_controller.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalEditorController', () {
    test('save creates a new entry and marks save success when AI is unavailable', () async {
      final repository = _FakeJournalRepository();
      final controller = JournalEditorController(
        repository: repository,
        idGenerator: () => 'generated-id',
        now: () => DateTime.utc(2026, 2, 16, 12),
      );

      controller
        ..updateTitle('New title')
        ..updateContent('New content')
        ..updateTagsInput('work,focus');

      final saved = await controller.save();

      expect(saved, isTrue);
      expect(repository.savedEntries, hasLength(1));
      expect(repository.savedEntries.single.id, 'generated-id');
      expect(repository.savedEntries.single.tags, const ['work', 'focus']);
      expect(controller.state.saveSucceeded, isTrue);
      expect(controller.state.title, 'New title');
      expect(controller.state.isEditing, isTrue);
      expect(controller.state.reflectionStatus, ReflectionStatus.idle);
    });

    test('save returns before reflection completes and updates reflection later', () async {
      final repository = _FakeJournalRepository();
      final orchestrator = _CompletingAIOrchestrator();
      final controller = JournalEditorController(
        repository: repository,
        idGenerator: () => 'generated-id',
        now: () => DateTime.utc(2026, 2, 16, 12),
        aiOrchestrator: orchestrator,
      );

      controller
        ..updateTitle('New title')
        ..updateContent('New content')
        ..updateTagsInput('work,focus');

      final saved = await controller.save();

      expect(saved, isTrue);
      expect(controller.state.saveSucceeded, isTrue);
      expect(controller.state.reflectionStatus, ReflectionStatus.loading);
      expect(controller.state.reflectionText, isNull);
      expect(orchestrator.reflectionRequests, hasLength(1));

      orchestrator.completeReflection(
        'You handled a difficult moment with a concrete self-regulation action.',
      );
      await _flushAsync();

      expect(controller.state.reflectionStatus, ReflectionStatus.success);
      expect(
        controller.state.reflectionText,
        'You handled a difficult moment with a concrete self-regulation action.',
      );
    });

    test('save succeeds when reflection generation fails and exposes retryable error', () async {
      final repository = _FakeJournalRepository();
      final controller = JournalEditorController(
        repository: repository,
        idGenerator: () => 'generated-id',
        now: () => DateTime.utc(2026, 2, 16, 12),
        aiOrchestrator: _FailingAIOrchestrator(),
      );

      controller
        ..updateTitle('New title')
        ..updateContent('New content');

      final saved = await controller.save();
      await _flushAsync();

      expect(saved, isTrue);
      expect(repository.savedEntries, hasLength(1));
      expect(controller.state.saveSucceeded, isTrue);
      expect(controller.state.reflectionStatus, ReflectionStatus.error);
      expect(controller.state.reflectionText, isNull);
      expect(controller.state.reflectionErrorMessage, isNotNull);
      expect(controller.state.reflectionRetryable, isTrue);
    });

    test('retryReflection retries after a reflection failure', () async {
      final repository = _FakeJournalRepository();
      final orchestrator = _ToggleFailingAIOrchestrator();
      final controller = JournalEditorController(
        repository: repository,
        idGenerator: () => 'generated-id',
        now: () => DateTime.utc(2026, 2, 16, 12),
        aiOrchestrator: orchestrator,
      );

      controller
        ..updateTitle('New title')
        ..updateContent('New content');

      await controller.save();
      await _flushAsync();
      expect(controller.state.reflectionStatus, ReflectionStatus.error);

      orchestrator.shouldFail = false;
      await controller.retryReflection();
      await _flushAsync();

      expect(controller.state.reflectionStatus, ReflectionStatus.success);
      expect(controller.state.reflectionText, 'Recovered reflection');
    });

    test(
      'loadForEditing + save updates same id and preserves createdAt',
      () async {
        final repository = _FakeJournalRepository();
        final existing = JournalEntry.create(
          id: 'entry-1',
          title: 'Original',
          content: 'Original content',
          tags: const ['growth'],
          createdAt: DateTime.utc(2026, 2, 10, 8),
          updatedAt: DateTime.utc(2026, 2, 10, 8),
        );
        repository.savedEntries.add(existing);

        final controller = JournalEditorController(
          repository: repository,
          idGenerator: () => 'unused-id',
          now: () => DateTime.utc(2026, 2, 16, 12),
        );

        controller.loadForEditing(existing);
        controller.updateContent('Updated content');

        final saved = await controller.save();

        expect(saved, isTrue);
        expect(repository.savedEntries, hasLength(1));
        expect(repository.savedEntries.single.id, 'entry-1');
        expect(repository.savedEntries.single.createdAt, existing.createdAt);
        expect(
          repository.savedEntries.single.updatedAt,
          DateTime.utc(2026, 2, 16, 12),
        );
        expect(repository.savedEntries.single.content, 'Updated content');
      },
    );

    test('clearEditor resets editing state', () {
      final controller = JournalEditorController(
        repository: _FakeJournalRepository(),
        idGenerator: () => 'generated-id',
        now: () => DateTime.utc(2026, 2, 16, 12),
      );
      final existing = JournalEntry.create(
        id: 'entry-2',
        title: 'Something',
        content: 'content',
        tags: const ['tag'],
        createdAt: DateTime.utc(2026, 2, 10, 8),
        updatedAt: DateTime.utc(2026, 2, 10, 8),
      );

      controller.loadForEditing(existing);
      expect(controller.state.isEditing, isTrue);

      controller.clearEditor();

      expect(controller.state.isEditing, isFalse);
      expect(controller.state.title, isEmpty);
      expect(controller.state.content, isEmpty);
      expect(controller.state.tagsInput, isEmpty);
      expect(controller.state.reflectionStatus, ReflectionStatus.idle);
    });
  });
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeJournalRepository implements JournalRepository {
  final List<JournalEntry> savedEntries = <JournalEntry>[];

  @override
  Future<void> deleteEntry(String id) async {
    savedEntries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<JournalEntry?> getEntryById(String id) async {
    for (final entry in savedEntries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<List<JournalEntry>> listEntries({String? query, String? tag}) async {
    return savedEntries;
  }

  @override
  Future<void> upsertEntry(JournalEntry entry) async {
    final index = savedEntries.indexWhere(
      (existing) => existing.id == entry.id,
    );
    if (index == -1) {
      savedEntries.add(entry);
      return;
    }

    savedEntries[index] = entry;
  }
}

class _CompletingAIOrchestrator implements AIOrchestrator {
  final List<AIReflectionRequest> reflectionRequests = <AIReflectionRequest>[];
  Completer<String>? _completer;

  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) async {
    return AIChatResponse(message: 'chat');
  }

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) async {
    return 'prompt';
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) {
    reflectionRequests.add(request);
    _completer = Completer<String>();
    return _completer!.future;
  }

  void completeReflection(String value) {
    _completer?.complete(value);
  }
}

class _ToggleFailingAIOrchestrator implements AIOrchestrator {
  bool shouldFail = true;

  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) async {
    throw Exception('not used');
  }

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) async {
    throw Exception('not used');
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) async {
    if (shouldFail) {
      throw Exception('reflection failed');
    }
    return 'Recovered reflection';
  }
}

class _FailingAIOrchestrator implements AIOrchestrator {
  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) async {
    throw Exception('not used');
  }

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) async {
    throw Exception('not used');
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) async {
    throw Exception('reflection failed');
  }
}
