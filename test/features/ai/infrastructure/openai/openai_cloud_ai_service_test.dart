import 'dart:convert';

import 'package:ai_journal/features/ai/domain/models/ai_privacy_policy.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_cloud_ai_service.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient httpClient;
  late OpenAIConfig validConfig;
  late AIPrivacyPolicy allowedPolicy;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    validConfig = const OpenAIConfig(
      apiKey: 'test-key',
      baseUrl: 'https://api.openai.com/v1',
      chatModel: 'gpt-4o',
    );
    allowedPolicy = const AIPrivacyPolicy(
      localOnlyAi: false,
      cloudAiConsent: true,
    );
  });

  OpenAICloudAIService createService({
    OpenAIConfig? config,
    AIPrivacyPolicy? policy,
  }) {
    return OpenAICloudAIService(
      config: config ?? validConfig,
      privacyPolicy: policy ?? allowedPolicy,
      httpClient: httpClient,
      timeout: const Duration(milliseconds: 100), // Short for testing timeouts
    );
  }

  group('OpenAICloudAIService - Prompt Generation', () {
    test('Throws configuration exception if API key is missing', () async {
      final service = createService(
        config: const OpenAIConfig(apiKey: ''),
      );

      expect(
        () => service.generatePrompt(AISmartPromptRequest(recentThemes: const [])),
        throwsA(isA<OpenAIConfigurationException>()),
      );
    });

    test('Throws policy exception if cloud is not allowed', () async {
      final service = createService(
        policy: const AIPrivacyPolicy(localOnlyAi: true, cloudAiConsent: false),
      );

      expect(
        () => service.generatePrompt(AISmartPromptRequest(recentThemes: const [])),
        throwsA(isA<AIConsentException>()),
      );
    });

    test('Successfully parses valid assistant message', () async {
      final service = createService();
      final validResponse = jsonEncode({
        'choices': [
          {'message': {'content': 'This is a test prompt.'}},
        ],
      });

      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(validResponse, 200));

      final result = await service.generatePrompt(
        AISmartPromptRequest(recentThemes: const ['theme1']),
      );

      expect(result, 'This is a test prompt.');
    });

    test('Fires retry for 429 Too Many Requests and then succeeds', () async {
      final service = createService();
      final validResponse = jsonEncode({
        'choices': [
          {'message': {'content': 'Success after retry.'}},
        ],
      });

      int attempts = 0;
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          return http.Response('Rate limited', 429);
        }
        return http.Response(validResponse, 200);
      });

      final result = await service.generatePrompt(
        AISmartPromptRequest(recentThemes: const []),
      );

      expect(result, 'Success after retry.');
      expect(attempts, 2);
    });

    test('Throws OpenAIServiceException immediately for 401 Unauthorized', () async {
      final service = createService();

      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'error': {'message': 'Invalid API Key'}}),
          401,
        ),
      );

      expect(
        () => service.generatePrompt(AISmartPromptRequest(recentThemes: const [])),
        throwsA(
          isA<OpenAIServiceException>().having(
            (e) => e.message,
            'message',
            contains('Invalid API Key'),
          ),
        ),
      );
    });

    test('Throws timeout exception when request exceeds duration', () async {
      final service = createService();

      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      });

      expect(
        () => service.generatePrompt(AISmartPromptRequest(recentThemes: const [])),
        throwsA(
          isA<OpenAIServiceException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });
}
