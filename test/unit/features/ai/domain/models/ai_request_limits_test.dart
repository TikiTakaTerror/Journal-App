import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/ai/domain/models/ai_request_limits.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AIRequestLimits', () {
    test('default values are privacy and cost aware', () {
      final limits = AIRequestLimits();

      expect(limits.maxChatHistoryMessages, 12);
      expect(limits.maxRetrievedEntries, 5);
      expect(limits.maxInputCharacters, 12000);
      expect(limits.maxOutputTokens, 512);
    });

    test('throws FormatException for invalid limits', () {
      expect(
        () => AIRequestLimits(maxChatHistoryMessages: 0),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AIRequestLimits(maxRetrievedEntries: -1),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AIRequestLimits(maxInputCharacters: 0),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AIRequestLimits(maxOutputTokens: 0),
        throwsA(isA<FormatException>()),
      );
    });

    test('trimChatHistory keeps only the latest N messages', () {
      final limits = AIRequestLimits(maxChatHistoryMessages: 2);
      final history = <AIChatMessage>[
        _message('m1', DateTime.utc(2026, 2, 16, 12, 0)),
        _message('m2', DateTime.utc(2026, 2, 16, 12, 1)),
        _message('m3', DateTime.utc(2026, 2, 16, 12, 2)),
      ];

      final trimmed = limits.trimChatHistory(history);

      expect(trimmed.map((message) => message.content), const ['m2', 'm3']);
    });

    test('limitRetrievedEntries keeps only top N entries', () {
      final limits = AIRequestLimits(maxRetrievedEntries: 2);
      final entries = <JournalEntry>[
        _entry('entry-1', hourOffset: 1),
        _entry('entry-2', hourOffset: 2),
        _entry('entry-3', hourOffset: 3),
      ];

      final limited = limits.limitRetrievedEntries(entries);

      expect(limited.map((entry) => entry.id), const ['entry-1', 'entry-2']);
    });

    test('clipInput truncates overly long text', () {
      final limits = AIRequestLimits(maxInputCharacters: 10);

      final clipped = limits.clipInput('  1234567890abcdef  ');

      expect(clipped, '1234567890');
    });
  });
}

AIChatMessage _message(String content, DateTime createdAt) {
  return AIChatMessage.create(
    role: AIChatRole.user,
    content: content,
    createdAt: createdAt,
  );
}

JournalEntry _entry(String id, {required int hourOffset}) {
  final now = DateTime.utc(2026, 2, 16, 10 + hourOffset);
  return JournalEntry.create(
    id: id,
    title: 'Title $id',
    content: 'Content $id',
    tags: const ['memory'],
    createdAt: now,
    updatedAt: now,
  );
}
