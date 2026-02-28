enum OpenAIApiMode { responses, chatCompletions }

/// Runtime/configuration values for OpenAI cloud access.
class OpenAIConfig {
  const OpenAIConfig({
    this.apiKey = '',
    this.baseUrl = 'https://api.openai.com/v1',
    this.chatModel = 'gpt-4.1-nano',
    this.embeddingModel = 'text-embedding-3-small',
    this.organization,
    this.apiMode = OpenAIApiMode.responses,
    this.maxRetries = 2,
    this.requestTimeoutMs = 25000,
    this.debugLoggingEnabled = false,
  });

  factory OpenAIConfig.fromEnvironment() {
    final organization = const String.fromEnvironment(
      'OPENAI_ORGANIZATION',
      defaultValue: '',
    ).trim();

    return OpenAIConfig(
      apiKey: const String.fromEnvironment('OPENAI_API_KEY', defaultValue: ''),
      baseUrl: const String.fromEnvironment(
        'OPENAI_BASE_URL',
        defaultValue: 'https://api.openai.com/v1',
      ),
      chatModel: const String.fromEnvironment(
        'OPENAI_CHAT_MODEL',
        defaultValue: 'gpt-4.1-nano',
      ),
      embeddingModel: const String.fromEnvironment(
        'OPENAI_EMBEDDING_MODEL',
        defaultValue: 'text-embedding-3-small',
      ),
      organization: organization.isEmpty ? null : organization,
      apiMode: _parseApiMode(
        const String.fromEnvironment(
          'OPENAI_API_MODE',
          defaultValue: 'responses',
        ),
      ),
      maxRetries: _parseIntDefine(
        const String.fromEnvironment('OPENAI_MAX_RETRIES', defaultValue: '2'),
        fallback: 2,
      ),
      requestTimeoutMs: _parseIntDefine(
        const String.fromEnvironment(
          'OPENAI_REQUEST_TIMEOUT_MS',
          defaultValue: '25000',
        ),
        fallback: 25000,
      ),
      debugLoggingEnabled: _parseBoolDefine(
        const String.fromEnvironment(
          'OPENAI_DEBUG_LOGS',
          defaultValue: 'false',
        ),
      ),
    );
  }

  final String apiKey;
  final String baseUrl;
  final String chatModel;
  final String embeddingModel;
  final String? organization;
  final OpenAIApiMode apiMode;
  final int maxRetries;
  final int requestTimeoutMs;
  final bool debugLoggingEnabled;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  Duration get requestTimeout => Duration(milliseconds: requestTimeoutMs);

  static OpenAIApiMode _parseApiMode(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    return switch (normalized) {
      'chat' || 'chatcompletions' || 'chat_completions' || 'chat-completions' =>
        OpenAIApiMode.chatCompletions,
      _ => OpenAIApiMode.responses,
    };
  }

  static int _parseIntDefine(String rawValue, {required int fallback}) {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed < 0) {
      return fallback;
    }
    return parsed;
  }

  static bool _parseBoolDefine(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }
}
