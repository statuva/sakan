import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_enums.dart';

class RhythmRecord {
  const RhythmRecord({
    required this.id,
    required this.familyId,
    required this.momentId,
    required this.expectedIntervalDays,
    required this.currentGapDays,
    required this.occurrenceCount,
    required this.status,
    required this.confidence,
    required this.updatedAt,
    this.lastOccurrenceAt,
  });

  final String id;
  final String familyId;
  final String momentId;

  final int expectedIntervalDays;
  final DateTime? lastOccurrenceAt;
  final int currentGapDays;
  final int occurrenceCount;

  final RhythmStatus status;
  final ConfidenceLevel confidence;

  final DateTime updatedAt;

  factory RhythmRecord.fromMap(String id, Map<String, dynamic> map) {
    return RhythmRecord(
      id: id,
      familyId: map['familyId'] as String,
      momentId: map['momentId'] as String,
      expectedIntervalDays: map['expectedIntervalDays'] as int,
      lastOccurrenceAt: map['lastOccurrenceAt'] == null
          ? null
          : (map['lastOccurrenceAt'] as Timestamp).toDate(),
      currentGapDays: map['currentGapDays'] as int,
      occurrenceCount: map['occurrenceCount'] as int,
      status: RhythmStatus.values.byName(map['status'] as String),
      confidence: ConfidenceLevel.values.byName(map['confidence'] as String),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'momentId': momentId,
      'expectedIntervalDays': expectedIntervalDays,
      'lastOccurrenceAt': lastOccurrenceAt == null
          ? null
          : Timestamp.fromDate(lastOccurrenceAt!),
      'currentGapDays': currentGapDays,
      'occurrenceCount': occurrenceCount,
      'status': status.name,
      'confidence': confidence.name,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
