import 'package:flutter/material.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,    
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'try again',
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    ),
    );  
  }
}