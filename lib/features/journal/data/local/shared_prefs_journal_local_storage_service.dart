import 'dart:convert';

import 'package:ai_journal/features/journal/data/local/journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/data/local/key_value_store.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';

/// Persistent local store used where SQLCipher is not supported (web/desktop).
class SharedPrefsJournalLocalStorageService
    implements JournalLocalStorageService {
  SharedPrefsJournalLocalStorageService({required KeyValueStore store})
    : _store = store;

  static const String _storageKey = 'journal_entries_v1';
  final KeyValueStore _store;

  final Map<String, JournalEntry> _entriesById = <String, JournalEntry>{};
  Future<void>? _initialization;

  @override
  Future<void> initialize() {
    _initialization ??= _initializeInternal();
    return _initialization!;
  }

  Future<void> _initializeInternal() async {
    final raw = await _store.readString(_storageKey);
    _entriesById.clear();

    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final entry = JournalEntry.fromMap(
          item.map((key, value) => MapEntry<String, Object?>(key, value)),
        );
        _entriesById[entry.id] = entry;
      }
    } catch (_) {
      // Reset malformed payloads to keep app usable.
      await _store.remove(_storageKey);
    }
  }

  @override
  Future<void> upsertEntry(JournalEntry entry) async {
    await initialize();
    _entriesById[entry.id] = entry;
    await _persist();
  }

  @override
  Future<List<JournalEntry>> listEntries({String? query, String? tag}) async {
    await initialize();
    final normalizedQuery = query?.trim().toLowerCase();
    final normalizedTag = tag?.trim().toLowerCase();

    final filtered =
        _entriesById.values
            .where((entry) {
              final matchesQuery =
                  normalizedQuery == null ||
                  normalizedQuery.isEmpty ||
                  entry.title.toLowerCase().contains(normalizedQuery) ||
                  entry.content.toLowerCase().contains(normalizedQuery);

              final matchesTag =
                  normalizedTag == null ||
                  normalizedTag.isEmpty ||
                  entry.tags.contains(normalizedTag);

              return matchesQuery && matchesTag;
            })
            .toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return filtered;
  }

  @override
  Future<JournalEntry?> getEntryById(String id) async {
    await initialize();
    return _entriesById[id];
  }

  @override
  Future<void> deleteEntry(String id) async {
    await initialize();
    _entriesById.remove(id);
    await _persist();
  }

  @override
  Future<void> close() async {}

  Future<void> _persist() {
    final payload = _entriesById.values
        .map((entry) => entry.toMap())
        .toList(growable: false);
    return _store.writeString(_storageKey, jsonEncode(payload));
  }
}
