enum AIApiKeyStorageProtection {
  secureStorage,
  localFallback,
  none,
}

class AIApiKeySnapshot {
  const AIApiKeySnapshot({
    required this.apiKey,
    required this.protection,
  });

  final String? apiKey;
  final AIApiKeyStorageProtection protection;

  bool get hasKey => apiKey != null && apiKey!.trim().isNotEmpty;
}

abstract interface class AIApiKeyStore {
  Future<AIApiKeySnapshot> read();

  Future<AIApiKeySnapshot> write(String apiKey);

  Future<AIApiKeySnapshot> clear();
}
