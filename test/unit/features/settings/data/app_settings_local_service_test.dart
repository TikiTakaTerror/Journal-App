import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:ai_journal/features/settings/data/local/app_settings_local_service.dart';
import 'package:ai_journal/features/settings/domain/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettingsLocalService', () {
    test('returns defaults when no settings are stored', () async {
      final service = AppSettingsLocalService(store: _InMemoryKeyValueStore());

      final settings = await service.load();

      expect(settings, const AppSettings());
    });

    test('persists and restores saved settings', () async {
      final store = _InMemoryKeyValueStore();
      final service = AppSettingsLocalService(store: store);
      const expected = AppSettings(
        localOnlyAi: false,
        cloudAiConsent: true,
        notificationsEnabled: true,
        darkMode: true,
      );

      await service.save(expected);

      final restored = await service.load();
      expect(restored, expected);
    });

    test('invalid payload is safely reset to defaults', () async {
      final store = _InMemoryKeyValueStore()
        ..writeStringSync('app_settings_v1', 'malformed');
      final service = AppSettingsLocalService(store: store);

      final settings = await service.load();

      expect(settings, const AppSettings());
      expect(await store.readString('app_settings_v1'), isNull);
    });
  });
}

class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> readString(String key) async => _values[key];

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }

  void writeStringSync(String key, String value) {
    _values[key] = value;
  }
}
