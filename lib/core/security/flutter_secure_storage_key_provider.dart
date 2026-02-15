import 'dart:convert';
import 'dart:math';

import 'package:ai_journal/features/journal/data/local/encrypted_database_factory.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FlutterSecureStorageKeyProvider implements EncryptionKeyProvider {
  FlutterSecureStorageKeyProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _storageKey = 'journal_db_encryption_key_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String> getKey() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && existing.trim().length >= 16) {
      return existing;
    }

    final generated = _generateKey();
    await _storage.write(key: _storageKey, value: generated);
    return generated;
  }

  String _generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
