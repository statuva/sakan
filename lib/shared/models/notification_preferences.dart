class NotificationPreferences {
  const NotificationPreferences({
    this.rhythmAlerts = true,
    this.careActionReminders = true,
    this.familyInvitations = true,
    this.weeklyReports = true,
    this.importantMoments = true,
    this.quietHoursEnabled = false,
    this.quietStartMinutes = 1320,
    this.quietEndMinutes = 420,
  });

  final bool rhythmAlerts;
  final bool careActionReminders;
  final bool familyInvitations;
  final bool weeklyReports;
  final bool importantMoments;

  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const NotificationPreferences();
    }

    return NotificationPreferences(
      rhythmAlerts: map['rhythmAlerts'] ?? true,
      careActionReminders: map['careActionReminders'] ?? true,
      familyInvitations: map['familyInvitations'] ?? true,
      weeklyReports: map['weeklyReports'] ?? true,
      importantMoments: map['importantMoments'] ?? true,
      quietHoursEnabled: map['quietHoursEnabled'] ?? false,
      quietStartMinutes: map['quietStartMinutes'] ?? 1320,
      quietEndMinutes: map['quietEndMinutes'] ?? 420,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rhythmAlerts': rhythmAlerts,
      'careActionReminders': careActionReminders,
      'familyInvitations': familyInvitations,
      'weeklyReports': weeklyReports,
      'importantMoments': importantMoments,
      'quietHoursEnabled': quietHoursEnabled,
      'quietStartMinutes': quietStartMinutes,
      'quietEndMinutes': quietEndMinutes,
    };
  }
}
