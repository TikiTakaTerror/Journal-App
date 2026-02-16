import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AIChatMessage', () {
    test('create trims content and preserves metadata', () {
      final createdAt = DateTime.utc(2026, 2, 16, 12);

      final message = AIChatMessage.create(
        role: AIChatRole.user,
        content: '  I felt stressed after work.  ',
        createdAt: createdAt,
      );

      expect(message.role, AIChatRole.user);
      expect(message.content, 'I felt stressed after work.');
      expect(message.createdAt, createdAt);
    });

    test('create throws FormatException for empty content', () {
      expect(
        () => AIChatMessage.create(
          role: AIChatRole.assistant,
          content: '   ',
          createdAt: DateTime.utc(2026, 2, 16, 12),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('toMap/fromMap supports serialization round-trip', () {
      final source = AIChatMessage.create(
        role: AIChatRole.assistant,
        content: 'Try naming one thing that gave you relief today.',
        createdAt: DateTime.utc(2026, 2, 16, 12, 5),
      );

      final decoded = AIChatMessage.fromMap(source.toMap());

      expect(decoded, source);
    });
  });
}
