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

enum EvidenceType { scheduledOnly, userConfirmed, photoAttached, manual }

enum MomentStatus { scheduled, active, completed, cancelled, missed }

enum CareActionStatus { pending, inProgress, completed, skipped }

/// Describes where a reminder was created.
enum CareActionSource { manual, calendar, digitalTwin, schedule }

/// Lifecycle of one concrete occurrence of a Family Moment.
enum MomentInstanceStatus {
  proposed,
  scheduled,
  inviting,
  active,
  completed,
  missed,
  cancelled,
}

/// Describes which Sakan flow created an occurrence.
enum MomentInstanceSource {
  calendar,
  familyInsight,
  manual,
  spontaneous,
  todayReview,
}

/// One member's state inside a concrete Moment occurrence.
enum ParticipantMomentState { invited, nearby, checkedIn, declined, left }

/// How a member confirmed participation.
enum MomentCheckInMethod { manual, bluetooth, qr, todayReview }

/// Confidence in the evidence that an occurrence happened.
enum MomentConfirmationLevel { low, medium, high }

/// Individual evidence signals collected for an occurrence.
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
