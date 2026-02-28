import 'dart:convert';

import 'package:ai_journal/features/ai/infrastructure/openai/openai_errors.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_request_policy.dart';
import 'package:http/http.dart' as http;

class OpenAIErrorMapper {
  OpenAIErrorMapper({required OpenAIRequestPolicy requestPolicy})
    : _requestPolicy = requestPolicy;

  final OpenAIRequestPolicy _requestPolicy;

  OpenAIServiceException timeout({required int attempts}) {
    return OpenAIServiceException(
      'OpenAI request timed out.',
      code: OpenAIServiceErrorCode.timeout,
      retryable: true,
      attempts: attempts,
    );
  }

  OpenAIServiceException network({required int attempts}) {
    return networkWithCause(attempts: attempts, cause: null);
  }

  OpenAIServiceException networkWithCause({
    required int attempts,
    required Object? cause,
  }) {
    final causeText = cause?.toString().toLowerCase() ?? '';
    final message = _networkMessageForCause(causeText);
    return OpenAIServiceException(
      message,
      code: OpenAIServiceErrorCode.network,
      retryable: true,
      attempts: attempts,
    );
  }

  OpenAIServiceException invalidResponse({
    required int attempts,
    int? statusCode,
    String? requestId,
    String message = 'Unable to parse OpenAI response body.',
  }) {
    return OpenAIServiceException(
      message,
      code: OpenAIServiceErrorCode.invalidResponse,
      retryable: false,
      statusCode: statusCode,
      requestId: requestId,
      attempts: attempts,
    );
  }

  OpenAIServiceException fromHttpResponse({
    required http.Response response,
    required int attempts,
  }) {
    final statusCode = response.statusCode;
    final requestId = _headerValue(response.headers, 'x-request-id');
    final retryable = _requestPolicy.isRetryableStatus(statusCode);
    final message = _extractErrorMessage(response.body, statusCode);
    return OpenAIServiceException(
      message,
      code: _mapStatusCode(statusCode),
      retryable: retryable,
      statusCode: statusCode,
      requestId: requestId,
      attempts: attempts,
    );
  }

  OpenAIServiceErrorCode _mapStatusCode(int statusCode) {
    if (statusCode == 400) {
      return OpenAIServiceErrorCode.invalidRequest;
    }
    if (statusCode == 401) {
      return OpenAIServiceErrorCode.unauthorized;
    }
    if (statusCode == 403) {
      return OpenAIServiceErrorCode.forbidden;
    }
    if (statusCode == 404) {
      return OpenAIServiceErrorCode.notFound;
    }
    if (statusCode == 409) {
      return OpenAIServiceErrorCode.conflict;
    }
    if (statusCode == 429) {
      return OpenAIServiceErrorCode.rateLimited;
    }
    if (statusCode >= 500 && statusCode <= 599) {
      return OpenAIServiceErrorCode.server;
    }
    return OpenAIServiceErrorCode.unknown;
  }

  String _extractErrorMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
      }
    } catch (_) {
      // Best-effort parsing only.
    }

    return 'OpenAI request failed with status $statusCode.';
  }

  static String? _headerValue(Map<String, String> headers, String target) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  String _networkMessageForCause(String causeText) {
    if (causeText.contains('xmlhttprequest error') ||
        causeText.contains('failed to fetch') ||
        causeText.contains('cors')) {
      return 'OpenAI request failed in the browser before receiving a response. '
          'If you are running on web, direct cloud calls can be blocked by CORS. '
          'Try iOS/Android/desktop or a backend proxy.';
    }

    if (causeText.contains('failed host lookup') ||
        causeText.contains('name or service not known')) {
      return 'OpenAI request failed before receiving a response (DNS lookup failed). '
          'Check internet access and OPENAI_BASE_URL.';
    }

    return 'OpenAI request failed before receiving a response.';
  }
}
