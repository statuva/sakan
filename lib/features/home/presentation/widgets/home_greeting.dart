import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({required this.displayName, required this.now, super.key});

  final String displayName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final firstName = _firstName(displayName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sakan',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${_greetingFor(now)},\n'),
              TextSpan(
                text: '$firstName.',
                style: const TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  String _greetingFor(DateTime value) {
    final hour = value.toLocal().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 18) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  String _firstName(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return 'there';
    }

    return clean.split(RegExp(r'\s+')).first;
  }
}
