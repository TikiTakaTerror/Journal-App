import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:ai_journal/features/settings/data/local/app_settings_local_service.dart';
import 'package:ai_journal/features/settings/presentation/state/app_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettingsController', () {
    test('loads persisted settings on startup', () async {
      final store = _InMemoryKeyValueStore()
        ..writeStringSync(
          'app_settings_v1',
          '{"localOnlyAi":false,"cloudAiConsent":true,"notificationsEnabled":true,"darkMode":true}',
        );
      final controller = AppSettingsController(
        service: AppSettingsLocalService(store: store),
      );

      await _flushAsync();

      expect(controller.state.localOnlyAi, isFalse);
      expect(controller.state.cloudAiConsent, isTrue);
      expect(controller.state.notificationsEnabled, isTrue);
      expect(controller.state.darkMode, isTrue);
    });

    test('toggleDarkMode updates and persists', () async {
      final store = _InMemoryKeyValueStore();
      final service = AppSettingsLocalService(store: store);
      final controller = AppSettingsController(service: service);

      await _flushAsync();
      await controller.toggleDarkMode();

      expect(controller.state.darkMode, isTrue);

      final restored = AppSettingsController(service: service);
      await _flushAsync();
      expect(restored.state.darkMode, isTrue);
    });

    test(
      'cannot enable cloud consent while local-only AI is enabled',
      () async {
        final controller = AppSettingsController(
          service: AppSettingsLocalService(store: _InMemoryKeyValueStore()),
        );

        await _flushAsync();
        await controller.setCloudAiConsent(true);

        expect(controller.state.localOnlyAi, isTrue);
        expect(controller.state.cloudAiConsent, isFalse);
      },
    );

    test('enabling local-only AI turns cloud consent off', () async {
      final controller = AppSettingsController(
        service: AppSettingsLocalService(store: _InMemoryKeyValueStore()),
      );

      await _flushAsync();
      await controller.setLocalOnlyAi(false);
      await controller.setCloudAiConsent(true);
      expect(controller.state.cloudAiConsent, isTrue);

      await controller.setLocalOnlyAi(true);

      expect(controller.state.localOnlyAi, isTrue);
      expect(controller.state.cloudAiConsent, isFalse);
    });

    test('notifications flag updates and persists', () async {
      final store = _InMemoryKeyValueStore();
      final service = AppSettingsLocalService(store: store);
      final controller = AppSettingsController(service: service);

      await _flushAsync();
      await controller.setNotificationsEnabled(true);
      expect(controller.state.notificationsEnabled, isTrue);

      final restored = AppSettingsController(service: service);
      await _flushAsync();
      expect(restored.state.notificationsEnabled, isTrue);
    });
  });
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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
