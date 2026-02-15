import 'package:ai_journal/features/journal/data/local/journal_local_storage_service.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/domain/repositories/journal_repository.dart';

class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl({required JournalLocalStorageService storageService})
    : _storageService = storageService;

  final JournalLocalStorageService _storageService;
  Future<void>? _initialization;

  Future<void> _ensureInitialized() {
    _initialization ??= _storageService.initialize();
    return _initialization!;
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _ensureInitialized();
    await _storageService.deleteEntry(id);
  }

  @override
  Future<JournalEntry?> getEntryById(String id) async {
    await _ensureInitialized();
    return _storageService.getEntryById(id);
  }

  @override
  Future<List<JournalEntry>> listEntries({String? query, String? tag}) async {
    await _ensureInitialized();
    return _storageService.listEntries(query: query, tag: tag);
  }

  @override
  Future<void> upsertEntry(JournalEntry entry) async {
    await _ensureInitialized();
    await _storageService.upsertEntry(entry);
  }
}
