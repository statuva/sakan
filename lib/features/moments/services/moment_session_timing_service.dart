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

    for (final block in relevantBlocks) {
      if (!block.occursOn(start)) {
        continue;
      }

      if (_overlaps(
        start: start,
        end: end,
        busyStartMinutes: block.startMinutes,
        busyEndMinutes: block.endMinutes,
      )) {
        conflicts.add(block.memberId);
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

  static bool _overlaps({
    required DateTime start,
    required DateTime end,
    required int busyStartMinutes,
    required int busyEndMinutes,
  }) {
    final localStart = start.toLocal();
    final localEnd = end.toLocal();

    final sessionStart = localStart.hour * 60 + localStart.minute;
    var sessionEnd = localEnd.hour * 60 + localEnd.minute;

    if (!_sameDate(localStart, localEnd) || sessionEnd <= sessionStart) {
      sessionEnd += 24 * 60;
    }

    final busyStart = busyStartMinutes.clamp(0, 1439).toInt();
    var busyEnd = busyEndMinutes.clamp(0, 1439).toInt();

    if (busyEnd <= busyStart) {
      busyEnd += 24 * 60;
    }

    return busyStart < sessionEnd && busyEnd > sessionStart;
  }

  static bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
