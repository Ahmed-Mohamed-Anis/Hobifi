import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class PushNotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // Request permission
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Init local notifications for foreground display
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await _localNotifications.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'hobifi_channel',
              'Hobifi Notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      });

      _initialized = true;
    } catch (e) {
      // Gracefully no-op if Firebase isn't configured
      debugPrint('PushNotificationService: Firebase not configured, skipping. $e');
    }
  }

  static Future<void> registerToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios');
      await SupabaseConfig.client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
      }, onConflict: 'user_id, token');
    } catch (e) {
      debugPrint('PushNotificationService.registerToken: $e');
    }
  }

  static Future<void> unregisterToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await SupabaseConfig.client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
    } catch (e) {
      debugPrint('PushNotificationService.unregisterToken: $e');
    }
  }
}
