import '../models/family_moment.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/moment_instance_repository.dart';

/// One-time compatibility helper for families created before MomentInstance
/// documents were introduced.
///
/// It creates only missing open scheduled occurrences. It never fabricates
/// completed history.
class MomentInstanceMigrationService {
  const MomentInstanceMigrationService({
    required CalendarRepository calendarRepository,
    required MomentInstanceRepository momentInstanceRepository,
  }) : _calendarRepository = calendarRepository,
       _momentInstanceRepository = momentInstanceRepository;

  final CalendarRepository _calendarRepository;
  final MomentInstanceRepository _momentInstanceRepository;

  Future<int> backfillCurrentSchedules({
    required String familyId,
    required String currentUserId,
  }) async {
    final results = await Future.wait<Object>([
      _calendarRepository.watchMoments(familyId: familyId).first,
      _momentInstanceRepository.watchInstances(familyId: familyId).first,
    ]);

    final moments = results[0] as List<FamilyMoment>;
    final instances = results[1] as List<MomentInstance>;

    final momentIdsWithInstances = instances
        .map((instance) => instance.momentId)
        .toSet();

    var createdCount = 0;

    for (final moment in moments) {
      if (moment.status != MomentStatus.scheduled ||
          momentIdsWithInstances.contains(moment.id)) {
        continue;
      }

      final created = await _momentInstanceRepository
          .syncScheduledInstanceFromMoment(
            moment: moment,
            createdBy: currentUserId,
            source: MomentInstanceSource.calendar,
          );

      if (created != null) {
        createdCount++;
      }
    }

    return createdCount;
  }
}
