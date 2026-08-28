import '../models/family_moment.dart';
import '../models/rhythm_record.dart';

abstract interface class CalendarRepository {
  Stream<List<FamilyMoment>> watchMoments({required String familyId});

  Stream<List<RhythmRecord>> watchRhythms({required String familyId});

  Future<FamilyMoment?> getMoment({
    required String familyId,
    required String momentId,
  });

  Future<void> saveMoment(FamilyMoment moment);

  Future<void> deleteMoment({
    required String familyId,
    required String momentId,
  });
}
