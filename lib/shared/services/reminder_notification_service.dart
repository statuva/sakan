import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/care_action.dart';

typedef ReminderNotificationTapCallback =
    void Function(ReminderNotificationPayload payload);

class ReminderNotificationPayload {
  const ReminderNotificationPayload({
    required this.familyId,
    required this.reminderId,
  });

  static const String payloadKind = 'sakanReminder';

  final String familyId;
  final String reminderId;

  String encode() {
    return jsonEncode({
      'kind': payloadKind,
      'familyId': familyId,
      'reminderId': reminderId,
    });
  }

  static ReminderNotificationPayload? tryParse(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawPayload);

      if (decoded is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(decoded);

      if (map['kind'] != payloadKind) {
        return null;
      }

      final familyId = map['familyId'];
      final reminderId = map['reminderId'];

      if (familyId is! String ||
          familyId.trim().isEmpty ||
          reminderId is! String ||
          reminderId.trim().isEmpty) {
        return null;
      }

      return ReminderNotificationPayload(
        familyId: familyId,
        reminderId: reminderId,
      );
    } catch (_) {
      return null;
    }
  }
}

class ReminderNotificationService {
  ReminderNotificationService._();

  static final ReminderNotificationService instance =
      ReminderNotificationService._();

  static const String _channelId = 'sakan_reminders';

  static const String _channelName = 'Sakan Reminders';

  static const String _channelDescription =
      'Personal reminders created or approved in Sakan.';

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  ReminderNotificationTapCallback? _onReminderTap;

  bool _initialized = false;

  bool get supportsScheduling {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  Future<ReminderNotificationPayload?> initialize({
    ReminderNotificationTapCallback? onReminderTap,
  }) async {
    _onReminderTap = onReminderTap;

    if (!supportsScheduling) {
      return null;
    }

    if (_initialized) {
      return null;
    }

    timezone_data.initializeTimeZones();

    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();

      timezone.setLocalLocation(
        timezone.getLocation(deviceTimezone.identifier),
      );
    } catch (_) {
      // The UTC fallback still schedules the same
      // absolute instant when dueAt is stored in UTC.
      timezone.setLocalLocation(timezone.UTC);
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    final initialized = await _notifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    _initialized = initialized ?? false;

    if (!_initialized) {
      return null;
    }

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImplementation?.createNotificationChannel(_androidChannel);

    final launchDetails = await _notifications
        .getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse?.payload != null) {
      return ReminderNotificationPayload.tryParse(
        launchDetails!.notificationResponse!.payload,
      );
    }

    return null;
  }

  Future<bool> requestPermission() async {
    if (!supportsScheduling || !_initialized) {
      return false;
    }

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation == null) {
      return false;
    }

    final alreadyEnabled = await androidImplementation
        .areNotificationsEnabled();

    if (alreadyEnabled == true) {
      return true;
    }

    final granted = await androidImplementation
        .requestNotificationsPermission();

    if (granted != null) {
      return granted;
    }

    return await androidImplementation.areNotificationsEnabled() ?? false;
  }

  Future<bool> notificationsEnabled() async {
    if (!supportsScheduling || !_initialized) {
      return false;
    }

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    return await androidImplementation?.areNotificationsEnabled() ?? false;
  }

  Future<bool> scheduleReminder(
    CareAction reminder, {
    bool requestPermission = false,
  }) async {
    if (!supportsScheduling || !_initialized) {
      return false;
    }

    if (reminder.isFinished ||
        !reminder.dueAt.toLocal().isAfter(DateTime.now())) {
      await cancelReminder(reminder.id);

      return false;
    }

    final permissionGranted = requestPermission
        ? await this.requestPermission()
        : await notificationsEnabled();

    if (!permissionGranted) {
      return false;
    }

    try {
      final notificationId = notificationIdFor(reminder.id);

      final body = _notificationBody(reminder);

      final scheduledDate = timezone.TZDateTime.from(
        reminder.dueAt.toUtc(),
        timezone.local,
      );

      await _notifications.cancel(id: notificationId);

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
        autoCancel: true,
        playSound: true,
        enableVibration: true,
      );

      await _notifications.zonedSchedule(
        id: notificationId,
        title: reminder.title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: ReminderNotificationPayload(
          familyId: reminder.familyId,
          reminderId: reminder.id,
        ).encode(),
      );

      return true;
    } catch (error) {
      debugPrint(
        'Could not schedule reminder '
        'notification: $error',
      );

      return false;
    }
  }

  Future<void> cancelReminder(String reminderId) async {
    if (!supportsScheduling || !_initialized) {
      return;
    }

    try {
      await _notifications.cancel(id: notificationIdFor(reminderId));
    } catch (error) {
      debugPrint(
        'Could not cancel reminder '
        'notification: $error',
      );
    }
  }

  Future<void> syncAssignedReminders(List<CareAction> reminders) async {
    if (!supportsScheduling || !_initialized) {
      return;
    }

    final permissionGranted = await notificationsEnabled();

    if (!permissionGranted) {
      return;
    }

    final now = DateTime.now();

    final schedulableReminders = reminders.where((reminder) {
      return !reminder.isFinished && reminder.dueAt.toLocal().isAfter(now);
    }).toList();

    final expectedNotificationIds = schedulableReminders
        .map((reminder) => notificationIdFor(reminder.id))
        .toSet();

    try {
      final pending = await _notifications.pendingNotificationRequests();

      for (final notification in pending) {
        final payload = ReminderNotificationPayload.tryParse(
          notification.payload,
        );

        if (payload == null) {
          continue;
        }

        if (!expectedNotificationIds.contains(notification.id)) {
          await _notifications.cancel(id: notification.id);
        }
      }

      for (final reminder in schedulableReminders) {
        await scheduleReminder(reminder, requestPermission: false);
      }
    } catch (error) {
      debugPrint(
        'Could not synchronize reminder '
        'notifications: $error',
      );
    }
  }

  Future<bool> openNotificationSettings() async {
    if (!supportsScheduling || !_initialized) {
      return false;
    }

    return await _notifications.openAppNotificationSettings() ?? false;
  }

  int notificationIdFor(String reminderId) {
    // Stable FNV-1a hash. String.hashCode is not
    // used because notification IDs must remain
    // stable between application launches.
    var hash = 0x811C9DC5;

    for (final codeUnit in reminderId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }

    return hash == 0 ? 1 : hash;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = ReminderNotificationPayload.tryParse(response.payload);

    if (payload == null) {
      return;
    }

    _onReminderTap?.call(payload);
  }

  String _notificationBody(CareAction reminder) {
    final note = reminder.reason.trim();

    if (note.isEmpty) {
      return 'Tap to open My Reminders.';
    }

    const maximumLength = 180;

    if (note.length <= maximumLength) {
      return note;
    }

    return '${note.substring(0, maximumLength - 3)}...';
  }
}
