import 'dart:convert';

import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/ai/domain/models/ai_privacy_policy.dart';
import 'package:ai_journal/features/ai/domain/models/ai_request_limits.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_cloud_ai_service.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_config.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenAICloudAIService', () {
    test(
      'generatePrompt uses responses API by default and parses structured output',
      () async {
        final client = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.example.test/v1/responses',
          );
          expect(request.headers['Authorization'], 'Bearer test-key');
          expect(request.headers['Content-Type'], 'application/json');

          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['model'], 'gpt-4.1-nano');
          expect(payload['max_output_tokens'], 96);
          expect(payload['instructions'], isA<String>());
          expect(payload['store'], isFalse);

          final input = payload['input'] as List<dynamic>;
          expect(input.length, 1);
          expect(input.first, isA<Map<String, dynamic>>());

          return http.Response(
            jsonEncode(<String, Object?>{
              'output': <Object?>[
                <String, Object?>{
                  'type': 'message',
                  'content': <Object?>[
                    <String, Object?>{
                      'type': 'output_text',
                      'text': 'What emotion surprised you most today?',
                    },
                  ],
                },
              ],
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        });

        final service = OpenAICloudAIService(
          config: const OpenAIConfig(
            apiKey: 'test-key',
            baseUrl: 'https://api.example.test/v1',
            chatModel: 'gpt-4.1-nano',
          ),
          privacyPolicy: const AIPrivacyPolicy(
            localOnlyAi: false,
            cloudAiConsent: true,
          ),
          httpClient: client,
        );

        final prompt = await service.generatePrompt(
          AISmartPromptRequest(
            recentThemes: const <String>['focus', 'stress'],
            moodHint: 'overwhelmed',
          ),
        );

        expect(prompt, 'What emotion surprised you most today?');
      },
    );

    test(
      'generatePrompt supports chat completions compatibility mode',
      () async {
        final client = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.example.test/v1/chat/completions',
          );
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['max_tokens'], 96);
          expect(payload['messages'], isA<List<dynamic>>());
          expect(payload['store'], isFalse);

          return http.Response(
            jsonEncode(<String, Object?>{
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{
                    'content': 'What did you learn about your energy today?',
                  },
                },
              ],
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        });

        final service = OpenAICloudAIService(
          config: const OpenAIConfig(
            apiKey: 'test-key',
            baseUrl: 'https://api.example.test/v1',
            chatModel: 'gpt-4.1-nano',
            apiMode: OpenAIApiMode.chatCompletions,
          ),
          privacyPolicy: const AIPrivacyPolicy(
            localOnlyAi: false,
            cloudAiConsent: true,
          ),
          httpClient: client,
        );

        final prompt = await service.generatePrompt(AISmartPromptRequest());

        expect(prompt, 'What did you learn about your energy today?');
      },
    );

    test(
      'reflectOnEntry maps retryable status metadata on non-200 response',
      () async {
        final client = MockClient((_) async {
          return http.Response(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{'message': 'Rate limit exceeded'},
            }),
            429,
            headers: <String, String>{
              'content-type': 'application/json',
              'x-request-id': 'req_123',
            },
          );
        });

        final service = OpenAICloudAIService(
          config: const OpenAIConfig(apiKey: 'test-key', maxRetries: 0),
          privacyPolicy: const AIPrivacyPolicy(
            localOnlyAi: false,
            cloudAiConsent: true,
          ),
          httpClient: client,
        );

        final entry = _entry(
          id: 'entry-1',
          title: 'Hard day',
          content: 'I felt pressure in meetings.',
          hourOffset: 1,
        );

        expect(
          () => service.reflectOnEntry(AIReflectionRequest(entry: entry)),
          throwsA(
            isA<OpenAIServiceException>()
                .having(
                  (error) => error.message,
                  'message',
                  contains('Rate limit exceeded'),
                )
                .having(
                  (error) => error.code,
                  'code',
                  OpenAIServiceErrorCode.rateLimited,
                )
                .having((error) => error.retryable, 'retryable', isTrue)
                .having((error) => error.statusCode, 'statusCode', 429)
                .having((error) => error.requestId, 'requestId', 'req_123')
                .having((error) => error.attempts, 'attempts', 1),
          ),
        );
      },
    );

    test('chatWithMemory trims chat history and retrieved entries', () async {
      final client = MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final body = jsonEncode(payload);

        expect(body, contains('latest-1'));
        expect(body, contains('latest-2'));
        expect(body, isNot(contains('older-history')));
        expect(body, contains('Entry A'));
        expect(body, isNot(contains('Entry B')));
        expect(payload['max_output_tokens'], 320);

        return http.Response(
          jsonEncode(<String, Object?>{
            'output_text': 'You often recover when you take a short walk.',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final service = OpenAICloudAIService(
        config: const OpenAIConfig(apiKey: 'test-key'),
        privacyPolicy: const AIPrivacyPolicy(
          localOnlyAi: false,
          cloudAiConsent: true,
        ),
        limits: AIRequestLimits(
          maxChatHistoryMessages: 2,
          maxRetrievedEntries: 1,
        ),
        httpClient: client,
      );

      final response = await service.chatWithMemory(
        AIChatRequest(
          userMessage: 'What should I focus on next?',
          memorySummary: 'Movement helps me regulate stress.',
          chatHistory: <AIChatMessage>[
            AIChatMessage.create(
              role: AIChatRole.user,
              content: 'older-history',
              createdAt: DateTime.utc(2026, 2, 16, 9, 0),
            ),
            AIChatMessage.create(
              role: AIChatRole.user,
              content: 'latest-1',
              createdAt: DateTime.utc(2026, 2, 16, 9, 1),
            ),
            AIChatMessage.create(
              role: AIChatRole.assistant,
              content: 'latest-2',
              createdAt: DateTime.utc(2026, 2, 16, 9, 2),
            ),
          ],
          relevantEntries: <JournalEntry>[
            _entry(
              id: 'entry-a',
              title: 'Entry A',
              content: 'I felt better after walking.',
              hourOffset: 1,
            ),
            _entry(
              id: 'entry-b',
              title: 'Entry B',
              content: 'Another entry that should be trimmed.',
              hourOffset: 2,
            ),
          ],
        ),
      );

      expect(response.message, isNotEmpty);
      expect(response.memorySummaryUpdated, isFalse);
    });

    test(
      'throws OpenAIConfigurationException when API key is missing',
      () async {
        var networkCalled = false;
        final client = MockClient((_) async {
          networkCalled = true;
          return http.Response('{}', 200);
        });

        final service = OpenAICloudAIService(
          config: const OpenAIConfig(apiKey: ''),
          privacyPolicy: const AIPrivacyPolicy(
            localOnlyAi: false,
            cloudAiConsent: true,
          ),
          httpClient: client,
        );

        expect(
          () => service.generatePrompt(AISmartPromptRequest()),
          throwsA(isA<OpenAIConfigurationException>()),
        );
        expect(networkCalled, isFalse);
      },
    );

    test('throws AIConsentException when cloud AI is not allowed', () async {
      var networkCalled = false;
      final client = MockClient((_) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });

      final service = OpenAICloudAIService(
        config: const OpenAIConfig(apiKey: 'test-key'),
        privacyPolicy: const AIPrivacyPolicy(
          localOnlyAi: true,
          cloudAiConsent: false,
        ),
        httpClient: client,
      );

      expect(
        () => service.generatePrompt(AISmartPromptRequest()),
        throwsA(isA<AIConsentException>()),
      );
      expect(networkCalled, isFalse);
    });

    test(
      'throws OpenAIServiceException when response payload is malformed',
      () async {
        final client = MockClient((_) async {
          return http.Response(
            jsonEncode(<String, Object?>{'unexpected': 'format'}),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        });

        final service = OpenAICloudAIService(
          config: const OpenAIConfig(apiKey: 'test-key'),
          privacyPolicy: const AIPrivacyPolicy(
            localOnlyAi: false,
            cloudAiConsent: true,
          ),
          httpClient: client,
        );

        expect(
          () => service.generatePrompt(AISmartPromptRequest()),
          throwsA(
            isA<OpenAIServiceException>()
                .having(
                  (error) => error.code,
                  'code',
                  OpenAIServiceErrorCode.invalidResponse,
                )
                .having((error) => error.retryable, 'retryable', isFalse),
          ),
        );
      },
    );
  });
}

JournalEntry _entry({
  required String id,
  required String title,
  required String content,
  required int hourOffset,
}) {
  final now = DateTime.utc(2026, 2, 16, 10 + hourOffset);
  return JournalEntry.create(
    id: id,
    title: title,
    content: content,
    tags: const <String>['memory'],
    createdAt: now,
    updatedAt: now,
  );
}
