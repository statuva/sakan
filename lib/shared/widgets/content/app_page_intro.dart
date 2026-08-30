import 'package:flutter/material.dart';

class AppPageIntro extends StatelessWidget {
  const AppPageIntro({
    required this.title,
    required this.description,
    this.secondaryText,
    super.key,
  });

  final String title;
  final String description;
  final String? secondaryText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        if (secondaryText != null) ...[
          const SizedBox(height: 5),
          Text(
            secondaryText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
