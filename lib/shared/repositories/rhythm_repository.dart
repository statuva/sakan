import '../models/rhythm_record.dart';

abstract interface class RhythmRepository {
  Stream<List<RhythmRecord>> watchRhythms(String familyId);

  Stream<RhythmRecord?> watchRhythm({
    required String familyId,
    required String momentId,
  });

  Future<void> saveRhythm(RhythmRecord rhythm);

  Future<void> deleteRhythm({
    required String familyId,
    required String momentId,
  });
}
