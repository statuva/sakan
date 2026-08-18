import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/rhythm_template.dart';

abstract final class UaeRhythmTemplates {
  static const List<RhythmTemplate> all = [
    RhythmTemplate(
      id: 'friday_lunch',
      title: 'Friday Lunch',
      description:
          'A regular family lunch that brings household and extended family members together.',
      category: MomentCategory.tradition,
      defaultIntervalDays: 7,
      defaultImportanceLevel: 5,
    ),

    RhythmTemplate(
      id: 'family_majlis',
      title: 'Family Majlis',
      description:
          'Time for conversation, hospitality, and connection with family members.',
      category: MomentCategory.tradition,
      defaultIntervalDays: 7,
      defaultImportanceLevel: 4,
    ),

    RhythmTemplate(
      id: 'grandparents_visit',
      title: 'Grandparents Visit',
      description:
          'Regular time dedicated to maintaining intergenerational connection.',
      category: MomentCategory.tradition,
      defaultIntervalDays: 14,
      defaultImportanceLevel: 5,
    ),

    RhythmTemplate(
      id: 'elder_visit',
      title: 'Elder Visit',
      description:
          'Time reserved for visiting and supporting older family members.',
      category: MomentCategory.care,
      defaultIntervalDays: 14,
      defaultImportanceLevel: 5,
    ),

    RhythmTemplate(
      id: 'extended_family_gathering',
      title: 'Extended Family Gathering',
      description: 'A gathering with relatives beyond the immediate household.',
      category: MomentCategory.tradition,
      defaultIntervalDays: 30,
      defaultImportanceLevel: 4,
    ),

    RhythmTemplate(
      id: 'weekend_breakfast',
      title: 'Weekend Breakfast',
      description: 'A calm shared breakfast at the end of the week.',
      category: MomentCategory.familyTime,
      defaultIntervalDays: 7,
      defaultImportanceLevel: 3,
    ),

    RhythmTemplate(
      id: 'family_dinner',
      title: 'Family Dinner',
      description:
          'A recurring meal where family members intentionally gather.',
      category: MomentCategory.familyTime,
      defaultIntervalDays: 7,
      defaultImportanceLevel: 4,
    ),

    RhythmTemplate(
      id: 'family_storytelling',
      title: 'Family Storytelling',
      description: 'Time for sharing family stories, memories, and heritage.',
      category: MomentCategory.tradition,
      defaultIntervalDays: 14,
      defaultImportanceLevel: 4,
    ),

    RhythmTemplate(
      id: 'desert_outing',
      title: 'Desert Outing',
      description:
          'An outdoor family activity connected to local environment and shared experience.',
      category: MomentCategory.familyTime,
      defaultIntervalDays: 30,
      defaultImportanceLevel: 3,
    ),

    RhythmTemplate(
      id: 'heritage_memory',
      title: 'Heritage Memory',
      description:
          'Time for preserving a family recipe, story, photograph, or tradition.',
      category: MomentCategory.memory,
      defaultIntervalDays: 30,
      defaultImportanceLevel: 4,
    ),
  ];
}
