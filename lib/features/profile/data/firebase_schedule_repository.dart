import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:sakan/shared/models/availability_block.dart';
import 'package:sakan/shared/models/schedule_block.dart';
import 'package:sakan/shared/repositories/schedule_repository.dart';

class FirebaseScheduleRepository implements ScheduleRepository {
  FirebaseScheduleRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  void _verifyOwner(String memberId) {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('A signed-in user is required.');
    }

    if (user.uid != memberId) {
      throw StateError('You may edit only your own schedule.');
    }
  }

  DocumentReference<Map<String, dynamic>> _scheduleReference({
    required String familyId,
    required String memberId,
    required String blockId,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .collection('scheduleBlocks')
        .doc(blockId);
  }

  DocumentReference<Map<String, dynamic>> _availabilityReference({
    required String familyId,
    required String memberId,
    required String blockId,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('availabilityBlocks')
        .doc(_availabilityId(memberId: memberId, blockId: blockId));
  }

  String _availabilityId({required String memberId, required String blockId}) {
    return '${memberId}_$blockId';
  }

  @override
  Stream<List<ScheduleBlock>> watchPersonalSchedule({
    required String familyId,
    required String memberId,
  }) {
    _verifyOwner(memberId);

    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .collection('scheduleBlocks')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();

          final blocks = snapshot.docs
              .map(
                (document) =>
                    ScheduleBlock.fromMap(document.id, document.data()),
              )
              .where((block) => !block.isExpiredAt(now))
              .toList();

          blocks.sort(_compareScheduleBlocks);

          return blocks;
        });
  }

  @override
  Stream<List<AvailabilityBlock>> watchFamilyAvailability({
    required String familyId,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('availabilityBlocks')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();

          final blocks = snapshot.docs
              .map(
                (document) =>
                    AvailabilityBlock.fromMap(document.id, document.data()),
              )
              .where((block) => !block.isExpiredAt(now))
              .toList();

          blocks.sort(_compareAvailabilityBlocks);

          return blocks;
        });
  }

  @override
  Future<void> createScheduleBlock(ScheduleBlock block) async {
    _verifyOwner(block.memberId);
    _validateBlock(block);

    final availabilityId = _availabilityId(
      memberId: block.memberId,
      blockId: block.id,
    );

    final availability = AvailabilityBlock.fromScheduleBlock(
      id: availabilityId,
      block: block,
    );

    final batch = _firestore.batch();

    batch.set(
      _scheduleReference(
        familyId: block.familyId,
        memberId: block.memberId,
        blockId: block.id,
      ),
      block.toMap(),
    );

    batch.set(
      _availabilityReference(
        familyId: block.familyId,
        memberId: block.memberId,
        blockId: block.id,
      ),
      availability.toMap(),
    );

    await batch.commit();
  }

  @override
  Future<void> updateScheduleBlock(ScheduleBlock block) async {
    _verifyOwner(block.memberId);
    _validateBlock(block);

    final availabilityId = _availabilityId(
      memberId: block.memberId,
      blockId: block.id,
    );

    final availability = AvailabilityBlock.fromScheduleBlock(
      id: availabilityId,
      block: block,
    );

    final batch = _firestore.batch();

    batch.set(
      _scheduleReference(
        familyId: block.familyId,
        memberId: block.memberId,
        blockId: block.id,
      ),
      block.toMap(),
    );

    batch.set(
      _availabilityReference(
        familyId: block.familyId,
        memberId: block.memberId,
        blockId: block.id,
      ),
      availability.toMap(),
    );

    await batch.commit();
  }

  @override
  Future<void> deleteScheduleBlock({
    required String familyId,
    required String memberId,
    required String blockId,
  }) async {
    _verifyOwner(memberId);

    final batch = _firestore.batch();

    batch.delete(
      _scheduleReference(
        familyId: familyId,
        memberId: memberId,
        blockId: blockId,
      ),
    );

    batch.delete(
      _availabilityReference(
        familyId: familyId,
        memberId: memberId,
        blockId: blockId,
      ),
    );

    await batch.commit();
  }

  void _validateBlock(ScheduleBlock block) {
    if (block.label.trim().isEmpty) {
      throw ArgumentError('Schedule label cannot be empty.');
    }

    if (block.startMinutes < 0 ||
        block.startMinutes >= 1440 ||
        block.endMinutes <= 0 ||
        block.endMinutes > 1440) {
      throw ArgumentError('Schedule times are invalid.');
    }

    if (block.endMinutes <= block.startMinutes) {
      throw ArgumentError('End time must be after start time.');
    }

    if (block.isRecurring) {
      if (block.repeatDays.isEmpty) {
        throw ArgumentError('Choose at least one repeat day.');
      }

      for (final day in block.repeatDays) {
        if (day < 1 || day > 7) {
          throw ArgumentError('Repeat days must be between 1 and 7.');
        }
      }

      if (block.repeatDays.toSet().length != block.repeatDays.length) {
        throw ArgumentError('Repeat days cannot contain duplicates.');
      }

      return;
    }

    final date = block.scheduledDate;

    if (date == null) {
      throw ArgumentError('A one-time schedule needs a date.');
    }

    final localDate = date.toLocal();

    final endDateTime = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
      block.endMinutes ~/ 60,
      block.endMinutes % 60,
    );

    if (!endDateTime.isAfter(DateTime.now())) {
      throw ArgumentError('A one-time schedule must end in the future.');
    }
  }

  int _compareScheduleBlocks(ScheduleBlock first, ScheduleBlock second) {
    if (first.isRecurring != second.isRecurring) {
      // Show upcoming one-time entries first.
      return first.isRecurring ? 1 : -1;
    }

    if (!first.isRecurring) {
      final dateResult = (first.scheduledDate ?? DateTime(9999)).compareTo(
        second.scheduledDate ?? DateTime(9999),
      );

      if (dateResult != 0) {
        return dateResult;
      }

      return first.startMinutes.compareTo(second.startMinutes);
    }

    final firstDay = first.repeatDays.isEmpty ? 8 : first.repeatDays.first;

    final secondDay = second.repeatDays.isEmpty ? 8 : second.repeatDays.first;

    final dayResult = firstDay.compareTo(secondDay);

    if (dayResult != 0) {
      return dayResult;
    }

    return first.startMinutes.compareTo(second.startMinutes);
  }

  int _compareAvailabilityBlocks(
    AvailabilityBlock first,
    AvailabilityBlock second,
  ) {
    if (first.isRecurring != second.isRecurring) {
      return first.isRecurring ? 1 : -1;
    }

    if (!first.isRecurring) {
      final dateResult = (first.scheduledDate ?? DateTime(9999)).compareTo(
        second.scheduledDate ?? DateTime(9999),
      );

      if (dateResult != 0) {
        return dateResult;
      }

      return first.startMinutes.compareTo(second.startMinutes);
    }

    final firstDay = first.repeatDays.isEmpty ? 8 : first.repeatDays.first;

    final secondDay = second.repeatDays.isEmpty ? 8 : second.repeatDays.first;

    final dayResult = firstDay.compareTo(secondDay);

    if (dayResult != 0) {
      return dayResult;
    }

    return first.startMinutes.compareTo(second.startMinutes);
  }
}
