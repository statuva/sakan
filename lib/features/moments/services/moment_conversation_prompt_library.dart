import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';

abstract final class MomentConversationPromptLibrary {
  static const Map<MomentCategory, List<String>> _prompts = {
    MomentCategory.tradition: <String>[
      'What is one small thing you hope the family keeps doing together?',
      'What is a family tradition you remember most clearly?',
      'What made you smile this week?',
      'What is something you appreciate about today?',
    ],
    MomentCategory.familyTime: <String>[
      'What was the best part of your day?',
      'What is something you would like the family to do soon?',
      'What made this week feel easier?',
      'What is one thing you want everyone to know today?',
    ],
    MomentCategory.milestone: <String>[
      'What are you most proud of about this moment?',
      'Who helped make this milestone possible?',
      'What do you hope to remember from today?',
    ],
    MomentCategory.care: <String>[
      'What would make today feel a little lighter?',
      'Is there one way the family can support you this week?',
      'What is something kind someone did for you recently?',
    ],
    MomentCategory.responsibility: <String>[
      'What can the family do together to make this easier?',
      'Which part should we solve first?',
      'What would a good result look like today?',
    ],
    MomentCategory.memory: <String>[
      'What detail from this moment do you want to remember?',
      'What made this moment feel special?',
      'What story would you tell about today later?',
    ],
  };

  static String promptFor({
    required FamilyMoment moment,
    required DateTime date,
  }) {
    final prompts =
        _prompts[moment.category] ?? _prompts[MomentCategory.familyTime]!;

    final dateKey = date.year * 10000 + date.month * 100 + date.day;
    final seed = _stableHash('${moment.id}:$dateKey');

    return prompts[seed % prompts.length];
  }

  static String intentionFor(FamilyMoment moment) {
    final note = moment.notes?.trim();

    if (note != null && note.isNotEmpty) {
      return note;
    }

    return switch (moment.category) {
      MomentCategory.tradition =>
        'Give this family tradition your full attention for a while.',
      MomentCategory.familyTime =>
        'Spend uninterrupted time together without turning it into a task.',
      MomentCategory.milestone =>
        'Be present for the person and the meaning behind this milestone.',
      MomentCategory.care =>
        'Make space for support, patience, and a simple check-in.',
      MomentCategory.responsibility =>
        'Work through this responsibility together and share the load.',
      MomentCategory.memory =>
        'Be present now; the family can decide later what is worth saving.',
    };
  }

  static int _stableHash(String value) {
    var hash = 0x811C9DC5;

    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }

    return hash;
  }
}
