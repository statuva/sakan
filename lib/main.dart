import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'app/sakan_app.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'shared/services/reminder_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  }

  final notificationService = ReminderNotificationService.instance;

  final launchPayload = await notificationService.initialize(
    onReminderTap: _handleReminderNotificationTap,
    onWeeklyReportTap: _handleWeeklyReportNotificationTap,
  );

  runApp(const SakanApp());

  if (launchPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleSakanNotificationTap(launchPayload);
    });
  }
}

void _handleSakanNotificationTap(SakanNotificationPayload payload) {
  switch (payload) {
    case ReminderNotificationPayload reminder:
      _handleReminderNotificationTap(reminder);
      return;
    case WeeklyReportNotificationPayload weeklyReport:
      _handleWeeklyReportNotificationTap(weeklyReport);
      return;
  }
}

void _handleReminderNotificationTap(ReminderNotificationPayload payload) {
  unawaited(_openMyReminders(payload));
}

void _handleWeeklyReportNotificationTap(
  WeeklyReportNotificationPayload payload,
) {
  unawaited(_openWeeklyReport(payload));
}

Future<void> _openMyReminders(ReminderNotificationPayload payload) async {
  if (!await _waitUntilStartupFinishes()) {
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    appRouter.go('/startup');
    return;
  }

  try {
    final familyContext = await AppDependencies.currentFamilyService.load();
    if (familyContext.familyId != payload.familyId) {
      appRouter.go('/startup');
      return;
    }
  } catch (_) {
    appRouter.go('/startup');
    return;
  }

  final location = Uri(
    path: '/my-reminders',
    queryParameters: {'reminderId': payload.reminderId},
  ).toString();

  await appRouter.push<void>(location);
}

Future<void> _openWeeklyReport(WeeklyReportNotificationPayload payload) async {
  if (!await _waitUntilStartupFinishes()) {
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    appRouter.go('/startup');
    return;
  }

  try {
    final familyContext = await AppDependencies.currentFamilyService.load();
    final matchesRecipient =
        familyContext.familyId == payload.familyId &&
        familyContext.userId == payload.memberId &&
        familyContext.isAdult;

    if (!matchesRecipient) {
      appRouter.go('/startup');
      return;
    }

    await appRouter.push<void>('/weekly-report');
  } catch (_) {
    appRouter.go('/startup');
  }
}

Future<bool> _waitUntilStartupFinishes() async {
  bool isReady() {
    return rootNavigatorKey.currentContext != null &&
        appRouter.routerDelegate.currentConfiguration.uri.path != '/startup';
  }

  if (isReady()) {
    return true;
  }

  final completer = Completer<bool>();
  late final Timer timeout;
  late final VoidCallback checkReadiness;

  void finish(bool result) {
    if (completer.isCompleted) {
      return;
    }

    appRouter.routerDelegate.removeListener(checkReadiness);
    timeout.cancel();
    completer.complete(result);
  }

  checkReadiness = () {
    if (isReady()) {
      finish(true);
    }
  };

  appRouter.routerDelegate.addListener(checkReadiness);
  timeout = Timer(const Duration(seconds: 30), () => finish(false));
  WidgetsBinding.instance.addPostFrameCallback((_) => checkReadiness());

  return completer.future;
}
