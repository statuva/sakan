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
          final blocks = snapshot.docs
              .map(
                (document) =>
                    ScheduleBlock.fromMap(document.id, document.data()),
              )
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
          final blocks = snapshot.docs
              .map(
                (document) =>
                    AvailabilityBlock.fromMap(document.id, document.data()),
              )
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

    if (block.dayOfWeek < 1 || block.dayOfWeek > 7) {
      throw ArgumentError('Schedule day must be between 1 and 7.');
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
  }

  int _compareScheduleBlocks(ScheduleBlock first, ScheduleBlock second) {
    final dayResult = first.dayOfWeek.compareTo(second.dayOfWeek);

    if (dayResult != 0) {
      return dayResult;
    }

    return first.startMinutes.compareTo(second.startMinutes);
  }

  int _compareAvailabilityBlocks(
    AvailabilityBlock first,
    AvailabilityBlock second,
  ) {
    final dayResult = first.dayOfWeek.compareTo(second.dayOfWeek);

    if (dayResult != 0) {
      return dayResult;
    }

    return first.startMinutes.compareTo(second.startMinutes);
  }
}
