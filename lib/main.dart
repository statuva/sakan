import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/sakan_app.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'shared/services/reminder_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationService = ReminderNotificationService.instance;

  final launchPayload = await notificationService.initialize(
    onReminderTap: _handleReminderNotificationTap,
  );

  runApp(const SakanApp());

  if (launchPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleReminderNotificationTap(launchPayload);
    });
  }
}

void _handleReminderNotificationTap(ReminderNotificationPayload payload) {
  unawaited(_openMyReminders(payload));
}

Future<void> _openMyReminders(ReminderNotificationPayload payload) async {
  // Wait briefly for MaterialApp.router and
  // Firebase Auth restoration to become ready.
  for (var attempt = 0; attempt < 20; attempt++) {
    if (rootNavigatorKey.currentContext != null) {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        appRouter.go('/startup');
        return;
      }

      final location = Uri(
        path: '/my-reminders',
        queryParameters: {'reminderId': payload.reminderId},
      ).toString();

      await appRouter.push<void>(location);

      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
