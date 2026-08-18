class PrivacyPreferences {
  const PrivacyPreferences({
    this.aiConsent = true,
    this.analyticsConsent = false,
  });

  final bool aiConsent;
  final bool analyticsConsent;

  factory PrivacyPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const PrivacyPreferences();
    }

    return PrivacyPreferences(
      aiConsent: map['aiConsent'] as bool? ?? true,
      analyticsConsent: map['analyticsConsent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'aiConsent': aiConsent, 'analyticsConsent': analyticsConsent};
  }

  PrivacyPreferences copyWith({bool? aiConsent, bool? analyticsConsent}) {
    return PrivacyPreferences(
      aiConsent: aiConsent ?? this.aiConsent,
      analyticsConsent: analyticsConsent ?? this.analyticsConsent,
    );
  }
}
