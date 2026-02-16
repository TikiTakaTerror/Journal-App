import 'package:ai_journal/features/ai/domain/models/ai_privacy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AIPrivacyPolicy', () {
    test('cloud access is blocked when local-only mode is enabled', () {
      const policy = AIPrivacyPolicy(localOnlyAi: true, cloudAiConsent: true);

      expect(policy.canUseCloud, isFalse);
      expect(
        () => policy.ensureCloudAllowed(),
        throwsA(isA<AIConsentException>()),
      );
    });

    test('cloud access is blocked without explicit consent', () {
      const policy = AIPrivacyPolicy(localOnlyAi: false, cloudAiConsent: false);

      expect(policy.canUseCloud, isFalse);
      expect(
        () => policy.ensureCloudAllowed(),
        throwsA(isA<AIConsentException>()),
      );
    });

    test('cloud access is allowed only with explicit consent', () {
      const policy = AIPrivacyPolicy(localOnlyAi: false, cloudAiConsent: true);

      expect(policy.canUseCloud, isTrue);
      expect(() => policy.ensureCloudAllowed(), returnsNormally);
    });
  });
}
