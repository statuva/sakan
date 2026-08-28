import 'package:flutter_test/flutter_test.dart';

import 'package:sakan/shared/models/family_memory.dart';

void main() {
  test('FamilyMemory preserves instanceId', () {
    final now = DateTime.utc(2026, 8, 28);

    final memory = FamilyMemory(
      id: 'instance-1',
      familyId: 'family-1',
      momentId: 'moment-1',
      instanceId: 'instance-1',
      title: 'Movie Night',
      occurredAt: now,
      photoUrls: const <String>[],
      participantIds: const <String>['member-1'],
      note: 'A good family evening.',
      createdAt: now,
      updatedAt: now,
    );

    final restored = FamilyMemory.fromMap(
      memory.id,
      memory.toMap(),
    );

    expect(restored.instanceId, 'instance-1');
    expect(restored.momentId, 'moment-1');
  });
}
