class AppSettings {
  const AppSettings({
    this.localOnlyAi = true,
    bool cloudAiConsent = false,
    this.notificationsEnabled = false,
    this.darkMode = false,
  }) : cloudAiConsent = localOnlyAi ? false : cloudAiConsent;

  final bool localOnlyAi;
  final bool cloudAiConsent;
  final bool notificationsEnabled;
  final bool darkMode;

  AppSettings copyWith({
    bool? localOnlyAi,
    bool? cloudAiConsent,
    bool? notificationsEnabled,
    bool? darkMode,
  }) {
    return AppSettings(
      localOnlyAi: localOnlyAi ?? this.localOnlyAi,
      cloudAiConsent: cloudAiConsent ?? this.cloudAiConsent,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'localOnlyAi': localOnlyAi,
      'cloudAiConsent': cloudAiConsent,
      'notificationsEnabled': notificationsEnabled,
      'darkMode': darkMode,
    };
  }

  factory AppSettings.fromMap(Map<String, Object?> map) {
    return AppSettings(
      localOnlyAi: map['localOnlyAi'] as bool? ?? true,
      cloudAiConsent: map['cloudAiConsent'] as bool? ?? false,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? false,
      darkMode: map['darkMode'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AppSettings &&
        other.localOnlyAi == localOnlyAi &&
        other.cloudAiConsent == cloudAiConsent &&
        other.notificationsEnabled == notificationsEnabled &&
        other.darkMode == darkMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      localOnlyAi,
      cloudAiConsent,
      notificationsEnabled,
      darkMode,
    );
  }
}
