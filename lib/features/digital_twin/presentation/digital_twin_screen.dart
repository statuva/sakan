import 'package:flutter/material.dart';
import 'package:sakan/shared/widgets/feedback/feature_placeholder.dart';

class DigitalTwinScreen extends StatelessWidget {
  const DigitalTwinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Digital Twin',
      description: 'The Family Moment Graph and family insights will appear here.',
      icon: Icons.account_tree_outlined,
    );
  }
}
