
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const int _restTimerId = 7001;
  static const int _testId = 7002;
  static const String _channelId = 'rest_timer';
  static const String _promptsKey = 'notification_prompts_v2';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Rest timer',
      channelDescription: 'Tells you when your rest time is over',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
    ),
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notify'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;

    debugPrint('NotificationService initialized.');
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// Requests notification permission where required.
  static Future<void> requestPermissionIfNeeded() async {
    try {
      await _ensureInitialized();

      final android = _android;
      final ios = _ios;

      if (android != null) {
        final enabled =
            await android.areNotificationsEnabled() ?? false;

        if (!enabled) {
          final prefs = await SharedPreferences.getInstance();
          final asked = prefs.getInt(_promptsKey) ?? 0;

          if (asked < 2) {
            await prefs.setInt(_promptsKey, asked + 1);
            await android.requestNotificationsPermission();
          }
        }
      }

      if (ios != null) {
        final prefs = await SharedPreferences.getInstance();
        final asked = prefs.getInt(_promptsKey) ?? 0;

        if (asked == 0) {
          await prefs.setInt(_promptsKey, 1);

          await ios.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Notification permission request failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Checks exact-alarm access and requests it if needed.
  /// The user may need to grant access in Android Settings.
  static Future<bool> requestExactAlarmAccess() async {
    try {
      await _ensureInitialized();

      final android = _android;
      if (android == null) return true;

      var allowed =
          await android.canScheduleExactNotifications() ?? false;

      if (!allowed) {
        debugPrint('Requesting exact-alarm access.');
        await android.requestExactAlarmsPermission();

        // The user may have to return from system Settings before
        // access becomes available.
        allowed =
            await android.canScheduleExactNotifications() ?? false;
      }

      debugPrint('Exact alarm access granted: $allowed');
      return allowed;
    } catch (e, stackTrace) {
      debugPrint('Exact-alarm permission error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Schedules or replaces the OS notification for the rest timer.
  static Future<void> scheduleRestOver(DateTime endTime) async {
    try {
      await _ensureInitialized();

      if (!endTime.isAfter(DateTime.now())) {
        debugPrint(
          'Rest notification not scheduled: end time has passed.',
        );
        await _plugin.cancel(id: _restTimerId);
        return;
      }

      final android = _android;

      var scheduleMode =
          AndroidScheduleMode.inexactAllowWhileIdle;

      if (android != null) {
        final exactAllowed =
            await android.canScheduleExactNotifications() ?? false;

        if (exactAllowed) {
          scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        }
      }

      debugPrint('Scheduling rest notification for $endTime');
      debugPrint('Schedule mode: $scheduleMode');

      await _plugin.zonedSchedule(
        id: _restTimerId,
        title: 'Rest over',
        body: 'Time for your next set',
        scheduledDate: tz.TZDateTime.from(endTime, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: scheduleMode,
      );

      final pending = await pendingRestNotifications();
      debugPrint('Rest notification pending after scheduling: $pending');
    } catch (e, stackTrace) {
      debugPrint('Could not schedule rest notification: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Cancels the rest notification and logs who requested cancellation.
  static Future<void> cancelRestOver() async {
    debugPrint('CANCEL REST NOTIFICATION called.');
    debugPrintStack(
      label: 'Rest notification cancellation caller',
    );

    try {
      await _ensureInitialized();
      await _plugin.cancel(id: _restTimerId);
      debugPrint('Rest notification cancelled.');
    } catch (e, stackTrace) {
      debugPrint('Could not cancel rest notification: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<bool> pendingRestNotifications() async {
    try {
      await _ensureInitialized();

      final pending = await _plugin.pendingNotificationRequests();

      return pending.any(
        (notification) => notification.id == _restTimerId,
      );
    } catch (e, stackTrace) {
      debugPrint('Could not inspect rest notification: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<void> openSystemSettings() async {
    try {
      await _ensureInitialized();
      await _plugin.openAppNotificationSettings();
    } catch (e, stackTrace) {
      debugPrint('Could not open notification settings: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Tests immediate and scheduled notifications.
  static Future<String> runTest() async {
    try {
      await _ensureInitialized();

      final android = _android;

      if (android != null) {
        var enabled =
            await android.areNotificationsEnabled() ?? false;

        if (!enabled) {
          await android.requestNotificationsPermission();
          enabled =
              await android.areNotificationsEnabled() ?? false;
        }

        if (!enabled) {
          return 'Notifications are disabled for RepTracker. '
              'Enable them in your phone settings.';
        }
      }

      final ios = _ios;

      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );

        if (granted != true) {
          return 'Notifications are disabled. Enable them in '
              'Settings > Notifications > RepTracker.';
        }
      }

      await _plugin.show(
        id: _testId,
        title: 'RepTracker',
        body: 'Immediate notifications are working',
        notificationDetails: _details,
      );

      await _plugin.zonedSchedule(
        id: _testId + 1,
        title: 'RepTracker',
        body: 'Scheduled notifications are working',
        scheduledDate: tz.TZDateTime.from(
          DateTime.now().add(const Duration(seconds: 15)),
          tz.UTC,
        ),
        notificationDetails: _details,
        androidScheduleMode:
            AndroidScheduleMode.inexactAllowWhileIdle,
      );

      final pending = await _plugin.pendingNotificationRequests();
      final exact =
          await _android?.canScheduleExactNotifications();

      return 'Immediate notification sent.\n'
          'Scheduled test notification set for 15 seconds later.\n'
          'Pending notifications: ${pending.length}\n'
          'Exact alarms allowed: '
          '${exact == null ? "unknown" : exact ? "yes" : "no"}\n\n'
          'Lock the phone to test scheduled delivery.';
    } catch (e, stackTrace) {
      debugPrint('Notification test failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return 'Notification test failed:\n$e';
    }
  }
}
