import 'dart:async';

import 'package:ai_journal/features/ai/domain/contracts/ai_api_key_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OpenAIApiKeySource { none, storedLocal, devOverride }

class OpenAIApiKeyState {
  const OpenAIApiKeyState({
    this.isLoading = false,
    this.isSaving = false,
    this.resolvedApiKey,
    this.source = OpenAIApiKeySource.none,
    this.storageProtection = AIApiKeyStorageProtection.none,
    this.errorMessage,
    this.devOverrideAvailable = false,
  });

  final bool isLoading;
  final bool isSaving;
  final String? resolvedApiKey;
  final OpenAIApiKeySource source;
  final AIApiKeyStorageProtection storageProtection;
  final String? errorMessage;
  final bool devOverrideAvailable;

  bool get hasKey => resolvedApiKey != null && resolvedApiKey!.trim().isNotEmpty;
  bool get usingStoredKey => source == OpenAIApiKeySource.storedLocal;
  bool get usingDevOverride => source == OpenAIApiKeySource.devOverride;

  String? get maskedPreview {
    final value = resolvedApiKey?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length <= 10) {
      return '${value.substring(0, 2)}***';
    }
    return '${value.substring(0, 6)}***${value.substring(value.length - 4)}';
  }

  OpenAIApiKeyState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? resolvedApiKey,
    bool clearResolvedApiKey = false,
    OpenAIApiKeySource? source,
    AIApiKeyStorageProtection? storageProtection,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? devOverrideAvailable,
  }) {
    return OpenAIApiKeyState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      resolvedApiKey: clearResolvedApiKey
          ? null
          : (resolvedApiKey ?? this.resolvedApiKey),
      source: source ?? this.source,
      storageProtection: storageProtection ?? this.storageProtection,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      devOverrideAvailable: devOverrideAvailable ?? this.devOverrideAvailable,
    );
  }
}

class OpenAIApiKeyController extends StateNotifier<OpenAIApiKeyState> {
  OpenAIApiKeyController({
    required AIApiKeyStore store,
    required String devFallbackApiKey,
  }) : _store = store,
       _devFallbackApiKey = devFallbackApiKey.trim(),
       super(
         OpenAIApiKeyState(
           isLoading: true,
           devOverrideAvailable: devFallbackApiKey.trim().isNotEmpty,
           resolvedApiKey: devFallbackApiKey.trim().isNotEmpty
               ? devFallbackApiKey.trim()
               : null,
           source: devFallbackApiKey.trim().isNotEmpty
               ? OpenAIApiKeySource.devOverride
               : OpenAIApiKeySource.none,
         ),
       ) {
    unawaited(load());
  }

  final AIApiKeyStore _store;
  final String _devFallbackApiKey;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final snapshot = await _store.read();
      state = _stateFromSnapshot(snapshot).copyWith(isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load stored API key.',
      );
    }
  }

  Future<void> saveKey(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      state = state.copyWith(errorMessage: 'API key cannot be empty.');
      return;
    }

    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      final snapshot = await _store.write(normalized);
      state = _stateFromSnapshot(snapshot).copyWith(isSaving: false);
    } on FormatException catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Unable to save API key right now.',
      );
    }
  }

  Future<void> removeKey() async {
    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      final snapshot = await _store.clear();
      state = _stateFromSnapshot(snapshot).copyWith(isSaving: false);
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Unable to remove API key right now.',
      );
    }
  }

  OpenAIApiKeyState _stateFromSnapshot(AIApiKeySnapshot snapshot) {
    final hasStored = snapshot.hasKey;
    final hasDev = _devFallbackApiKey.isNotEmpty;

    if (hasStored) {
      return OpenAIApiKeyState(
        resolvedApiKey: snapshot.apiKey,
        source: OpenAIApiKeySource.storedLocal,
        storageProtection: snapshot.protection,
        devOverrideAvailable: hasDev,
      );
    }

    if (hasDev) {
      return OpenAIApiKeyState(
        resolvedApiKey: _devFallbackApiKey,
        source: OpenAIApiKeySource.devOverride,
        storageProtection: AIApiKeyStorageProtection.none,
        devOverrideAvailable: true,
      );
    }

    return const OpenAIApiKeyState(
      source: OpenAIApiKeySource.none,
      storageProtection: AIApiKeyStorageProtection.none,
      devOverrideAvailable: false,
    );
  }
}
