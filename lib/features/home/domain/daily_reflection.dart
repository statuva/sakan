enum DailyReflectionKind { familyQuote, hadith }

class DailyReflection {
  const DailyReflection({
    required this.id,
    required this.kind,
    this.arabicText,
    this.englishText,
    this.source,
    this.reference,
  }) : assert(
         arabicText != null || englishText != null,
         'A reflection needs Arabic or English text.',
       ),
       assert(
         kind != DailyReflectionKind.hadith || source != null,
         'A Hadith entry must include a verified source.',
       );

  final String id;
  final DailyReflectionKind kind;
  final String? arabicText;
  final String? englishText;
  final String? source;
  final String? reference;

  String? get sourceLine {
    final cleanSource = source?.trim();
    final cleanReference = reference?.trim();

    if (cleanSource == null || cleanSource.isEmpty) {
      return cleanReference == null || cleanReference.isEmpty
          ? null
          : cleanReference;
    }

    if (cleanReference == null || cleanReference.isEmpty) {
      return cleanSource;
    }

    return '$cleanSource · $cleanReference';
  }
}
