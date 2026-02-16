import 'dart:async';

import 'package:ai_journal/features/settings/data/local/app_settings_local_service.dart';
import 'package:ai_journal/features/settings/domain/models/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController({required AppSettingsLocalService service})
    : _service = service,
      super(const AppSettings()) {
    unawaited(_load());
  }

  final AppSettingsLocalService _service;

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> toggleDarkMode() async {
    state = state.copyWith(darkMode: !state.darkMode);
    await _service.save(state);
  }

  Future<void> setLocalOnlyAi(bool value) async {
    state = state.copyWith(
      localOnlyAi: value,
      cloudAiConsent: value ? false : state.cloudAiConsent,
    );
    await _service.save(state);
  }

  Future<void> setCloudAiConsent(bool value) async {
    if (value && state.localOnlyAi) {
      return;
    }

    state = state.copyWith(cloudAiConsent: value);
    await _service.save(state);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _service.save(state);
  }
}
