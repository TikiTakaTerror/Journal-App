import 'dart:developer' as developer;
import 'dart:convert';

class OpenAILogEvent {
  const OpenAILogEvent({required this.name, required this.data});

  final String name;
  final Map<String, Object?> data;
}

abstract interface class OpenAIRedactedLogger {
  void log(OpenAILogEvent event);
}

class NoopOpenAIRedactedLogger implements OpenAIRedactedLogger {
  const NoopOpenAIRedactedLogger();

  @override
  void log(OpenAILogEvent event) {}
}

class PrintOpenAIRedactedLogger implements OpenAIRedactedLogger {
  const PrintOpenAIRedactedLogger();

  @override
  void log(OpenAILogEvent event) {
    final payload = <String, Object?>{'event': event.name, ...event.data};
    // Safe because callers only pass redacted metadata.
    developer.log(jsonEncode(payload), name: 'OpenAIRedactedLogger');
  }
}
