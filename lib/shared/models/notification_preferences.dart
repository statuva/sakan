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
      rhythmAlerts: map['rhythmAlerts'] as bool? ?? true,
      careActionReminders: map['careActionReminders'] as bool? ?? true,
      familyInvitations: map['familyInvitations'] as bool? ?? true,
      weeklyReports: map['weeklyReports'] as bool? ?? true,
      importantMoments: map['importantMoments'] as bool? ?? true,
      quietHoursEnabled: map['quietHoursEnabled'] as bool? ?? false,
      quietStartMinutes: map['quietStartMinutes'] as int? ?? 1320,
      quietEndMinutes: map['quietEndMinutes'] as int? ?? 420,
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

  NotificationPreferences copyWith({
    bool? rhythmAlerts,
    bool? careActionReminders,
    bool? familyInvitations,
    bool? weeklyReports,
    bool? importantMoments,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) {
    return NotificationPreferences(
      rhythmAlerts: rhythmAlerts ?? this.rhythmAlerts,
      careActionReminders: careActionReminders ?? this.careActionReminders,
      familyInvitations: familyInvitations ?? this.familyInvitations,
      weeklyReports: weeklyReports ?? this.weeklyReports,
      importantMoments: importantMoments ?? this.importantMoments,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
    );
  }
}
