import 'package:sakan/features/home/domain/daily_reflection.dart';

abstract final class DailyReflectionLibrary {
  static const List<DailyReflection> items = <DailyReflection>[
    DailyReflection(
      id: 'family-quote-01',
      kind: DailyReflectionKind.familyQuote,
      englishText:
          'I loved watching her at the dinner table as she talked with enthusiasm about her work. This, I told myself, was “home.” ',
      source: 'haruki Murakami',
    ),
  ];

  static DailyReflection? forFamilyDate({
    required String familyId,
    required DateTime date,
  }) {
    return pickFrom(entries: items, familyId: familyId, date: date);
  }

  static DailyReflection? pickFrom({
    required List<DailyReflection> entries,
    required String familyId,
    required DateTime date,
  }) {
    if (entries.isEmpty) {
      return null;
    }

    final localDate = date.toLocal();
    final dateKey =
        '${localDate.year.toString().padLeft(4, '0')}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.day.toString().padLeft(2, '0')}';

    final index = _stableHash('$familyId|$dateKey') % entries.length;
    return entries[index];
  }

  static int _stableHash(String value) {
    var hash = 17;

    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    return hash;
  }
}
