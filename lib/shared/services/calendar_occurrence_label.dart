import 'package:intl/intl.dart';

import '../models/family_moment.dart';
import '../models/model_enums.dart';
import '../models/moment_instance.dart';

abstract final class CalendarOccurrenceLabel {
  static String forInstance({
    required MomentInstance instance,
    required FamilyMoment? definition,
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toLocal();
    final start = instance.scheduledStartAt.toLocal();
    final recurring =
        definition?.type == MomentType.recurring ||
        instance.typeSnapshot == MomentType.recurring;

    return switch (instance.status) {
      MomentInstanceStatus.proposed || MomentInstanceStatus.scheduled =>
        _sameDay(start, reference)
            ? 'Today · ${DateFormat('h:mm a').format(start)}'
            : 'Upcoming',
      MomentInstanceStatus.inviting => 'Getting ready',
      MomentInstanceStatus.active => 'Live now',
      MomentInstanceStatus.completed =>
        recurring
            ? (_sameDay(start, reference)
                  ? 'Completed today'
                  : 'Completed on ${DateFormat('d MMM').format(start)}')
            : 'Completed',
      MomentInstanceStatus.missed =>
        recurring ? 'Missed this occurrence' : 'Missed',
      MomentInstanceStatus.cancelled =>
        recurring ? 'Cancelled this occurrence' : 'Cancelled',
    };
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
