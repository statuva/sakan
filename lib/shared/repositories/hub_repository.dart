import 'package:sakan/shared/models/hub.dart';

abstract interface class HubRepository {
  Stream<List<Hub>> watchHubs(String familyId);
  Future<Hub?> getHub({required String familyId, required String hubId});

  Future<void> registerHub(Hub hub);

  Future<void> updateHub(Hub hub);
  Future<void> removeHub({required String familyId, required String hubId});
  Future<bool> verifyHub({required String familyId, required String tagIdHash});
}
