import 'package:flutter/material.dart';
import 'app_empty_state.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child : AppEmptyState(
          icon: icon,
          title: title,
          message: description,
        ),
      ),
    );
  }
}
