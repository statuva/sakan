import '../../../shared/models/family_insight_snapshot.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/rhythm_record.dart';

class CalendarInstanceEntry {
  const CalendarInstanceEntry({
    required this.instance,
    required this.calendarMoment,
    required this.rhythm,
    this.definition,
  });

  final MomentInstance instance;
  final FamilyMoment? definition;
  final FamilyMoment calendarMoment;
  final RhythmRecord? rhythm;

  FamilyMoment get definitionOrSnapshot {
    final existing = definition;

    if (existing != null) {
      return existing;
    }

    return FamilyMoment(
      id: instance.momentId,
      familyId: instance.familyId,
      title: instance.titleSnapshot,
      type: instance.typeSnapshot,
      category: instance.categorySnapshot,
      importanceLevel: instance.importanceLevelSnapshot,
      expectedParticipantIds: instance.expectedParticipantIds,
      startAt: instance.scheduledStartAt,
      endAt: instance.scheduledEndAt,
      location: instance.locationSnapshot,
      evidenceType: EvidenceType.scheduledOnly,
      status: MomentStatus.scheduled,
      createdBy: instance.createdBy,
      createdAt: instance.createdAt,
      updatedAt: instance.updatedAt,
    );
  }
}

List<CalendarInstanceEntry> buildCalendarInstanceEntries(
  FamilyInsightSnapshot snapshot, {
  bool includeCancelled = false,
}) {
  final entries = <CalendarInstanceEntry>[];

  for (final instance in snapshot.instances) {
    if (!includeCancelled &&
        instance.status == MomentInstanceStatus.cancelled) {
      continue;
    }

    final definition = snapshot.momentById(instance.momentId);

    entries.add(
      CalendarInstanceEntry(
        instance: instance,
        definition: definition,
        calendarMoment: projectInstanceForCalendar(
          instance: instance,
          definition: definition,
        ),
        rhythm: snapshot.rhythmForMoment(instance.momentId),
      ),
    );
  }

  entries.sort(
    (first, second) =>
        first.calendarMoment.startAt.compareTo(second.calendarMoment.startAt),
  );

  return entries;
}

FamilyMoment projectInstanceForCalendar({
  required MomentInstance instance,
  FamilyMoment? definition,
}) {
  return FamilyMoment(
    // Existing Calendar widgets use this ID to return the tapped item.
    // The occurrence ID is therefore intentionally used here.
    id: instance.id,
    familyId: instance.familyId,
    title: instance.titleSnapshot,
    type: instance.typeSnapshot,
    category: instance.categorySnapshot,
    importanceLevel: instance.importanceLevelSnapshot,
    expectedParticipantIds: instance.expectedParticipantIds,
    startAt: instance.effectiveStartAt,
    endAt: instance.effectiveEndAt,
    expectedIntervalDays: definition?.expectedIntervalDays,
    location: instance.locationSnapshot,
    notes: instance.reviewNote ?? definition?.notes,
    evidenceType: _evidenceType(instance),
    status: _momentStatus(instance.status),
    createdBy: instance.createdBy,
    createdAt: instance.createdAt,
    updatedAt: instance.updatedAt,
  );
}

MomentStatus _momentStatus(MomentInstanceStatus status) {
  return switch (status) {
    MomentInstanceStatus.proposed ||
    MomentInstanceStatus.scheduled ||
    MomentInstanceStatus.inviting => MomentStatus.scheduled,
    MomentInstanceStatus.active => MomentStatus.active,
    MomentInstanceStatus.completed => MomentStatus.completed,
    MomentInstanceStatus.missed => MomentStatus.missed,
    MomentInstanceStatus.cancelled => MomentStatus.cancelled,
  };
}

EvidenceType _evidenceType(MomentInstance instance) {
  if (instance.status == MomentInstanceStatus.completed) {
    return EvidenceType.userConfirmed;
  }

  if (instance.status == MomentInstanceStatus.active ||
      instance.evidenceSignals.contains(MomentEvidenceSignal.manualCheckIn) ||
      instance.evidenceSignals.contains(MomentEvidenceSignal.todayReview)) {
    return EvidenceType.manual;
  }

  return EvidenceType.scheduledOnly;
}
