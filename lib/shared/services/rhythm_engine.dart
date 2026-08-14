import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/models/rhythm_record.dart';

abstract interface class RhythmEngine {
  RhythmRecord evaluate({
    required FamilyMoment moment,
    required List<MomentInstance> completedInstances,
    required DateTime now,
  });
}
