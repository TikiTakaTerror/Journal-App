import 'package:ai_journal/features/ai/infrastructure/openai/openai_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenAIConfig', () {
    test('hasApiKey is false when key is empty', () {
      const config = OpenAIConfig(apiKey: '');

      expect(config.hasApiKey, isFalse);
    });

    test('hasApiKey is true when key has content', () {
      const config = OpenAIConfig(apiKey: 'test-key');

      expect(config.hasApiKey, isTrue);
    });

    test('fromEnvironment safely defaults when no defines are present', () {
      final config = OpenAIConfig.fromEnvironment();

      expect(config.apiKey, isEmpty);
      expect(config.baseUrl, isNotEmpty);
      expect(config.chatModel, isNotEmpty);
      expect(config.embeddingModel, isNotEmpty);
      expect(config.apiMode, OpenAIApiMode.responses);
      expect(config.maxRetries, greaterThanOrEqualTo(0));
      expect(config.requestTimeoutMs, greaterThan(0));
      expect(config.debugLoggingEnabled, isFalse);
    });
  });
}
