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

    DailyReflection(
      id: 'hadith-01',
      kind: DailyReflectionKind.hadith,
      englishText:
          'All of you are shepherds and each of you is responsible for his flock. A man is the shepherd of the people of his house and he is responsible. A woman is the shepherd of the house of her husband and she is responsible. Each of you is a shepherd and each is responsible for his flock.',
      arabicText:
          'كُلُّكُمْ رَاعٍ وَمَسْئُولٌ عَنْ رَعِيَّتِهِ، فَالإِمَامُ رَاعٍ وَمَسْئُولٌ عَنْ رَعِيَّتِهِ، وَالرَّجُلُ فِي أَهْلِهِ رَاعٍ وَهُوَ مَسْئُولٌ عَنْ رَعِيَّتِهِ، وَالْمَرْأَةُ فِي بَيْتِ زَوْجِهَا رَاعِيَةٌ وَهِيَ مَسْئُولَةٌ عَنْ رَعِيَّتِهِا',
      source: 'رواه البخاري ومسلم',
    ),

    DailyReflection(
      id: 'family-quote-02',
      kind: DailyReflectionKind.familyQuote,
      englishText: 'Family is not an important thing. It’s everything. ',
      source: 'Michael J. Fox',
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
