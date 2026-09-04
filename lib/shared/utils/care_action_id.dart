abstract final class CareActionId {
  static String forInsight({
    required String familyId,
    required String memberId,
    String? momentId,
    String? instanceId,
    required String purpose,
  }) {
    final source = <String>[
      familyId,
      memberId,
      instanceId ?? '',
      momentId ?? '',
      purpose,
    ].join('|');
    var hash = 0x811c9dc5;
    for (final unit in source.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'care_${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
