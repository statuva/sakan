import 'model_enums.dart';

class RhythmTemplate {
  const RhythmTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.defaultIntervalDays,
    required this.defaultImportanceLevel,
  });

  final String id;
  final String title;
  final String description;
  final MomentCategory category;
  final int defaultIntervalDays;
  final int defaultImportanceLevel;
}