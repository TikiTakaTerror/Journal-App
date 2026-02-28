import 'dart:math' as math;

import 'package:ai_journal/features/ai/domain/contracts/ai_service.dart';
import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/ai/domain/models/ai_privacy_policy.dart';
import 'package:ai_journal/features/ai/domain/models/ai_request_limits.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_config.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_error_mapper.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_errors.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_http_client.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_redacted_logger.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_request_policy.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:http/http.dart' as http;

export 'package:ai_journal/features/ai/infrastructure/openai/openai_errors.dart'
    show
        OpenAIConfigurationException,
        OpenAIServiceErrorCode,
        OpenAIServiceException;

/// Single cloud adapter responsible for all OpenAI text generation calls.
class OpenAICloudAIService implements AIService {
  OpenAICloudAIService({
    required OpenAIConfig config,
    required AIPrivacyPolicy privacyPolicy,
    AIRequestLimits? limits,
    http.Client? httpClient,
    Duration? timeout,
    OpenAIHttpClient? openAIHttpClient,
    OpenAIRequestPolicy? requestPolicy,
    OpenAIErrorMapper? errorMapper,
    OpenAIRedactedLogger? logger,
  }) : _config = config,
       _privacyPolicy = privacyPolicy,
       _limits = limits ?? AIRequestLimits() {
    if (openAIHttpClient != null) {
      _openAIHttpClient = openAIHttpClient;
      _ownedHttpClient = null;
      return;
    }

    final client = httpClient ?? http.Client();
    _ownedHttpClient = httpClient == null ? client : null;

    final policy =
        requestPolicy ?? OpenAIRequestPolicy(maxRetries: config.maxRetries);
    final mapper = errorMapper ?? OpenAIErrorMapper(requestPolicy: policy);
    final redactedLogger =
        logger ??
        (config.debugLoggingEnabled
            ? const PrintOpenAIRedactedLogger()
            : const NoopOpenAIRedactedLogger());

    _openAIHttpClient = OpenAIHttpClient(
      httpClient: client,
      requestPolicy: policy,
      errorMapper: mapper,
      logger: redactedLogger,
      timeout: timeout ?? config.requestTimeout,
    );
  }

  static const String _jsonContentType = 'application/json';

  final OpenAIConfig _config;
  final AIPrivacyPolicy _privacyPolicy;
  final AIRequestLimits _limits;
  late final OpenAIHttpClient _openAIHttpClient;
  http.Client? _ownedHttpClient;

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

    return _sendTextGeneration(
      operation: 'generate_prompt',
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
      maxOutputTokens: math.min(_limits.maxOutputTokens, 96),
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

    return _sendTextGeneration(
      operation: 'reflect_on_entry',
      messages: <Map<String, String>>[
        const <String, String>{
          'role': 'system',
          'content':
              'You are a thoughtful journaling reflection coach. Keep response concise. '
              'Do not provide medical, legal, or therapy claims.',
        },
        <String, String>{'role': 'user', 'content': userPrompt},
      ],
      temperature: 0.4,
      maxOutputTokens: math.min(_limits.maxOutputTokens, 192),
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
            'You are a calm, practical journaling companion. Use memory context if provided. '
            'Do not present yourself as a therapist or crisis service.',
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

    final answer = await _sendTextGeneration(
      operation: 'chat_with_memory',
      messages: messages,
      temperature: 0.4,
      maxOutputTokens: math.min(_limits.maxOutputTokens, 320),
    );

    return AIChatResponse(
      message: answer,
      memorySummaryUpdated: false,
      updatedMemorySummary: null,
    );
  }

  void dispose() {
    _ownedHttpClient?.close();
  }

  Future<String> _sendTextGeneration({
    required String operation,
    required List<Map<String, String>> messages,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    _privacyPolicy.ensureCloudAllowed();
    if (!_config.hasApiKey) {
      throw const OpenAIConfigurationException(
        'OpenAI API key is missing. Provide it using --dart-define=OPENAI_API_KEY=...',
      );
    }

    return switch (_config.apiMode) {
      OpenAIApiMode.responses => _sendResponsesRequest(
        operation: operation,
        messages: messages,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
      ),
      OpenAIApiMode.chatCompletions => _sendChatCompletionsRequest(
        operation: operation,
        messages: messages,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
      ),
    };
  }

  Future<String> _sendResponsesRequest({
    required String operation,
    required List<Map<String, String>> messages,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    final uri = Uri.parse('${_normalizedBaseUrl(_config.baseUrl)}/responses');
    final response = await _openAIHttpClient.postJson(
      uri: uri,
      headers: _buildHeaders(),
      payload: <String, Object?>{
        'model': _config.chatModel,
        'store': false,
        if (_buildResponsesInstructions(messages).isNotEmpty)
          'instructions': _buildResponsesInstructions(messages),
        'input': _buildResponsesInput(messages),
        'temperature': temperature,
        'max_output_tokens': maxOutputTokens,
      },
      operation: operation,
      model: _config.chatModel,
      messageCount: messages.length,
    );

    return _extractResponsesMessage(
      response.decodedBody,
      attempts: response.attempts,
      statusCode: response.statusCode,
      requestId: response.requestId,
    );
  }

  Future<String> _sendChatCompletionsRequest({
    required String operation,
    required List<Map<String, String>> messages,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    final uri = Uri.parse(
      '${_normalizedBaseUrl(_config.baseUrl)}/chat/completions',
    );
    final response = await _openAIHttpClient.postJson(
      uri: uri,
      headers: _buildHeaders(),
      payload: <String, Object?>{
        'model': _config.chatModel,
        'store': false,
        'messages': messages,
        'max_tokens': maxOutputTokens,
        'temperature': temperature,
      },
      operation: operation,
      model: _config.chatModel,
      messageCount: messages.length,
    );

    return _extractChatCompletionMessage(
      response.decodedBody,
      attempts: response.attempts,
      statusCode: response.statusCode,
      requestId: response.requestId,
    );
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': _jsonContentType,
      'Authorization': 'Bearer ${_config.apiKey.trim()}',
    };

    final organization = _config.organization?.trim();
    if (organization != null && organization.isNotEmpty) {
      headers['OpenAI-Organization'] = organization;
    }

    return headers;
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

  String _extractChatCompletionMessage(
    Map<String, dynamic> decoded, {
    required int attempts,
    required int statusCode,
    required String? requestId,
  }) {
    try {
      final choices = decoded['choices'];
      if (choices is! List<dynamic> || choices.isEmpty) {
        throw _invalidResponse(
          'OpenAI response is missing completion choices.',
          attempts: attempts,
          statusCode: statusCode,
          requestId: requestId,
        );
      }

      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        throw _invalidResponse(
          'OpenAI completion choice is invalid.',
          attempts: attempts,
          statusCode: statusCode,
          requestId: requestId,
        );
      }

      final message = first['message'];
      if (message is! Map<String, dynamic>) {
        throw _invalidResponse(
          'OpenAI completion message is missing.',
          attempts: attempts,
          statusCode: statusCode,
          requestId: requestId,
        );
      }

      final content = message['content'];
      final normalized = _normalizeChatCompletionContent(content).trim();
      if (normalized.isEmpty) {
        throw _invalidResponse(
          'OpenAI completion message content is empty.',
          attempts: attempts,
          statusCode: statusCode,
          requestId: requestId,
        );
      }

      return normalized;
    } on OpenAIServiceException {
      rethrow;
    } catch (_) {
      throw _invalidResponse(
        'Unable to parse OpenAI response body.',
        attempts: attempts,
        statusCode: statusCode,
        requestId: requestId,
      );
    }
  }

  String _extractResponsesMessage(
    Map<String, dynamic> decoded, {
    required int attempts,
    required int statusCode,
    required String? requestId,
  }) {
    try {
      final topLevelOutputText = decoded['output_text'];
      if (topLevelOutputText is String && topLevelOutputText.trim().isNotEmpty) {
        return topLevelOutputText.trim();
      }

      final output = decoded['output'];
      if (output is! List<dynamic> || output.isEmpty) {
        throw _invalidResponse(
          'OpenAI response is missing output content.',
          attempts: attempts,
          statusCode: statusCode,
          requestId: requestId,
        );
      }

      final parts = <String>[];
      for (final item in output) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final content = item['content'];
        if (content is! List<dynamic>) {
          continue;
        }

        for (final segment in content) {
          if (segment is String && segment.trim().isNotEmpty) {
            parts.add(segment.trim());
            continue;
          }

          if (segment is! Map<String, dynamic>) {
            continue;
          }

          final text = segment['text'];
          if (text is String && text.trim().isNotEmpty) {
            parts.add(text.trim());
            continue;
          }

          if (text is Map<String, dynamic>) {
            final value = text['value'];
            if (value is String && value.trim().isNotEmpty) {
              parts.add(value.trim());
            }
          }
        }
      }

      final joined = parts.join('\n').trim();
      if (joined.isEmpty) {
        throw _invalidResponse(
          'OpenAI response output text is empty.',
          attempts: attempts,
          statusCode: statusCode,
          requestId: requestId,
        );
      }

      return joined;
    } on OpenAIServiceException {
      rethrow;
    } catch (_) {
      throw _invalidResponse(
        'Unable to parse OpenAI response body.',
        attempts: attempts,
        statusCode: statusCode,
        requestId: requestId,
      );
    }
  }

  String _normalizeChatCompletionContent(Object? content) {
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
            continue;
          }
          if (text is Map<String, dynamic>) {
            final value = text['value'];
            if (value is String && value.trim().isNotEmpty) {
              parts.add(value);
            }
          }
        }
      }

      return parts.join('\n').trim();
    }

    return '';
  }

  String _buildResponsesInstructions(List<Map<String, String>> messages) {
    final systemMessages = messages
        .where((message) => message['role'] == 'system')
        .map((message) => (message['content'] ?? '').trim())
        .where((content) => content.isNotEmpty)
        .toList(growable: false);

    return systemMessages.join('\n\n').trim();
  }

  List<Map<String, Object?>> _buildResponsesInput(List<Map<String, String>> messages) {
    final input = <Map<String, Object?>>[];

    for (final message in messages) {
      final role = (message['role'] ?? '').trim();
      final content = (message['content'] ?? '').trim();
      if (role.isEmpty || content.isEmpty || role == 'system') {
        continue;
      }

      input.add(<String, Object?>{'role': role, 'content': content});
    }

    if (input.isNotEmpty) {
      return input;
    }

    return <Map<String, Object?>>[
      const <String, Object?>{'role': 'user', 'content': 'Hello.'},
    ];
  }

  OpenAIServiceException _invalidResponse(
    String message, {
    required int attempts,
    required int statusCode,
    required String? requestId,
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

  static String _normalizedBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    if (normalized.endsWith('/')) {
      return normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }
}
