import 'package:flutter/material.dart';
import 'package:sakan/shared/widgets/feedback/feature_placeholder.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Calendar',
      description:
          'Recurring traditions and meaningful one-time moments will appear here.',
      icon: Icons.calendar_month_outlined,
    );
  }
}
