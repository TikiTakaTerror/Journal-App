import 'dart:async';
import 'dart:convert';

import 'package:ai_journal/features/ai/infrastructure/openai/openai_error_mapper.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_errors.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_redacted_logger.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_request_policy.dart';
import 'package:http/http.dart' as http;

typedef OpenAIDelayFn = Future<void> Function(Duration delay);

class OpenAIHttpJsonResponse {
  const OpenAIHttpJsonResponse({
    required this.decodedBody,
    required this.statusCode,
    required this.headers,
    required this.requestId,
    required this.attempts,
  });

  final Map<String, dynamic> decodedBody;
  final int statusCode;
  final Map<String, String> headers;
  final String? requestId;
  final int attempts;
}

class OpenAIHttpClient {
  OpenAIHttpClient({
    required http.Client httpClient,
    required OpenAIRequestPolicy requestPolicy,
    required OpenAIErrorMapper errorMapper,
    OpenAIRedactedLogger? logger,
    Duration timeout = const Duration(seconds: 25),
    OpenAIDelayFn? delay,
  }) : _httpClient = httpClient,
       _requestPolicy = requestPolicy,
       _errorMapper = errorMapper,
       _logger = logger ?? const NoopOpenAIRedactedLogger(),
       _timeout = timeout,
       _delay = delay ?? _defaultDelay;

  final http.Client _httpClient;
  final OpenAIRequestPolicy _requestPolicy;
  final OpenAIErrorMapper _errorMapper;
  final OpenAIRedactedLogger _logger;
  final Duration _timeout;
  final OpenAIDelayFn _delay;

  Future<OpenAIHttpJsonResponse> postJson({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, Object?> payload,
    required String operation,
    required String model,
    required int messageCount,
  }) async {
    final body = jsonEncode(payload);
    final payloadBytes = utf8.encode(body).length;
    final redactedHeaders = _redactHeaders(headers);

    for (var attempt = 1; ; attempt++) {
      final stopwatch = Stopwatch()..start();
      _logger.log(
        OpenAILogEvent(
          name: 'openai.request.start',
          data: <String, Object?>{
            'operation': operation,
            'endpoint': uri.path,
            'model': model,
            'attempt': attempt,
            'timeout_ms': _timeout.inMilliseconds,
            'payload_bytes': payloadBytes,
            'message_count': messageCount,
            'headers': redactedHeaders,
          },
        ),
      );

      http.Response response;
      try {
        response = await _httpClient
            .post(uri, headers: headers, body: body)
            .timeout(_timeout);
      } on TimeoutException {
        stopwatch.stop();
        final error = _errorMapper.timeout(attempts: attempt);
        if (_requestPolicy.canRetryAfterAttempt(attempt)) {
          final delay = _requestPolicy.retryDelayForAttempt(attempt: attempt);
          _logger.log(
            OpenAILogEvent(
              name: 'openai.request.retry',
              data: <String, Object?>{
                'operation': operation,
                'endpoint': uri.path,
                'attempt': attempt,
                'next_attempt': attempt + 1,
                'delay_ms': delay.inMilliseconds,
                'reason': error.code.name,
                'latency_ms': stopwatch.elapsedMilliseconds,
              },
            ),
          );
          await _delay(delay);
          continue;
        }

        _logger.log(
          OpenAILogEvent(
            name: 'openai.request.failure',
            data: <String, Object?>{
              'operation': operation,
              'endpoint': uri.path,
              'attempt': attempt,
              'reason': error.code.name,
              'latency_ms': stopwatch.elapsedMilliseconds,
            },
          ),
        );
        throw error;
      } on Exception catch (error) {
        stopwatch.stop();
        final mappedError = _errorMapper.networkWithCause(
          attempts: attempt,
          cause: error,
        );
        if (_requestPolicy.canRetryAfterAttempt(attempt)) {
          final delay = _requestPolicy.retryDelayForAttempt(attempt: attempt);
          _logger.log(
            OpenAILogEvent(
              name: 'openai.request.retry',
              data: <String, Object?>{
                'operation': operation,
                'endpoint': uri.path,
                'attempt': attempt,
                'next_attempt': attempt + 1,
                'delay_ms': delay.inMilliseconds,
                'reason': mappedError.code.name,
                'latency_ms': stopwatch.elapsedMilliseconds,
                'error_type': error.runtimeType.toString(),
                'error_message': error.toString(),
              },
            ),
          );
          await _delay(delay);
          continue;
        }

        _logger.log(
          OpenAILogEvent(
            name: 'openai.request.failure',
            data: <String, Object?>{
              'operation': operation,
              'endpoint': uri.path,
              'attempt': attempt,
              'reason': mappedError.code.name,
              'latency_ms': stopwatch.elapsedMilliseconds,
              'error_type': error.runtimeType.toString(),
              'error_message': error.toString(),
            },
          ),
        );
        throw mappedError;
      }

      stopwatch.stop();
      final requestId = _headerValue(response.headers, 'x-request-id');
      _logger.log(
        OpenAILogEvent(
          name: 'openai.request.response',
          data: <String, Object?>{
            'operation': operation,
            'endpoint': uri.path,
            'attempt': attempt,
            'status_code': response.statusCode,
            'latency_ms': stopwatch.elapsedMilliseconds,
            'request_id': requestId,
            'response_bytes': utf8.encode(response.body).length,
          },
        ),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = _errorMapper.fromHttpResponse(
          response: response,
          attempts: attempt,
        );
        if (error.retryable && _requestPolicy.canRetryAfterAttempt(attempt)) {
          final delay = _requestPolicy.retryDelayForAttempt(
            attempt: attempt,
            responseHeaders: response.headers,
          );
          _logger.log(
            OpenAILogEvent(
              name: 'openai.request.retry',
              data: <String, Object?>{
                'operation': operation,
                'endpoint': uri.path,
                'attempt': attempt,
                'next_attempt': attempt + 1,
                'delay_ms': delay.inMilliseconds,
                'reason': error.code.name,
                'status_code': response.statusCode,
                'request_id': requestId,
              },
            ),
          );
          await _delay(delay);
          continue;
        }
        throw error;
      }

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw _errorMapper.invalidResponse(
            attempts: attempt,
            statusCode: response.statusCode,
            requestId: requestId,
            message: 'Unexpected OpenAI response format.',
          );
        }

        return OpenAIHttpJsonResponse(
          decodedBody: decoded,
          statusCode: response.statusCode,
          headers: Map<String, String>.unmodifiable(response.headers),
          requestId: requestId,
          attempts: attempt,
        );
      } on OpenAIServiceException {
        rethrow;
      } catch (_) {
        throw _errorMapper.invalidResponse(
          attempts: attempt,
          statusCode: response.statusCode,
          requestId: requestId,
        );
      }
    }
  }

  static Future<void> _defaultDelay(Duration delay) {
    return Future<void>.delayed(delay);
  }

  static Map<String, String> _redactHeaders(Map<String, String> headers) {
    final redacted = <String, String>{};
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        redacted[entry.key] = 'Bearer ***';
        continue;
      }
      redacted[entry.key] = entry.value;
    }
    return Map<String, String>.unmodifiable(redacted);
  }

  static String? _headerValue(Map<String, String> headers, String target) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }
}
