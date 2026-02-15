import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalEntry', () {
    test('create trims text and normalizes unique tags', () {
      final createdAt = DateTime.utc(2026, 1, 1);
      final updatedAt = DateTime.utc(2026, 1, 2);

      final entry = JournalEntry.create(
        id: 'entry-1',
        title: '  Daily Reflection  ',
        content: '  I felt calmer after writing.  ',
        tags: const [' Work ', 'wellness', 'work', '', 'Wellness'],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(entry.title, 'Daily Reflection');
      expect(entry.content, 'I felt calmer after writing.');
      expect(entry.tags, const ['work', 'wellness']);
      expect(entry.createdAt, createdAt);
      expect(entry.updatedAt, updatedAt);
    });

    test('create throws FormatException for empty title', () {
      expect(
        () => JournalEntry.create(
          id: 'entry-2',
          title: '   ',
          content: 'valid content',
          tags: const ['mindfulness'],
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('toMap/fromMap supports safe serialization round-trip', () {
      final entry = JournalEntry.create(
        id: 'entry-3',
        title: 'My Title',
        content: 'My Content',
        tags: const ['focus', 'health'],
        createdAt: DateTime.utc(2026, 2, 14, 13, 0),
        updatedAt: DateTime.utc(2026, 2, 14, 13, 5),
      );

      final decoded = JournalEntry.fromMap(entry.toMap());

      expect(decoded, entry);
    });
  });
}
