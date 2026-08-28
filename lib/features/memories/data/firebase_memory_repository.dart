import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/family_memory.dart';
import '../../../shared/repositories/memory_repository.dart';

class FirebaseMemoryRepository implements MemoryRepository {
  FirebaseMemoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _memories(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('memories');
  }

  Query<Map<String, dynamic>> _memoryForMomentQuery({
    required String familyId,
    required String momentId,
  }) {
    return _memories(familyId).where('momentId', isEqualTo: momentId);
  }

  Query<Map<String, dynamic>> _memoryForInstanceQuery({
    required String familyId,
    required String instanceId,
  }) {
    return _memories(familyId).where('instanceId', isEqualTo: instanceId);
  }

  @override
  Stream<List<FamilyMemory>> watchMemories({required String familyId}) {
    return _memories(familyId).snapshots().map((snapshot) {
      final memories = snapshot.docs
          .map((document) => FamilyMemory.fromMap(document.id, document.data()))
          .toList();

      memories.sort(
        (first, second) => second.occurredAt.compareTo(first.occurredAt),
      );

      return memories;
    });
  }

  @override
  Stream<FamilyMemory?> watchMemoryForMoment({
    required String familyId,
    required String momentId,
  }) {
    return _memoryForMomentQuery(
      familyId: familyId,
      momentId: momentId,
    ).snapshots().map((snapshot) {
      return _newestMemory(snapshot.docs);
    });
  }

  @override
  Stream<FamilyMemory?> watchMemoryForInstance({
    required String familyId,
    required String instanceId,
  }) {
    return _memoryForInstanceQuery(
      familyId: familyId,
      instanceId: instanceId,
    ).snapshots().map((snapshot) {
      return _newestMemory(snapshot.docs);
    });
  }

  @override
  Future<FamilyMemory?> getMemoryForMoment({
    required String familyId,
    required String momentId,
  }) async {
    final snapshot = await _memoryForMomentQuery(
      familyId: familyId,
      momentId: momentId,
    ).get();

    return _newestMemory(snapshot.docs);
  }

  @override
  Future<FamilyMemory?> getMemoryForInstance({
    required String familyId,
    required String instanceId,
  }) async {
    final snapshot = await _memoryForInstanceQuery(
      familyId: familyId,
      instanceId: instanceId,
    ).get();

    return _newestMemory(snapshot.docs);
  }

  @override
  Future<void> saveMemory(FamilyMemory memory) async {
    _validateMemory(memory);

    final QuerySnapshot<Map<String, dynamic>> existingSnapshot;

    if (memory.instanceId != null && memory.instanceId!.trim().isNotEmpty) {
      existingSnapshot = await _memoryForInstanceQuery(
        familyId: memory.familyId,
        instanceId: memory.instanceId!,
      ).get();
    } else {
      existingSnapshot = await _memoryForMomentQuery(
        familyId: memory.familyId,
        momentId: memory.momentId,
      ).get();
    }

    final DocumentReference<Map<String, dynamic>> reference;

    if (existingSnapshot.docs.isNotEmpty) {
      reference = existingSnapshot.docs.first.reference;
    } else {
      reference = _memories(
        memory.familyId,
      ).doc(memory.instanceId ?? memory.momentId);
    }

    await reference.set(memory.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteMemory({
    required String familyId,
    required String memoryId,
  }) {
    return _memories(familyId).doc(memoryId).delete();
  }

  FamilyMemory? _newestMemory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    if (documents.isEmpty) {
      return null;
    }

    final memories =
        documents
            .map(
              (document) => FamilyMemory.fromMap(document.id, document.data()),
            )
            .toList()
          ..sort(
            (first, second) => second.occurredAt.compareTo(first.occurredAt),
          );

    return memories.first;
  }

  void _validateMemory(FamilyMemory memory) {
    if (memory.familyId.trim().isEmpty) {
      throw ArgumentError('Memory family ID cannot be empty.');
    }

    if (memory.momentId.trim().isEmpty) {
      throw ArgumentError('A Memory must belong to a Moment.');
    }

    if (memory.title.trim().isEmpty) {
      throw ArgumentError('Memory title cannot be empty.');
    }

    if (memory.note == null || memory.note!.trim().isEmpty) {
      throw ArgumentError('A family note is required.');
    }
  }
}
