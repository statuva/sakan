import 'package:sakan/shared/models/availability_block.dart';
import 'package:sakan/shared/models/schedule_block.dart';

abstract interface class ScheduleRepository {
  /// The signed-in member's private recurring schedule.
  Stream<List<ScheduleBlock>> watchPersonalSchedule({
    required String familyId,
    required String memberId,
  });

  /// Busy periods used later by the Calendar and availability engine.
  ///
  /// These records do not contain personal schedule labels.
  Stream<List<AvailabilityBlock>> watchFamilyAvailability({
    required String familyId,
  });

  Future<void> createScheduleBlock(ScheduleBlock block);

  Future<void> updateScheduleBlock(ScheduleBlock block);

  Future<void> deleteScheduleBlock({
    required String familyId,
    required String memberId,
    required String blockId,
  });
}
