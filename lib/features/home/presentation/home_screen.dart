import 'package:flutter/material.dart';
import 'package:sakan/shared/widgets/feedback/feature_placeholder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Home',
      description: "Today’s family insight and next best action will appear here.",
      icon: Icons.home_outlined,
    );
  }
}
