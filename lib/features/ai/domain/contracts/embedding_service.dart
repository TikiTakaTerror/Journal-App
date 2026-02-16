/// Embedding generation contract for semantic retrieval workflows.
abstract interface class EmbeddingService {
  Future<List<double>> createEmbedding(String text);
}
