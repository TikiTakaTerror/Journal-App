class OpenAIConfigurationException implements Exception {
  const OpenAIConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'OpenAIConfigurationException: $message';
}

enum OpenAIServiceErrorCode {
  timeout,
  network,
  invalidRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  rateLimited,
  server,
  invalidResponse,
  unknown,
}

class OpenAIServiceException implements Exception {
  const OpenAIServiceException(
    this.message, {
    this.code = OpenAIServiceErrorCode.unknown,
    this.retryable = false,
    this.statusCode,
    this.requestId,
    this.attempts = 1,
  });

  final String message;
  final OpenAIServiceErrorCode code;
  final bool retryable;
  final int? statusCode;
  final String? requestId;
  final int attempts;

  @override
  String toString() {
    final details = <String>[
      'code=$code',
      'retryable=$retryable',
      'attempts=$attempts',
      if (statusCode != null) 'status=$statusCode',
      if (requestId != null && requestId!.isNotEmpty) 'requestId=$requestId',
    ].join(', ');
    return 'OpenAIServiceException($details): $message';
  }
}
