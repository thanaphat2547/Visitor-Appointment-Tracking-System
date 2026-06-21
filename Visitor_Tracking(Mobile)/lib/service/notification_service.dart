import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:beacon_tracking/api_constants.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

Future<String?> _getAnyUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('user_id') ??
      prefs.getString('emp_id') ??
      prefs.getString('vis_id');
}

Future<bool> _shouldShowNotification(RemoteMessage message) async {
  try {
    final currentUser = await _getAnyUserId();
    final targetUser = message.data['user_id'];
    if (targetUser == null || targetUser.isEmpty) return true;
    if (currentUser == null) return false;
    return currentUser == targetUser;
  } catch (e) {
    return false;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!await _shouldShowNotification(message)) return;
  try {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotifications.initialize(const InitializationSettings(android: androidInit));
    const androidDetails = AndroidNotificationDetails(
      'beacon_channel', 'Beacon Notifications',
      channelDescription: 'แจ้งเตือนระบบติดตาม Beacon',
      importance: Importance.max, priority: Priority.high,
      playSound: true, enableVibration: true,
    );
    final title = message.notification?.title ?? message.data['title'] ?? 'แจ้งเตือน';
    final body = message.notification?.body ?? message.data['body'] ?? 'มีการแจ้งเตือนใหม่';
    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body,
      const NotificationDetails(android: androidDetails),
    );
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('unread_notification_count') ?? 0;
    await prefs.setInt('unread_notification_count', currentCount + 1);
  } catch (e) {
    print('❌ Error in background handler: $e');
  }
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;


  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);

  Function()? onNotificationReceived;

  Future<void> init() async {

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

    NotificationSettings settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );

    const channel = AndroidNotificationChannel(
      'beacon_channel', 'Beacon Notifications',
      description: 'แจ้งเตือนระบบติดตาม Beacon',
      importance: Importance.high, playSound: true, enableVibration: true,
    );
    const reminderChannel = AndroidNotificationChannel(
      'reminder_channel', 'Appointment Reminders',
      description: 'แจ้งเตือนล่วงหน้าก่อนนัดหมาย',
      importance: Importance.high, playSound: true, enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(reminderChannel);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (details) => print('📱 Notification tapped'),
    );

    updateTokenAfterLogin();
    _fcm.onTokenRefresh.listen(_saveFcmToken);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    await _loadUnreadCount();
  }

  Future<void> scheduleAppointmentReminders(List<dynamic> bookings) async {
    await _cancelAllReminders();

    int notifId = 1000;
    for (final booking in bookings) {
      final statusStr = booking['bk_status']?.toString() ?? '4';
      if (statusStr == '2' || statusStr == '3' || statusStr == '4') continue;

      final startStr = booking['appointment_start']?.toString();
      if (startStr == null) continue;

      DateTime? appointmentTime;
      try {
        appointmentTime = DateTime.parse(startStr).toLocal();
      } catch (_) {
        continue;
      }

      final now = DateTime.now();
      final visitorName = booking['visitor_name'] ?? 'ผู้มาติดต่อ';
      final buildingName = booking['building_name'] ?? '';

      // 1 day before reminder
      final oneDayBefore = appointmentTime.subtract(const Duration(days: 1));
      if (oneDayBefore.isAfter(now)) {
        await _scheduleLocalNotification(
          id: notifId++,
          title: '📅 แจ้งเตือนนัดหมายพรุ่งนี้',
          body: '$visitorName นัดพรุ่งนี้ ${_formatTime(appointmentTime)}${buildingName.isNotEmpty ? " ที่ $buildingName" : ""}',
          scheduledTime: oneDayBefore,
          channelId: 'reminder_channel',
        );
      }

      // 1 hour before reminder
      final oneHourBefore = appointmentTime.subtract(const Duration(hours: 1));
      if (oneHourBefore.isAfter(now)) {
        await _scheduleLocalNotification(
          id: notifId++,
          title: '⏰ อีก 1 ชั่วโมงถึงเวลานัดหมาย',
          body: '$visitorName${buildingName.isNotEmpty ? " ที่ $buildingName" : ""} เวลา ${_formatTime(appointmentTime)}',
          scheduledTime: oneHourBefore,
          channelId: 'reminder_channel',
        );
      }
    }

    print('✅ Scheduled ${notifId - 1000} reminder notifications');
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m น.';
  }

  Future<void> _scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String channelId = 'beacon_channel',
  }) async {
    try {
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId == 'reminder_channel' ? 'Appointment Reminders' : 'Beacon Notifications',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('⚠️ Schedule notification error: $e');
    }
  }

  Future<void> _cancelAllReminders() async {
    for (int i = 1000; i < 3000; i++) {
      await _localNotifications.cancel(i);
    }
  }

  Future<void> updateTokenAfterLogin() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) await _saveFcmToken(token);
    } catch (e) {
      print('⚠️ Error getting FCM Token: $e');
    }
  }

  Future<void> _loadUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    _unreadCount = prefs.getInt('unread_notification_count') ?? 0;
    notifyListeners();
  }

  Future<void> _incrementUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    _unreadCount++;
    await prefs.setInt('unread_notification_count', _unreadCount);
    notifyListeners();
  }

  Future<void> resetUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    _unreadCount = 0;
    await prefs.setInt('unread_notification_count', 0);
    notifyListeners();
  }

  Future<void> markAllRead() async => await resetUnreadCount();

  void clearAll() {
    _notifications.clear();
    resetUnreadCount();
    notifyListeners();
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await _getAnyUserId();
      final role = prefs.getString('role') ??
          (prefs.getString('emp_id') != null ? 'officer' : 'visitor');
      if (userId == null) return;
      final response = await http.post(
        ApiConstants.savetoken,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'fcm_token': token, 'role': role}),
      );
      if (response.statusCode == 200) print('✅ FCM token saved for $role: $userId');
    } catch (e) {
      print('❌ Error during _saveFcmToken: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!await _shouldShowNotification(message)) return;
    final title = message.notification?.title ?? message.data['title'] ?? 'แจ้งเตือน';
    final body = message.notification?.body ?? message.data['body'] ?? 'มีการแจ้งเตือนใหม่';
    final type = message.data['type'] ?? '';

    const androidDetails = AndroidNotificationDetails(
      'beacon_channel', 'Beacon Notifications',
      importance: Importance.max, priority: Priority.high,
      playSound: true, enableVibration: true,
    );
    await _localNotifications.show(
      message.hashCode, title, body,
      const NotificationDetails(android: androidDetails),
    );

    _notifications.add({
      'title': title,
      'body': body,
      'type': type,
      'bk_id': message.data['bk_id'] ?? message.data['booking_id'] ?? null,
      'receivedAt': DateTime.now(),
    });

    await _incrementUnreadCount();
    if (onNotificationReceived != null) onNotificationReceived!();
    notifyListeners();
  }

  void _handleMessageOpenedApp(RemoteMessage message) async {
    if (!await _shouldShowNotification(message)) return;
    resetUnreadCount();
  }
}