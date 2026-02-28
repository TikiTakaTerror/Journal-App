import 'package:ai_journal/app/base_providers.dart';
import 'package:ai_journal/features/ai/application/chat_with_memory_use_case.dart';
import 'package:ai_journal/features/ai/application/default_ai_orchestrator.dart';
import 'package:ai_journal/features/ai/application/summarize_memory_use_case.dart';
import 'package:ai_journal/features/ai/domain/contracts/ai_api_key_store.dart';
import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/contracts/memory_service.dart';
import 'package:ai_journal/features/ai/domain/models/ai_privacy_policy.dart';
import 'package:ai_journal/features/ai/infrastructure/local/local_memory_service.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_api_key_store.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_cloud_ai_service.dart';
import 'package:ai_journal/features/ai/infrastructure/openai/openai_config.dart';
import 'package:ai_journal/features/ai/presentation/state/ai_companion_controller.dart';
import 'package:ai_journal/features/ai/presentation/state/openai_api_key_controller.dart';
import 'package:ai_journal/features/ai/presentation/state/smart_prompt_controller.dart';
import 'package:ai_journal/features/ai/presentation/state/smart_prompt_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final openAIDefaultConfigProvider = Provider<OpenAIConfig>((ref) {
  return OpenAIConfig.fromEnvironment();
});

final aiApiKeyStoreProvider = Provider<AIApiKeyStore>((ref) {
  return OpenAIApiKeyStore(fallbackStore: ref.watch(keyValueStoreProvider));
});

final openAIApiKeyControllerProvider =
    StateNotifierProvider<OpenAIApiKeyController, OpenAIApiKeyState>((ref) {
      final baseConfig = ref.watch(openAIDefaultConfigProvider);
      return OpenAIApiKeyController(
        store: ref.watch(aiApiKeyStoreProvider),
        devFallbackApiKey: baseConfig.apiKey,
      );
    });

final openAIConfigProvider = Provider<OpenAIConfig>((ref) {
  final base = ref.watch(openAIDefaultConfigProvider);
  final keyState = ref.watch(openAIApiKeyControllerProvider);
  return OpenAIConfig(
    apiKey: keyState.resolvedApiKey ?? '',
    baseUrl: base.baseUrl,
    chatModel: base.chatModel,
    embeddingModel: base.embeddingModel,
    organization: base.organization,
    apiMode: base.apiMode,
    maxRetries: base.maxRetries,
    requestTimeoutMs: base.requestTimeoutMs,
    debugLoggingEnabled: base.debugLoggingEnabled,
  );
});

final aiPrivacyPolicyProvider = Provider<AIPrivacyPolicy>((ref) {
  final settings = ref.watch(appSettingsControllerProvider);
  return AIPrivacyPolicy(
    localOnlyAi: settings.localOnlyAi,
    cloudAiConsent: settings.cloudAiConsent,
  );
});

final aiOrchestratorProvider = Provider<AIOrchestrator?>((ref) {
  final config = ref.watch(openAIConfigProvider);
  final policy = ref.watch(aiPrivacyPolicyProvider);

  if (!policy.canUseCloud || !config.hasApiKey) {
    return null;
  }

  final service = OpenAICloudAIService(config: config, privacyPolicy: policy);
  ref.onDispose(service.dispose);
  return DefaultAIOrchestrator(aiService: service);
});

final smartPromptControllerProvider =
    StateNotifierProvider<SmartPromptController, SmartPromptState>((ref) {
      return SmartPromptController(
        repository: ref.watch(journalRepositoryProvider),
        aiOrchestrator: ref.watch(aiOrchestratorProvider),
      );
    });

final memoryServiceProvider = Provider<MemoryService>((ref) {
  return LocalMemoryService(
    store: ref.watch(keyValueStoreProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
  );
});

final summarizeMemoryUseCaseProvider = Provider<SummarizeMemoryUseCase>((ref) {
  return const SummarizeMemoryUseCase();
});

final chatWithMemoryUseCaseProvider = Provider<ChatWithMemoryUseCase?>((ref) {
  final orchestrator = ref.watch(aiOrchestratorProvider);
  if (orchestrator == null) {
    return null;
  }
  return ChatWithMemoryUseCase(
    memoryService: ref.watch(memoryServiceProvider),
    orchestrator: orchestrator,
    summarizeMemory: ref.watch(summarizeMemoryUseCaseProvider),
  );
});

final aiCompanionControllerProvider =
    StateNotifierProvider<AICompanionController, AICompanionState>((ref) {
      return AICompanionController(
        memoryService: ref.watch(memoryServiceProvider),
        chatWithMemory: ref.watch(chatWithMemoryUseCaseProvider),
      );
    });
