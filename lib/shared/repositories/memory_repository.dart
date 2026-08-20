import '../models/family_memory.dart';

abstract interface class MemoryRepository {
  Stream<List<FamilyMemory>> watchMemories({required String familyId});

  Future<FamilyMemory?> getMemory({
    required String familyId,
    required String memoryId,
  });
}
