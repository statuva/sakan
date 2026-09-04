import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/shared/models/privacy_preferences.dart';

void main() {
  test('AI consent is denied when preferences are absent', () {
    expect(PrivacyPreferences.fromMap(null).aiConsent, isFalse);
    expect(PrivacyPreferences.fromMap(const <String, dynamic>{}).aiConsent, isFalse);
  });

  test('AI consent requires an explicit true value', () {
    final preferences = PrivacyPreferences.fromMap(
      const <String, dynamic>{'aiConsent': true},
    );
    expect(preferences.aiConsent, isTrue);
  });
}
