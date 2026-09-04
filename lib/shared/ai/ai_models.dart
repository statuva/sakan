enum SakanAiFeature {
  homeInsight,
  memoryReflection,
  weeklyReport,
  digitalTwinReflection,
  simulationParse,
  simulationExplain,
}

enum SakanAiMessageRole { user, assistant }

class SakanAiMessage {
  const SakanAiMessage({required this.role, required this.text});

  final SakanAiMessageRole role;
  final String text;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'role': role.name, 'text': text};
  }
}

class SakanAiResult {
  SakanAiResult({
    required this.requestId,
    required this.feature,
    required this.text,
    required this.generatedAt,
    required this.inputHash,
    required this.cached,
    this.title,
    this.reasons = const <String>[],
    this.suggestedActions = const <String>[],
    this.evidenceRefs = const <String>[],
    this.quickReplies = const <String>[],
    this.reminderTitle,
    this.reminderReason,
    this.scenario,
  });

  final String requestId;
  final String feature;
  final String? title;
  final String text;
  final List<String> reasons;
  final List<String> suggestedActions;
  final List<String> evidenceRefs;
  final List<String> quickReplies;
  final String? reminderTitle;
  final String? reminderReason;
  final Map<String, dynamic>? scenario;
  final DateTime generatedAt;
  final String inputHash;
  final bool cached;

  factory SakanAiResult.fromMap(Map<String, dynamic> map) {
    return SakanAiResult(
      requestId: _requiredString(map, 'requestId'),
      feature: _requiredString(map, 'feature'),
      title: _optionalString(map['title']),
      text: _requiredString(map, 'text'),
      reasons: _stringList(map['reasons']),
      suggestedActions: _stringList(map['suggestedActions']),
      evidenceRefs: _stringList(map['evidenceRefs']),
      quickReplies: _stringList(map['quickReplies']),
      reminderTitle: _optionalString(map['reminderTitle']),
      reminderReason: _optionalString(map['reminderReason']),
      scenario: map['scenario'] is Map
          ? Map<String, dynamic>.from(map['scenario'] as Map)
          : null,
      generatedAt: DateTime.parse(_requiredString(map, 'generatedAt')),
      inputHash: _requiredString(map, 'inputHash'),
      cached: map['cached'] == true,
    );
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = _optionalString(map[key]);
    if (value == null) {
      throw const FormatException('The AI response was incomplete.');
    }
    return value;
  }

  static String? _optionalString(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class SakanAiException implements Exception {
  const SakanAiException(this.message, {this.code = 'ai-unavailable'});

  final String code;
  final String message;

  @override
  String toString() => message;
}
