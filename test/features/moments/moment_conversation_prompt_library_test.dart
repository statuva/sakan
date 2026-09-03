import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/features/moments/services/moment_conversation_prompt_library.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/model_enums.dart';

void main() {
  FamilyMoment moment() {
    return FamilyMoment(
      id: 'friday-lunch',
      familyId: 'family-1',
      title: 'Friday Lunch',
      type: MomentType.recurring,
      category: MomentCategory.tradition,
      importanceLevel: 4,
      expectedParticipantIds: const <String>['a', 'b'],
      startAt: DateTime.utc(2026, 9, 4, 13),
      expectedIntervalDays: 7,
      evidenceType: EvidenceType.manual,
      status: MomentStatus.scheduled,
      createdBy: 'a',
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );
  }

  test('the same Moment receives the same prompt for the same day', () {
    final first = MomentConversationPromptLibrary.promptFor(
      moment: moment(),
      date: DateTime(2026, 9, 3),
    );
    final second = MomentConversationPromptLibrary.promptFor(
      moment: moment(),
      date: DateTime(2026, 9, 3),
    );

    expect(first, second);
    expect(first, isNotEmpty);
  });
}
