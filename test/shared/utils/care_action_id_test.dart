import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/shared/utils/care_action_id.dart';

void main() {
  test('the same occurrence and purpose produce the same reminder ID', () {
    final first = CareActionId.forInsight(
      familyId: 'family',
      memberId: 'adult',
      momentId: 'moment',
      instanceId: 'occurrence',
      purpose: 'prepare',
    );
    final second = CareActionId.forInsight(
      familyId: 'family',
      memberId: 'adult',
      momentId: 'moment',
      instanceId: 'occurrence',
      purpose: 'prepare',
    );
    expect(second, first);
  });

  test('different occurrences do not share a reminder ID', () {
    final first = CareActionId.forInsight(
      familyId: 'family',
      memberId: 'adult',
      momentId: 'moment',
      instanceId: 'first',
      purpose: 'prepare',
    );
    final second = CareActionId.forInsight(
      familyId: 'family',
      memberId: 'adult',
      momentId: 'moment',
      instanceId: 'second',
      purpose: 'prepare',
    );
    expect(second, isNot(first));
  });
}
