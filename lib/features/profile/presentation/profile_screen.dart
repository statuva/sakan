import 'package:flutter/material.dart';
import 'package:sakan/shared/widgets/feedback/feature_placeholder.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Profile',
      description: 'Personal preferences, schedules, privacy, and Hub settings will appear here.',
      icon: Icons.person_outline_rounded,
    );
  }
}
