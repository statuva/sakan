enum DigitalTwinInterpretationOrigin { ruleBasedFallback, externalAi }

class MomentTwinInterpretation {
  const MomentTwinInterpretation({
    required this.summary,
    required this.themes,
    required this.origin,
  });

  final String summary;
  final List<String> themes;
  final DigitalTwinInterpretationOrigin origin;
}

class FamilyTwinInterpretation {
  const FamilyTwinInterpretation({
    required this.summary,
    required this.themes,
    required this.origin,
  });

  final String summary;
  final List<String> themes;
  final DigitalTwinInterpretationOrigin origin;
}
