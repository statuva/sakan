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

  @override
  Stream<List<FamilyMemory>> watchMemories({required String familyId}) {
    return _memories(familyId).snapshots().map((snapshot) {
      final memories = snapshot.docs
          .map((document) => FamilyMemory.fromMap(document.id, document.data()))
          .where((memory) => memory.photoUrls.isNotEmpty)
          .toList();

      memories.sort(
        (first, second) => second.occurredAt.compareTo(first.occurredAt),
      );

      return memories;
    });
  }

  @override
  Future<FamilyMemory?> getMemory({
    required String familyId,
    required String memoryId,
  }) async {
    final snapshot = await _memories(familyId).doc(memoryId).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return FamilyMemory.fromMap(snapshot.id, data);
  }
}
