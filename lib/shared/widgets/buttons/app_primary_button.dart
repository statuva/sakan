import 'package:flutter/material.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row( 
           mainAxisSize: MainAxisSize.min,
           mainAxisAlignment: MainAxisAlignment.center,
           children: [if (icon != null) ...[
                Icon(icon, size: 22),
                const SizedBox(width: 12),
              ],
              Text(label),
            ],
          );
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 56,
      child : FilledButton(
        onPressed: isLoading ? null : onPressed,
        child:child
       ),
    );
  }  
}