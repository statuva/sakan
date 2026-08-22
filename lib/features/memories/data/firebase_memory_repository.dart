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
    return _memories(familyId).where('momentId', isEqualTo: momentId).limit(1);
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
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final document = snapshot.docs.first;

      return FamilyMemory.fromMap(document.id, document.data());
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

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final document = snapshot.docs.first;

    return FamilyMemory.fromMap(document.id, document.data());
  }

  @override
  Future<void> saveMemory(FamilyMemory memory) async {
    _validateMemory(memory);

    final existingSnapshot = await _memoryForMomentQuery(
      familyId: memory.familyId,
      momentId: memory.momentId,
    ).get();

    final DocumentReference<Map<String, dynamic>> reference;

    if (existingSnapshot.docs.isNotEmpty) {
      // Reuse the existing document when this
      // Moment already has a Memory.
      //
      // This changes Add Memory into Edit Memory
      // rather than creating a duplicate.
      reference = existingSnapshot.docs.first.reference;
    } else {
      // For new Memories, the Moment ID is used as
      // the document ID. This naturally supports
      // one Memory per Moment.
      reference = _memories(memory.familyId).doc(memory.momentId);
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
