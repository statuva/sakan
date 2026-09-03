import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/moment_participant.dart';

class PreparedMomentSession {
  const PreparedMomentSession({
    required this.instance,
    required this.preparedBy,
    required this.createdForPreparation,
  });

  final MomentInstance instance;
  final String preparedBy;
  final bool createdForPreparation;
}

/// Owns the short-lived Ready Room state before a shared Moment becomes live.
///
/// Preparation is persisted as an `inviting` MomentInstance so the same record
/// can later support remote invitations and Bluetooth nearby evidence. The
/// actual timer is not started until the existing Moment repository transitions
/// the occurrence to `active`.
class MomentSessionPreparationService {
  MomentSessionPreparationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  static const Duration staleAfter = Duration(minutes: 30);

  static const String _preparedByField = 'preparedBy';
  static const String _preparedAtField = 'preparedAt';
  static const String _originalStatusField = 'preparationOriginalStatus';
  static const String _createdForPreparationField =
      'preparationCreatedOccurrence';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _instances(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('momentInstances');
  }

  DocumentReference<Map<String, dynamic>> _instanceReference({
    required String familyId,
    required String instanceId,
  }) {
    return _instances(familyId).doc(instanceId);
  }

  CollectionReference<Map<String, dynamic>> _participants({
    required String familyId,
    required String instanceId,
  }) {
    return _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    ).collection('participants');
  }

  Future<PreparedMomentSession> prepare({
    required FamilyMoment moment,
    required String preparedBy,
    required MomentInstanceSource source,
    String? existingInstanceId,
  }) async {
    _verifyCurrentUser(preparedBy);

    if (moment.familyId.trim().isEmpty || moment.id.trim().isEmpty) {
      throw ArgumentError('The Family Moment is incomplete.');
    }

    if (moment.expectedParticipantIds.isEmpty) {
      throw StateError('Add at least one expected participant first.');
    }

    await _clearStalePreparations(
      familyId: moment.familyId,
      currentInstanceId: existingInstanceId,
      updatedBy: preparedBy,
    );

    final openSnapshot = await _instances(moment.familyId).get();

    for (final document in openSnapshot.docs) {
      final instance = MomentInstance.fromMap(document.id, document.data());

      if (instance.status == MomentInstanceStatus.active) {
        throw StateError(
          '${instance.titleSnapshot} is already live. '
          'End it before preparing another Moment.',
        );
      }

      if (instance.status == MomentInstanceStatus.inviting &&
          instance.id != existingInstanceId) {
        throw StateError(
          '${instance.titleSnapshot} already has an open Ready Room.',
        );
      }
    }

    final now = DateTime.now().toUtc();
    final reference = existingInstanceId == null
        ? null
        : _instanceReference(
            familyId: moment.familyId,
            instanceId: existingInstanceId,
          );

    MomentInstance instance;
    var createdForPreparation = false;
    String? originalStatus;

    if (reference != null) {
      final existingSnapshot = await reference.get();
      final data = existingSnapshot.data();

      if (!existingSnapshot.exists || data == null) {
        throw StateError('The selected Moment occurrence no longer exists.');
      }

      final existing = MomentInstance.fromMap(existingSnapshot.id, data);

      if (existing.momentId != moment.id) {
        throw StateError('This occurrence belongs to a different Moment.');
      }

      final canPrepare =
          existing.status == MomentInstanceStatus.proposed ||
          existing.status == MomentInstanceStatus.scheduled ||
          existing.status == MomentInstanceStatus.inviting;

      if (!canPrepare) {
        throw StateError('This Moment occurrence cannot enter a Ready Room.');
      }

      if (existing.status == MomentInstanceStatus.inviting) {
        originalStatus = data[_originalStatusField] as String?;
      } else {
        originalStatus = existing.status.name;
      }

      createdForPreparation =
          data[_createdForPreparationField] as bool? ?? false;

      instance = existing.copyWith(
        status: MomentInstanceStatus.inviting,
        updatedAt: now,
      );
    } else {
      createdForPreparation = true;
      final duration = _plannedDuration(moment);
      final instanceId =
          'instance_${moment.id}_ready_${DateTime.now().microsecondsSinceEpoch}';

      final scheduled = MomentInstance.scheduledFromMoment(
        id: instanceId,
        moment: moment,
        source: source,
        createdBy: preparedBy,
        scheduledStartAt: now,
        scheduledEndAt: duration == null ? null : now.add(duration),
        now: now,
      );

      instance = scheduled.copyWith(
        status: MomentInstanceStatus.inviting,
        updatedAt: now,
      );
    }

    final data = instance.toMap()
      ..[_preparedByField] = preparedBy
      ..[_preparedAtField] = Timestamp.fromDate(now)
      ..[_originalStatusField] = originalStatus
      ..[_createdForPreparationField] = createdForPreparation;

    await _instanceReference(
      familyId: instance.familyId,
      instanceId: instance.id,
    ).set(data, SetOptions(merge: true));

    return PreparedMomentSession(
      instance: instance,
      preparedBy: preparedBy,
      createdForPreparation: createdForPreparation,
    );
  }

  Future<PreparedMomentSession?> loadPreparedSession({
    required String familyId,
    required String instanceId,
  }) async {
    final snapshot = await _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    ).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    final instance = MomentInstance.fromMap(snapshot.id, data);

    if (instance.status != MomentInstanceStatus.inviting) {
      return null;
    }

    return PreparedMomentSession(
      instance: instance,
      preparedBy: data[_preparedByField] as String? ?? instance.createdBy,
      createdForPreparation:
          data[_createdForPreparationField] as bool? ?? false,
    );
  }

  Future<void> joinReadyRoom({
    required String familyId,
    required String instanceId,
    required String memberId,
  }) async {
    _verifyCurrentUser(memberId);

    final instanceSnapshot = await _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    ).get();
    final instanceData = instanceSnapshot.data();

    if (!instanceSnapshot.exists || instanceData == null) {
      throw StateError('This Ready Room no longer exists.');
    }

    final instance = MomentInstance.fromMap(instanceSnapshot.id, instanceData);

    if (instance.status != MomentInstanceStatus.inviting) {
      throw StateError('This Ready Room is no longer open.');
    }

    if (!instance.expectedParticipantIds.contains(memberId)) {
      throw StateError('You are not listed for this Family Moment.');
    }

    final reference = _participants(
      familyId: familyId,
      instanceId: instanceId,
    ).doc(memberId);
    final participantSnapshot = await reference.get();
    final participantData = participantSnapshot.data();
    final now = DateTime.now().toUtc();

    final participant = participantSnapshot.exists && participantData != null
        ? MomentParticipant.fromMap(
            participantSnapshot.id,
            participantData,
          ).copyWith(
            state: ParticipantMomentState.ready,
            checkInMethod: null,
            checkedInAt: null,
            checkedOutAt: null,
            confirmedAt: null,
            updatedAt: now,
          )
        : MomentParticipant(
            familyId: familyId,
            instanceId: instanceId,
            memberId: memberId,
            state: ParticipantMomentState.ready,
            createdAt: now,
            updatedAt: now,
          );

    await reference.set(participant.toMap(), SetOptions(merge: true));
  }

  Future<void> leaveReadyRoom({
    required String familyId,
    required String instanceId,
    required String memberId,
  }) async {
    _verifyCurrentUser(memberId);

    final instanceSnapshot = await _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    ).get();
    final instanceData = instanceSnapshot.data();

    if (!instanceSnapshot.exists || instanceData == null) {
      return;
    }

    final instance = MomentInstance.fromMap(instanceSnapshot.id, instanceData);

    if (instance.status != MomentInstanceStatus.inviting) {
      return;
    }

    final reference = _participants(
      familyId: familyId,
      instanceId: instanceId,
    ).doc(memberId);
    final participantSnapshot = await reference.get();
    final participantData = participantSnapshot.data();

    if (!participantSnapshot.exists || participantData == null) {
      return;
    }

    final existing = MomentParticipant.fromMap(
      participantSnapshot.id,
      participantData,
    );

    if (existing.state != ParticipantMomentState.ready) {
      return;
    }

    final nextState = existing.nearbyDetectedAt == null
        ? ParticipantMomentState.invited
        : ParticipantMomentState.nearby;

    await reference.set(
      existing
          .copyWith(
            state: nextState,
            checkInMethod: null,
            checkedInAt: null,
            checkedOutAt: null,
            confirmedAt: null,
            updatedAt: DateTime.now().toUtc(),
          )
          .toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> cancelPreparation({
    required String familyId,
    required String instanceId,
    required String cancelledBy,
  }) async {
    _verifyCurrentUser(cancelledBy);

    final reference = _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    );

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return;
    }

    final instance = MomentInstance.fromMap(snapshot.id, data);

    if (instance.status != MomentInstanceStatus.inviting) {
      await clearPreparationMetadata(
        familyId: familyId,
        instanceId: instanceId,
      );
      return;
    }

    final createdForPreparation =
        data[_createdForPreparationField] as bool? ?? false;
    final originalStatus = _safeOriginalStatus(data[_originalStatusField]);
    final now = DateTime.now().toUtc();

    await _resetReadyParticipants(
      familyId: familyId,
      instanceId: instanceId,
      now: now,
    );

    await reference.update(<String, dynamic>{
      'status': createdForPreparation
          ? MomentInstanceStatus.cancelled.name
          : originalStatus.name,
      'updatedAt': Timestamp.fromDate(now),
      _preparedByField: FieldValue.delete(),
      _preparedAtField: FieldValue.delete(),
      _originalStatusField: FieldValue.delete(),
      _createdForPreparationField: FieldValue.delete(),
    });
  }

  Future<void> clearPreparationMetadata({
    required String familyId,
    required String instanceId,
  }) async {
    final reference = _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    );

    try {
      await reference.update(<String, dynamic>{
        _preparedByField: FieldValue.delete(),
        _preparedAtField: FieldValue.delete(),
        _originalStatusField: FieldValue.delete(),
        _createdForPreparationField: FieldValue.delete(),
      });
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') {
        rethrow;
      }
    }
  }

  Future<void> _clearStalePreparations({
    required String familyId,
    required String? currentInstanceId,
    required String updatedBy,
  }) async {
    final snapshot = await _instances(
      familyId,
    ).where('status', isEqualTo: MomentInstanceStatus.inviting.name).get();

    final now = DateTime.now().toUtc();

    for (final document in snapshot.docs) {
      if (document.id == currentInstanceId) {
        continue;
      }

      final data = document.data();
      final preparedAt = _dateFromMap(data[_preparedAtField]);

      if (preparedAt == null || now.difference(preparedAt) >= staleAfter) {
        await cancelPreparation(
          familyId: familyId,
          instanceId: document.id,
          cancelledBy: updatedBy,
        );
      }
    }
  }

  Future<void> _resetReadyParticipants({
    required String familyId,
    required String instanceId,
    required DateTime now,
  }) async {
    final snapshot = await _participants(
      familyId: familyId,
      instanceId: instanceId,
    ).where('state', isEqualTo: ParticipantMomentState.ready.name).get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final document in snapshot.docs) {
      final participant = MomentParticipant.fromMap(
        document.id,
        document.data(),
      );
      final nextState = participant.nearbyDetectedAt == null
          ? ParticipantMomentState.invited
          : ParticipantMomentState.nearby;

      batch.update(document.reference, <String, dynamic>{
        'state': nextState.name,
        'updatedAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
  }

  MomentInstanceStatus _safeOriginalStatus(Object? rawValue) {
    if (rawValue is String) {
      for (final status in <MomentInstanceStatus>[
        MomentInstanceStatus.proposed,
        MomentInstanceStatus.scheduled,
      ]) {
        if (status.name == rawValue) {
          return status;
        }
      }
    }

    return MomentInstanceStatus.scheduled;
  }

  DateTime? _dateFromMap(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  Duration? _plannedDuration(FamilyMoment moment) {
    final startMinutes = moment.resolvedPreferredStartMinutes;
    final endMinutes = moment.resolvedPreferredEndMinutes;

    if (endMinutes == null) {
      return const Duration(minutes: 60);
    }

    var durationMinutes = endMinutes - startMinutes;

    if (durationMinutes <= 0) {
      durationMinutes += 24 * 60;
    }

    if (durationMinutes < 5 || durationMinutes > 8 * 60) {
      return const Duration(minutes: 60);
    }

    return Duration(minutes: durationMinutes);
  }

  void _verifyCurrentUser(String expectedUserId) {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('A signed-in user is required.');
    }

    if (user.uid != expectedUserId) {
      throw StateError('This action can be completed only as yourself.');
    }
  }
}
