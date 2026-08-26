import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_participant.dart';

void main() {
  test(
    'checkedIn participant serializes and restores',
    () {
      final now =
          DateTime.utc(2026, 8, 26, 18);

      final participant =
          MomentParticipant.checkedIn(
        familyId: 'family-1',
        instanceId: 'instance-1',
        memberId: 'member-1',
        method: MomentCheckInMethod.manual,
        now: now,
      );

      final restored =
          MomentParticipant.fromMap(
        participant.memberId,
        participant.toMap(),
      );

      expect(
        restored.state,
        ParticipantMomentState.checkedIn,
      );

      expect(
        restored.checkInMethod,
        MomentCheckInMethod.manual,
      );

      expect(restored.checkedInAt, now);
      expect(restored.hasCheckedIn, isTrue);
    },
  );

  test(
    'participant can check out without losing check-in evidence',
    () {
      final now =
          DateTime.utc(2026, 8, 26, 18);

      final participant =
          MomentParticipant.checkedIn(
        familyId: 'family-1',
        instanceId: 'instance-1',
        memberId: 'member-1',
        method: MomentCheckInMethod.manual,
        now: now,
      );

      final later = now.add(
        const Duration(minutes: 45),
      );

      final checkedOut =
          participant.copyWith(
        state: ParticipantMomentState.left,
        checkedOutAt: later,
        updatedAt: later,
      );

      expect(
        checkedOut.state,
        ParticipantMomentState.left,
      );

      expect(
        checkedOut.checkedInAt,
        participant.checkedInAt,
      );

      expect(checkedOut.checkedOutAt, later);
    },
  );
}
