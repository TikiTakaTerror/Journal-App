import 'dart:async';
import 'dart:convert';

import 'package:ai_journal/features/ai/domain/contracts/ai_service.dart';
import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/ai/domain/models/ai_privacy_policy.dart';
import 'package:ai_journal/features/ai/domain/models/ai_request_limits.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_config.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';

/// Raised when OpenAI is requested without valid runtime configuration.
class OpenAIConfigurationException implements Exception {
  const OpenAIConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'OpenAIConfigurationException: $message';
}

/// Raised when a cloud request fails or returns malformed data.
class OpenAIServiceException implements Exception {
  const OpenAIServiceException(this.message);

  final String message;

  @override
  String toString() => 'OpenAIServiceException: $message';
}

/// Single cloud adapter responsible for all OpenAI chat-completion calls.
class OpenAICloudAIService implements AIService {
  OpenAICloudAIService({
    required OpenAIConfig config,
    required AIPrivacyPolicy privacyPolicy,
    AIRequestLimits? limits,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 25),
  }) : _config = config,
       _privacyPolicy = privacyPolicy,
       _limits = limits ?? AIRequestLimits(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _timeout = timeout;

  static const String _jsonContentType = 'application/json';

  final OpenAIConfig _config;
  final AIPrivacyPolicy _privacyPolicy;
  final AIRequestLimits _limits;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration _timeout;

  @override
  Future<String> generatePrompt(AISmartPromptRequest request) async {
    final themes = request.recentThemes.isEmpty
        ? 'none'
        : request.recentThemes.join(', ');

    final buffer =
        StringBuffer('Generate one concise journaling prompt (one sentence).')
          ..writeln()
          ..write('Recent themes: $themes.');

    final moodHint = request.moodHint?.trim();
    if (moodHint != null && moodHint.isNotEmpty) {
      buffer
        ..writeln()
        ..write('Mood hint: $moodHint.');
    }

    final writingGoal = request.writingGoal?.trim();
    if (writingGoal != null && writingGoal.isNotEmpty) {
      buffer
        ..writeln()
        ..write('Writing goal: $writingGoal.');
    }

    return _sendChatCompletion(
      messages: <Map<String, String>>[
        const <String, String>{
          'role': 'system',
          'content':
              'You are a privacy-first journaling assistant. Return a single supportive prompt.',
        },
        <String, String>{
          'role': 'user',
          'content': _limits.clipInput(buffer.toString()),
        },
      ],
      temperature: 0.8,
    );
  }

  @override
  Future<String> reflectOnEntry(AIReflectionRequest request) async {
    final entry = request.entry;
    final tags = entry.tags.isEmpty ? 'none' : entry.tags.join(', ');

    final userPrompt = _limits.clipInput(
      'Provide a short, compassionate reflection for this journal entry. '
      'Focus on patterns, strengths, and one practical next step. '
      'Title: ${entry.title}. Tags: $tags. Content: ${entry.content}',
    );

    return _sendChatCompletion(
      messages: <Map<String, String>>[
        const <String, String>{
          'role': 'system',
          'content':
              'You are a thoughtful journaling reflection coach. Keep response concise.',
        },
        <String, String>{'role': 'user', 'content': userPrompt},
      ],
      temperature: 0.4,
    );
  }

  @override
  Future<AIChatResponse> chatWithMemory(AIChatRequest request) async {
    final trimmedHistory = _limits.trimChatHistory(request.chatHistory);
    final limitedEntries = _limits.limitRetrievedEntries(
      request.relevantEntries,
    );

    final messages = <Map<String, String>>[
      const <String, String>{
        'role': 'system',
        'content':
            'You are a calm, practical journaling companion. Use memory context if provided.',
      },
    ];

    final memoryContext = _buildMemoryContext(
      memorySummary: request.memorySummary,
      entries: limitedEntries,
    );
    if (memoryContext.isNotEmpty) {
      messages.add(<String, String>{
        'role': 'system',
        'content': _limits.clipInput(memoryContext),
      });
    }

    for (final message in trimmedHistory) {
      messages.add(<String, String>{
        'role': _toOpenAIRole(message.role),
        'content': _limits.clipInput(message.content),
      });
    }

    messages.add(<String, String>{
      'role': 'user',
      'content': _limits.clipInput(request.userMessage),
    });

    final answer = await _sendChatCompletion(
      messages: messages,
      temperature: 0.4,
    );

    return AIChatResponse(
      message: answer,
      memorySummaryUpdated: false,
      updatedMemorySummary: null,
    );
  }

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<String> _sendChatCompletion({
    required List<Map<String, String>> messages,
    required double temperature,
  }) async {
    _privacyPolicy.ensureCloudAllowed();
    if (!_config.hasApiKey) {
      throw const OpenAIConfigurationException(
        'OpenAI API key is missing. Provide it using --dart-define=OPENAI_API_KEY=...',
      );
    }

    final uri = Uri.parse(
      '${_normalizedBaseUrl(_config.baseUrl)}/chat/completions',
    );
    final headers = <String, String>{
      'Content-Type': _jsonContentType,
      'Authorization': 'Bearer ${_config.apiKey.trim()}',
    };

    final organization = _config.organization?.trim();
    if (organization != null && organization.isNotEmpty) {
      headers['OpenAI-Organization'] = organization;
    }

    final payload = <String, Object?>{
      'model': _config.chatModel,
      'messages': messages,
      'max_tokens': _limits.maxOutputTokens,
      'temperature': temperature,
    };

    try {
      final response = await retry(
        () async {
          final res = await _httpClient
              .post(uri, headers: headers, body: jsonEncode(payload))
              .timeout(_timeout);

          if (res.statusCode >= 500 || res.statusCode == 429) {
            // These are generally transient or rate-limiting errors we can retry.
            throw _TransientHttpException(res.statusCode);
          }

          if (res.statusCode < 200 || res.statusCode >= 300) {
            // Unrecoverable errors (400, 401, 403, 404, etc.)
            throw OpenAIServiceException(
              _extractErrorMessage(res.body, res.statusCode),
            );
          }

          return res;
        },
        retryIf: (e) =>
            e is TimeoutException ||
            e is http.ClientException ||
            e is _TransientHttpException,
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 5),
      );

      return _extractAssistantMessage(response.body);
    } on TimeoutException {
      throw const OpenAIServiceException('OpenAI request timed out.');
    } on OpenAIServiceException {
      rethrow; // Pass through our unrecoverable errors directly.
    } on _TransientHttpException {
      throw const OpenAIServiceException(
        'OpenAI service is currently overloaded or down.',
      );
    } catch (e) {
      throw const OpenAIServiceException(
        'OpenAI request failed before receiving a response.',
      );
    }
  }

  String _buildMemoryContext({
    required String memorySummary,
    required List<JournalEntry> entries,
  }) {
    final buffer = StringBuffer();
    final summary = memorySummary.trim();

    if (summary.isNotEmpty) {
      buffer
        ..writeln('Memory summary:')
        ..writeln(summary)
        ..writeln();
    }

    if (entries.isNotEmpty) {
      buffer.writeln('Relevant journal entries:');
      for (final entry in entries) {
        buffer
          ..writeln('- ${entry.title}: ${entry.content}')
          ..writeln();
      }
    }

    return buffer.toString().trim();
  }

  String _toOpenAIRole(AIChatRole role) {
    return switch (role) {
      AIChatRole.system => 'system',
      AIChatRole.user => 'user',
      AIChatRole.assistant => 'assistant',
    };
  }

  String _extractAssistantMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const OpenAIServiceException(
          'Unexpected OpenAI response format.',
        );
      }

      final choices = decoded['choices'];
      if (choices is! List<dynamic> || choices.isEmpty) {
        throw const OpenAIServiceException(
          'OpenAI response is missing completion choices.',
        );
      }

      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        throw const OpenAIServiceException(
          'OpenAI completion choice is invalid.',
        );
      }

      final message = first['message'];
      if (message is! Map<String, dynamic>) {
        throw const OpenAIServiceException(
          'OpenAI completion message is missing.',
        );
      }

      final content = message['content'];
      final normalized = _normalizeContent(content).trim();
      if (normalized.isEmpty) {
        throw const OpenAIServiceException(
          'OpenAI completion message content is empty.',
        );
      }

      return normalized;
    } on OpenAIServiceException {
      rethrow;
    } catch (_) {
      throw const OpenAIServiceException(
        'Unable to parse OpenAI response body.',
      );
    }
  }

  String _normalizeContent(Object? content) {
    if (content is String) {
      return content;
    }

    if (content is List<dynamic>) {
      final parts = <String>[];
      for (final segment in content) {
        if (segment is String) {
          parts.add(segment);
          continue;
        }

        if (segment is Map<String, dynamic>) {
          final text = segment['text'];
          if (text is String && text.trim().isNotEmpty) {
            parts.add(text);
          }
        }
      }

      return parts.join('\n').trim();
    }

    return '';
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
      // Best effort parsing only.
    }

    return 'OpenAI request failed with status $statusCode.';
  }

  static String _normalizedBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    if (normalized.endsWith('/')) {
      return normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }
}

class _TransientHttpException implements Exception {
  const _TransientHttpException(this.statusCode);

  final int statusCode;

  @override
  String toString() => '_TransientHttpException: $statusCode';
}
