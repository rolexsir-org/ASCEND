import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/local_repository.dart';
import '../../domain/models.dart';

enum ReminderKind { morning, evening, weeklyCheckIn, rescan }

class ReminderPreference {
  const ReminderPreference({required this.enabled, required this.hour, required this.minute});
  final bool enabled;
  final int hour;
  final int minute;

  Map<String, Object?> toJson() => {'enabled': enabled, 'hour': hour, 'minute': minute};
  factory ReminderPreference.fromJson(Map<String, Object?> json) => ReminderPreference(
    enabled: json['enabled'] as bool? ?? false,
    hour: ((json['hour'] as num?)?.toInt() ?? 9).clamp(0, 23).toInt(),
    minute: ((json['minute'] as num?)?.toInt() ?? 0).clamp(0, 59).toInt(),
  );
}

class ReminderService {
  ReminderService({required this.repository, FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final LocalRepository repository;
  final FlutterLocalNotificationsPlugin _plugin;
  static const _channelId = 'ascend_routines';
  static const _channelName = 'Routine reminders';
  static const _channelDescription = 'Optional reminders for routines and check-ins.';
  static const Map<ReminderKind, int> _ids = {
    ReminderKind.morning: 401,
    ReminderKind.evening: 402,
    ReminderKind.weeklyCheckIn: 403,
    ReminderKind.rescan: 404,
  };
  bool _initialized = false;
  bool _permissionGranted = false;
  String? initializationError;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
      ));
      _permissionGranted = await android?.areNotificationsEnabled() ?? false;
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      _initialized = true;
    } on PlatformException catch (error) {
      initializationError = error.message ?? 'Notification services are unavailable.';
    } on MissingPluginException {
      initializationError = 'Notification services are unavailable on this build.';
    } on ArgumentError catch (error) {
      initializationError = error.message?.toString() ?? 'Device timezone could not be loaded.';
    } on Object {
      initializationError = 'Optional reminder services could not be initialized.';
      _initialized = false;
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!_initialized) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    _permissionGranted = await android?.requestNotificationsPermission() ?? true;
    return _permissionGranted;
  }

  Future<Map<ReminderKind, ReminderPreference>> loadPreferences() async {
    final raw = await repository.readSetting('reminders');
    final stored = raw?['items'];
    final map = stored is Map ? Map<String, Object?>.from(stored) : <String, Object?>{};
    return {
      for (final kind in ReminderKind.values)
        kind: ReminderPreference.fromJson(
          map[enumName(kind)] is Map
              ? Map<String, Object?>.from(map[enumName(kind)]! as Map)
              : const {},
        ),
    };
  }

  Future<bool> setReminder(
    ReminderKind kind,
    ReminderPreference preference, {
    required bool permissionAlreadyExplained,
  }) async {
    await initialize();
    if (!_initialized) return false;
    if (preference.enabled && !_permissionGranted) {
      if (!permissionAlreadyExplained) return false;
      if (!await requestPermission()) return false;
    }
    if (preference.enabled) {
      await _schedule(kind, preference);
    } else {
      await _plugin.cancel(id: _ids[kind]!);
    }
    final all = await loadPreferences();
    all[kind] = preference;
    await repository.saveSetting('reminders', {
      'items': {for (final entry in all.entries) enumName(entry.key): entry.value.toJson()},
    });
    return true;
  }

  Future<void> restoreScheduledReminders() async {
    await initialize();
    if (!_initialized) return;
    final preferences = await loadPreferences();
    for (final entry in preferences.entries) {
      if (entry.value.enabled) await _schedule(entry.key, entry.value);
    }
  }

  Future<void> cancelAll() async {
    if (_initialized) await _plugin.cancelAll();
  }

  Future<void> _schedule(ReminderKind kind, ReminderPreference preference) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, preference.hour, preference.minute,
    );
    if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));
    final weekly = kind == ReminderKind.weeklyCheckIn || kind == ReminderKind.rescan;
    if (weekly) {
      while (scheduled.weekday != DateTime.sunday) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 7));
    }
    final title = switch (kind) {
      ReminderKind.morning => 'ASCEND morning routine',
      ReminderKind.evening => 'ASCEND evening routine',
      ReminderKind.weeklyCheckIn => 'ASCEND weekly check-in',
      ReminderKind.rescan => 'ASCEND progress check-in',
    };
    await _plugin.zonedSchedule(
      id: _ids[kind]!,
      title: title,
      body: 'Your routine is ready when you are.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: weekly
          ? DateTimeComponents.dayOfWeekAndTime
          : DateTimeComponents.time,
    );
  }
}
