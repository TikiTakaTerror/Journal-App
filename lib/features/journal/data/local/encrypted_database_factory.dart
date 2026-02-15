import 'dart:async';

import 'package:ai_journal/features/journal/data/local/database_client.dart';

/// Provides an encryption key used to open the local SQLCipher database.
abstract interface class EncryptionKeyProvider {
  Future<String> getKey();
}

/// Opens an encrypted database and exposes it through [DatabaseClient].
abstract interface class EncryptedDatabaseFactory {
  Future<DatabaseClient> open({
    required String path,
    required String password,
    required int version,
    required FutureOr<void> Function(DatabaseClient db, int version) onCreate,
  });
}
