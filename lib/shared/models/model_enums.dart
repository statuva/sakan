enum FamilyRole { admin, adult, child }

enum FamilyRelationship {
  parent,
  child,
  grandparent,
  sibling,
  guardian,
  relative,
  other,
}

enum AgeGroup { adult, child, teen, senior }

enum MomentType { recurring, singular }

enum MomentCategory {
  tradition,
  milestone,
  responsibility,
  care,
  familyTime,
  memory,
}

/// How one occurrence of a Moment is experienced and confirmed.
///
/// sharedSession = Sakan live session, Ready Room, timer, check-ins.
/// externalEvent = something that happens outside the live-session flow,
/// such as a graduation, birthday event, wedding, ceremony, appointment, etc.
enum MomentFormat { sharedSession, externalEvent }

enum EvidenceType { scheduledOnly, userConfirmed, photoAttached, manual }

enum MomentStatus { scheduled, active, completed, cancelled, missed }

enum CareActionStatus { pending, inProgress, completed, skipped }

enum CareActionSource { manual, calendar, digitalTwin, schedule }

enum MomentInstanceStatus {
  proposed,
  scheduled,
  inviting,
  active,
  completed,
  missed,
  cancelled,
}

enum MomentInstanceSource {
  calendar,
  familyInsight,
  manual,
  spontaneous,
  todayReview,
}

enum ParticipantMomentState {
  invited,
  ready,
  nearby,
  checkedIn,
  declined,
  left,
}

enum MomentCheckInMethod { manual, bluetooth, qr, todayReview }

enum MomentConfirmationLevel { low, medium, high }

enum MomentEvidenceSignal {
  scheduled,
  hostStarted,
  manualCheckIn,
  multipleCheckIns,
  durationRecorded,
  bluetoothNearby,
  qrCheckIn,
  todayReview,
  familyNote,
  memoryCreated,
}

enum RhythmStatus { stillLearning, stable, drifting, recovering, strengthening }

enum ConfidenceLevel { low, medium, high }
