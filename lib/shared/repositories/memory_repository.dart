import '../models/family_memory.dart';

abstract interface class MemoryRepository {
  Stream<List<FamilyMemory>> watchMemories({required String familyId});

  Stream<FamilyMemory?> watchMemoryForMoment({
    required String familyId,
    required String momentId,
  });

  Stream<FamilyMemory?> watchMemoryForInstance({
    required String familyId,
    required String instanceId,
  });

  Future<FamilyMemory?> getMemoryForMoment({
    required String familyId,
    required String momentId,
  });

  Future<FamilyMemory?> getMemoryForInstance({
    required String familyId,
    required String instanceId,
  });

  Future<void> saveMemory(FamilyMemory memory);

  Future<void> deleteMemory({
    required String familyId,
    required String memoryId,
  });
}
