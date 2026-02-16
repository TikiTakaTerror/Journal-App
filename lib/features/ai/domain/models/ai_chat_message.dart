/// Roles supported by the chat-memory conversation stream.
enum AIChatRole { system, user, assistant }

/// Immutable message entity used by AI chat and memory subsystems.
class AIChatMessage {
  AIChatMessage._({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  static const int _maxContentLength = 8000;

  final AIChatRole role;
  final String content;
  final DateTime createdAt;

  factory AIChatMessage.create({
    required AIChatRole role,
    required String content,
    required DateTime createdAt,
  }) {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw const FormatException('Chat message content cannot be empty.');
    }
    if (normalizedContent.length > _maxContentLength) {
      throw const FormatException('Chat message content exceeds max length.');
    }

    return AIChatMessage._(
      role: role,
      content: normalizedContent,
      createdAt: createdAt.toUtc(),
    );
  }

  factory AIChatMessage.fromMap(Map<String, Object?> map) {
    final roleRaw = map['role'] as String?;
    final parsedRole = AIChatRole.values.where(
      (value) => value.name == roleRaw,
    );
    if (parsedRole.isEmpty) {
      throw const FormatException('Invalid chat role.');
    }

    return AIChatMessage.create(
      role: parsedRole.first,
      content: map['content'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'role': role.name,
      'content': content,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AIChatMessage &&
        other.role == role &&
        other.content == content &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(role, content, createdAt);
}
