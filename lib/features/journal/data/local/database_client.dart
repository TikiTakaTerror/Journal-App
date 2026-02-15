/// Minimal database client abstraction for testability and decoupling.
abstract interface class DatabaseClient {
  Future<void> execute(String sql);

  Future<int> insertOrReplace(String table, Map<String, Object?> values);

  Future<List<Map<String, Object?>>> query({
    required String table,
    String? where,
    List<Object?> whereArgs = const <Object?>[],
    String? orderBy,
  });

  Future<int> delete({
    required String table,
    required String where,
    required List<Object?> whereArgs,
  });

  Future<void> close();
}
