import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/rhythm_record.dart';
import '../../../shared/repositories/rhythm_repository.dart';

class FirebaseRhythmRepository implements RhythmRepository {
  FirebaseRhythmRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _rhythms(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('rhythms');
  }

  @override
  Stream<List<RhythmRecord>> watchRhythms(String familyId) {
    return _rhythms(familyId).snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((document) => RhythmRecord.fromMap(document.id, document.data()))
          .toList();

      records.sort(
        (first, second) => first.momentId.compareTo(second.momentId),
      );

      return records;
    });
  }

  @override
  Stream<RhythmRecord?> watchRhythm({
    required String familyId,
    required String momentId,
  }) {
    return _rhythms(familyId).doc(momentId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return RhythmRecord.fromMap(snapshot.id, data);
    });
  }

  @override
  Future<void> saveRhythm(RhythmRecord rhythm) {
    return _rhythms(
      rhythm.familyId,
    ).doc(rhythm.momentId).set(rhythm.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteRhythm({
    required String familyId,
    required String momentId,
  }) {
    return _rhythms(familyId).doc(momentId).delete();
  }
}
