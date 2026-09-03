import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/features/moments/services/moment_session_timing_service.dart';
import 'package:sakan/shared/models/availability_block.dart';

void main() {
  AvailabilityBlock busyBlock({
    required String memberId,
    required int weekday,
    required int startMinutes,
    required int endMinutes,
  }) {
    return AvailabilityBlock(
      id: 'block-$memberId-$startMinutes',
      familyId: 'family-1',
      memberId: memberId,
      repeatDays: <int>[weekday],
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      isRecurring: true,
      updatedAt: DateTime.utc(2026, 9, 1),
    );
  }

  test('returns null when no expected member has schedule data', () {
    final note = MomentSessionTimingService.build(
      expectedParticipantIds: const <String>['a', 'b'],
      availability: const <AvailabilityBlock>[],
      start: DateTime(2026, 9, 4, 18),
      end: DateTime(2026, 9, 4, 19),
    );

    expect(note, isNull);
  });

  test('reports no recorded conflicts when busy periods do not overlap', () {
    final start = DateTime(2026, 9, 4, 18);
    final note = MomentSessionTimingService.build(
      expectedParticipantIds: const <String>['a', 'b'],
      availability: <AvailabilityBlock>[
        busyBlock(
          memberId: 'a',
          weekday: start.weekday,
          startMinutes: 9 * 60,
          endMinutes: 10 * 60,
        ),
        busyBlock(
          memberId: 'b',
          weekday: start.weekday,
          startMinutes: 12 * 60,
          endMinutes: 13 * 60,
        ),
      ],
      start: start,
      end: start.add(const Duration(hours: 1)),
    );

    expect(note, isNotNull);
    expect(note!.conflictingMemberIds, isEmpty);
    expect(note.membersWithScheduleData, 2);
  });

  test('reports the exact expected members with overlapping busy periods', () {
    final start = DateTime(2026, 9, 4, 18);
    final note = MomentSessionTimingService.build(
      expectedParticipantIds: const <String>['a', 'b', 'c'],
      availability: <AvailabilityBlock>[
        busyBlock(
          memberId: 'a',
          weekday: start.weekday,
          startMinutes: 17 * 60 + 30,
          endMinutes: 18 * 60 + 30,
        ),
        busyBlock(
          memberId: 'b',
          weekday: start.weekday,
          startMinutes: 20 * 60,
          endMinutes: 21 * 60,
        ),
      ],
      start: start,
      end: start.add(const Duration(hours: 1)),
    );

    expect(note, isNotNull);
    expect(note!.conflictingMemberIds, <String>{'a'});
    expect(note.membersWithScheduleData, 2);
  });
}
