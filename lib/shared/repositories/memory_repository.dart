import '../models/family_memory.dart';

abstract interface class MemoryRepository {
  /// Watches every saved Memory in the family.
  ///
  /// The list should be returned newest first.
  Stream<List<FamilyMemory>> watchMemories({required String familyId});

  /// Watches the single Memory connected to a Moment.
  ///
  /// Returns null when that Moment has no Memory yet.
  Stream<FamilyMemory?> watchMemoryForMoment({
    required String familyId,
    required String momentId,
  });

  /// Loads the Memory connected to one Moment once.
  Future<FamilyMemory?> getMemoryForMoment({
    required String familyId,
    required String momentId,
  });

  /// Creates or updates a Memory.
  ///
  /// For the current MVP, each Moment can have only one Memory.
  Future<void> saveMemory(FamilyMemory memory);

  /// Deletes a saved Memory.
  Future<void> deleteMemory({
    required String familyId,
    required String memoryId,
  });
}
