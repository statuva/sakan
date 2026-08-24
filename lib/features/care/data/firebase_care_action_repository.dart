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
      throw ArgumentError(
        'A reminder must be assigned '
        'to a member.',
      );
    }

    if (action.title.trim().isEmpty) {
      throw ArgumentError('Reminder title cannot be empty.');
    }
  }
}
