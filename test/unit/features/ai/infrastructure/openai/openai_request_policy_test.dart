import 'package:ai_journal/features/ai/infrastructure/openai/openai_request_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenAIRequestPolicy', () {
    test('uses Retry-After seconds header when present', () {
      final policy = OpenAIRequestPolicy(
        maxRetries: 2,
        maxBackoff: const Duration(seconds: 10),
        randomDouble: () => 0.5,
      );

      final delay = policy.retryDelayForAttempt(
        attempt: 1,
        responseHeaders: const <String, String>{'Retry-After': '3'},
      );

      expect(delay, const Duration(seconds: 3));
    });

    test('parses Retry-After HTTP-date header', () {
      final now = DateTime.utc(2026, 2, 26, 12, 0, 0);
      final policy = OpenAIRequestPolicy(
        maxRetries: 2,
        maxBackoff: const Duration(seconds: 10),
        now: () => now,
        randomDouble: () => 0.5,
      );

      final delay = policy.retryDelayForAttempt(
        attempt: 1,
        responseHeaders: const <String, String>{
          'retry-after': 'Thu, 26 Feb 2026 12:00:04 GMT',
        },
      );

      expect(delay, const Duration(seconds: 4));
    });

    test('falls back to exponential backoff with jitter disabled', () {
      final policy = OpenAIRequestPolicy(
        maxRetries: 2,
        baseBackoff: const Duration(milliseconds: 200),
        maxBackoff: const Duration(seconds: 5),
        jitterRatio: 0,
        randomDouble: () => 0.5,
      );

      expect(
        policy.retryDelayForAttempt(attempt: 1),
        const Duration(milliseconds: 200),
      );
      expect(
        policy.retryDelayForAttempt(attempt: 2),
        const Duration(milliseconds: 400),
      );
    });
  });
}
