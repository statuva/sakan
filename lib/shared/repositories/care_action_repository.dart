import '../models/care_action.dart';

abstract interface class CareActionRepository {
  Stream<List<CareAction>> watchCareActions(String familyId);

  Stream<List<CareAction>> watchMomentCareActions({
    required String familyId,
    required String momentId,
  });

  Future<void> createCareAction(CareAction action);

  Future<void> updateCareAction(CareAction action);

  Future<void> deleteCareAction({
    required String familyId,
    required String actionId,
  });
}
