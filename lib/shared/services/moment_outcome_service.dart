import '../models/family_moment.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/moment_instance_repository.dart';
import 'rhythm_update_service.dart';

class MomentOutcomeResult {
  const MomentOutcomeResult({
    required this.instance,
    required this.rhythmUpdate,
  });

  final MomentInstance instance;
  final RhythmUpdateResult rhythmUpdate;
}

class MomentOutcomeService {
  const MomentOutcomeService({
    required CalendarRepository calendarRepository,
    required MomentInstanceRepository momentInstanceRepository,
    required RhythmUpdateService rhythmUpdateService,
  }) : _calendarRepository = calendarRepository,
       _momentInstanceRepository = momentInstanceRepository,
       _rhythmUpdateService = rhythmUpdateService;

  final CalendarRepository _calendarRepository;
  final MomentInstanceRepository _momentInstanceRepository;
  final RhythmUpdateService _rhythmUpdateService;

  Future<MomentOutcomeResult> endLiveMoment({
    required String familyId,
    required String instanceId,
    required String endedBy,
  }) async {
    final instance = await _momentInstanceRepository.endInstance(
      familyId: familyId,
      instanceId: instanceId,
      endedBy: endedBy,
    );

    final rhythmUpdate = await _rhythmUpdateService.refreshMoment(
      familyId: familyId,
      momentId: instance.momentId,
      updatedBy: endedBy,
    );

    return MomentOutcomeResult(instance: instance, rhythmUpdate: rhythmUpdate);
  }

  Future<MomentOutcomeResult> completeFromTodayReview({
    required String familyId,
    required String instanceId,
    required String reviewedBy,
    required DateTime actualStartAt,
    required int durationMinutes,
    required List<String> reportedParticipantIds,
    String? note,
    bool isPartial = false,
  }) async {
    final instance = await _momentInstanceRepository.completeFromTodayReview(
      familyId: familyId,
      instanceId: instanceId,
      reviewedBy: reviewedBy,
      actualStartAt: actualStartAt,
      durationMinutes: durationMinutes,
      reportedParticipantIds: reportedParticipantIds,
      note: note,
      isPartial: isPartial,
    );

    final rhythmUpdate = await _rhythmUpdateService.refreshMoment(
      familyId: familyId,
      momentId: instance.momentId,
      updatedBy: reviewedBy,
    );

    return MomentOutcomeResult(instance: instance, rhythmUpdate: rhythmUpdate);
  }

  Future<MomentOutcomeResult> markMissed({
    required String familyId,
    required String instanceId,
    required String updatedBy,
  }) async {
    final instance = await _momentInstanceRepository.markMissed(
      familyId: familyId,
      instanceId: instanceId,
      updatedBy: updatedBy,
    );

    final rhythmUpdate = await _rhythmUpdateService.refreshMoment(
      familyId: familyId,
      momentId: instance.momentId,
      updatedBy: updatedBy,
    );

    return MomentOutcomeResult(instance: instance, rhythmUpdate: rhythmUpdate);
  }

  Future<MomentInstance> reschedule({
    required String familyId,
    required String instanceId,
    required String updatedBy,
    required DateTime scheduledStartAt,
    DateTime? scheduledEndAt,
  }) async {
    final instance = await _momentInstanceRepository.rescheduleInstance(
      familyId: familyId,
      instanceId: instanceId,
      updatedBy: updatedBy,
      scheduledStartAt: scheduledStartAt,
      scheduledEndAt: scheduledEndAt,
    );

    final moment = await _calendarRepository.getMoment(
      familyId: familyId,
      momentId: instance.momentId,
    );

    if (moment != null) {
      await _calendarRepository.saveMoment(
        moment.copyWith(
          startAt: instance.scheduledStartAt,
          endAt: instance.scheduledEndAt,
          status: MomentStatus.scheduled,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }

    return instance;
  }

  Future<MomentOutcomeResult> logUnplannedMoment({
    required String familyId,
    required String createdBy,
    required String title,
    required MomentCategory category,
    required int importanceLevel,
    required List<String> participantIds,
    required DateTime actualStartAt,
    required int durationMinutes,
    required bool saveAsRecurring,
    required int expectedIntervalDays,
    String? note,
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Enter a name for the family Moment.');
    }

    if (participantIds.isEmpty) {
      throw ArgumentError('Choose at least one participant.');
    }

    if (durationMinutes < 0) {
      throw ArgumentError('Duration cannot be negative.');
    }

    if (saveAsRecurring && expectedIntervalDays <= 0) {
      throw ArgumentError('Choose a valid recurring interval.');
    }

    final now = DateTime.now().toUtc();
    final start = actualStartAt.toUtc();
    final end = start.add(Duration(minutes: durationMinutes));

    if (end.isAfter(now.add(const Duration(minutes: 5)))) {
      throw ArgumentError('The unplanned Moment cannot end in the future.');
    }

    final momentId =
        'moment_${createdBy}_'
        '${DateTime.now().microsecondsSinceEpoch}';

    final moment = FamilyMoment(
      id: momentId,
      familyId: familyId,
      title: title.trim(),
      type: saveAsRecurring ? MomentType.recurring : MomentType.singular,
      category: category,
      importanceLevel: importanceLevel,
      expectedParticipantIds: participantIds.toSet().toList(),
      startAt: start,
      endAt: end,
      expectedIntervalDays: saveAsRecurring ? expectedIntervalDays : null,
      notes: note == null || note.trim().isEmpty ? null : note.trim(),
      evidenceType: EvidenceType.manual,
      status: MomentStatus.completed,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );

    await _calendarRepository.saveMoment(moment);

    final instance = await _momentInstanceRepository
        .createCompletedUnplannedInstance(
          moment: moment,
          reportedBy: createdBy,
          actualStartAt: start,
          durationMinutes: durationMinutes,
          reportedParticipantIds: participantIds,
          note: note,
        );

    final rhythmUpdate = await _rhythmUpdateService.refreshMoment(
      familyId: familyId,
      momentId: moment.id,
      updatedBy: createdBy,
    );

    return MomentOutcomeResult(instance: instance, rhythmUpdate: rhythmUpdate);
  }
}
