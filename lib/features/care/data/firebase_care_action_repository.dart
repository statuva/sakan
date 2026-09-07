import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/care_action.dart';
import '../../../shared/repositories/care_action_repository.dart';

class FirebaseCareActionRepository implements CareActionRepository {
  FirebaseCareActionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _actions(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('careActions');
  }

  @override
  Stream<List<CareAction>> watchCareActions(String familyId) {
    return _actions(familyId).snapshots().map(_mapActions);
  }

  @override
  Stream<List<CareAction>> watchAssignedCareActions({
    required String familyId,
    required String memberId,
  }) {
    return _actions(familyId)
        .where('assignedMemberId', isEqualTo: memberId)
        .snapshots()
        .map(_mapActions);
  }

  @override
  Stream<List<CareAction>> watchMomentCareActions({
    required String familyId,
    required String momentId,
  }) {
    return _actions(
      familyId,
    ).where('momentId', isEqualTo: momentId).snapshots().map(_mapActions);
  }

  @override
  Future<void> createCareAction(CareAction action) {
    _validateAction(action);
    return _actions(action.familyId).doc(action.id).set(action.toMap());
  }

  /// Creates an AI/recommendation reminder once and returns the stored value.
  /// A retry returns the stored reminder instead of intentionally replacing it.
  Future<CareAction> createCareActionIfAbsent(CareAction action) async {
    _validateAction(action);
    final reference = _actions(action.familyId).doc(action.id);

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        final existing = snapshot.data();
        if (snapshot.exists && existing != null) {
          return CareAction.fromMap(snapshot.id, existing);
        }

        transaction.set(reference, action.toMap());
        return action;
      });
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }

      // A child or teen may create and read a reminder assigned to them, but
      // cannot read a missing family Care Action document. That makes the
      // transaction's first get fail before the permitted create is reached.
      // Use an ownership-filtered query, which satisfies the existing read
      // rule, then create the same deterministic document directly.
      return _createAfterAssignedLookup(action);
    }
  }

  Future<CareAction> _createAfterAssignedLookup(CareAction action) async {
    final existing = await _findAssignedActionById(action);
    if (existing != null) {
      return existing;
    }

    final reference = _actions(action.familyId).doc(action.id);

    try {
      await reference.set(action.toMap());
      return action;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }

      // If another device created the deterministic reminder after the query,
      // return that stored value instead of replacing or duplicating it.
      final racedExisting = await _findAssignedActionById(action);
      if (racedExisting != null) {
        return racedExisting;
      }

      rethrow;
    }
  }

  Future<CareAction?> _findAssignedActionById(CareAction action) async {
    final snapshot = await _actions(action.familyId)
        .where('assignedMemberId', isEqualTo: action.assignedMemberId)
        .get();

    for (final document in snapshot.docs) {
      if (document.id == action.id) {
        return CareAction.fromMap(document.id, document.data());
      }
    }

    return null;
  }

  @override
  Future<void> updateCareAction(CareAction action) {
    _validateAction(action);

    return _actions(
      action.familyId,
    ).doc(action.id).set(action.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteCareAction({
    required String familyId,
    required String actionId,
  }) {
    return _actions(familyId).doc(actionId).delete();
  }

  List<CareAction> _mapActions(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final actions = snapshot.docs
        .map((document) => CareAction.fromMap(document.id, document.data()))
        .toList();

    actions.sort((first, second) => first.dueAt.compareTo(second.dueAt));
    return actions;
  }

  void _validateAction(CareAction action) {
    if (action.familyId.trim().isEmpty) {
      throw ArgumentError('Reminder family ID cannot be empty.');
    }
    if (action.assignedMemberId.trim().isEmpty) {
      throw ArgumentError('A reminder must be assigned to a member.');
    }
    if (action.title.trim().isEmpty) {
      throw ArgumentError('Reminder title cannot be empty.');
    }
  }
}
