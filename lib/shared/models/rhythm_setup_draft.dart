import 'model_enums.dart';

class RhythmSetupDraft {
  const RhythmSetupDraft({
    required this.templateId,
    required this.title,
    required this.category,
    required this.expectedIntervalDays,
    required this.importanceLevel,
    required this.expectedParticipantIds,
    required this.nextOccurrenceAt,
    this.description = '',
    this.lastOccurrenceAt,
    this.isCustom = false,
  });

  final String templateId;
  final String title;
  final String description;
  final MomentCategory category;
  final int expectedIntervalDays;
  final int importanceLevel;
  final List<String> expectedParticipantIds;
  final DateTime nextOccurrenceAt;
  final DateTime? lastOccurrenceAt;
  final bool isCustom;

  RhythmSetupDraft copyWith({
    String? title,
    String? description,
    MomentCategory? category,
    int? expectedIntervalDays,
    int? importanceLevel,
    List<String>? expectedParticipantIds,
    DateTime? nextOccurrenceAt,
    DateTime? lastOccurrenceAt,
    bool removeLastOccurrence = false,
  }) {
    return RhythmSetupDraft(
      templateId: templateId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      expectedIntervalDays:
          expectedIntervalDays ?? this.expectedIntervalDays,
      importanceLevel:
          importanceLevel ?? this.importanceLevel,
      expectedParticipantIds:
          expectedParticipantIds ?? this.expectedParticipantIds,
      nextOccurrenceAt:
          nextOccurrenceAt ?? this.nextOccurrenceAt,
      lastOccurrenceAt: removeLastOccurrence
          ? null
          : lastOccurrenceAt ?? this.lastOccurrenceAt,
      isCustom: isCustom,
    );
  }
}
