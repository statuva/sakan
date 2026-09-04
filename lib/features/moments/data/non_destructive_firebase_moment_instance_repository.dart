import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/repositories/non_destructive_occurrence_repository.dart';
import 'firebase_moment_instance_repository.dart';

class NonDestructiveFirebaseMomentInstanceRepository
    extends FirebaseMomentInstanceRepository
    implements NonDestructiveOccurrenceRepository {
  NonDestructiveFirebaseMomentInstanceRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       super(auth: auth, firestore: firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<MomentInstance> scheduleOccurrence({
    required FamilyMoment moment,
    required DateTime scheduledStartAt,
    DateTime? scheduledEndAt,
    required String createdBy,
    MomentInstanceSource source = MomentInstanceSource.manual,
  }) async {
    final result = await materializeOccurrence(
      moment: moment,
      scheduledStartAt: scheduledStartAt,
      scheduledEndAt: scheduledEndAt,
      createdBy: createdBy,
      source: source,
    );
    return result.instance;
  }

  @override
  Future<OccurrenceMaterializationResult> materializeOccurrence({
    required FamilyMoment moment,
    required DateTime scheduledStartAt,
    DateTime? scheduledEndAt,
    required String createdBy,
    MomentInstanceSource source = MomentInstanceSource.calendar,
  }) async {
    _validateRequest(moment: moment, createdBy: createdBy);

    final start = scheduledStartAt.toUtc();
    final end = scheduledEndAt?.toUtc();
    if (end != null && !end.isAfter(start)) {
      throw ArgumentError('The end time must be after the start time.');
    }

    final id = _scheduledInstanceId(
      momentId: moment.id,
      scheduledStartAt: start,
    );
    final reference = _firestore
        .collection('families')
        .doc(moment.familyId)
        .collection('momentInstances')
        .doc(id);
    final createdAt = DateTime.now().toUtc();
    final candidate = MomentInstance.scheduledFromMoment(
      id: id,
      moment: moment,
      source: source,
      scheduledStartAt: start,
      scheduledEndAt: end,
      createdBy: createdBy,
      now: createdAt,
    );

    return _firestore.runTransaction<OccurrenceMaterializationResult>((
      transaction,
    ) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();

      if (snapshot.exists) {
        if (data == null) {
          throw StateError('The existing Moment occurrence is unreadable.');
        }

        final existing = MomentInstance.fromMap(snapshot.id, data);
        if (existing.familyId != moment.familyId ||
            existing.momentId != moment.id) {
          throw StateError('The Moment occurrence identifier is already used.');
        }

        return OccurrenceMaterializationResult(
          instance: existing,
          wasCreated: false,
        );
      }

      transaction.set(reference, candidate.toMap());
      return OccurrenceMaterializationResult(
        instance: candidate,
        wasCreated: true,
      );
    });
  }

  void _validateRequest({
    required FamilyMoment moment,
    required String createdBy,
  }) {
    final user = _auth.currentUser;
    if (user == null || user.uid != createdBy) {
      throw StateError('This action must use the signed-in member.');
    }
    if (moment.familyId.trim().isEmpty || moment.id.trim().isEmpty) {
      throw ArgumentError('The Family Moment is invalid.');
    }
    if (moment.title.trim().isEmpty) {
      throw ArgumentError('Moment title cannot be empty.');
    }
    if (moment.expectedParticipantIds.isEmpty) {
      throw ArgumentError('Choose at least one expected participant.');
    }
  }

  String _scheduledInstanceId({
    required String momentId,
    required DateTime scheduledStartAt,
  }) {
    return 'instance_${momentId}_'
        '${scheduledStartAt.millisecondsSinceEpoch}';
  }
}
