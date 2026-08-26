import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/moment_participant.dart';
import '../../../shared/repositories/moment_instance_repository.dart';

class FirebaseMomentInstanceRepository implements MomentInstanceRepository {
  FirebaseMomentInstanceRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User get _currentUser {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('A signed-in user is required.');
    }

    return user;
  }

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

  @override
  Stream<List<MomentInstance>> watchInstances({required String familyId}) {
    return _instances(familyId).snapshots().map((snapshot) {
      final instances = snapshot.docs
          .map(
            (document) => MomentInstance.fromMap(document.id, document.data()),
          )
          .toList();

      instances.sort(
        (first, second) =>
            first.effectiveStartAt.compareTo(second.effectiveStartAt),
      );

      return instances;
    });
  }

  @override
  Stream<List<MomentInstance>> watchMomentInstances({
    required String familyId,
    required String momentId,
  }) {
    return _instances(
      familyId,
    ).where('momentId', isEqualTo: momentId).snapshots().map((snapshot) {
      final instances = snapshot.docs
          .map(
            (document) => MomentInstance.fromMap(document.id, document.data()),
          )
          .toList();

      instances.sort(
        (first, second) =>
            first.effectiveStartAt.compareTo(second.effectiveStartAt),
      );

      return instances;
    });
  }

  @override
  Stream<List<MomentInstance>> watchUpcomingInstances({
    required String familyId,
  }) {
    return watchInstances(familyId: familyId).map((instances) {
      final now = DateTime.now();

      return instances
          .where((instance) {
            final isUpcomingStatus =
                instance.status == MomentInstanceStatus.proposed ||
                instance.status == MomentInstanceStatus.scheduled ||
                instance.status == MomentInstanceStatus.inviting;

            return isUpcomingStatus &&
                !instance.scheduledStartAt.toLocal().isBefore(now);
          })
          .toList(growable: false);
    });
  }

  @override
  Stream<MomentInstance?> watchActiveInstance({required String familyId}) {
    return _instances(familyId)
        .where('status', isEqualTo: MomentInstanceStatus.active.name)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }

          final active = snapshot.docs
              .map(
                (document) =>
                    MomentInstance.fromMap(document.id, document.data()),
              )
              .toList();

          active.sort(
            (first, second) =>
                first.effectiveStartAt.compareTo(second.effectiveStartAt),
          );

          return active.first;
        });
  }

  @override
  Stream<MomentInstance?> watchInstance({
    required String familyId,
    required String instanceId,
  }) {
    return _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    ).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return MomentInstance.fromMap(snapshot.id, data);
    });
  }

  @override
  Stream<List<MomentParticipant>> watchParticipants({
    required String familyId,
    required String instanceId,
  }) {
    return _participants(
      familyId: familyId,
      instanceId: instanceId,
    ).snapshots().map((snapshot) {
      final participants = snapshot.docs
          .map(
            (document) =>
                MomentParticipant.fromMap(document.id, document.data()),
          )
          .toList();

      participants.sort((first, second) {
        final firstTime = first.checkedInAt ?? DateTime(9999);

        final secondTime = second.checkedInAt ?? DateTime(9999);

        final timeResult = firstTime.compareTo(secondTime);

        if (timeResult != 0) {
          return timeResult;
        }

        return first.memberId.compareTo(second.memberId);
      });

      return participants;
    });
  }

  @override
  Future<MomentInstance?> getInstance({
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

    return MomentInstance.fromMap(snapshot.id, data);
  }

  @override
  Future<MomentInstance?> getOpenInstanceForMoment({
    required String familyId,
    required String momentId,
  }) async {
    final snapshot = await _instances(
      familyId,
    ).where('momentId', isEqualTo: momentId).get();

    final openInstances = snapshot.docs
        .map((document) => MomentInstance.fromMap(document.id, document.data()))
        .where((instance) {
          return instance.status == MomentInstanceStatus.proposed ||
              instance.status == MomentInstanceStatus.scheduled ||
              instance.status == MomentInstanceStatus.inviting ||
              instance.status == MomentInstanceStatus.active;
        })
        .toList();

    openInstances.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      return first.scheduledStartAt.compareTo(second.scheduledStartAt);
    });

    return openInstances.isEmpty ? null : openInstances.first;
  }

  @override
  Future<List<MomentParticipant>> getParticipants({
    required String familyId,
    required String instanceId,
  }) async {
    final snapshot = await _participants(
      familyId: familyId,
      instanceId: instanceId,
    ).get();

    return snapshot.docs
        .map(
          (document) => MomentParticipant.fromMap(document.id, document.data()),
        )
        .toList(growable: false);
  }

  @override
  Future<MomentInstance?> syncScheduledInstanceFromMoment({
    required FamilyMoment moment,
    required String createdBy,
    MomentInstanceSource source = MomentInstanceSource.calendar,
  }) async {
    _verifyCurrentUser(createdBy);
    _validateMoment(moment);

    if (moment.status == MomentStatus.cancelled) {
      await cancelOpenInstancesForMoment(
        familyId: moment.familyId,
        momentId: moment.id,
        cancelledBy: createdBy,
      );

      return null;
    }

    if (moment.status != MomentStatus.scheduled) {
      return null;
    }

    final snapshot = await _instances(
      moment.familyId,
    ).where('momentId', isEqualTo: moment.id).get();

    final openScheduled =
        snapshot.docs
            .map(
              (document) =>
                  MomentInstance.fromMap(document.id, document.data()),
            )
            .where((instance) {
              return instance.status == MomentInstanceStatus.proposed ||
                  instance.status == MomentInstanceStatus.scheduled ||
                  instance.status == MomentInstanceStatus.inviting;
            })
            .toList()
          ..sort(
            (first, second) =>
                first.scheduledStartAt.compareTo(second.scheduledStartAt),
          );

    final now = DateTime.now().toUtc();

    late final MomentInstance instance;

    if (openScheduled.isNotEmpty) {
      final existing = openScheduled.first;

      instance = existing.copyWith(
        titleSnapshot: moment.title,
        typeSnapshot: moment.type,
        categorySnapshot: moment.category,
        importanceLevelSnapshot: moment.importanceLevel,
        locationSnapshot: moment.location,
        expectedParticipantIds: moment.expectedParticipantIds,
        scheduledStartAt: moment.startAt.toUtc(),
        scheduledEndAt: moment.endAt?.toUtc(),
        updatedAt: now,
      );
    } else {
      final instanceId = _scheduledInstanceId(
        momentId: moment.id,
        scheduledStartAt: moment.startAt.toUtc(),
      );

      instance = MomentInstance.scheduledFromMoment(
        id: instanceId,
        moment: moment,
        source: source,
        createdBy: createdBy,
        now: now,
      );
    }

    await _instanceReference(
      familyId: instance.familyId,
      instanceId: instance.id,
    ).set(instance.toMap(), SetOptions(merge: true));

    return instance;
  }

  @override
  Future<int> cancelOpenInstancesForMoment({
    required String familyId,
    required String momentId,
    required String cancelledBy,
  }) async {
    _verifyCurrentUser(cancelledBy);

    final snapshot = await _instances(
      familyId,
    ).where('momentId', isEqualTo: momentId).get();

    final now = DateTime.now().toUtc();
    final batch = _firestore.batch();

    var cancelledCount = 0;

    for (final document in snapshot.docs) {
      final instance = MomentInstance.fromMap(document.id, document.data());

      if (!instance.isOpen) {
        continue;
      }

      final actualStart = instance.actualStartAt;

      var durationMinutes = instance.actualDurationMinutes;

      if (actualStart != null) {
        durationMinutes = now.difference(actualStart).inMinutes;

        if (durationMinutes < 0) {
          durationMinutes = 0;
        }
      }

      batch.set(
        document.reference,
        instance
            .copyWith(
              status: MomentInstanceStatus.cancelled,
              actualEndAt: actualStart == null ? null : now,
              actualDurationMinutes: durationMinutes,
              endedBy: cancelledBy,
              updatedAt: now,
            )
            .toMap(),
        SetOptions(merge: true),
      );

      cancelledCount++;
    }

    if (cancelledCount > 0) {
      await batch.commit();
    }

    return cancelledCount;
  }

  @override
  Future<MomentInstance> startMomentNow({
    required FamilyMoment moment,
    required String startedBy,
    required MomentInstanceSource source,
    String? existingInstanceId,
  }) async {
    _verifyCurrentUser(startedBy);
    _validateMoment(moment);

    final activeSnapshot = await _instances(moment.familyId)
        .where('status', isEqualTo: MomentInstanceStatus.active.name)
        .limit(2)
        .get();

    if (activeSnapshot.docs.isNotEmpty) {
      final activeInstances =
          activeSnapshot.docs
              .map(
                (document) =>
                    MomentInstance.fromMap(document.id, document.data()),
              )
              .toList()
            ..sort(
              (first, second) =>
                  first.effectiveStartAt.compareTo(second.effectiveStartAt),
            );

      final active = activeInstances.first;

      if (active.momentId == moment.id || existingInstanceId == active.id) {
        return active;
      }

      throw StateError('Another family Moment is already active.');
    }

    final now = DateTime.now().toUtc();

    MomentInstance? existing;

    if (existingInstanceId != null) {
      existing = await getInstance(
        familyId: moment.familyId,
        instanceId: existingInstanceId,
      );
    } else {
      existing = await getOpenInstanceForMoment(
        familyId: moment.familyId,
        momentId: moment.id,
      );
    }

    if (existing != null && existing.momentId != moment.id) {
      throw StateError(
        'This occurrence belongs to '
        'a different Family Moment.',
      );
    }

    late final MomentInstance instance;

    if (existing != null) {
      final canStart =
          existing.status == MomentInstanceStatus.proposed ||
          existing.status == MomentInstanceStatus.scheduled ||
          existing.status == MomentInstanceStatus.inviting;

      if (!canStart) {
        throw StateError('This Moment occurrence cannot be started.');
      }

      final evidence = existing.evidenceSignals.toSet()
        ..add(MomentEvidenceSignal.hostStarted)
        ..add(MomentEvidenceSignal.manualCheckIn);

      instance = existing.copyWith(
        source: source,
        status: MomentInstanceStatus.active,
        actualStartAt: now,
        actualEndAt: null,
        actualDurationMinutes: null,
        startedBy: startedBy,
        endedBy: null,
        confirmedParticipantIds: <String>[startedBy],
        evidenceSignals: evidence.toList(),
        confirmationLevel: MomentConfirmationLevel.low,
        updatedAt: now,
      );
    } else {
      final plannedDuration = _plannedDuration(moment);

      final instanceId =
          'instance_${moment.id}_'
          '${DateTime.now().microsecondsSinceEpoch}';

      final scheduled = MomentInstance.scheduledFromMoment(
        id: instanceId,
        moment: moment,
        source: source,
        createdBy: startedBy,
        scheduledStartAt: now,
        scheduledEndAt: plannedDuration == null
            ? null
            : now.add(plannedDuration),
        now: now,
      );

      instance = scheduled.copyWith(
        status: MomentInstanceStatus.active,
        actualStartAt: now,
        startedBy: startedBy,
        confirmedParticipantIds: <String>[startedBy],
        evidenceSignals: <MomentEvidenceSignal>[
          MomentEvidenceSignal.scheduled,
          MomentEvidenceSignal.hostStarted,
          MomentEvidenceSignal.manualCheckIn,
        ],
        confirmationLevel: MomentConfirmationLevel.low,
        updatedAt: now,
      );
    }

    final hostParticipant = MomentParticipant.checkedIn(
      familyId: instance.familyId,
      instanceId: instance.id,
      memberId: startedBy,
      method: MomentCheckInMethod.manual,
      now: now,
    );

    final batch = _firestore.batch();

    batch.set(
      _instanceReference(familyId: instance.familyId, instanceId: instance.id),
      instance.toMap(),
      SetOptions(merge: true),
    );

    batch.set(
      _participants(
        familyId: instance.familyId,
        instanceId: instance.id,
      ).doc(startedBy),
      hostParticipant.toMap(),
      SetOptions(merge: true),
    );

    await batch.commit();

    return instance;
  }

  @override
  Future<void> checkIn({
    required String familyId,
    required String instanceId,
    required String memberId,
    MomentCheckInMethod method = MomentCheckInMethod.manual,
  }) async {
    _verifyCurrentUser(memberId);

    final instance = await getInstance(
      familyId: familyId,
      instanceId: instanceId,
    );

    if (instance == null) {
      throw StateError(
        'The active Family Moment '
        'could not be found.',
      );
    }

    if (instance.status != MomentInstanceStatus.active) {
      throw StateError(
        'You can check in only while '
        'the Moment is active.',
      );
    }

    final reference = _participants(
      familyId: familyId,
      instanceId: instanceId,
    ).doc(memberId);

    final snapshot = await reference.get();
    final now = DateTime.now().toUtc();

    final existingData = snapshot.data();

    final participant = snapshot.exists && existingData != null
        ? MomentParticipant.fromMap(snapshot.id, existingData).copyWith(
            state: ParticipantMomentState.checkedIn,
            checkInMethod: method,
            checkedInAt: now,
            checkedOutAt: null,
            confirmedAt: now,
            updatedAt: now,
          )
        : MomentParticipant.checkedIn(
            familyId: familyId,
            instanceId: instanceId,
            memberId: memberId,
            method: method,
            now: now,
          );

    await reference.set(participant.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> checkOut({
    required String familyId,
    required String instanceId,
    required String memberId,
  }) async {
    _verifyCurrentUser(memberId);

    final reference = _participants(
      familyId: familyId,
      instanceId: instanceId,
    ).doc(memberId);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return;
    }

    final now = DateTime.now().toUtc();

    final participant = MomentParticipant.fromMap(snapshot.id, data).copyWith(
      state: ParticipantMomentState.left,
      checkedOutAt: now,
      updatedAt: now,
    );

    await reference.set(participant.toMap(), SetOptions(merge: true));
  }

  @override
  Future<MomentInstance> endInstance({
    required String familyId,
    required String instanceId,
    required String endedBy,
  }) async {
    _verifyCurrentUser(endedBy);

    final instance = await _requiredInstance(
      familyId: familyId,
      instanceId: instanceId,
    );

    if (instance.status != MomentInstanceStatus.active) {
      throw StateError('Only an active Moment can be ended.');
    }

    final participants = await getParticipants(
      familyId: familyId,
      instanceId: instanceId,
    );

    final now = DateTime.now().toUtc();
    final actualStart = instance.actualStartAt ?? now;

    var durationMinutes = now.difference(actualStart).inMinutes;

    if (durationMinutes < 0) {
      durationMinutes = 0;
    }

    final confirmedParticipants = participants
        .where((participant) => participant.checkedInAt != null)
        .toList();

    final confirmedIds =
        confirmedParticipants
            .map((participant) => participant.memberId)
            .toSet()
            .toList()
          ..sort();

    final evidence = instance.evidenceSignals.toSet();

    if (confirmedParticipants.isNotEmpty) {
      evidence.add(MomentEvidenceSignal.manualCheckIn);
    }

    if (confirmedParticipants.length >= 2) {
      evidence.add(MomentEvidenceSignal.multipleCheckIns);
    }

    if (durationMinutes > 0) {
      evidence.add(MomentEvidenceSignal.durationRecorded);
    }

    if (confirmedParticipants.any(
      (participant) =>
          participant.nearbyDetectedAt != null ||
          participant.checkInMethod == MomentCheckInMethod.bluetooth,
    )) {
      evidence.add(MomentEvidenceSignal.bluetoothNearby);
    }

    if (confirmedParticipants.any(
      (participant) => participant.checkInMethod == MomentCheckInMethod.qr,
    )) {
      evidence.add(MomentEvidenceSignal.qrCheckIn);
    }

    if (confirmedParticipants.any(
      (participant) =>
          participant.checkInMethod == MomentCheckInMethod.todayReview,
    )) {
      evidence.add(MomentEvidenceSignal.todayReview);
    }

    final confirmation = _confirmationLevel(
      expectedCount: instance.expectedParticipantIds.length,
      confirmedCount: confirmedParticipants.length,
      durationMinutes: durationMinutes,
    );

    final updated = instance.copyWith(
      status: MomentInstanceStatus.completed,
      actualEndAt: now,
      actualDurationMinutes: durationMinutes,
      endedBy: endedBy,
      confirmedParticipantIds: confirmedIds,
      evidenceSignals: evidence.toList(),
      confirmationLevel: confirmation,
      updatedAt: now,
    );

    await _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    ).set(updated.toMap(), SetOptions(merge: true));

    return updated;
  }

  @override
  Future<MomentInstance> cancelInstance({
    required String familyId,
    required String instanceId,
    required String cancelledBy,
  }) async {
    _verifyCurrentUser(cancelledBy);

    final instance = await _requiredInstance(
      familyId: familyId,
      instanceId: instanceId,
    );

    if (instance.isFinished) {
      return instance;
    }

    final now = DateTime.now().toUtc();
    final actualStart = instance.actualStartAt;

    int? durationMinutes = instance.actualDurationMinutes;

    if (actualStart != null) {
      durationMinutes = now.difference(actualStart).inMinutes;

      if (durationMinutes < 0) {
        durationMinutes = 0;
      }
    }

    final updated = instance.copyWith(
      status: MomentInstanceStatus.cancelled,
      actualEndAt: actualStart == null ? null : now,
      actualDurationMinutes: durationMinutes,
      endedBy: cancelledBy,
      updatedAt: now,
    );

    await _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    ).set(updated.toMap(), SetOptions(merge: true));

    return updated;
  }

  @override
  Future<MomentInstance> markMissed({
    required String familyId,
    required String instanceId,
    required String updatedBy,
  }) async {
    _verifyCurrentUser(updatedBy);

    final instance = await _requiredInstance(
      familyId: familyId,
      instanceId: instanceId,
    );

    if (instance.isFinished) {
      return instance;
    }

    if (instance.status == MomentInstanceStatus.active) {
      throw StateError(
        'End or cancel the active Moment '
        'instead of marking it missed.',
      );
    }

    final updated = instance.copyWith(
      status: MomentInstanceStatus.missed,
      endedBy: updatedBy,
      updatedAt: DateTime.now().toUtc(),
    );

    await _instanceReference(
      familyId: familyId,
      instanceId: instanceId,
    ).set(updated.toMap(), SetOptions(merge: true));

    return updated;
  }

  Future<MomentInstance> _requiredInstance({
    required String familyId,
    required String instanceId,
  }) async {
    final instance = await getInstance(
      familyId: familyId,
      instanceId: instanceId,
    );

    if (instance == null) {
      throw StateError(
        'The Family Moment occurrence '
        'could not be found.',
      );
    }

    return instance;
  }

  void _verifyCurrentUser(String userId) {
    if (_currentUser.uid != userId) {
      throw StateError(
        'This action must use the '
        'signed-in member.',
      );
    }
  }

  void _validateMoment(FamilyMoment moment) {
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

  Duration? _plannedDuration(FamilyMoment moment) {
    final end = moment.endAt;

    if (end == null || !end.isAfter(moment.startAt)) {
      return null;
    }

    return end.difference(moment.startAt);
  }

  String _scheduledInstanceId({
    required String momentId,
    required DateTime scheduledStartAt,
  }) {
    return 'instance_${momentId}_'
        '${scheduledStartAt.millisecondsSinceEpoch}';
  }

  MomentConfirmationLevel _confirmationLevel({
    required int expectedCount,
    required int confirmedCount,
    required int durationMinutes,
  }) {
    if (confirmedCount <= 0) {
      return MomentConfirmationLevel.low;
    }

    final normalizedExpected = math.max(1, expectedCount);

    final highThreshold = normalizedExpected == 1
        ? 1
        : math.max(2, (normalizedExpected * 0.6).ceil());

    if (confirmedCount >= highThreshold && durationMinutes >= 15) {
      return MomentConfirmationLevel.high;
    }

    if (confirmedCount >= 2 || durationMinutes >= 15) {
      return MomentConfirmationLevel.medium;
    }

    return MomentConfirmationLevel.low;
  }
}
