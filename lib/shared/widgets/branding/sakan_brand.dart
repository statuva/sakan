import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class SakanWordmark extends StatelessWidget {
  const SakanWordmark({this.height = 34, super.key});

  static const String assetPath = 'assets/images/sakan_wordmark.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Sakan',
      child: SizedBox(
        height: height,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) {
            return Text(
              'Sakan',
              style: GoogleFonts.yesevaOne(
                color: AppColors.textPrimary,
                fontSize: height * 0.9,
                height: 1,
              ),
            );
          },
        ),
      ),
    );
  }
}

class SakanAiStar extends StatelessWidget {
  const SakanAiStar({this.size = 64, this.selected = false, super.key});

  static const String assetPath = 'assets/images/sakan_ai_star.png';

  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Sakan AI',
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: SizedBox.square(
          dimension: size,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) {
              return Icon(
                Icons.auto_awesome_rounded,
                size: size * 0.72,
                color: AppColors.accent,
              );
            },
          ),
        ),
      ),
    );
  }
}
