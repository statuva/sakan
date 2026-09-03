import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_participant.dart';

void main() {
  test('Ready Room participation round-trips without becoming a check-in', () {
    final timestamp = DateTime.utc(2026, 9, 3, 10);
    final participant = MomentParticipant(
      familyId: 'family-1',
      instanceId: 'instance-1',
      memberId: 'member-1',
      state: ParticipantMomentState.ready,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    final restored = MomentParticipant.fromMap(
      participant.memberId,
      participant.toMap(),
    );

    expect(restored.state, ParticipantMomentState.ready);
    expect(restored.checkedInAt, isNull);
    expect(restored.confirmedAt, isNull);
    expect(restored.hasCheckedIn, isFalse);
  });
}
