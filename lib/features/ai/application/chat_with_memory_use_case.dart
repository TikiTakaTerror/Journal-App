import 'package:ai_journal/features/ai/application/summarize_memory_use_case.dart';
import 'package:ai_journal/features/ai/domain/contracts/ai_orchestrator.dart';
import 'package:ai_journal/features/ai/domain/contracts/memory_service.dart';
import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/ai/domain/models/ai_requests.dart';
import 'package:ai_journal/features/ai/domain/models/ai_responses.dart';

class ChatWithMemoryUseCase {
  ChatWithMemoryUseCase({
    required MemoryService memoryService,
    required AIOrchestrator orchestrator,
    SummarizeMemoryUseCase? summarizeMemory,
    DateTime Function()? now,
    this.recentHistoryLimit = 12,
    this.relevantEntryLimit = 4,
    this.summaryRefreshInterval = 4,
  }) : _memoryService = memoryService,
       _orchestrator = orchestrator,
       _summarizeMemory = summarizeMemory ?? const SummarizeMemoryUseCase(),
       _now = now ?? DateTime.now;

  final MemoryService _memoryService;
  final AIOrchestrator _orchestrator;
  final SummarizeMemoryUseCase _summarizeMemory;
  final DateTime Function() _now;
  final int recentHistoryLimit;
  final int relevantEntryLimit;
  final int summaryRefreshInterval;

  Future<AIChatConversationResult> call(String userMessage) async {
    final history = await _memoryService.loadRecentChatMessages(
      limit: recentHistoryLimit,
    );
    final summary = await _memoryService.loadMemorySummary();
    final relevantEntries = await _memoryService.findRelevantEntries(
      query: userMessage,
      limit: relevantEntryLimit,
    );

    final response = await _orchestrator.chatWithMemory(
      AIChatRequest(
        userMessage: userMessage,
        memorySummary: summary,
        chatHistory: history,
        relevantEntries: relevantEntries,
      ),
    );

    final userChat = AIChatMessage.create(
      role: AIChatRole.user,
      content: userMessage,
      createdAt: _now(),
    );
    final assistantChat = AIChatMessage.create(
      role: AIChatRole.assistant,
      content: response.message,
      createdAt: _now(),
    );

    await _memoryService.appendChatMessage(userChat);
    await _memoryService.appendChatMessage(assistantChat);

    final updatedHistory = <AIChatMessage>[...history, userChat, assistantChat];
    final shouldRefreshSummary = summary.trim().isEmpty ||
        updatedHistory.where((m) => m.role == AIChatRole.user).length %
                summaryRefreshInterval ==
            0;

    String? updatedSummary;
    if (shouldRefreshSummary) {
      updatedSummary = _summarizeMemory(
        recentMessages: updatedHistory,
        existingSummary: summary,
      );
      await _memoryService.saveMemorySummary(updatedSummary);
    }

    return AIChatConversationResult(
      response: response,
      userMessage: userChat,
      assistantMessage: assistantChat,
      memorySummary: updatedSummary ?? summary,
      relevantEntriesCount: relevantEntries.length,
    );
  }
}

class AIChatConversationResult {
  const AIChatConversationResult({
    required this.response,
    required this.userMessage,
    required this.assistantMessage,
    required this.memorySummary,
    required this.relevantEntriesCount,
  });

  final AIChatResponse response;
  final AIChatMessage userMessage;
  final AIChatMessage assistantMessage;
  final String memorySummary;
  final int relevantEntriesCount;
}
