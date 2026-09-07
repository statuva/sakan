import '../../../shared/models/availability_block.dart';

class MomentSessionTimingNote {
  const MomentSessionTimingNote({
    required this.title,
    required this.body,
    required this.membersWithScheduleData,
    required this.conflictingMemberIds,
  });

  final String title;
  final String body;
  final int membersWithScheduleData;
  final Set<String> conflictingMemberIds;
}

abstract final class MomentSessionTimingService {
  static MomentSessionTimingNote? build({
    required List<String> expectedParticipantIds,
    required List<AvailabilityBlock> availability,
    required DateTime start,
    required DateTime end,
  }) {
    final expectedIds = expectedParticipantIds.toSet();

    if (expectedIds.isEmpty) {
      return null;
    }

    final relevantBlocks = availability
        .where((block) => expectedIds.contains(block.memberId))
        .toList(growable: false);

    final membersWithScheduleData = relevantBlocks
        .map((block) => block.memberId)
        .toSet();

    if (membersWithScheduleData.isEmpty) {
      return null;
    }

    final conflicts = <String>{};

    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    final startDate = _dateOnly(localStart);
    final endDate = _dateOnly(localEnd);
    final dates = <DateTime>[
      startDate.subtract(const Duration(days: 1)),
      startDate,
      if (!_sameDate(startDate, endDate)) endDate,
    ];

    for (final block in relevantBlocks) {
      for (final blockDate in dates) {
        if (_blockOverlaps(
          block: block,
          blockDate: blockDate,
          start: localStart,
          end: localEnd,
        )) {
          conflicts.add(block.memberId);
          break;
        }
      }
    }

    if (conflicts.isEmpty) {
      final covered = membersWithScheduleData.length;
      final expected = expectedIds.length;

      return MomentSessionTimingNote(
        title: 'The recorded timing looks clear',
        body: covered == expected
            ? 'No recorded busy-time conflicts were found for the expected members during this session.'
            : 'No recorded conflicts were found among the $covered of $expected expected members who have schedule data.',
        membersWithScheduleData: covered,
        conflictingMemberIds: conflicts,
      );
    }

    final count = conflicts.length;

    return MomentSessionTimingNote(
      title: 'Some recorded schedules overlap',
      body:
          '$count ${count == 1 ? 'expected member has' : 'expected members have'} a recorded busy period during this time. The family can still continue if the timing works in real life.',
      membersWithScheduleData: membersWithScheduleData.length,
      conflictingMemberIds: conflicts,
    );
  }

  static bool _blockOverlaps({
    required AvailabilityBlock block,
    required DateTime blockDate,
    required DateTime start,
    required DateTime end,
  }) {
    if (!block.occursOn(blockDate)) return false;

    final busyStart = blockDate.add(Duration(minutes: block.startMinutes));
    var busyEnd = blockDate.add(Duration(minutes: block.endMinutes));
    if (!busyEnd.isAfter(busyStart)) {
      busyEnd = busyEnd.add(const Duration(days: 1));
    }

    return start.isBefore(busyEnd) && end.isAfter(busyStart);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
