import '../models/care_action.dart';

abstract interface class CareActionRepository {
  /// Watches all family Care Actions.
  ///
  /// Intended for authorized family-management
  /// or future Digital Twin functionality.
  Stream<List<CareAction>> watchCareActions(
    String familyId,
  );

  /// Watches only actions assigned to one member.
  ///
  /// My Reminders uses this stream.
  Stream<List<CareAction>>
  watchAssignedCareActions({
    required String familyId,
    required String memberId,
  });

  Stream<List<CareAction>>
  watchMomentCareActions({
    required String familyId,
    required String momentId,
  });

  Future<void> createCareAction(
    CareAction action,
  );

  Future<void> updateCareAction(
    CareAction action,
  );

  Future<void> deleteCareAction({
    required String familyId,
    required String actionId,
  });
}