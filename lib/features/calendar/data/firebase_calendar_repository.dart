import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/rhythm_record.dart';
import '../../../shared/repositories/calendar_repository.dart';

class FirebaseCalendarRepository implements CalendarRepository {
  FirebaseCalendarRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _moments(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('moments');
  }

  CollectionReference<Map<String, dynamic>> _rhythms(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('rhythms');
  }

  @override
  Stream<List<FamilyMoment>> watchMoments({required String familyId}) {
    return _moments(familyId).snapshots().map((snapshot) {
      final moments = snapshot.docs
          .map((document) => FamilyMoment.fromMap(document.id, document.data()))
          .toList();

      moments.sort((first, second) => first.startAt.compareTo(second.startAt));
      return moments;
    });
  }

  @override
  Stream<List<RhythmRecord>> watchRhythms({required String familyId}) {
    return _rhythms(familyId).snapshots().map((snapshot) {
      final rhythms = snapshot.docs
          .map((document) => RhythmRecord.fromMap(document.id, document.data()))
          .toList();

      rhythms.sort(
        (first, second) => first.momentId.compareTo(second.momentId),
      );
      return rhythms;
    });
  }

  @override
  Future<void> saveMoment(FamilyMoment moment) async {
    final momentReference = _moments(moment.familyId).doc(moment.id);
    final rhythmReference = _rhythms(moment.familyId).doc(moment.id);

    await _firestore.runTransaction<void>((transaction) async {
      final rhythmSnapshot = await transaction.get(rhythmReference);

      transaction.set(momentReference, moment.toMap());

      if (moment.type == MomentType.recurring) {
        final intervalDays = moment.expectedIntervalDays ?? 7;

        if (rhythmSnapshot.exists && rhythmSnapshot.data() != null) {
          final existing = RhythmRecord.fromMap(
            rhythmSnapshot.id,
            rhythmSnapshot.data()!,
          );

          final updated = RhythmRecord(
            id: moment.id,
            familyId: moment.familyId,
            momentId: moment.id,
            expectedIntervalDays: intervalDays,
            lastOccurrenceAt: existing.lastOccurrenceAt,
            currentGapDays: existing.currentGapDays,
            occurrenceCount: existing.occurrenceCount,
            status: existing.status,
            confidence: existing.confidence,
            updatedAt: DateTime.now().toUtc(),
          );

          transaction.set(rhythmReference, updated.toMap());
        } else {
          final created = RhythmRecord(
            id: moment.id,
            familyId: moment.familyId,
            momentId: moment.id,
            expectedIntervalDays: intervalDays,
            currentGapDays: 0,
            occurrenceCount: 0,
            status: RhythmStatus.stillLearning,
            confidence: ConfidenceLevel.low,
            updatedAt: DateTime.now().toUtc(),
          );

          transaction.set(rhythmReference, created.toMap());
        }
      } else if (rhythmSnapshot.exists) {
        transaction.delete(rhythmReference);
      }
    });
  }

  @override
  Future<void> deleteMoment({
    required String familyId,
    required String momentId,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_moments(familyId).doc(momentId));
    batch.delete(_rhythms(familyId).doc(momentId));
    await batch.commit();
  }
}
