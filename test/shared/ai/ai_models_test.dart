import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/shared/ai/ai_models.dart';

void main() {
  test('parses a bounded callable response', () {
    final result = SakanAiResult.fromMap(<String, dynamic>{
      'requestId': 'request',
      'feature': 'homeInsight',
      'title': 'A useful focus',
      'text': 'The recorded data suggests preparing a little earlier.',
      'reasons': <String>['The Moment is approaching.'],
      'suggestedActions': <String>['Choose what to prepare.'],
      'evidenceRefs': <String>['target.moments'],
      'quickReplies': <String>[],
      'reminderTitle': 'Prepare for the Moment',
      'reminderReason': 'A small step before the scheduled Moment.',
      'scenario': null,
      'generatedAt': '2026-09-04T12:00:00.000Z',
      'inputHash': 'hash',
      'cached': false,
    });

    expect(result.title, 'A useful focus');
    expect(result.reasons, hasLength(1));
    expect(result.cached, isFalse);
  });

  test('rejects a response without required text', () {
    expect(
      () => SakanAiResult.fromMap(<String, dynamic>{
        'requestId': 'request',
        'feature': 'chat',
        'generatedAt': '2026-09-04T12:00:00.000Z',
        'inputHash': 'hash',
        'cached': false,
      }),
      throwsFormatException,
    );
  });
}
