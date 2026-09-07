import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/services/member_moment_recommendation_builder.dart';

void main() {
  final now = DateTime.utc(2026, 9, 7, 12);

  group('MemberMomentRecommendationBuilder', () {
    test('graduation tasks change for adult, teen, and child', () {
      final moment = _moment(
        title: 'Lara Graduation',
        category: MomentCategory.milestone,
        startAt: now.add(const Duration(days: 1)),
      );

      final adult = MemberMomentRecommendationBuilder.build(
        member: _member(
          id: 'adult',
          role: FamilyRole.adult,
          ageGroup: AgeGroup.adult,
          now: now,
        ),
        moment: moment,
      );
      final teen = MemberMomentRecommendationBuilder.build(
        member: _member(
          id: 'teen',
          role: FamilyRole.child,
          ageGroup: AgeGroup.teen,
          now: now,
        ),
        moment: moment,
      );
      final child = MemberMomentRecommendationBuilder.build(
        member: _member(
          id: 'child',
          role: FamilyRole.child,
          ageGroup: AgeGroup.child,
          now: now,
        ),
        moment: moment,
      );

      expect(adult.primaryTask.toLowerCase(), contains('gift'));
      expect(teen.primaryTask.toLowerCase(), contains('message'));
      expect(child.primaryTask.toLowerCase(), contains('card'));
      for (final result in <MemberMomentRecommendation>[adult, teen, child]) {
        expect(result.tasks, hasLength(3));
        expect(result.tasks.toSet(), hasLength(result.tasks.length));
      }
    });

    test('subject does not receive a task to prepare their own gift', () {
      final moment = _moment(
        title: 'Lara Graduation',
        category: MomentCategory.milestone,
        startAt: now.add(const Duration(days: 1)),
        subjectMemberIds: const <String>['teen'],
      );

      final result = MemberMomentRecommendationBuilder.build(
        member: _member(
          id: 'teen',
          role: FamilyRole.child,
          ageGroup: AgeGroup.teen,
          now: now,
        ),
        moment: moment,
      );

      expect(result.tasks.join(' ').toLowerCase(), isNot(contains('gift')));
      expect(result.primaryTask.toLowerCase(), contains('ceremony'));
    });

    test('adult conflict adds simulation without exceeding three tasks', () {
      final result = MemberMomentRecommendationBuilder.build(
        member: _member(
          id: 'adult',
          role: FamilyRole.admin,
          ageGroup: AgeGroup.adult,
          now: now,
        ),
        moment: _moment(
          title: 'Family Picnic',
          category: MomentCategory.familyTime,
          startAt: now.add(const Duration(days: 2)),
          type: MomentType.recurring,
        ),
        hasScheduleConflict: true,
      );

      expect(result.recommendsSimulation, isTrue);
      expect(result.tasks, hasLength(3));
      expect(
        result.tasks.last.toLowerCase(),
        allOf(contains('simulation'), contains('conflict-free')),
      );
      expect(result.scheduleNote, contains('busy time'));
    });

    test('teen conflict asks an adult and never exposes simulation', () {
      final result = MemberMomentRecommendationBuilder.build(
        member: _member(
          id: 'teen',
          role: FamilyRole.child,
          ageGroup: AgeGroup.teen,
          now: now,
        ),
        moment: _moment(
          title: 'Family Picnic',
          category: MomentCategory.familyTime,
          startAt: now.add(const Duration(days: 2)),
          type: MomentType.recurring,
        ),
        hasScheduleConflict: true,
      );

      expect(result.recommendsSimulation, isFalse);
      expect(result.tasks.last.toLowerCase(), contains('ask an adult'));
    });

    test('a fixed one-time conflict does not offer an unsupported simulation', () {
      final result = MemberMomentRecommendationBuilder.build(
        member: _member(
          id: 'adult',
          role: FamilyRole.adult,
          ageGroup: AgeGroup.adult,
          now: now,
        ),
        moment: _moment(
          title: 'Lara Graduation',
          category: MomentCategory.milestone,
          startAt: now.add(const Duration(days: 1)),
          type: MomentType.singular,
        ),
        hasScheduleConflict: true,
      );

      expect(result.recommendsSimulation, isFalse);
      expect(result.tasks.join(' ').toLowerCase(), isNot(contains('simulation')));
    });

    test('teen age stays teen-safe even when the stored role is admin', () {
      final result = MemberMomentRecommendationBuilder.build(
        member: _member(
          id: 'teen',
          role: FamilyRole.admin,
          ageGroup: AgeGroup.teen,
          now: now,
        ),
        moment: _moment(
          title: 'Family Picnic',
          category: MomentCategory.familyTime,
          startAt: now.add(const Duration(days: 2)),
          type: MomentType.recurring,
        ),
        hasScheduleConflict: true,
      );

      expect(result.primaryTask.toLowerCase(), contains('game'));
      expect(result.recommendsSimulation, isFalse);
      expect(result.tasks.last.toLowerCase(), contains('ask an adult'));
    });

    test('drifting adult rhythm leads with actionable simulation', () {
      final result = MemberMomentRecommendationBuilder.build(
        member: _member(
          id: 'adult',
          role: FamilyRole.adult,
          ageGroup: AgeGroup.adult,
          now: now,
        ),
        moment: _moment(
          title: 'Evening Walk',
          category: MomentCategory.tradition,
          startAt: now,
          type: MomentType.recurring,
        ),
        isDrifting: true,
      );

      expect(result.primaryTask.toLowerCase(), contains('simulation'));
      expect(result.recommendsSimulation, isTrue);
      expect(result.tasks, hasLength(3));
    });
  });
}

Member _member({
  required String id,
  required FamilyRole role,
  required AgeGroup ageGroup,
  required DateTime now,
}) {
  return Member(
    id: id,
    familyId: 'family',
    displayName: id,
    role: role,
    ageGroup: ageGroup,
    interests: const <String>[],
    preferredDays: const <int>[],
    isActive: true,
    joinedAt: now,
    updatedAt: now,
  );
}

FamilyMoment _moment({
  required String title,
  required MomentCategory category,
  required DateTime startAt,
  List<String> subjectMemberIds = const <String>[],
  MomentType type = MomentType.singular,
}) {
  return FamilyMoment(
    id: 'moment',
    familyId: 'family',
    title: title,
    type: type,
    category: category,
    importanceLevel: 5,
    expectedParticipantIds: const <String>['adult', 'teen', 'child'],
    subjectMemberIds: subjectMemberIds,
    startAt: startAt,
    expectedIntervalDays: type == MomentType.recurring ? 7 : null,
    preferredStartMinutes: startAt.hour * 60 + startAt.minute,
    isDayFlexible: false,
    evidenceType: EvidenceType.manual,
    status: MomentStatus.scheduled,
    createdBy: 'adult',
    createdAt: startAt.subtract(const Duration(days: 2)),
    updatedAt: startAt.subtract(const Duration(days: 1)),
  );
}
