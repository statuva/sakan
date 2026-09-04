import '../models/family_moment.dart';
import '../models/member.dart';
import '../models/model_enums.dart';

class MomentReviewCopy {
  const MomentReviewCopy({
    required this.question,
    required this.positiveLabel,
    required this.negativeLabel,
    this.allowReschedule = true,
  });

  final String question;
  final String positiveLabel;
  final String negativeLabel;
  final bool allowReschedule;
}

abstract final class MomentReviewQuestionBuilder {
  static MomentReviewCopy build({
    required FamilyMoment moment,
    required Member currentMember,
  }) {
    final isSubject = moment.isSubject(currentMember.id);

    if (moment.format == MomentFormat.externalEvent) {
      if (moment.category == MomentCategory.responsibility ||
          moment.category == MomentCategory.care) {
        return MomentReviewCopy(
          question: 'Was ${moment.title} completed?',
          positiveLabel: 'Completed',
          negativeLabel: 'Not Completed',
        );
      }

      if (isSubject) {
        return MomentReviewCopy(
          question:
              'Did your ${_subjectFriendlyTitle(moment.title)} take place?',
          positiveLabel: 'Yes',
          negativeLabel: 'No',
        );
      }

      return MomentReviewCopy(
        question: 'Did you attend ${moment.title}?',
        positiveLabel: 'I Attended',
        negativeLabel: 'I Didn’t Attend',
      );
    }

    return MomentReviewCopy(
      question: 'Did ${moment.title} happen?',
      positiveLabel: 'It Happened',
      negativeLabel: 'It Didn’t Happen',
    );
  }

  static String _subjectFriendlyTitle(String title) {
    final apostrophe = title.indexOf("'s ");
    if (apostrophe >= 0 && apostrophe + 3 < title.length) {
      return title.substring(apostrophe + 3).toLowerCase();
    }
    return title.toLowerCase();
  }
}
