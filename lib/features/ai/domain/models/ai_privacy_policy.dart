/// Thrown when cloud AI usage is attempted without explicit permission.
class AIConsentException implements Exception {
  const AIConsentException(this.message);

  final String message;

  @override
  String toString() => 'AIConsentException: $message';
}

/// Encapsulates AI privacy policy derived from user settings.
class AIPrivacyPolicy {
  const AIPrivacyPolicy({
    required this.localOnlyAi,
    required this.cloudAiConsent,
  });

  final bool localOnlyAi;
  final bool cloudAiConsent;

  bool get canUseCloud => !localOnlyAi && cloudAiConsent;

  void ensureCloudAllowed() {
    if (canUseCloud) {
      return;
    }

    throw const AIConsentException(
      'Cloud AI access is disabled. Require explicit user consent.',
    );
  }
}
