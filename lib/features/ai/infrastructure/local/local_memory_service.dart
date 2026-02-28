import 'dart:convert';

import 'package:ai_journal/features/ai/domain/contracts/memory_service.dart';
import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';

class LocalMemoryService implements MemoryService {
  LocalMemoryService({
    required KeyValueStore store,
    required JournalRepository journalRepository,
  }) : _store = store,
       _journalRepository = journalRepository;

  static const String _chatHistoryKey = 'ai_memory_chat_history_v1';
  static const String _summaryKey = 'ai_memory_summary_v1';

  final KeyValueStore _store;
  final JournalRepository _journalRepository;

  @override
  Future<void> appendChatMessage(AIChatMessage message) async {
    final messages = await _loadChatMessages();
    messages.add(message);
    if (messages.length > 120) {
      messages.removeRange(0, messages.length - 120);
    }
    await _saveChatMessages(messages);
  }

  @override
  Future<List<AIChatMessage>> loadRecentChatMessages({required int limit}) async {
    if (limit <= 0) {
      return const <AIChatMessage>[];
    }
    final messages = await _loadChatMessages();
    if (messages.length <= limit) {
      return List<AIChatMessage>.unmodifiable(messages);
    }
    return List<AIChatMessage>.unmodifiable(
      messages.sublist(messages.length - limit),
    );
  }

  @override
  Future<String> loadMemorySummary() async {
    final raw = await _store.readString(_summaryKey);
    return raw?.trim() ?? '';
  }

  @override
  Future<void> saveMemorySummary(String summary) async {
    final normalized = summary.trim();
    if (normalized.isEmpty) {
      await _store.remove(_summaryKey);
      return;
    }
    await _store.writeString(_summaryKey, normalized);
  }

  @override
  Future<List<JournalEntry>> findRelevantEntries({
    required String query,
    required int limit,
  }) async {
    if (limit <= 0) {
      return const <JournalEntry>[];
    }
    final all = await _journalRepository.listEntries();
    if (all.isEmpty) {
      return const <JournalEntry>[];
    }

    final terms = _tokenize(query);
    if (terms.isEmpty) {
      return List<JournalEntry>.unmodifiable(all.take(limit));
    }

    final scored = all.map((entry) {
      final haystack = '${entry.title} ${entry.content} ${entry.tags.join(' ')}'
          .toLowerCase();
      final tokens = _tokenize(haystack);
      final overlap = tokens.intersection(terms).length;
      final exactTitleBoost = terms.any(
        (term) => entry.title.toLowerCase().contains(term),
      )
          ? 2
          : 0;
      final recencyBoost = all.length - all.indexOf(entry);
      final score = overlap * 5 + exactTitleBoost + (recencyBoost / 100);
      return (entry: entry, score: score);
    }).toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));

    final filtered = scored.where((row) => row.score > 0).take(limit).map((row) => row.entry);
    return List<JournalEntry>.unmodifiable(filtered);
  }

  Future<List<AIChatMessage>> _loadChatMessages() async {
    final raw = await _store.readString(_chatHistoryKey);
    if (raw == null || raw.trim().isEmpty) {
      return <AIChatMessage>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return <AIChatMessage>[];
      }

      final messages = <AIChatMessage>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        try {
          messages.add(
            AIChatMessage.fromMap(
              item.map((key, value) => MapEntry<String, Object?>(key, value)),
            ),
          );
        } catch (_) {
          // Skip malformed rows.
        }
      }
      return messages;
    } catch (_) {
      return <AIChatMessage>[];
    }
  }

  Future<void> _saveChatMessages(List<AIChatMessage> messages) async {
    final encoded = jsonEncode(
      messages.map((message) => message.toMap()).toList(growable: false),
    );
    await _store.writeString(_chatHistoryKey, encoded);
  }

  Set<String> _tokenize(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((part) => part.trim())
        .where((part) => part.length >= 3)
        .toSet();
  }
}
