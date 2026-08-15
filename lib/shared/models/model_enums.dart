enum FamilyRole { admin, adult, child }

enum FamilyRelationship {
  parent,
  child,
  granparent,
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

enum EvidenceType {
  scheduledOnly,
  userConfirmed,
  photoAttached,
  hubVerified,
  manual,
}

enum MomentStatus { scheduled, active, completed, cancelled, missed }

enum CareActionStatus { pending, inProgress, completed, skipped }

enum RhythmStatus { stillLearning, stable, drifting, recovering, strengthening }

enum ConfidenceLevel { low, medium, high }
