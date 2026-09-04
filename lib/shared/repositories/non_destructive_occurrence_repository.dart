import '../models/family_moment.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';

class OccurrenceMaterializationResult {
  const OccurrenceMaterializationResult({
    required this.instance,
    required this.wasCreated,
  });

  final MomentInstance instance;
  final bool wasCreated;
}

abstract interface class NonDestructiveOccurrenceRepository {
  Future<OccurrenceMaterializationResult> materializeOccurrence({
    required FamilyMoment moment,
    required DateTime scheduledStartAt,
    DateTime? scheduledEndAt,
    required String createdBy,
    MomentInstanceSource source = MomentInstanceSource.calendar,
  });
}
