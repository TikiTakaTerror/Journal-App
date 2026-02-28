import 'package:ai_journal/features/ai/domain/contracts/ai_api_key_store.dart';
import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecretStringStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureSecretStringStore implements SecretStringStore {
  FlutterSecureSecretStringStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class OpenAIApiKeyStore implements AIApiKeyStore {
  OpenAIApiKeyStore({
    required KeyValueStore fallbackStore,
    SecretStringStore? secureStore,
  }) : _fallbackStore = fallbackStore,
       _secureStore = secureStore ?? FlutterSecureSecretStringStore();

  static const String _secureKey = 'openai_api_key_v1';
  static const String _fallbackKey = 'openai_api_key_fallback_v1';

  final KeyValueStore _fallbackStore;
  final SecretStringStore _secureStore;

  @override
  Future<AIApiKeySnapshot> read() async {
    final secure = await _safeReadSecure();
    if (secure != null) {
      final normalized = _normalizeKey(secure);
      if (normalized != null) {
        return AIApiKeySnapshot(
          apiKey: normalized,
          protection: AIApiKeyStorageProtection.secureStorage,
        );
      }
    }

    final fallback = await _safeReadFallback();
    final normalizedFallback = _normalizeKey(fallback);
    return AIApiKeySnapshot(
      apiKey: normalizedFallback,
      protection: normalizedFallback == null
          ? AIApiKeyStorageProtection.none
          : AIApiKeyStorageProtection.localFallback,
    );
  }

  @override
  Future<AIApiKeySnapshot> write(String apiKey) async {
    final normalized = _normalizeKey(apiKey);
    if (normalized == null) {
      throw const FormatException('API key cannot be empty.');
    }

    final wroteSecure = await _safeWriteSecure(normalized);
    if (wroteSecure) {
      await _safeDeleteFallback();
      return AIApiKeySnapshot(
        apiKey: normalized,
        protection: AIApiKeyStorageProtection.secureStorage,
      );
    }

    await _fallbackStore.writeString(_fallbackKey, normalized);
    return AIApiKeySnapshot(
      apiKey: normalized,
      protection: AIApiKeyStorageProtection.localFallback,
    );
  }

  @override
  Future<AIApiKeySnapshot> clear() async {
    await _safeDeleteSecure();
    await _safeDeleteFallback();
    return const AIApiKeySnapshot(
      apiKey: null,
      protection: AIApiKeyStorageProtection.none,
    );
  }

  Future<String?> _safeReadSecure() async {
    try {
      return await _secureStore.read(_secureKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _safeReadFallback() async {
    try {
      return await _fallbackStore.readString(_fallbackKey);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _safeWriteSecure(String value) async {
    try {
      await _secureStore.write(_secureKey, value);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _safeDeleteSecure() async {
    try {
      await _secureStore.delete(_secureKey);
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  Future<void> _safeDeleteFallback() async {
    try {
      await _fallbackStore.remove(_fallbackKey);
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  String? _normalizeKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
