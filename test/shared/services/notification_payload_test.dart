import 'package:flutter_test/flutter_test.dart';
import 'package:sakan/shared/services/reminder_notification_service.dart';

void main() {
  test('parses reminder payload through the shared parser', () {
    const reminder = ReminderNotificationPayload(
      familyId: 'family-1',
      reminderId: 'reminder-1',
    );

    final parsed = SakanNotificationPayload.tryParse(reminder.encode());

    expect(parsed, isA<ReminderNotificationPayload>());
    expect(
      (parsed! as ReminderNotificationPayload).reminderId,
      reminder.reminderId,
    );
  });

  test('parses weekly report payload through the shared parser', () {
    const weeklyReport = WeeklyReportNotificationPayload(
      familyId: 'family-1',
      memberId: 'adult-1',
    );

    final parsed = SakanNotificationPayload.tryParse(weeklyReport.encode());

    expect(parsed, isA<WeeklyReportNotificationPayload>());
    final payload = parsed! as WeeklyReportNotificationPayload;
    expect(payload.familyId, weeklyReport.familyId);
    expect(payload.memberId, weeklyReport.memberId);
  });

  test('rejects incomplete weekly report payload', () {
    final parsed = SakanNotificationPayload.tryParse(
      '{"kind":"sakanWeeklyReport","familyId":"family-1"}',
    );

    expect(parsed, isNull);
  });
}
