import 'package:ai_journal/features/ai/domain/contracts/ai_api_key_store.dart';
import 'package:ai_journal/features/ai/presentation/state/openai_api_key_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenAIApiKeyController', () {
    test('defaults to dev override while loading and prefers stored key after load', () async {
      final store = _FakeAIApiKeyStore(
        readSnapshot: const AIApiKeySnapshot(
          apiKey: 'sk-stored',
          protection: AIApiKeyStorageProtection.secureStorage,
        ),
      );

      final controller = OpenAIApiKeyController(
        store: store,
        devFallbackApiKey: 'sk-dev',
      );

      expect(controller.state.usingDevOverride, isTrue);
      expect(controller.state.hasKey, isTrue);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.usingStoredKey, isTrue);
      expect(controller.state.resolvedApiKey, 'sk-stored');
      expect(controller.state.storageProtection, AIApiKeyStorageProtection.secureStorage);
    });

    test('saveKey stores key and updates source', () async {
      final store = _FakeAIApiKeyStore(
        writeSnapshot: const AIApiKeySnapshot(
          apiKey: 'sk-new',
          protection: AIApiKeyStorageProtection.localFallback,
        ),
      );
      final controller = OpenAIApiKeyController(
        store: store,
        devFallbackApiKey: '',
      );

      await Future<void>.delayed(Duration.zero);
      await controller.saveKey('sk-new');

      expect(controller.state.usingStoredKey, isTrue);
      expect(controller.state.resolvedApiKey, 'sk-new');
      expect(controller.state.storageProtection, AIApiKeyStorageProtection.localFallback);
      expect(store.lastWrittenKey, 'sk-new');
    });

    test('removeKey falls back to dev override when available', () async {
      final store = _FakeAIApiKeyStore(
        readSnapshot: const AIApiKeySnapshot(
          apiKey: 'sk-stored',
          protection: AIApiKeyStorageProtection.secureStorage,
        ),
        clearSnapshot: const AIApiKeySnapshot(
          apiKey: null,
          protection: AIApiKeyStorageProtection.none,
        ),
      );
      final controller = OpenAIApiKeyController(
        store: store,
        devFallbackApiKey: 'sk-dev',
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await controller.removeKey();

      expect(controller.state.usingDevOverride, isTrue);
      expect(controller.state.resolvedApiKey, 'sk-dev');
      expect(store.clearCalled, isTrue);
    });
  });
}

class _FakeAIApiKeyStore implements AIApiKeyStore {
  _FakeAIApiKeyStore({
    AIApiKeySnapshot? readSnapshot,
    AIApiKeySnapshot? writeSnapshot,
    AIApiKeySnapshot? clearSnapshot,
  }) : _readSnapshot = readSnapshot ??
            const AIApiKeySnapshot(
              apiKey: null,
              protection: AIApiKeyStorageProtection.none,
            ),
       _writeSnapshot = writeSnapshot ??
            const AIApiKeySnapshot(
              apiKey: 'sk-write',
              protection: AIApiKeyStorageProtection.secureStorage,
            ),
       _clearSnapshot = clearSnapshot ??
            const AIApiKeySnapshot(
              apiKey: null,
              protection: AIApiKeyStorageProtection.none,
            );

  final AIApiKeySnapshot _readSnapshot;
  final AIApiKeySnapshot _writeSnapshot;
  final AIApiKeySnapshot _clearSnapshot;
  bool clearCalled = false;
  String? lastWrittenKey;

  @override
  Future<AIApiKeySnapshot> clear() async {
    clearCalled = true;
    return _clearSnapshot;
  }

  @override
  Future<AIApiKeySnapshot> read() async => _readSnapshot;

  @override
  Future<AIApiKeySnapshot> write(String apiKey) async {
    lastWrittenKey = apiKey;
    return _writeSnapshot;
  }
}
