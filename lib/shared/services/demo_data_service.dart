import 'package:sakan/shared/models/app_user.dart';
import "package:sakan/shared/models/family.dart";
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/family_moment.dart';

class DemoDataService {
  DemoDataService({DateTime? now}) : now = now ?? DateTime.now();
  final DateTime now;

  late final AppUser user = AppUser(
    id: 'demo_user_sara',
    email: 'sara@sakan.demo',
    displayName: 'Sara',
    familyIds: const ['demo_family'],
    currentFamilyId: 'demo_family',
    createdAt: now,
    updatedAt: now,
  );

  late final Family family = Family(
    id: 'demo_family',
    name: 'Al Mansoori Family',
    createdBy: 'demo_user_mom',
    countryCode: 'AE',
    city: 'Abu Dhabi',
    preferredLanguage: 'en',
    setupComplete: true,
    createdAt: now,
    updatedAt: now,
  );

  late final List<Member> members = [
    Member(
      id: 'demo_user_mom',
      familyId: 'demo_family',
      displayName: 'Mom',
      role: FamilyRole.admin,
      ageGroup: AgeGroup.adult,
      interests: const ['Family Dinner', 'Majlis'],
      preferredDays: const [5, 6],
      preferredStartMinutes: 1080,
      preferredEndMinutes: 1260,
      isActive: true,
      joinedAt: now,
      updatedAt: now,
    ),

    Member(
      id: 'demo_user_dad',
      familyId: 'demo_family',
      displayName: 'Dad',
      role: FamilyRole.adult,
      ageGroup: AgeGroup.adult,
      interests: const ['Desert Outing', 'Friday Lunch'],
      preferredDays: const [5, 6],
      preferredStartMinutes: 1080,
      preferredEndMinutes: 1260,
      isActive: true,
      joinedAt: now,
      updatedAt: now,
    ),

    Member(
      id: 'demo_user_sara',
      familyId: 'demo_family',
      displayName: 'Sara',
      role: FamilyRole.child,
      ageGroup: AgeGroup.teen,
      interests: const ['Movie Night', 'Weekend Breakfast'],
      preferredDays: const [5, 6],
      preferredStartMinutes: 1020,
      preferredEndMinutes: 1320,
      isActive: true,
      joinedAt: now,
      updatedAt: now,
    ),
  ];

  late final List<FamilyMoment> moments = [
    FamilyMoment(
      id: 'friday_lunch',
      familyId: 'demo_family',
      title: 'Friday Lunch',
      type: MomentType.recurring,
      category: MomentCategory.tradition,
      importanceLevel: 5,
      expectedParticipantIds: const [
        'demo_user_mom',
        'demo_user_dad',
        'demo_user_sara',
      ],

      startAt: now.add(const Duration(days: 2)),
      expectedIntervalDays: 7,
      evidenceType: EvidenceType.photoAttached,
      status: MomentStatus.scheduled,
      createdBy: 'demo_user_mom',
      createdAt: now,
      updatedAt: now,
    ),

    FamilyMoment(
      id: 'ali_graduation',
      familyId: 'demo_family',
      title: "Ali's Graduation",
      type: MomentType.singular,
      category: MomentCategory.milestone,
      importanceLevel: 5,
      expectedParticipantIds: const [
        'demo_user_mom',
        'demo_user_dad',
        'demo_user_sara',
      ],
      startAt: now.add(const Duration(days: 3)),
      evidenceType: EvidenceType.userConfirmed,
      status: MomentStatus.scheduled,
      createdBy: 'demo_user_mom',
      createdAt: now,
      updatedAt: now,
    ),
  ];
}
