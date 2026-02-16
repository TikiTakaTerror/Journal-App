/// Runtime/configuration values for OpenAI cloud access.
class OpenAIConfig {
  const OpenAIConfig({
    this.apiKey = '',
    this.baseUrl = 'https://api.openai.com/v1',
    this.chatModel = 'gpt-4.1-nano',
    this.embeddingModel = 'text-embedding-3-small',
    this.organization,
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
    );
  }

  final String apiKey;
  final String baseUrl;
  final String chatModel;
  final String embeddingModel;
  final String? organization;

  bool get hasApiKey => apiKey.trim().isNotEmpty;
}
