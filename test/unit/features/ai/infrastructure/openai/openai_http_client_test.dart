import 'dart:async';
import 'dart:convert';

import 'package:ai_journal/features/ai/infrastructure/openai/openai_error_mapper.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_errors.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_http_client.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_redacted_logger.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_request_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenAIHttpClient', () {
    test('retries 429 responses and honors Retry-After header', () async {
      var callCount = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((_) async {
        callCount += 1;
        if (callCount == 1) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{'message': 'Too many requests'},
            }),
            429,
            headers: <String, String>{'retry-after': '2'},
          );
        }

        return http.Response(
          jsonEncode(<String, Object?>{'ok': true}),
          200,
          headers: <String, String>{'x-request-id': 'req_final'},
        );
      });

      final policy = OpenAIRequestPolicy(
        maxRetries: 2,
        randomDouble: () => 0.5,
      );
      final client = OpenAIHttpClient(
        httpClient: mockClient,
        requestPolicy: policy,
        errorMapper: OpenAIErrorMapper(requestPolicy: policy),
        delay: (delay) async {
          delays.add(delay);
        },
      );

      final response = await client.postJson(
        uri: Uri.parse('https://api.example.test/v1/responses'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer secret-key',
        },
        payload: const <String, Object?>{
          'model': 'gpt-4.1-nano',
          'input': 'hello',
        },
        operation: 'test_op',
        model: 'gpt-4.1-nano',
        messageCount: 1,
      );

      expect(callCount, 2);
      expect(response.attempts, 2);
      expect(response.decodedBody['ok'], isTrue);
      expect(delays, <Duration>[const Duration(seconds: 2)]);
    });

    test('does not retry 401 responses', () async {
      var callCount = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((_) async {
        callCount += 1;
        return http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{'message': 'Invalid API key'},
          }),
          401,
        );
      });

      final policy = OpenAIRequestPolicy(maxRetries: 2, randomDouble: () => 0.5);
      final client = OpenAIHttpClient(
        httpClient: mockClient,
        requestPolicy: policy,
        errorMapper: OpenAIErrorMapper(requestPolicy: policy),
        delay: (delay) async {
          delays.add(delay);
        },
      );

      await expectLater(
        client.postJson(
          uri: Uri.parse('https://api.example.test/v1/responses'),
          headers: const <String, String>{'Authorization': 'Bearer secret-key'},
          payload: const <String, Object?>{'model': 'gpt-4.1-nano'},
          operation: 'test_op',
          model: 'gpt-4.1-nano',
          messageCount: 1,
        ),
        throwsA(
          isA<OpenAIServiceException>()
              .having(
                (error) => error.code,
                'code',
                OpenAIServiceErrorCode.unauthorized,
              )
              .having((error) => error.retryable, 'retryable', isFalse)
              .having((error) => error.attempts, 'attempts', 1),
        ),
      );

      expect(callCount, 1);
      expect(delays, isEmpty);
    });

    test('retries timeout and succeeds on the next attempt', () async {
      var callCount = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((_) async {
        callCount += 1;
        if (callCount == 1) {
          throw TimeoutException('timed out');
        }
        return http.Response(jsonEncode(<String, Object?>{'ok': true}), 200);
      });

      final policy = OpenAIRequestPolicy(
        maxRetries: 1,
        baseBackoff: const Duration(milliseconds: 125),
        maxBackoff: const Duration(milliseconds: 500),
        jitterRatio: 0,
        randomDouble: () => 0.5,
      );
      final client = OpenAIHttpClient(
        httpClient: mockClient,
        requestPolicy: policy,
        errorMapper: OpenAIErrorMapper(requestPolicy: policy),
        delay: (delay) async {
          delays.add(delay);
        },
      );

      final response = await client.postJson(
        uri: Uri.parse('https://api.example.test/v1/responses'),
        headers: const <String, String>{'Authorization': 'Bearer secret-key'},
        payload: const <String, Object?>{'model': 'gpt-4.1-nano'},
        operation: 'test_op',
        model: 'gpt-4.1-nano',
        messageCount: 1,
      );

      expect(callCount, 2);
      expect(response.attempts, 2);
      expect(delays, <Duration>[const Duration(milliseconds: 125)]);
    });

    test('logger output is redacted and does not include body text', () async {
      final logger = _CollectingLogger();
      final mockClient = MockClient((_) async {
        return http.Response(jsonEncode(<String, Object?>{'ok': true}), 200);
      });

      final policy = OpenAIRequestPolicy(maxRetries: 0, randomDouble: () => 0.5);
      final client = OpenAIHttpClient(
        httpClient: mockClient,
        requestPolicy: policy,
        errorMapper: OpenAIErrorMapper(requestPolicy: policy),
        logger: logger,
      );

      await client.postJson(
        uri: Uri.parse('https://api.example.test/v1/responses'),
        headers: const <String, String>{
          'Authorization': 'Bearer sk-secret-value',
          'Content-Type': 'application/json',
        },
        payload: const <String, Object?>{
          'model': 'gpt-4.1-nano',
          'input': 'journal body secret phrase',
        },
        operation: 'test_op',
        model: 'gpt-4.1-nano',
        messageCount: 1,
      );

      final allText = logger.events.map(_flattenToString).join('\n');
      expect(allText, contains('Bearer ***'));
      expect(allText, isNot(contains('sk-secret-value')));
      expect(allText, isNot(contains('journal body secret phrase')));
    });

    test('maps browser-style network errors to actionable guidance', () async {
      final mockClient = MockClient((_) async {
        throw http.ClientException('XMLHttpRequest error.');
      });

      final policy = OpenAIRequestPolicy(maxRetries: 0, randomDouble: () => 0.5);
      final client = OpenAIHttpClient(
        httpClient: mockClient,
        requestPolicy: policy,
        errorMapper: OpenAIErrorMapper(requestPolicy: policy),
      );

      await expectLater(
        client.postJson(
          uri: Uri.parse('https://api.example.test/v1/responses'),
          headers: const <String, String>{'Authorization': 'Bearer secret-key'},
          payload: const <String, Object?>{'model': 'gpt-4.1-nano'},
          operation: 'test_op',
          model: 'gpt-4.1-nano',
          messageCount: 1,
        ),
        throwsA(
          isA<OpenAIServiceException>()
              .having(
                (error) => error.code,
                'code',
                OpenAIServiceErrorCode.network,
              )
              .having(
                (error) => error.message,
                'message',
                contains('CORS'),
              ),
        ),
      );
    });
  });
}

class _CollectingLogger implements OpenAIRedactedLogger {
  final List<OpenAILogEvent> events = <OpenAILogEvent>[];

  @override
  void log(OpenAILogEvent event) {
    events.add(event);
  }
}

String _flattenToString(OpenAILogEvent event) {
  final buffer = StringBuffer(event.name);
  void visit(Object? value) {
    if (value == null) {
      return;
    }
    if (value is Map<Object?, Object?>) {
      for (final entry in value.entries) {
        visit(entry.key);
        visit(entry.value);
      }
      return;
    }
    if (value is Iterable<Object?>) {
      for (final item in value) {
        visit(item);
      }
      return;
    }
    buffer.write(' ');
    buffer.write(value.toString());
  }

  visit(event.data);
  return buffer.toString();
}
