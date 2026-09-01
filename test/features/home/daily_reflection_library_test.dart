import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/features/home/data/daily_reflection_library.dart';
import 'package:sakan/features/home/domain/daily_reflection.dart';

void main() {
  test('empty reflection library returns no Home reflection', () {
    final result = DailyReflectionLibrary.pickFrom(
      entries: const <DailyReflection>[],
      familyId: 'family-1',
      date: DateTime(2026, 9, 1),
    );

    expect(result, isNull);
  });

  test('the same family and date receive the same reflection', () {
    const entries = <DailyReflection>[
      DailyReflection(
        id: 'one',
        kind: DailyReflectionKind.familyQuote,
        englishText: 'First reflection',
      ),
      DailyReflection(
        id: 'two',
        kind: DailyReflectionKind.familyQuote,
        englishText: 'Second reflection',
      ),
      DailyReflection(
        id: 'three',
        kind: DailyReflectionKind.familyQuote,
        englishText: 'Third reflection',
      ),
    ];

    final first = DailyReflectionLibrary.pickFrom(
      entries: entries,
      familyId: 'family-1',
      date: DateTime(2026, 9, 1, 8),
    );

    final second = DailyReflectionLibrary.pickFrom(
      entries: entries,
      familyId: 'family-1',
      date: DateTime(2026, 9, 1, 22),
    );

    expect(first?.id, second?.id);
    expect(entries.map((item) => item.id), contains(first?.id));
  });
}
