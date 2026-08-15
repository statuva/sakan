import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _resolveDestination();
  }

  Future<void> _resolveDestination() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        _go('/sign-in');
        return;
      }

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      final userData = userSnapshot.data();
      final currentFamilyId = userData?['currentFamilyId'] as String?;

      if (currentFamilyId == null || currentFamilyId.isEmpty) {
        _go('/family-access');
        return;
      }

      final familySnapshot = await FirebaseFirestore.instance
          .collection('families')
          .doc(currentFamilyId)
          .get();

      final familyData = familySnapshot.data();
      final setupComplete = familyData?['setupComplete'] as bool? ?? false;
      _go(setupComplete ? '/home' : '/family-setup');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    }
  }

  String? _error;

  void _go(String location) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(location);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            message: _error!,
            onRetry: () {
              setState(() => _error = null);
              _resolveDestination();
            },
          ),
        ),
      );
    }

    return const Scaffold(
      body: SafeArea(
        child: AppLoadingState(message: 'Preparing your family home…'),
      ),
    );
  }
}
