import 'dart:convert';

/// Immutable journal entry entity used across domain, data, and UI layers.
class JournalEntry {
  JournalEntry._({
    required this.id,
    required this.title,
    required this.content,
    required List<String> tags,
    required this.createdAt,
    required this.updatedAt,
  }) : tags = List<String>.unmodifiable(tags);

  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const int _maxTitleLength = 200;
  static const int _maxContentLength = 50000;
  static final RegExp _tagAllowedChars = RegExp(r'[^a-z0-9-]');

  /// Factory that enforces input validation and deterministic normalization.
  factory JournalEntry.create({
    required String id,
    required String title,
    required String content,
    required List<String> tags,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final normalizedId = id.trim();
    final normalizedTitle = title.trim();
    final normalizedContent = content.trim();
    final normalizedTags = _normalizeTags(tags);

    if (normalizedId.isEmpty) {
      throw const FormatException('Entry id cannot be empty.');
    }
    if (normalizedTitle.isEmpty) {
      throw const FormatException('Entry title cannot be empty.');
    }
    if (normalizedContent.isEmpty) {
      throw const FormatException('Entry content cannot be empty.');
    }
    if (normalizedTitle.length > _maxTitleLength) {
      throw const FormatException('Entry title exceeds max length.');
    }
    if (normalizedContent.length > _maxContentLength) {
      throw const FormatException('Entry content exceeds max length.');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('updatedAt must be >= createdAt.');
    }

    return JournalEntry._(
      id: normalizedId,
      title: normalizedTitle,
      content: normalizedContent,
      tags: normalizedTags,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory JournalEntry.fromMap(Map<String, Object?> map) {
    final tagsRaw = map['tags_json'];
    final tags = switch (tagsRaw) {
      final String value =>
        (jsonDecode(value) as List<dynamic>)
            .map((dynamic tag) => tag.toString())
            .toList(growable: false),
      final List<dynamic> value =>
        value.map((dynamic tag) => tag.toString()).toList(growable: false),
      _ => const <String>[],
    };

    return JournalEntry.create(
      id: map['id']! as String,
      title: map['title']! as String,
      content: map['content']! as String,
      tags: tags,
      createdAt: DateTime.parse(map['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(map['updated_at']! as String).toUtc(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'content': content,
      'tags_json': jsonEncode(tags),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static List<String> _normalizeTags(List<String> tags) {
    final normalized = <String>[];
    final seen = <String>{};

    for (final tag in tags) {
      var value = tag.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      value = value.replaceAll(_tagAllowedChars, '');
      value = value
          .replaceAll(RegExp(r'-{2,}'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');

      if (value.isEmpty || seen.contains(value)) {
        continue;
      }

      seen.add(value);
      normalized.add(value);
    }

    return normalized;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is JournalEntry &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        _listEquals(other.tags, tags) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      content,
      Object.hashAll(tags),
      createdAt,
      updatedAt,
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }
}
