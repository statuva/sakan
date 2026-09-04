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

List<CalendarInstanceEntry> buildAgendaInstanceEntries(
  List<CalendarInstanceEntry> entries, {
  DateTime? now,
}) {
  final reference = (now ?? DateTime.now()).toLocal();
  final today = DateTime(reference.year, reference.month, reference.day);
  final selectedByMomentId = <String, CalendarInstanceEntry>{};

  for (final entry in entries) {
    final moment = entry.calendarMoment;
    final localStart = moment.startAt.toLocal();
    final startDay = DateTime(
      localStart.year,
      localStart.month,
      localStart.day,
    );

    if (moment.status == MomentStatus.cancelled || startDay.isBefore(today)) {
      continue;
    }

    final current = selectedByMomentId[entry.instance.momentId];

    if (current == null || _compareAgendaEntries(entry, current, today) < 0) {
      selectedByMomentId[entry.instance.momentId] = entry;
    }
  }

  final result = selectedByMomentId.values.toList()
    ..sort(
      (first, second) =>
          first.calendarMoment.startAt.compareTo(second.calendarMoment.startAt),
    );

  return result;
}

int _compareAgendaEntries(
  CalendarInstanceEntry first,
  CalendarInstanceEntry second,
  DateTime today,
) {
  final firstStart = first.calendarMoment.startAt.toLocal();
  final secondStart = second.calendarMoment.startAt.toLocal();
  final firstDay = DateTime(firstStart.year, firstStart.month, firstStart.day);
  final secondDay = DateTime(
    secondStart.year,
    secondStart.month,
    secondStart.day,
  );

  final dayComparison = firstDay.compareTo(secondDay);

  if (dayComparison != 0) {
    return dayComparison;
  }

  final statusComparison = _agendaStatusPriority(
    first.instance.status,
  ).compareTo(_agendaStatusPriority(second.instance.status));

  if (firstDay == today && statusComparison != 0) {
    return statusComparison;
  }

  return firstStart.compareTo(secondStart);
}

int _agendaStatusPriority(MomentInstanceStatus status) {
  return switch (status) {
    MomentInstanceStatus.active => 0,
    MomentInstanceStatus.completed => 1,
    MomentInstanceStatus.missed => 2,
    MomentInstanceStatus.inviting => 3,
    MomentInstanceStatus.proposed || MomentInstanceStatus.scheduled => 4,
    MomentInstanceStatus.cancelled => 5,
  };
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
