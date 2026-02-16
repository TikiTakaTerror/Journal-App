import 'dart:convert';

import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:ai_journal/features/settings/domain/models/app_settings.dart';

class AppSettingsLocalService {
  AppSettingsLocalService({required KeyValueStore store}) : _store = store;

  static const String _storageKey = 'app_settings_v1';
  final KeyValueStore _store;

  Future<AppSettings> load() async {
    final raw = await _store.readString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const AppSettings();
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromMap(
        decoded.map((key, value) => MapEntry<String, Object?>(key, value)),
      );
    } catch (_) {
      await _store.remove(_storageKey);
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) {
    return _store.writeString(_storageKey, jsonEncode(settings.toMap()));
  }
}
