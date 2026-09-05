import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sakan/core/theme/app_colors.dart';
import 'package:sakan/core/theme/app_text_styles.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 4000);
  static const _background = Color(0xFFF9FAEC);

  late final AnimationController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_error != null) setState(() => _error = null);
    _controller.forward(from: 0);

    try {
      final results = await Future.wait<Object?>([
        _resolveDestination(),
        Future<void>.delayed(_duration),
      ]);
      _go(results.first as String);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<String> _resolveDestination() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return '/sign-in';

    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();
    final currentFamilyId =
        userSnapshot.data()?['currentFamilyId'] as String?;

    if (currentFamilyId == null || currentFamilyId.isEmpty) {
      return '/family-access';
    }

    final familySnapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(currentFamilyId)
        .get();
    final setupComplete =
        familySnapshot.data()?['setupComplete'] as bool? ?? false;
    return setupComplete ? '/home' : '/family-setup';
  }

  void _go(String location) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(location);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: AppErrorState(message: _error!, onRetry: _start),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 1080,
            height: 1920,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _buildFrame(_controller.value),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrame(double timeline) {
    final wordProgress = _progress(timeline, 0, 110.322 / 240);
    final familyProgress = _progress(
      timeline,
      62.4 / 240,
      104.4 / 240,
      Curves.easeOutCubic,
    );
    final blueProgress = _progress(
      timeline,
      51.162 / 240,
      141.162 / 240,
      Curves.easeOutCubic,
    );
    final goldProgress = _progress(
      timeline,
      74.922 / 240,
      191.562 / 240,
      Curves.easeOutCubic,
    );

    return ColoredBox(
      color: _background,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 452,
            top: 849.5,
            width: 304,
            height: 304,
            child: Opacity(
              opacity: blueProgress,
              child: Transform.rotate(
                angle: (-45 * (1 - blueProgress)) * math.pi / 180,
                child: Transform.scale(
                  scale: blueProgress,
                  child: Image.asset(
                    'assets/images/sakan_intro_star_blue.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 260,
            top: 642 - (100 * familyProgress),
            width: 429.5,
            height: 402,
            child: Opacity(
              opacity: familyProgress,
              child: Image.asset(
                'assets/images/sakan_intro_family.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          Positioned(
            left: 58,
            top: 790,
            width: 964,
            height: 240,
            child: Opacity(
              opacity: wordProgress,
              child: Transform.scale(
                scale: 1.2 - (0.2 * wordProgress),
                child: Image.asset(
                  'assets/images/sakan_intro_wordmark.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: 485.5,
            top: 761,
            width: 326,
            height: 326,
            child: Opacity(
              opacity: goldProgress,
              child: Transform.rotate(
                angle: (-45 * (1 - goldProgress)) * math.pi / 180,
                child: Transform.scale(
                  scale: goldProgress,
                  child: Image.asset(
                    'assets/images/sakan_intro_star_gold.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          _quoteLine(
            text: "Moments that bring us together",
            top: 1187,
            progress: _progress(timeline, 120 / 240, 219.72 / 240),
          ),
          _quoteLine(
            text: 'Memories that stay with us',
            top: 1259,
            progress: _progress(timeline, 130.08 / 240, 229.8 / 240),
          ),
        ],
      ),
    );
  }

  Widget _quoteLine({
    required String text,
    required double top,
    required double progress,
  }) {
    return Positioned(
      left: 58,
      right: 58,
      top: top,
      height: 72,
      child: Opacity(
        opacity: progress,
        child: Text(
          text,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: AppTextStyles.arabic.copyWith(
            color: AppColors.textPrimary,
            fontSize: 48,
            fontWeight: FontWeight.w400,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  double _progress(
    double timeline,
    double start,
    double end, [
    Curve curve = Curves.linear,
  ]) {
    final value = ((timeline - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(value.toDouble());
  }
}
