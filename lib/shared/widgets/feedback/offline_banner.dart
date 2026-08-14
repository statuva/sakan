import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_colors.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warning.withAlpha(35),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.warning),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'You are offline, Changes will sync when you reconnect.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
