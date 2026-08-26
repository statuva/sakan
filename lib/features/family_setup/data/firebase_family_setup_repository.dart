import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/family_moment.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/moment_instance.dart';
import 'package:sakan/shared/models/rhythm_record.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';
import 'package:sakan/shared/repositories/family_setup_repository.dart';

class FirebaseFamilySetupRepository implements FamilySetupRepository {
  FirebaseFamilySetupRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _currentUserId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('A signed-in user is required.');
    }

    return user.uid;
  }

  @override
  Stream<Family?> watchFamily(String familyId) {
    return _firestore.collection('families').doc(familyId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return Family.fromMap(snapshot.id, data);
    });
  }

  @override
  Stream<List<Member>> watchMembers(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final members = snapshot.docs
              .map((document) => Member.fromMap(document.id, document.data()))
              .toList();

          members.sort(
            (first, second) => first.displayName.compareTo(second.displayName),
          );

          return members;
        });
  }

  @override
  Future<void> updateMemberRelationship({
    required String familyId,
    required String memberId,
    required FamilyRelationship relationship,
  }) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .update({
          'relationship': relationship.name,
          'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
        });
  }

  @override
  Future<void> completeSetup({
    required String familyId,
    required List<RhythmSetupDraft> rhythms,
  }) async {
    if (rhythms.isEmpty) {
      throw ArgumentError('At least one family rhythm is required.');
    }

    final currentUserId = _currentUserId;
    final now = DateTime.now().toUtc();

    final familyReference = _firestore.collection('families').doc(familyId);

    final batch = _firestore.batch();

    for (final draft in rhythms) {
      if (draft.expectedParticipantIds.isEmpty) {
        throw ArgumentError(
          '${draft.title} requires '
          'at least one participant.',
        );
      }

      final momentReference = familyReference.collection('moments').doc();

      final currentGapDays = draft.lastOccurrenceAt == null
          ? 0
          : now.difference(draft.lastOccurrenceAt!.toUtc()).inDays;

      final moment = FamilyMoment(
        id: momentReference.id,
        familyId: familyId,
        title: draft.title.trim(),
        type: MomentType.recurring,
        category: draft.category,
        importanceLevel: draft.importanceLevel,
        expectedParticipantIds: List<String>.unmodifiable(
          draft.expectedParticipantIds,
        ),
        startAt: draft.nextOccurrenceAt.toUtc(),
        expectedIntervalDays: draft.expectedIntervalDays,
        notes: draft.description.trim().isEmpty
            ? null
            : draft.description.trim(),
        evidenceType: EvidenceType.manual,
        status: MomentStatus.scheduled,
        createdBy: currentUserId,
        createdAt: now,
        updatedAt: now,
      );

      final rhythm = RhythmRecord(
        id: momentReference.id,
        familyId: familyId,
        momentId: momentReference.id,
        expectedIntervalDays: draft.expectedIntervalDays,
        lastOccurrenceAt: draft.lastOccurrenceAt?.toUtc(),
        currentGapDays: currentGapDays,
        occurrenceCount: 0,
        status: RhythmStatus.stillLearning,
        confidence: ConfidenceLevel.low,
        updatedAt: now,
      );

      final instanceId =
          'instance_${moment.id}_'
          '${moment.startAt.millisecondsSinceEpoch}';

      final instance = MomentInstance.scheduledFromMoment(
        id: instanceId,
        moment: moment,
        source: MomentInstanceSource.calendar,
        createdBy: currentUserId,
        now: now,
      );

      batch.set(momentReference, moment.toMap());

      batch.set(
        familyReference.collection('rhythms').doc(momentReference.id),
        rhythm.toMap(),
      );

      batch.set(
        familyReference.collection('momentInstances').doc(instance.id),
        instance.toMap(),
      );
    }

    batch.update(familyReference, {
      'setupComplete': true,
      'baselineCreatedAt': Timestamp.fromDate(now),
      'baselineCreatedBy': currentUserId,
      'updatedAt': Timestamp.fromDate(now),
    });

    await batch.commit();
  }
}
