import 'dart:math' as math;

typedef OpenAIRandomDouble = double Function();
typedef OpenAIClock = DateTime Function();

class OpenAIRequestPolicy {
  OpenAIRequestPolicy({
    this.maxRetries = 2,
    this.baseBackoff = const Duration(milliseconds: 300),
    this.maxBackoff = const Duration(seconds: 4),
    this.jitterRatio = 0.2,
    OpenAIRandomDouble? randomDouble,
    OpenAIClock? now,
  }) : _randomDouble = randomDouble ?? _defaultRandomDouble,
       _now = now ?? DateTime.now {
    if (maxRetries < 0) {
      throw const FormatException('maxRetries must be >= 0.');
    }
    if (baseBackoff <= Duration.zero) {
      throw const FormatException('baseBackoff must be > 0.');
    }
    if (maxBackoff <= Duration.zero) {
      throw const FormatException('maxBackoff must be > 0.');
    }
    if (jitterRatio < 0 || jitterRatio > 1) {
      throw const FormatException('jitterRatio must be between 0 and 1.');
    }
  }

  final int maxRetries;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final double jitterRatio;
  final OpenAIRandomDouble _randomDouble;
  final OpenAIClock _now;

  bool canRetryAfterAttempt(int attempt) => attempt <= maxRetries;

  bool isRetryableStatus(int statusCode) {
    return statusCode == 408 ||
        statusCode == 409 ||
        statusCode == 429 ||
        (statusCode >= 500 && statusCode <= 599);
  }

  Duration retryDelayForAttempt({
    required int attempt,
    Map<String, String>? responseHeaders,
  }) {
    final retryAfter = _retryAfterDelay(responseHeaders);
    if (retryAfter != null) {
      return _capDelay(retryAfter);
    }

    final factor = 1 << math.max(0, attempt - 1);
    final rawMs = baseBackoff.inMilliseconds * factor;
    final cappedMs = math.min(rawMs, maxBackoff.inMilliseconds);

    if (cappedMs <= 0 || jitterRatio == 0) {
      return Duration(milliseconds: cappedMs);
    }

    final jitterWindow = (cappedMs * jitterRatio).round();
    final random = _randomDouble().clamp(0.0, 1.0);
    final jitterOffset = ((random * 2) - 1) * jitterWindow;
    final withJitter = math.max(0, cappedMs + jitterOffset.round());
    return Duration(milliseconds: withJitter);
  }

  Duration? _retryAfterDelay(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return null;
    }

    final value = _headerValue(headers, 'retry-after');
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    final seconds = int.tryParse(trimmed);
    if (seconds != null) {
      return Duration(seconds: math.max(0, seconds));
    }

    final parsedDate = _parseHttpDate(trimmed);
    if (parsedDate == null) {
      return null;
    }

    final delay = parsedDate.difference(_now());
    return delay.isNegative ? Duration.zero : delay;
  }

  static String? _headerValue(Map<String, String> headers, String target) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  Duration _capDelay(Duration delay) {
    if (delay <= maxBackoff) {
      return delay;
    }
    return maxBackoff;
  }

  static DateTime? _parseHttpDate(String value) {
    final match = RegExp(
      r'^[A-Za-z]{3},\s(\d{2})\s([A-Za-z]{3})\s(\d{4})\s(\d{2}):(\d{2}):(\d{2})\sGMT$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }

    final month = _monthIndex(match.group(2)!);
    if (month == null) {
      return null;
    }

    return DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }

  static int? _monthIndex(String month) {
    const months = <String, int>{
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    return months[month];
  }

  static double _defaultRandomDouble() => math.Random().nextDouble();
}
