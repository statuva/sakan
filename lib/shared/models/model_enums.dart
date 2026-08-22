enum FamilyRole {
  admin,
  adult,
  child,
}

enum FamilyRelationship {
  parent,
  child,
  grandparent,
  sibling,
  guardian,
  relative,
  other,
}

enum AgeGroup {
  adult,
  child,
  teen,
  senior,
}

enum MomentType {
  recurring,
  singular,
}

enum MomentCategory {
  tradition,
  milestone,
  responsibility,
  care,
  familyTime,
  memory,
}

enum EvidenceType {
  scheduledOnly,
  userConfirmed,
  photoAttached,
  hubVerified,
  manual,
}

enum MomentStatus {
  scheduled,
  active,
  completed,
  cancelled,
  missed,
}

enum CareActionStatus {
  pending,
  inProgress,
  completed,
  skipped,
}

/// Describes where a reminder was originally created.
///
/// This allows My Reminders to explain whether an item
/// was created manually or suggested elsewhere in Sakan.
enum CareActionSource {
  manual,
  calendar,
  digitalTwin,
  schedule,
}

enum RhythmStatus {
  stillLearning,
  stable,
  drifting,
  recovering,
  strengthening,
}

enum ConfidenceLevel {
  low,
  medium,
  high,
}