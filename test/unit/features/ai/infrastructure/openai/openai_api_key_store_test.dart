import 'package:ai_journal/features/ai/domain/contracts/ai_api_key_store.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_api_key_store.dart';
import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenAIApiKeyStore', () {
    test('writes and reads using secure storage when available', () async {
      final secure = _FakeSecretStringStore();
      final fallback = _InMemoryKeyValueStore();
      final store = OpenAIApiKeyStore(
        fallbackStore: fallback,
        secureStore: secure,
      );

      final written = await store.write(' sk-test-key ');
      expect(written.protection, AIApiKeyStorageProtection.secureStorage);
      expect(written.apiKey, 'sk-test-key');
      expect(await fallback.readString('openai_api_key_fallback_v1'), isNull);

      final loaded = await store.read();
      expect(loaded.hasKey, isTrue);
      expect(loaded.protection, AIApiKeyStorageProtection.secureStorage);
      expect(loaded.apiKey, 'sk-test-key');
    });

    test('falls back to local store when secure storage throws', () async {
      final secure = _FakeSecretStringStore(
        throwOnWrite: true,
        throwOnRead: true,
      );
      final fallback = _InMemoryKeyValueStore();
      final store = OpenAIApiKeyStore(
        fallbackStore: fallback,
        secureStore: secure,
      );

      final written = await store.write('sk-fallback');
      expect(written.protection, AIApiKeyStorageProtection.localFallback);

      final loaded = await store.read();
      expect(loaded.hasKey, isTrue);
      expect(loaded.protection, AIApiKeyStorageProtection.localFallback);
      expect(loaded.apiKey, 'sk-fallback');
    });

    test('clear removes stored keys from both backends', () async {
      final secure = _FakeSecretStringStore()..values['openai_api_key_v1'] = 'sk1';
      final fallback = _InMemoryKeyValueStore()
        ..values['openai_api_key_fallback_v1'] = 'sk2';
      final store = OpenAIApiKeyStore(
        fallbackStore: fallback,
        secureStore: secure,
      );

      final cleared = await store.clear();

      expect(cleared.hasKey, isFalse);
      expect(secure.values, isEmpty);
      expect(fallback.values, isEmpty);
    });
  });
}

class _FakeSecretStringStore implements SecretStringStore {
  _FakeSecretStringStore({
    this.throwOnRead = false,
    this.throwOnWrite = false,
  });

  final Map<String, String> values = <String, String>{};
  final bool throwOnRead;
  final bool throwOnWrite;
  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    if (throwOnRead) {
      throw Exception('read failed');
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (throwOnWrite) {
      throw Exception('write failed');
    }
    values[key] = value;
  }
}

class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}
