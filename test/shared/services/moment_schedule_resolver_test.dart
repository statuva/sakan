import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/services/moment_schedule_resolver.dart';

void main() {
  test('daily Moment uses today when the preferred time has not passed', () {
    final start = MomentScheduleResolver.firstExactStart(
      type: MomentType.recurring,
      reference: DateTime(2026, 8, 31, 13),
      startMinutes: 15 * 60,
      intervalDays: 1,
    );

    expect(start, DateTime(2026, 8, 31, 15));
  });

  test('daily Moment moves to tomorrow after the preferred time', () {
    final start = MomentScheduleResolver.firstExactStart(
      type: MomentType.recurring,
      reference: DateTime(2026, 8, 31, 17),
      startMinutes: 15 * 60,
      intervalDays: 1,
    );

    expect(start, DateTime(2026, 9, 1, 15));
  });

  test('weekly Moment chooses the next requested weekday', () {
    final start = MomentScheduleResolver.firstExactStart(
      type: MomentType.recurring,
      reference: DateTime(2026, 8, 31, 10), // Monday
      startMinutes: 13 * 60,
      intervalDays: 7,
      preferredWeekday: DateTime.friday,
    );

    expect(start, DateTime(2026, 9, 4, 13));
  });

  test('flexible recurring Moment has no exact first occurrence', () {
    final start = MomentScheduleResolver.firstExactStart(
      type: MomentType.recurring,
      reference: DateTime(2026, 8, 31, 10),
      startMinutes: 18 * 60,
      intervalDays: 30,
      isDayFlexible: true,
    );

    expect(start, isNull);
  });

  test('monthly recurrence clamps day 31 in a shorter month', () {
    final moment = _moment(
      startAt: DateTime(2026, 1, 31, 18),
      intervalDays: 30,
      preferredDay: 31,
    );

    final next = MomentScheduleResolver.nextExactStart(
      moment: moment,
      after: DateTime(2026, 1, 31, 18),
      now: DateTime(2026, 2, 1),
    );

    expect(next, DateTime(2026, 2, 28, 18));
  });
}

FamilyMoment _moment({
  required DateTime startAt,
  required int intervalDays,
  int? preferredDay,
}) {
  return FamilyMoment(
    id: 'moment-1',
    familyId: 'family-1',
    title: 'Family Moment',
    type: MomentType.recurring,
    category: MomentCategory.tradition,
    importanceLevel: 4,
    expectedParticipantIds: const <String>['adult', 'child'],
    startAt: startAt,
    expectedIntervalDays: intervalDays,
    preferredStartMinutes: 18 * 60,
    preferredDayOfMonth: preferredDay,
    evidenceType: EvidenceType.manual,
    status: MomentStatus.scheduled,
    createdBy: 'adult',
    createdAt: startAt,
    updatedAt: startAt,
  );
}
