import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/daily_reflection.dart';

class HomeDailyReflection extends StatelessWidget {
  const HomeDailyReflection({required this.reflection, super.key});

  final DailyReflection reflection;

  @override
  Widget build(BuildContext context) {
    final arabic = reflection.arabicText?.trim();
    final english = reflection.englishText?.trim();
    final sourceLine = reflection.sourceLine;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (arabic != null && arabic.isNotEmpty)
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        arabic,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.55,
                            ),
                      ),
                    ),
                  ),
                if (arabic != null &&
                    arabic.isNotEmpty &&
                    english != null &&
                    english.isNotEmpty)
                  const SizedBox(height: 5),
                if (english != null && english.isNotEmpty)
                  Text(
                    '“$english”',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                    ),
                  ),
                if (sourceLine != null && sourceLine.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    sourceLine,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
